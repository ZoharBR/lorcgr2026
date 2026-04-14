from django.core.management.base import BaseCommand
from django.utils import timezone
from equipments.models import Equipment
from api.models import ServiceConfig
import requests

class Command(BaseCommand):
    help = 'Sincroniza equipamentos com LibreNMS e Zabbix'
    
    def handle(self, *args, **options):
        self.stdout.write('Iniciando sincronizacao...')
        
        for eq in Equipment.objects.filter(auto_sync=True, status='active'):
            self.stdout.write(f'Sincronizando {eq.name}...')
            
            result = {'librenms': {}, 'zabbix': {}}
            
            # LibreNMS
            if eq.librenms_id:
                try:
                    cfg = ServiceConfig.objects.get(service_type='librenms')
                    url = f"{cfg.api_url.rstrip('/')}/devices/{eq.librenms_id}"
                    resp = requests.get(url, headers={'X-Auth-Token': cfg.api_key}, timeout=30)
                    if resp.status_code == 200:
                        d = resp.json().get('devices', [{}])[0]
                        eq.hostname = d.get('sysName', eq.hostname)
                        eq.model = d.get('hardware', eq.model)
                        eq.os_version = d.get('version', eq.os_version)
                        eq.serial_number = d.get('serial', eq.serial_number)
                        eq.save()
                        result['librenms'] = {'success': True, 'message': 'Atualizado'}
                except Exception as e:
                    result['librenms'] = {'success': False, 'message': str(e)}
            
            # Zabbix - só cria se não tiver
            if not eq.zabbix_id:
                try:
                    cfg = ServiceConfig.objects.get(service_type='zabbix')
                    auth = requests.post(cfg.api_url, json={
                        "jsonrpc": "2.0", "method": "user.login",
                        "params": {"user": cfg.username, "password": cfg.password}, "id": 1
                    }, headers={'Content-Type': 'application/json'}, timeout=30)
                    token = auth.json().get('result')
                    if token:
                        host = requests.post(cfg.api_url, json={
                            "jsonrpc": "2.0", "method": "host.create",
                            "params": {
                                "host": eq.name, "name": eq.name,
                                "interfaces": [{"type": 1, "main": 1, "useip": 1,
                                    "ip": eq.primary_ip, "dns": "", "port": "161",
                                    "details": {"version": 2, "community": eq.snmp_community or "public"}}],
                                "groups": [{"groupid": "15"}],
                                "templates": [{"templateid": "10081"}]
                            }, "auth": token, "id": 2
                        }, headers={'Content-Type': 'application/json'}, timeout=30)
                        hd = host.json()
                        if 'result' in hd and 'hostids' in hd['result']:
                            eq.zabbix_id = int(hd['result']['hostids'][0])
                            eq.save()
                            result['zabbix'] = {'success': True, 'message': 'Criado'}
                        requests.post(cfg.api_url, json={
                            "jsonrpc": "2.0", "method": "user.logout",
                            "params": [], "auth": token, "id": 3
                        }, headers={'Content-Type': 'application/json'}, timeout=10)
                except Exception as e:
                    result['zabbix'] = {'success': False, 'message': str(e)}
            
            eq.sync_status = {'last_sync': timezone.now().isoformat(), **result}
            eq.save()
        
        self.stdout.write(self.style.SUCCESS('Sincronizacao concluida!'))
