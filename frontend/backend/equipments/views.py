from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from .models import Equipment, EquipmentInterface, SyncLog
from .serializers import EquipmentSerializer, EquipmentListSerializer, EquipmentInterfaceSerializer, SyncLogSerializer
from api.models import ServiceConfig
import requests
import json
import time

class EquipmentViewSet(viewsets.ModelViewSet):
    queryset = Equipment.objects.all()
    
    def get_serializer_class(self):
        if self.action == 'list':
            return EquipmentListSerializer
        return EquipmentSerializer
    
    def perform_create(self, serializer):
        user = self.request.user if hasattr(self.request, 'user') and self.request.user.is_authenticated else None
        serializer.save(created_by=user)
    
    @action(detail=False, methods=['get'])
    def by_status(self, request):
        status_filter = request.query_params.get('status', 'active')
        equipments = Equipment.objects.filter(status=status_filter)
        serializer = EquipmentListSerializer(equipments, many=True)
        return Response(serializer.data)
    
    @action(detail=True, methods=['post'])
    def sync_to_librenms(self, request, pk=None):
        equipment = self.get_object()
        try:
            config = ServiceConfig.objects.get(service_type='librenms')
        except ServiceConfig.DoesNotExist:
            return Response({'error': 'LibreNMS nao configurado'}, status=400)
        
        result = {'success': False, 'message': '', 'librenms_id': None, 'discovered': {}}
        
        try:
            url = config.api_url.rstrip('/') + '/devices'
            headers = {'X-Auth-Token': config.api_key}
            
            data = {
                'hostname': equipment.primary_ip,
                'display': equipment.name,
                'snmpver': equipment.snmp_version or 'v2c',
                'community': equipment.snmp_community or 'public',
                'port': 161,
            }
            
            resp = requests.post(url, headers=headers, json=data, timeout=60)
            
            if resp.status_code in [200, 201]:
                result_data = resp.json()
                device_id = result_data.get('devices', [{}])[0].get('device_id') if 'devices' in result_data else None
                
                if device_id:
                    equipment.librenms_id = device_id
                    result['librenms_id'] = device_id
                    time.sleep(5)
                    
                    discover_url = config.api_url.rstrip('/') + '/devices/' + str(device_id)
                    discover_resp = requests.get(discover_url, headers=headers, timeout=30)
                    
                    if discover_resp.status_code == 200:
                        d = discover_resp.json().get('devices', [{}])[0]
                        equipment.hostname = d.get('sysName', equipment.hostname)
                        equipment.model = d.get('hardware', equipment.model)
                        equipment.os_version = d.get('version', equipment.os_version)
                        equipment.serial_number = d.get('serial', equipment.serial_number)
                        equipment.save()
                        result['success'] = True
                        result['discovered'] = {'hostname': equipment.hostname, 'model': equipment.model, 'os_version': equipment.os_version}
                        
            elif resp.status_code == 409:
                result['success'] = True
                result['message'] = 'Ja existe no LibreNMS'
                if equipment.librenms_id:
                    result['librenms_id'] = equipment.librenms_id
                    
        except Exception as e:
            result['message'] = str(e)
        
        return Response(result)
    
    @action(detail=True, methods=['post'])
    def sync_to_zabbix(self, request, pk=None):
        equipment = self.get_object()
        try:
            config = ServiceConfig.objects.get(service_type='zabbix')
        except ServiceConfig.DoesNotExist:
            return Response({'error': 'Zabbix nao configurado'}, status=400)
        
        result = {'success': False, 'message': '', 'zabbix_id': None}
        
        try:
            # Login Zabbix 7.0 - usa 'username' nao 'user'
            auth_resp = requests.post(config.api_url, json={
                "jsonrpc": "2.0", "method": "user.login",
                "params": {"username": config.username, "password": config.password},
                "id": 1
            }, headers={'Content-Type': 'application/json'}, timeout=30)
            
            token = auth_resp.json().get('result')
            if not token:
                return Response({'error': 'Erro autenticacao Zabbix', 'details': auth_resp.json()})
            
            # Criar host
            host_resp = requests.post(config.api_url, json={
                "jsonrpc": "2.0", "method": "host.create",
                "params": {
                    "host": equipment.name,
                    "name": equipment.name,
                    "interfaces": [{
                        "type": 1, "main": 1, "useip": 1,
                        "ip": equipment.primary_ip, "dns": "", "port": "161",
                        "details": {"version": 2, "community": equipment.snmp_community or "public"}
                    }],
                    "groups": [{"groupid": "22"}],
                    "templates": [{"templateid": "10081"}]
                },
                "auth": token, "id": 2
            }, headers={'Content-Type': 'application/json'}, timeout=30)
            
            host_data = host_resp.json()
            if 'result' in host_data and 'hostids' in host_data['result']:
                equipment.zabbix_id = int(host_data['result']['hostids'][0])
                equipment.save()
                result['success'] = True
                result['zabbix_id'] = equipment.zabbix_id
                result['message'] = 'Host criado no Zabbix'
            else:
                result['message'] = str(host_data)
            
            # Logout
            requests.post(config.api_url, json={
                "jsonrpc": "2.0", "method": "user.logout", "params": [],
                "auth": token, "id": 3
            }, headers={'Content-Type': 'application/json'}, timeout=10)
            
        except Exception as e:
            result['message'] = str(e)
        
        return Response(result)
    
    @action(detail=True, methods=['post'])
    def sync_all(self, request, pk=None):
        equipment = self.get_object()
        results = {
            'librenms': self.sync_to_librenms(request, pk=pk).data,
            'zabbix': self.sync_to_zabbix(request, pk=pk).data,
        }
        equipment.sync_status = results
        equipment.save()
        return Response(results)


    @action(detail=False, methods=['post'])
    def sync_all_devices(self, request):
        """Sincroniza todos os equipamentos com LibreNMS e Zabbix"""
        results = []
        
        for equipment in Equipment.objects.all():
            eq_result = {'id': equipment.id, 'name': equipment.name}
            
            # Sync LibreNMS
            try:
                config = ServiceConfig.objects.get(service_type='librenms')
                url = config.api_url.rstrip('/') + '/devices'
                headers = {'X-Auth-Token': config.api_key}
                data = {
                    'hostname': equipment.primary_ip,
                    'display': equipment.name,
                    'snmpver': equipment.snmp_version or 'v2c',
                    'community': equipment.snmp_community or 'public',
                    'port': 161,
                }
                resp = requests.post(url, headers=headers, json=data, timeout=60)
                if resp.status_code in [200, 201, 409]:
                    eq_result['librenms'] = {'success': True, 'message': 'Sincronizado'}
                else:
                    eq_result['librenms'] = {'success': False, 'message': str(resp.text[:100])}
            except Exception as e:
                eq_result['librenms'] = {'success': False, 'error': str(e)[:100]}
            
            # Sync Zabbix
            try:
                config = ServiceConfig.objects.get(service_type='zabbix')
                auth_resp = requests.post(config.api_url, json={
                    "jsonrpc": "2.0", "method": "user.login",
                    "params": {"username": config.username, "password": config.password},
                    "id": 1
                }, headers={'Content-Type': 'application/json'}, timeout=30)
                token = auth_resp.json().get('result')
                
                if token and equipment.zabbix_id:
                    eq_result['zabbix'] = {'success': True, 'message': 'Ja existe', 'zabbix_id': equipment.zabbix_id}
                elif token:
                    host_resp = requests.post(config.api_url, json={
                        "jsonrpc": "2.0", "method": "host.create",
                        "params": {
                            "host": equipment.name,
                            "name": equipment.name,
                            "interfaces": [{
                                "type": 2, "main": 1, "useip": 1,
                                "ip": equipment.primary_ip, "dns": "", "port": "161",
                                "details": {"version": "2", "bulk": "1", "community": equipment.snmp_community or "public"}
                            }],
                            "groups": [{"groupid": "22"}],
                            "templates": [{"templateid": "10229"}]
                        },
                        "auth": token, "id": 2
                    }, headers={'Content-Type': 'application/json'}, timeout=30)
                    host_data = host_resp.json()
                    if 'result' in host_data:
                        eq_result['zabbix'] = {'success': True, 'message': 'Criado'}
                    else:
                        eq_result['zabbix'] = {'success': False, 'message': str(host_data.get('error', host_data))[:100]}
                else:
                    eq_result['zabbix'] = {'success': False, 'message': 'Erro auth Zabbix'}
            except Exception as e:
                eq_result['zabbix'] = {'success': False, 'error': str(e)[:100]}
            
            results.append(eq_result)
        
        return Response({'success': True, 'results': results, 'count': len(results)})


    @action(detail=False, methods=['get'])
    def discover_from_ip(self, request):
        """Busca informações de um IP no LibreNMS"""
        ip = request.query_params.get('ip')
        if not ip:
            return Response({'error': 'IP obrigatorio'}, status=400)
        
        try:
            config = ServiceConfig.objects.get(service_type='librenms')
        except ServiceConfig.DoesNotExist:
            return Response({'error': 'LibreNMS nao configurado'}, status=400)
        
        try:
            # Buscar dispositivo por IP no LibreNMS
            url = f"{config.api_url.rstrip('/')}/devices/{ip}"
            headers = {'X-Auth-Token': config.api_key}
            
            resp = requests.get(url, headers=headers, timeout=30)
            
            if resp.status_code == 200:
                data = resp.json()
                device = data.get('devices', [{}])[0] if 'devices' in data else {}
                
                result = {
                    'found': True,
                    'librenms_id': device.get('device_id'),
                    'hostname': device.get('sysName', ''),
                    'name': device.get('display', device.get('sysName', '')),
                    'ip': device.get('hostname', ip),
                    'vendor': '',
                    'model': device.get('hardware', ''),
                    'os_version': device.get('version', ''),
                    'serial_number': device.get('serial', ''),
                    'snmp_community': 'public',
                    'status': 'active' if device.get('status', '') == '1' else 'inactive',
                }
                
                # Detectar vendor pelo sysDescr ou hardware
                sysdescr = device.get('sysDescr', '').lower()
                hardware = device.get('hardware', '').lower()
                
                if 'huawei' in sysdescr or 'huawei' in hardware:
                    result['vendor'] = 'huawei'
                elif 'cisco' in sysdescr or 'cisco' in hardware:
                    result['vendor'] = 'cisco'
                elif 'mikrotik' in sysdescr or 'mikrotik' in hardware:
                    result['vendor'] = 'mikrotik'
                elif 'juniper' in sysdescr or 'juniper' in hardware:
                    result['vendor'] = 'juniper'
                elif 'aruba' in sysdescr or 'aruba' in hardware or 'procurve' in sysdescr:
                    result['vendor'] = 'aruba'
                elif 'ubiquiti' in sysdescr or 'ubiquiti' in hardware:
                    result['vendor'] = 'ubiquiti'
                elif 'fortinet' in sysdescr or 'forti' in hardware:
                    result['vendor'] = 'fortinet'
                elif 'linux' in sysdescr:
                    result['vendor'] = 'linux'
                else:
                    result['vendor'] = 'other'
                
                return Response(result)
            else:
                return Response({'found': False, 'error': 'Dispositivo nao encontrado no LibreNMS'})
                
        except Exception as e:
            return Response({'found': False, 'error': str(e)})

    @action(detail=False, methods=['get'])
    def import_from_librenms(self, request):
        """Importa todos os dispositivos do LibreNMS"""
        try:
            config = ServiceConfig.objects.get(service_type='librenms')
        except ServiceConfig.DoesNotExist:
            return Response({'error': 'LibreNMS nao configurado'}, status=400)
        
        try:
            url = f"{config.api_url.rstrip('/')}/devices"
            headers = {'X-Auth-Token': config.api_key}
            
            resp = requests.get(url, headers=headers, timeout=60)
            
            if resp.status_code == 200:
                data = resp.json()
                devices = data.get('devices', [])
                
                imported = []
                skipped = []
                
                for device in devices:
                    # Verificar se já existe
                    ip = device.get('hostname', '')
                    name = device.get('display', device.get('sysName', ip))
                    
                    if Equipment.objects.filter(primary_ip=ip).exists():
                        skipped.append({'ip': ip, 'name': name, 'reason': 'IP ja existe'})
                        continue
                    
                    if Equipment.objects.filter(name=name).exists():
                        skipped.append({'ip': ip, 'name': name, 'reason': 'Nome ja existe'})
                        continue
                    
                    # Detectar vendor
                    sysdescr = device.get('sysDescr', '').lower()
                    hardware = device.get('hardware', '').lower()
                    vendor = 'other'
                    
                    if 'huawei' in sysdescr or 'huawei' in hardware:
                        vendor = 'huawei'
                    elif 'cisco' in sysdescr or 'cisco' in hardware:
                        vendor = 'cisco'
                    elif 'mikrotik' in sysdescr or 'mikrotik' in hardware:
                        vendor = 'mikrotik'
                    elif 'juniper' in sysdescr or 'juniper' in hardware:
                        vendor = 'juniper'
                    elif 'aruba' in sysdescr or 'aruba' in hardware:
                        vendor = 'aruba'
                    elif 'ubiquiti' in sysdescr or 'ubiquiti' in hardware:
                        vendor = 'ubiquiti'
                    elif 'fortinet' in sysdescr or 'forti' in hardware:
                        vendor = 'fortinet'
                    elif 'linux' in sysdescr:
                        vendor = 'linux'
                    
                    # Detectar tipo
                    device_type = 'other'
                    if 'router' in sysdescr or 'bras' in name.lower():
                        device_type = 'router'
                    elif 'switch' in sysdescr or 'switch' in name.lower():
                        device_type = 'switch'
                    elif 'firewall' in sysdescr:
                        device_type = 'firewall'
                    elif 'server' in name.lower():
                        device_type = 'server'
                    
                    # Criar equipamento
                    eq = Equipment.objects.create(
                        name=name[:100],
                        hostname=device.get('sysName', '')[:255],
                        primary_ip=ip,
                        librenms_id=device.get('device_id'),
                        vendor=vendor,
                        model=device.get('hardware', '')[:100],
                        os_version=device.get('version', '')[:100],
                        serial_number=device.get('serial', '')[:100],
                        snmp_community='public',
                        snmp_version='v2c',
                        device_type=device_type,
                        status='active' if device.get('status') == '1' else 'inactive',
                    )
                    imported.append({'id': eq.id, 'name': eq.name, 'ip': eq.primary_ip})
                
                return Response({
                    'success': True,
                    'imported': imported,
                    'skipped': skipped,
                    'total_imported': len(imported),
                    'total_skipped': len(skipped)
                })
            else:
                return Response({'error': 'Erro ao buscar dispositivos do LibreNMS'}, status=400)
                
        except Exception as e:
            return Response({'error': str(e)}, status=500)



    @action(detail=False, methods=['get'])
    def server_health(self, request):
        """Retorna saúde do servidor LOR-CGR"""
        import psutil
        import platform
        from datetime import datetime, timedelta
        
        try:
            # CPU
            cpu_percent = psutil.cpu_percent(interval=1)
            cpu_cores = psutil.cpu_count()
            cpu_freq = psutil.cpu_freq()
            
            # Memória
            memory = psutil.virtual_memory()
            swap = psutil.swap_memory()
            
            # Disco
            disk = psutil.disk_usage('/')
            disk_io = psutil.disk_io_counters()
            
            # Rede
            net_io = psutil.net_io_counters()
            
            # Uptime
            boot_time = datetime.fromtimestamp(psutil.boot_time())
            uptime = datetime.now() - boot_time
            
            # Processos
            process_count = len(psutil.pids())
            
            return Response({
                'cpu': {
                    'percent': round(cpu_percent, 1),
                    'cores': cpu_cores,
                    'freq_mhz': round(cpu_freq.current, 0) if cpu_freq else 0,
                },
                'memory': {
                    'total_gb': round(memory.total / (1024**3), 2),
                    'used_gb': round(memory.used / (1024**3), 2),
                    'percent': round(memory.percent, 1),
                    'available_gb': round(memory.available / (1024**3), 2),
                },
                'swap': {
                    'total_gb': round(swap.total / (1024**3), 2),
                    'used_gb': round(swap.used / (1024**3), 2),
                    'percent': round(swap.percent, 1),
                },
                'disk': {
                    'total_gb': round(disk.total / (1024**3), 2),
                    'used_gb': round(disk.used / (1024**3), 2),
                    'percent': round(disk.percent, 1),
                    'free_gb': round(disk.free / (1024**3), 2),
                    'read_mb': round(disk_io.read_bytes / (1024**2), 2) if disk_io else 0,
                    'write_mb': round(disk_io.write_bytes / (1024**2), 2) if disk_io else 0,
                },
                'network': {
                    'sent_mb': round(net_io.bytes_sent / (1024**2), 2),
                    'recv_mb': round(net_io.bytes_recv / (1024**2), 2),
                    'packets_sent': net_io.packets_sent,
                    'packets_recv': net_io.packets_recv,
                },
                'uptime': {
                    'days': uptime.days,
                    'hours': uptime.seconds // 3600,
                    'minutes': (uptime.seconds % 3600) // 60,
                    'formatted': str(uptime).split('.')[0],
                },
                'system': {
                    'hostname': platform.node(),
                    'os': platform.system(),
                    'os_version': platform.version(),
                    'python_version': platform.python_version(),
                },
                'process_count': process_count,
                'timestamp': datetime.now().isoformat(),
            })
        except Exception as e:
            return Response({'error': str(e)}, status=500)


class EquipmentInterfaceViewSet(viewsets.ModelViewSet):
    queryset = EquipmentInterface.objects.all()
    serializer_class = EquipmentInterfaceSerializer

class SyncLogViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = SyncLog.objects.all()
