from django.contrib import admin
from .models import Equipment, EquipmentInterface, SyncLog, EquipmentStatus, PingHistory


@admin.register(Equipment)
class EquipmentAdmin(admin.ModelAdmin):
    list_display = ['name', 'device_type', 'vendor', 'status', 'primary_ip', 'site']
    list_filter = ['status', 'device_type', 'vendor', 'site']
    search_fields = ['name', 'hostname', 'serial_number']
    readonly_fields = ['created_at', 'updated_at']


@admin.register(EquipmentStatus)
class EquipmentStatusAdmin(admin.ModelAdmin):
    list_display = ['equipment', 'status', 'latency_ms', 'packet_loss', 'last_check', 'is_flashing']
    list_filter = ['status']
    search_fields = ['equipment__name']
    readonly_fields = ['last_check', 'last_success', 'consecutive_failures']


@admin.register(PingHistory)
class PingHistoryAdmin(admin.ModelAdmin):
    list_display = ['equipment', 'latency_ms', 'success', 'timestamp']
    list_filter = ['success', 'equipment']
    date_hierarchy = 'timestamp'


@admin.register(EquipmentInterface)
class EquipmentInterfaceAdmin(admin.ModelAdmin):
    list_display = ['equipment', 'name', 'ip_address', 'status']
    list_filter = ['status']


@admin.register(SyncLog)
class SyncLogAdmin(admin.ModelAdmin):
    list_display = ['equipment', 'system', 'action', 'status', 'created_at']
    list_filter = ['system', 'status']
    readonly_fields = ['created_at']
