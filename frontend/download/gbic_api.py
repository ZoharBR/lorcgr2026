from django.http import JsonResponse
from django.views.decorators.http import require_http_methods
from django.views.decorators.csrf import csrf_exempt
import json

@csrf_exempt
@require_http_methods(["GET"])
def gbic_list(request):
    """Lista todos os GBICs com dados DDM individuais"""
    from devices.models import DeviceInterface
    
    interfaces = DeviceInterface.objects.filter(has_gbic=True).select_related('device')
    
    gbics = []
    for i in interfaces:
        device_name = i.device.name if i.device else f"Device {i.device_id}"
        
        # Calcular status do GBIC
        status = 'unknown'
        alerts = []
        
        if i.if_oper_status == 'down':
            status = 'down'
            alerts.append('Interface DOWN')
        elif i.gbic_temperature is not None and i.tx_power is not None and i.rx_power is not None:
            # Verificar temperatura
            if i.gbic_temperature > 60:
                status = 'critical'
                alerts.append(f'Temperatura CRITICA: {i.gbic_temperature}C')
            elif i.gbic_temperature > 45:
                status = 'warning'
                alerts.append(f'Temperatura elevada: {i.gbic_temperature}C')
            
            # Verificar RX Power (sinal recebido)
            if i.rx_power < -25:
                status = 'critical' if status != 'critical' else status
                alerts.append(f'RX Power BAIXO (fibra degradada?): {i.rx_power:.2f} dBm')
            elif i.rx_power < -20:
                if status != 'critical':
                    status = 'warning'
                alerts.append(f'RX Power em atencao: {i.rx_power:.2f} dBm')
            
            # Verificar TX Power
            if i.tx_power < -5:
                status = 'critical' if status != 'critical' else status
                alerts.append(f'TX Power BAIXO: {i.tx_power:.2f} dBm')
            elif i.tx_power < 0:
                if status != 'critical':
                    status = 'warning'
                alerts.append(f'TX Power em atencao: {i.tx_power:.2f} dBm')
            
            if not alerts:
                status = 'normal'
        else:
            status = 'no_data'
            alerts.append('Sem dados DDM')
        
        gbics.append({
            'id': i.id,
            'device_id': i.device_id,
            'device_name': device_name,
            'interface': i.if_name,
            'alias': i.if_alias or '',
            'type': i.gbic_type or 'Unknown',
            'vendor': i.gbic_vendor or '',
            'serial': i.gbic_serial or '',
            'temperature': i.gbic_temperature,
            'tx_power': float(i.tx_power) if i.tx_power else None,
            'rx_power': float(i.rx_power) if i.rx_power else None,
            'bias_current': float(i.gbic_bias_current) if i.gbic_bias_current else None,
            'oper_status': i.if_oper_status,
            'status': status,
            'alerts': alerts,
        })
    
    # Ordenar por status (critical primeiro, depois warning, etc)
    status_order = {'critical': 0, 'down': 1, 'warning': 2, 'no_data': 3, 'normal': 4, 'unknown': 5}
    gbics.sort(key=lambda x: status_order.get(x['status'], 5))
    
    return JsonResponse({
        'status': 'success',
        'total': len(gbics),
        'summary': {
            'critical': len([g for g in gbics if g['status'] == 'critical']),
            'warning': len([g for g in gbics if g['status'] == 'warning']),
            'down': len([g for g in gbics if g['status'] == 'down']),
            'normal': len([g for g in gbics if g['status'] == 'normal']),
            'no_data': len([g for g in gbics if g['status'] == 'no_data']),
        },
        'gbics': gbics
    })


@csrf_exempt
@require_http_methods(["GET"])
def gbic_detail(request, gbic_id):
    """Detalhes de um GBIC especifico"""
    from devices.models import DeviceInterface
    
    try:
        i = DeviceInterface.objects.get(id=gbic_id)
        device_name = i.device.name if i.device else f"Device {i.device_id}"
        
        return JsonResponse({
            'status': 'success',
            'gbic': {
                'id': i.id,
                'device_id': i.device_id,
                'device_name': device_name,
                'interface': i.if_name,
                'alias': i.if_alias or '',
                'type': i.gbic_type or 'Unknown',
                'vendor': i.gbic_vendor or '',
                'serial': i.gbic_serial or '',
                'temperature': i.gbic_temperature,
                'tx_power': float(i.tx_power) if i.tx_power else None,
                'rx_power': float(i.rx_power) if i.rx_power else None,
                'bias_current': float(i.gbic_bias_current) if i.gbic_bias_current else None,
                'oper_status': i.if_oper_status,
                'last_updated': i.last_updated.isoformat() if i.last_updated else None,
            }
        })
    except DeviceInterface.DoesNotExist:
        return JsonResponse({'status': 'error', 'message': 'GBIC nao encontrado'}, status=404)
