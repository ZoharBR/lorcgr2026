from rest_framework import viewsets, status
from rest_framework.decorators import action, api_view
from rest_framework.response import Response
from django.http import JsonResponse
from .models import ServiceConfig, SystemSettings, SecurityConfig
from .serializers import ServiceConfigSerializer, SystemSettingsSerializer, SecurityConfigSerializer
import requests

def health(request):
    return JsonResponse({'status': 'ok', 'version': '1.0.0'})

class ServiceConfigViewSet(viewsets.ModelViewSet):
    queryset = ServiceConfig.objects.all()
    serializer_class = ServiceConfigSerializer
    
    @action(detail=True, methods=['post'])
    def test_connection(self, request, pk=None):
        service = self.get_object()
        result = {'success': False, 'message': ''}
        try:
            if service.service_type == 'librenms':
                resp = requests.get(
                    f"{service.api_url}/devices",
                    headers={'X-Auth-Token': service.api_key},
                    timeout=10
                )
                result['success'] = resp.status_code == 200
                result['message'] = 'OK' if result['success'] else f'Erro: {resp.status_code}'
            elif service.service_type == 'phpipam':
                resp = requests.post(
                    f"{service.api_url}/user/",
                    auth=(service.username, service.password),
                    timeout=10
                )
                result['success'] = resp.status_code == 200
                result['message'] = 'OK' if result['success'] else f'Erro: {resp.status_code}'
            elif service.service_type == 'zabbix':
                resp = requests.post(
                    service.api_url,
                    json={"jsonrpc": "2.0", "method": "apiinfo.version", "params": {}, "id": 1},
                    headers={'Content-Type': 'application-json'},
                    timeout=10
                )
                result['success'] = resp.status_code == 200
                result['message'] = 'OK' if result['success'] else f'Erro: {resp.status_code}'
            elif service.service_type == 'grafana':
                resp = requests.get(f"{service.url}/api/health", timeout=10)
                result['success'] = resp.status_code == 200
                result['message'] = 'OK' if result['success'] else f'Erro: {resp.status_code}'
            elif service.service_type == 'nexterm':
                resp = requests.get(f"{service.url}/", timeout=10)
                result['success'] = resp.status_code in [200, 302]
                result['message'] = 'OK' if result['success'] else f'Erro: {resp.status_code}'
        except Exception as e:
            result['message'] = f'Erro: {str(e)}'
        return Response(result)

class SystemSettingsViewSet(viewsets.ModelViewSet):
    queryset = SystemSettings.objects.all()
    serializer_class = SystemSettingsSerializer
    lookup_field = 'key'

@api_view(['GET'])
def dashboard_config(request):
    services = ServiceConfig.objects.filter(enabled=True)
    services_data = ServiceConfigSerializer(services, many=True).data
    settings = {s.key: s.value for s in SystemSettings.objects.all()}
    return Response({'services': services_data, 'settings': settings})


class SecurityConfigViewSet(viewsets.ModelViewSet):
    queryset = SecurityConfig.objects.all()
    serializer_class = SecurityConfigSerializer
    lookup_field = 'config_type'
