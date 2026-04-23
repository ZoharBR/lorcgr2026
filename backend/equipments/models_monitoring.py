from django.db import models
from django.utils import timezone
from equipments.models import Equipment


class EquipmentStatus(models.Model):
    """Status real-time de equipamentos via ICMP"""
    
    STATUS_CHOICES = [
        ('online', 'Online'),
        ('degraded', 'Degraded'),
        ('offline', 'Offline'),
    ]
    
    equipment = models.OneToOneField(
        Equipment, 
        on_delete=models.CASCADE, 
        related_name='realtime_status'
    )
    status = models.CharField(
        max_length=10, 
        choices=STATUS_CHOICES, 
        default='offline'
    )
    latency_ms = models.FloatField(null=True, blank=True)
    packet_loss = models.IntegerField(default=0)  # Percentual 0-100
    last_check = models.DateTimeField(auto_now=True)
    last_success = models.DateTimeField(null=True, blank=True)
    consecutive_failures = models.IntegerField(default=0)
    is_flashing = models.BooleanField(default=False)  # Para animação offline
    
    class Meta:
        verbose_name = "Equipment Real-time Status"
        verbose_name_plural = "Equipment Real-time Statuses"
        ordering = ['-last_check']
    
    def __str__(self):
        return f"{self.equipment.name} - {self.status} ({self.latency_ms or 0}ms)"
    
    def get_color_class(self):
        """Retorna classe CSS baseada no status/latência"""
        if self.status == 'offline':
            return 'status-offline'  # Vermelho piscando
        elif self.status == 'degraded':
            return 'status-degraded'  # Laranja
        else:
            return 'status-online'  # Verde
    
    @property
    def uptime_percentage(self):
        """Calcula uptime baseado nos últimos checks"""
        # Implementar lógica de histórico se necessário
        return 100 if self.status != 'offline' else 0


class PingHistory(models.Model):
    """Histórico de pings para gráficos"""
    
    equipment = models.ForeignKey(
        Equipment, 
        on_delete=models.CASCADE, 
        related_name='ping_history'
    )
    timestamp = models.DateTimeField(auto_now_add=True)
    latency_ms = models.FloatField()
    success = models.BooleanField(default=True)
    
    class Meta:
        ordering = ['-timestamp']
        indexes = [
            models.Index(fields=['equipment', 'timestamp']),
        ]
    
    def __str__(self):
        return f"{self.equipment.name} - {self.latency_ms}ms at {self.timestamp}"
