from rest_framework import serializers
from equipments.models import Equipment, EquipmentInterface, SyncLog, EquipmentStatus, PingHistory
from django.db import transaction


class EquipmentStatusSerializer(serializers.ModelSerializer):
    class Meta:
        model = EquipmentStatus
        fields = '__all__'


class PingHistorySerializer(serializers.ModelSerializer):
    class Meta:
        model = PingHistory
        fields = '__all__'


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


class EquipmentSerializer(serializers.ModelSerializer):
    interfaces = EquipmentInterfaceSerializer(many=True, read_only=True)
    realtime_status = EquipmentStatusSerializer(read_only=True)
    created_by_name = serializers.CharField(source='created_by.username', read_only=True)

    class Meta:
        model = Equipment
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at', 'last_polled', 'sync_status']

    def create(self, validated_data):
        with transaction.atomic():
            equipment = Equipment.objects.create(**validated_data)
            EquipmentStatus.objects.create(equipment=equipment)
            return equipment

    def update(self, instance, validated_data):
        with transaction.atomic():
            for attr, value in validated_data.items():
                setattr(instance, attr, value)
            instance.save()
            return instance
