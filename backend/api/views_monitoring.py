from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django.utils import timezone
from datetime import timedelta
from equipments.models import EquipmentStatus, PingHistory
from equipments.models import Equipment


class EquipmentMonitoringViewSet(viewsets.ViewSet):
    """API para monitoramento real-time de equipamentos"""
    
    @action(detail=False, methods=['get'])
    def all_status(self, request):
        """Retorna status atual de todos equipamentos"""
        statuses = EquipmentStatus.objects.select_related('equipment').all()
        
        data = []
        for s in statuses:
            data.append({
                'id': s.equipment.id,
                'name': s.equipment.name,
                'primary_ip': str(s.equipment.primary_ip),
                'device_type': s.equipment.device_type,
                'vendor': s.equipment.vendor,
                'status': s.status,
                'latency_ms': s.latency_ms,
                'packet_loss': s.packet_loss,
                'last_check': s.last_check.isoformat() if s.last_check else None,
                'last_success': s.last_success.isoformat() if s.last_success else None,
                'is_flashing': s.is_flashing,
                'color_class': s.get_color_class(),
            })
        
        return Response({
            'success': True,
            'count': len(data),
            'data': data,
            'timestamp': timezone.now().isoformat()
        })
    
    @action(detail=False, methods=['get'])
    def summary(self, request):
        """Resumo para Dashboard"""
        total = EquipmentStatus.objects.count()
        online = EquipmentStatus.objects.filter(status='online').count()
        degraded = EquipmentStatus.objects.filter(status='degraded').count()
        offline = EquipmentStatus.objects.filter(status='offline').count()
        
        return Response({
            'success': True,
            'summary': {
                'total': total,
                'online': online,
                'degraded': degraded,
                'offline': offline,
                'uptime_percentage': round((online / total * 100) if total > 0 else 0, 2)
            }
        })
    
    @action(detail=True, methods=['get'])
    def history(self, request, pk=None):
        """Histórico de pings de um equipamento (últimas 24h)"""
        try:
            equipment = Equipment.objects.get(pk=pk)
        except Equipment.DoesNotExist:
            return Response(
                {'success': False, 'error': 'Equipamento não encontrado'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        since = timezone.now() - timedelta(hours=24)
        history = PingHistory.objects.filter(
            equipment=equipment,
            timestamp__gte=since
        ).order_by('timestamp')[:500]
        
        data = [{
            'timestamp': h.timestamp.isoformat(),
            'latency_ms': h.latency_ms,
            'success': h.success
        } for h in history]
        
        return Response({
            'success': True,
            'equipment_id': pk,
            'equipment_name': equipment.name,
            'period_hours': 24,
            'points_count': len(data),
            'data': data
        })
