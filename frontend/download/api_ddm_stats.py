# Adicionar ao devices/views.py

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from .models import Device, DeviceInterface
import psutil

@csrf_exempt
def api_interfaces_stats(request):
    """Estatísticas de interfaces e DDM para o Dashboard"""
    try:
        # Total de interfaces
        total_interfaces = DeviceInterface.objects.count()
        
        # Interfaces com transceiver/GBIC
        transceivers = DeviceInterface.objects.filter(has_gbic=True)
        total_transceivers = transceivers.count()
        
        # Calcular médias DDM
        avg_temp = 0
        avg_rx = 0
        avg_tx = 0
        
        if total_transceivers > 0:
            temps = [t.gbic_temperature for t in transceivers if t.gbic_temperature]
            rxs = [t.rx_power for t in transceivers if t.rx_power]
            txs = [t.tx_power for t in transceivers if t.tx_power]
            
            if temps:
                avg_temp = sum(temps) / len(temps)
            if rxs:
                avg_rx = sum(rxs) / len(rxs)
            if txs:
                avg_tx = sum(txs) / len(txs)
        
        # Contar alertas DDM
        critical = 0
        warning = 0
        normal = 0
        issues = []
        
        for t in transceivers:
            status = 'normal'
            
            # Check temperature (normal: <45, warning: 45-55, critical: >55)
            if t.gbic_temperature:
                if t.gbic_temperature > 55:
                    critical += 1
                    status = 'critical'
                    issues.append({
                        'device_name': t.device.name if t.device else 'Unknown',
                        'interface_name': t.if_name,
                        'type': 'temperature',
                        'value': t.gbic_temperature,
                        'status': 'critical',
                        'message': f'Temperatura alta: {t.gbic_temperature:.1f}°C'
                    })
                elif t.gbic_temperature > 45:
                    warning += 1
                    status = 'warning'
                else:
                    normal += 1
            
            # Check Rx power (normal: -3 to -20, warning: -20 to -25, critical: < -25)
            if t.rx_power:
                if t.rx_power < -25:
                    critical += 1
                    issues.append({
                        'device_name': t.device.name if t.device else 'Unknown',
                        'interface_name': t.if_name,
                        'type': 'rx_power',
                        'value': t.rx_power,
                        'status': 'critical',
                        'message': f'Rx Power baixo: {t.rx_power:.2f} dBm'
                    })
                elif t.rx_power < -20:
                    warning += 1
        
        # Interfaces up/down
        interfaces_up = DeviceInterface.objects.filter(oper_status='up').count()
        interfaces_down = DeviceInterface.objects.filter(oper_status='down').count()
        
        return JsonResponse({
            'status': 'success',
            'total_interfaces': total_interfaces,
            'interfaces_with_transceiver': total_transceivers,
            'interfaces_up': interfaces_up,
            'interfaces_down': interfaces_down,
            'total_transceivers': total_transceivers,
            'avg_temperature': avg_temp,
            'avg_rx_power': avg_rx,
            'avg_tx_power': avg_tx,
            'alerts': {
                'critical': critical,
                'warning': warning,
                'normal': normal if normal > 0 else total_transceivers - critical - warning
            },
            'issues': issues[:10]  # Top 10 issues
        })
    except Exception as e:
        return JsonResponse({
            'status': 'error',
            'message': str(e),
            'total_transceivers': 0,
            'avg_temperature': 0,
            'avg_rx_power': 0,
            'avg_tx_power': 0,
            'alerts': {'critical': 0, 'warning': 0, 'normal': 0},
            'issues': []
        })


@csrf_exempt  
def api_dashboard_enhanced(request):
    """Dashboard melhorado com todas as estatísticas"""
    try:
        # Server health
        server_health = {
            'cpu': psutil.cpu_percent(),
            'ram': psutil.virtual_memory().percent,
            'disk': psutil.disk_usage('/').percent
        }
        
        # Device stats
        total_devices = Device.objects.count()
        active_devices = Device.objects.filter(is_active=True).count()
        inactive_devices = total_devices - active_devices
        
        # BRAS stats
        bras_devices = Device.objects.filter(is_bras=True)
        bras_count = bras_devices.count()
        
        # PPPoE (se disponível)
        pppoe_total = 0
        pppoe_details = []
        for bras in bras_devices:
            count = get_pppoe_online(bras) if 'get_pppoe_online' in dir() else 0
            if count and count > 0:
                pppoe_total += count
                pppoe_details.append({
                    'name': bras.name,
                    'ip': bras.ip,
                    'count': count
                })
        
        # Interface stats
        total_interfaces = DeviceInterface.objects.count()
        transceivers = DeviceInterface.objects.filter(has_gbic=True)
        total_transceivers = transceivers.count()
        
        # DDM averages
        avg_temp = 0
        avg_rx = 0
        avg_tx = 0
        ddm_alerts = {'critical': 0, 'warning': 0, 'normal': 0}
        
        if total_transceivers > 0:
            temps = [t.gbic_temperature for t in transceivers if t.gbic_temperature]
            rxs = [t.rx_power for t in transceivers if t.rx_power]
            txs = [t.tx_power for t in transceivers if t.tx_power]
            
            if temps:
                avg_temp = sum(temps) / len(temps)
            if rxs:
                avg_rx = sum(rxs) / len(rxs)
            if txs:
                avg_tx = sum(txs) / len(txs)
            
            # Count alerts
            for t in transceivers:
                if t.gbic_temperature and t.gbic_temperature > 55:
                    ddm_alerts['critical'] += 1
                elif t.gbic_temperature and t.gbic_temperature > 45:
                    ddm_alerts['warning'] += 1
                else:
                    ddm_alerts['normal'] += 1
        
        # Device types
        device_types = {}
        for d in Device.objects.all():
            dtype = d.device_type or 'outro'
            device_types[dtype] = device_types.get(dtype, 0) + 1
        
        return JsonResponse({
            'status': 'success',
            'devices_total': total_devices,
            'active_devices': active_devices,
            'inactive_devices': inactive_devices,
            'bras_count': bras_count,
            'pppoe_total': pppoe_total,
            'pppoe_details': pppoe_details,
            'server_health': server_health,
            'interface_stats': {
                'total_interfaces': total_interfaces,
                'total_transceivers': total_transceivers,
                'avg_temperature': avg_temp,
                'avg_rx_power': avg_rx,
                'avg_tx_power': avg_tx,
                'ddm_alerts': ddm_alerts
            },
            'device_types': device_types
        })
    except Exception as e:
        return JsonResponse({
            'status': 'error',
            'message': str(e)
        })
