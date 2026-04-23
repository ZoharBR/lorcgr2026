from rest_framework import serializers
from equipments.models import Equipment, EquipmentType, EquipmentStatus, PingHistory
from equipments.models import BRAS, OLT, Switch, Router # Importar BRAS, OLT, Switch, Router diretamente
from django.db import transaction

class BRASSerializer(serializers.ModelSerializer):
    class Meta:
        model = BRAS
        fields = '__all__'

class OLTSerializer(serializers.ModelSerializer):
    class Meta:
        model = OLT
        fields = '__all__'

class SwitchSerializer(serializers.ModelSerializer):
    class Meta:
        model = Switch
        fields = '__all__'

class RouterSerializer(serializers.ModelSerializer):
    class Meta:
        model = Router
        fields = '__all__'

class EquipmentSerializer(serializers.ModelSerializer):
    bras = BRASSerializer(required=False, allow_null=True)
    olt = OLTSerializer(required=False, allow_null=True)
    switch = SwitchSerializer(required=False, allow_null=True)
    router = RouterSerializer(required=False, allow_null=True)
class Meta:
    model = Equipment
    fields = '__all__'
    read_only_fields = ('equipment_type',) # equipment_type é definido automaticamente

def create(self, validated_data):
    bras_data = validated_data.pop('bras', None)
    olt_data = validated_data.pop('olt', None)
    switch_data = validated_data.pop('switch', None)
    router_data = validated_data.pop('router', None)

    with transaction.atomic():
        # Determinar o tipo de equipamento e criar a instância específica
        equipment_type_name = validated_data.get('device_type')
        if not equipment_type_name:
            raise serializers.ValidationError({"device_type": "Device type is required."})

        try:
            equipment_type = EquipmentType.objects.get(name=equipment_type_name)
        except EquipmentType.DoesNotExist:
            raise serializers.ValidationError({"device_type": f"EquipmentType '{equipment_type_name}' does not exist."})

        validated_data['equipment_type'] = equipment_type
        equipment = Equipment.objects.create(**validated_data)

        if bras_data:
            BRAS.objects.create(equipment=equipment, **bras_data)
        elif olt_data:
            OLT.objects.create(equipment=equipment, **olt_data)
        elif switch_data:
            Switch.objects.create(equipment=equipment, **switch_data)
        elif router_data:
            Router.objects.create(equipment=equipment, **router_data)

    return equipment

def update(self, instance, validated_data):
    bras_data = validated_data.pop('bras', None)
    olt_data = validated_data.pop('olt', None)
    switch_data = validated_data.pop('switch', None)
    router_data = validated_data.pop('router', None)

    with transaction.atomic():
        # Atualizar campos do Equipment
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()

        # Atualizar ou criar BRAS
        if bras_data is not None:
            bras_instance, created = BRAS.objects.get_or_create(equipment=instance)
            for attr, value in bras_data.items():
                setattr(bras_instance, attr, value)
            bras_instance.save()
        else:
            # Se bras_data for None, significa que o frontend não enviou,
            # então não devemos apagar se já existir.
            # Se a intenção for remover o BRAS, o frontend precisaria enviar um sinal explícito.
            pass

        # Repetir para OLT, Switch, Router
        if olt_data is not None:
            olt_instance, created = OLT.objects.get_or_create(equipment=instance)
            for attr, value in olt_data.items():
                setattr(olt_instance, attr, value)
            olt_instance.save()
        else:
            pass

        if switch_data is not None:
            switch_instance, created = Switch.objects.get_or_create(equipment=instance)
            for attr, value in switch_data.items():
                setattr(switch_instance, attr, value)
            switch_instance.save()
        else:
            pass

        if router_data is not None:
            router_instance, created = Router.objects.get_or_create(equipment=instance)
            for attr, value in router_data.items():
                setattr(router_instance, attr, value)
            router_instance.save()
        else:
            pass

    return instance
class EquipmentListSerializer(serializers.ModelSerializer):
    # Este serializer é para listagem, então não precisa dos detalhes aninhados
    # para evitar consultas extras desnecessárias.
    class Meta:
        model = Equipment
        fields = '__all__'

class EquipmentInterfaceSerializer(serializers.ModelSerializer):
    class Meta:
        model = EquipmentType
        fields = '__all__'

class EquipmentStatusSerializer(serializers.ModelSerializer):
    class Meta:
        model = EquipmentStatus
        fields = '__all__'

class PingHistorySerializer(serializers.ModelSerializer):
    class Meta:
        model = PingHistory
        fields = '__all__'

class SyncLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = EquipmentType
        fields = '__all__'
