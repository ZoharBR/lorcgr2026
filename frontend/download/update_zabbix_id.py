#!/usr/bin/env python3
"""
Script simples para atualizar o zabbix_id do equipamento no banco de dados
Execute no servidor: python3 update_zabbix_id.py
"""

import os
import sys
import django

# Configurar Django
sys.path.insert(0, '/opt/lorcgr/backend')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'lorcgr.settings')
django.setup()

from api.models import Equipment

# Atualizar o equipamento BRAS_NE8000
try:
    equip = Equipment.objects.get(id=1)
    equip.zabbix_id = '10680'  # ID do host criado no Zabbix
    equip.save()
    print(f"✅ Equipamento atualizado: {equip.name}")
    print(f"   LibreNMS ID: {equip.librenms_id}")
    print(f"   Zabbix ID: {equip.zabbix_id}")
except Equipment.DoesNotExist:
    print("❌ Equipamento não encontrado")
except Exception as e:
    print(f"❌ Erro: {e}")
