from django.db import models
from django.contrib.auth.models import User

class Equipment(models.Model):
    """Modelo principal de equipamentos"""
    
    DEVICE_TYPES = [
        ('router', 'Router'),
        ('switch', 'Switch'),
        ('firewall', 'Firewall'),
        ('server', 'Server'),
        ('ap', 'Access Point'),
        ('printer', 'Printer'),
        ('phone', 'IP Phone'),
        ('camera', 'IP Camera'),
        ('storage', 'Storage'),
        ('ups', 'UPS'),
        ('other', 'Other'),
    ]
    
    VENDOR_CHOICES = [
        ('cisco', 'Cisco'),
        ('juniper', 'Juniper'),
        ('huawei', 'Huawei'),
        ('mikrotik', 'MikroTik'),
        ('aruba', 'Aruba/HPE'),
        ('dell', 'Dell'),
        ('hp', 'HP/Procurve'),
        ('fortinet', 'Fortinet'),
        ('paloalto', 'Palo Alto'),
        ('ubiquiti', 'Ubiquiti'),
        ('linux', 'Linux'),
        ('windows', 'Windows'),
        ('other', 'Other'),
    ]
    
    STATUS_CHOICES = [
        ('active', 'Active'),
        ('inactive', 'Inactive'),
        ('maintenance', 'Maintenance'),
        ('offline', 'Offline'),
    ]
    
    # Campos básicos
    name = models.CharField(max_length=100, unique=True)
    hostname = models.CharField(max_length=255, blank=True)
    device_type = models.CharField(max_length=20, choices=DEVICE_TYPES, default='other')
    vendor = models.CharField(max_length=20, choices=VENDOR_CHOICES, default='other')
    model = models.CharField(max_length=100, blank=True)
    serial_number = models.CharField(max_length=100, blank=True)
    
    # Rede
    primary_ip = models.GenericIPAddressField(blank=True, null=True)
    primary_ip_id = models.IntegerField(blank=True, null=True)
    management_ip = models.GenericIPAddressField(blank=True, null=True)
    mac_address = models.CharField(max_length=17, blank=True)
    
    # Localização
    location = models.CharField(max_length=100, blank=True)
    site = models.CharField(max_length=100, blank=True)
    rack = models.CharField(max_length=50, blank=True)
    position = models.CharField(max_length=20, blank=True)
    
    # SNMP
    snmp_version = models.CharField(max_length=5, choices=[('v1', 'v1'), ('v2c', 'v2c'), ('v3', 'v3')], blank=True, default='v2c')
    snmp_community = models.CharField(max_length=100, blank=True, default='public')
    snmp_username = models.CharField(max_length=100, blank=True)
    snmp_auth_password = models.CharField(max_length=100, blank=True)
    snmp_priv_password = models.CharField(max_length=100, blank=True)
    snmp_auth_protocol = models.CharField(max_length=10, blank=True, choices=[('MD5', 'MD5'), ('SHA', 'SHA')])
    snmp_priv_protocol = models.CharField(max_length=10, blank=True, choices=[('DES', 'DES'), ('AES', 'AES')])
    
    # SSH/Telnet
    ssh_username = models.CharField(max_length=100, blank=True)
    ssh_password = models.CharField(max_length=255, blank=True)
    ssh_port = models.IntegerField(default=22)
    enable_password = models.CharField(max_length=255, blank=True)
    
    # Informações coletadas
    os_version = models.CharField(max_length=100, blank=True)
    firmware_version = models.CharField(max_length=100, blank=True)
    uptime = models.CharField(max_length=100, blank=True)
    interfaces_count = models.IntegerField(default=0)
    last_polled = models.DateTimeField(blank=True, null=True)
    
    # Status
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='active')
    description = models.TextField(blank=True)
    
    # Integrações - IDs externos
    librenms_id = models.IntegerField(blank=True, null=True)
    zabbix_id = models.IntegerField(blank=True, null=True)
    phpipam_id = models.IntegerField(blank=True, null=True)
    
    # Controle
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    auto_sync = models.BooleanField(default=True)
    sync_status = models.JSONField(default=dict, blank=True)
    
    class Meta:
        ordering = ['name']
    
    def __str__(self):
        return self.name


class EquipmentInterface(models.Model):
    """Interfaces de rede"""
    equipment = models.ForeignKey(Equipment, on_delete=models.CASCADE, related_name='interfaces')
    name = models.CharField(max_length=100)
    description = models.CharField(max_length=255, blank=True)
    if_type = models.CharField(max_length=50, blank=True)
    mac_address = models.CharField(max_length=17, blank=True)
    ip_address = models.GenericIPAddressField(blank=True, null=True)
    ip_address_id = models.IntegerField(blank=True, null=True)
    netmask = models.CharField(max_length=20, blank=True)
    speed = models.CharField(max_length=20, blank=True)
    status = models.CharField(max_length=20, choices=[('up', 'Up'), ('down', 'Down'), ('admin_down', 'Admin Down')], default='down')
    vlan_id = models.IntegerField(blank=True, null=True)
    phpipam_id = models.IntegerField(blank=True, null=True)
    
    class Meta:
        unique_together = ['equipment', 'name']
    
    def __str__(self):
        return f"{self.equipment.name} - {self.name}"


class SyncLog(models.Model):
    """Log de sincronização"""
    equipment = models.ForeignKey(Equipment, on_delete=models.CASCADE, related_name='sync_logs')
    system = models.CharField(max_length=50)
    action = models.CharField(max_length=50)
    status = models.CharField(max_length=20, choices=[('success', 'Success'), ('error', 'Error'), ('partial', 'Partial')])
    message = models.TextField(blank=True)
    external_id = models.CharField(max_length=100, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        ordering = ['-created_at']

# Importar modelos de monitoramento (no final do arquivo)
from .models_monitoring import EquipmentStatus, PingHistory
