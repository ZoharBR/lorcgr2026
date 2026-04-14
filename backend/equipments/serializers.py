from rest_framework import serializers
from .models import Equipment, EquipmentInterface, SyncLog

class EquipmentInterfaceSerializer(serializers.ModelSerializer):
    class Meta:
        model = EquipmentInterface
        fields = '__all__'
        read_only_fields = ['equipment', 'phpipam_id']

class SyncLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = SyncLog
        fields = '__all__'
        read_only_fields = ['equipment', 'created_at']

class EquipmentSerializer(serializers.ModelSerializer):
    interfaces = EquipmentInterfaceSerializer(many=True, read_only=True)
    created_by_name = serializers.CharField(source='created_by.username', read_only=True)
    
    class Meta:
        model = Equipment
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at', 'last_polled', 'sync_status']

class EquipmentListSerializer(serializers.ModelSerializer):
    class Meta:
        model = Equipment
        fields = [
            'id', 'name', 'hostname', 'device_type', 'vendor', 'model', 
            'primary_ip', 'status', 'location', 
            'librenms_id', 'zabbix_id', 'created_at',
            'ssh_username', 'ssh_password', 'ssh_port',
            'snmp_community', 'snmp_version',
            'os_version', 'serial_number', 'uptime'
        ]
