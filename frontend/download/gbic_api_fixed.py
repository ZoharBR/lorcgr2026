"""
GBIC API - Complete Fixed Version
Copy to: /opt/lorcgr/devices/gbic_api.py
"""
from rest_framework.decorators import api_view
from django.http import JsonResponse
from django.db.models import Q
from devices.models import Device, DeviceInterface


@api_view(['GET'])
def gbic_list(request):
    """List all GBICs with DDM data"""
    try:
        hide_no_data = request.GET.get('hide_no_data', 'false').lower() == 'true'
        
        # Query interfaces that have GBIC data
        interfaces = DeviceInterface.objects.filter(
            has_gbic=True
        ).select_related('device')
        
        gbics = []
        summary = {'critical': 0, 'warning': 0, 'down': 0, 'normal': 0}
        
        for iface in interfaces:
            # Skip if no data and hide_no_data is true
            if hide_no_data:
                temp = iface.gbic_temperature
                tx = iface.tx_power
                rx = iface.rx_power
                if temp is None and tx is None and rx is None:
                    continue
            
            # Determine status
            status = 'normal'
            alerts = []
            
            # Check interface status first
            if iface.if_oper_status and iface.if_oper_status.lower() in ['down', 'lowerlayerdown']:
                status = 'down'
                alerts.append('Interface DOWN')
            
            temp = iface.gbic_temperature
            tx = iface.tx_power
            rx = iface.rx_power
            
            # Temperature checks
            if temp is not None:
                if temp > 60:
                    status = 'critical'
                    alerts.append(f'Temperatura CRITICA: {temp}C')
                elif temp > 45:
                    if status != 'critical':
                        status = 'warning'
                    alerts.append(f'Temperatura elevada: {temp}C')
            
            # TX Power checks
            if tx is not None:
                if tx < -10:
                    if status not in ['critical']:
                        status = 'critical'
                    alerts.append(f'TX Power muito baixo: {tx}dBm')
                elif tx < 0:
                    if status == 'normal':
                        status = 'warning'
                    alerts.append(f'TX Power baixo: {tx}dBm')
            
            # RX Power checks
            if rx is not None:
                if rx < -25:
                    if status not in ['critical']:
                        status = 'critical'
                    alerts.append(f'RX Power muito baixo: {rx}dBm')
                elif rx < -20:
                    if status == 'normal':
                        status = 'warning'
                    alerts.append(f'RX Power baixo: {rx}dBm')
            
            gbics.append({
                'id': iface.id,
                'device_id': iface.device_id,
                'device_name': iface.device.name if iface.device else 'Unknown',
                'device_ip': iface.device.ip if iface.device else '',
                'interface': iface.if_name or '',
                'description': iface.if_description or '',
                'temperature': temp,
                'tx_power': tx,
                'rx_power': rx,
                'status': status,
                'alerts': alerts,
                'oper_status': iface.if_oper_status or 'unknown',
            })
            
            # Update summary
            if status in summary:
                summary[status] += 1
        
        return JsonResponse({
            'status': 'success',
            'total': len(gbics),
            'summary': summary,
            'gbics': gbics
        })
        
    except Exception as e:
        return JsonResponse({
            'status': 'error',
            'message': str(e),
            'total': 0,
            'summary': {'critical': 0, 'warning': 0, 'down': 0, 'normal': 0},
            'gbics': []
        }, status=500)


@api_view(['GET'])
def gbic_detail(request, gbic_id):
    """Get detailed GBIC data including history"""
    try:
        iface = DeviceInterface.objects.filter(id=gbic_id).select_related('device').first()
        
        if not iface:
            return JsonResponse({'status': 'error', 'message': 'GBIC not found'}, status=404)
        
        return JsonResponse({
            'status': 'success',
            'gbic': {
                'id': iface.id,
                'device_id': iface.device_id,
                'device_name': iface.device.name if iface.device else 'Unknown',
                'device_ip': iface.device.ip if iface.device else '',
                'interface': iface.if_name or '',
                'description': iface.if_description or '',
                'temperature': iface.gbic_temperature,
                'tx_power': iface.tx_power,
                'rx_power': iface.rx_power,
                'oper_status': iface.if_oper_status or 'unknown',
            }
        })
        
    except Exception as e:
        return JsonResponse({'status': 'error', 'message': str(e)}, status=500)
