from django.contrib import admin
from .models import Equipment, EquipmentInterface, SyncLog

class EquipmentInterfaceInline(admin.TabularInline):
    model = EquipmentInterface
    extra = 1
    fields = ['name', 'description', 'ip_address', 'mac_address', 'status', 'vlan_id']

class SyncLogInline(admin.TabularInline):
    model = SyncLog
    extra = 0
    readonly_fields = ['system', 'action', 'status', 'message', 'external_id', 'created_at']
    can_delete = False

@admin.register(Equipment)
class EquipmentAdmin(admin.ModelAdmin):
    list_display = ['name', 'hostname', 'device_type', 'vendor', 'primary_ip', 'status', 'librenms_id', 'zabbix_id']
    list_filter = ['device_type', 'vendor', 'status', 'auto_sync']
    search_fields = ['name', 'hostname', 'primary_ip', 'serial_number']
    readonly_fields = ['created_at', 'updated_at', 'last_polled', 'librenms_id', 'zabbix_id', 'phpipam_id', 'sync_status']
    inlines = [EquipmentInterfaceInline, SyncLogInline]
    
    fieldsets = (
        ('Informações Básicas', {
            'fields': ('name', 'hostname', 'device_type', 'vendor', 'model', 'serial_number', 'description')
        }),
        ('Rede', {
            'fields': ('primary_ip', 'management_ip', 'mac_address')
        }),
        ('Localização', {
            'fields': ('location', 'site', 'rack', 'position')
        }),
        ('SNMP', {
            'fields': ('snmp_version', 'snmp_community', 'snmp_username', 
                      'snmp_auth_password', 'snmp_auth_protocol',
                      'snmp_priv_password', 'snmp_priv_protocol')
        }),
        ('SSH/Telnet', {
            'fields': ('ssh_username', 'ssh_password', 'ssh_port', 'enable_password')
        }),
        ('Informações Coletadas', {
            'fields': ('os_version', 'firmware_version', 'uptime', 'interfaces_count', 'last_polled')
        }),
        ('Integrações', {
            'fields': ('librenms_id', 'zabbix_id', 'phpipam_id', 'auto_sync', 'sync_status')
        }),
        ('Status', {
            'fields': ('status', 'created_by', 'created_at', 'updated_at')
        }),
    )

@admin.register(EquipmentInterface)
class EquipmentInterfaceAdmin(admin.ModelAdmin):
    list_display = ['equipment', 'name', 'ip_address', 'mac_address', 'status', 'vlan_id']
    list_filter = ['status']
    search_fields = ['equipment__name', 'name', 'ip_address', 'mac_address']

@admin.register(SyncLog)
class SyncLogAdmin(admin.ModelAdmin):
    list_display = ['equipment', 'system', 'action', 'status', 'created_at']
    list_filter = ['system', 'status', 'action']
    search_fields = ['equipment__name', 'message']
    readonly_fields = ['equipment', 'system', 'action', 'status', 'message', 'external_id', 'created_at']
