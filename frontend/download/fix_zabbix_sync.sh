#!/bin/bash
# Script para corrigir sincronização Zabbix no servidor LOR-CGR
# Execute no servidor: bash fix_zabbix_sync.sh

set -e

echo "=== CORRIGINDO SINCRONIZAÇÃO ZABBIX ==="

# Diretório do projeto
PROJECT_DIR="/opt/lorcgr/backend"
cd $PROJECT_DIR

# Ativar virtualenv
source venv/bin/activate

# Backup
echo "1. Fazendo backup..."
cp api/views.py api/views.py.bak.$(date +%Y%m%d_%H%M%S)

# Criar arquivo de configuração para Zabbix
echo "2. Criando configuração de grupos e templates..."
cat > api/zabbix_config.py << 'EOF'
# Configuração de sincronização Zabbix
ZABBIX_CONFIG = {
    # ID do grupo padrão para dispositivos de rede
    'DEFAULT_HOSTGROUP_ID': '22',  # Network Devices
    
    # Mapeamento de vendor para template ID
    'VENDOR_TEMPLATES': {
        'huawei': '10229',      # Huawei VRP by SNMP
        'cisco': '10218',       # Cisco IOS by SNMP
        'juniper': '10231',     # Juniper by SNMP
        'mikrotik': '10233',    # Mikrotik by SNMP
        'arista': '10254',      # Arista by SNMP
        'hp': '10250',          # HP Enterprise Switch by SNMP
        'dell': '10221',        # Dell Force S-Series by SNMP
        'default': '10226',     # Network Generic Device by SNMP
    },
    
    # Mapeamento de tipo de dispositivo para template
    'DEVICE_TYPE_TEMPLATES': {
        'router': '10226',      # Network Generic Device
        'switch': '10226',      # Network Generic Device
        'firewall': '10604',    # FortiGate by SNMP (default)
        'server': '10248',      # Linux by SNMP
    }
}

def get_template_id(vendor=None, device_type=None):
    """Retorna o template ID apropriado baseado no vendor e tipo"""
    config = ZABBIX_CONFIG
    
    # Primeiro tenta pelo vendor
    if vendor and vendor.lower() in config['VENDOR_TEMPLATES']:
        return config['VENDOR_TEMPLATES'][vendor.lower()]
    
    # Depois tenta pelo tipo
    if device_type and device_type.lower() in config['DEVICE_TYPE_TEMPLATES']:
        return config['DEVICE_TYPE_TEMPLATES'][device_type.lower()]
    
    # Retorna o default
    return config['VENDOR_TEMPLATES']['default']
EOF

echo "3. Atualizando views.py..."

# Função Python para atualizar views.py
python3 << 'PYTHON_SCRIPT'
import re

# Ler o arquivo atual
with open('api/views.py', 'r') as f:
    content = f.read()

# Adicionar import do zabbix_config no topo se não existir
if 'from .zabbix_config import' not in content:
    # Encontrar a primeira linha de import
    import_match = re.search(r'^(from |import )', content, re.MULTILINE)
    if import_match:
        insert_pos = import_match.start()
        import_line = 'from .zabbix_config import get_template_id, ZABBIX_CONFIG\n'
        content = content[:insert_pos] + import_line + content[insert_pos:]

# Substituir groupid hardcoded
content = content.replace('"groupid": "1"', '"groupid": ZABBIX_CONFIG["DEFAULT_HOSTGROUP_ID"]')
content = content.replace('"groupid": 1', '"groupid": ZABBIX_CONFIG["DEFAULT_HOSTGROUP_ID"]')

# Substituir templateid hardcoded (se existir)
content = re.sub(
    r'"templateid":\s*"\d+"',
    '"templateid": get_template_id(vendor=equipment.vendor, device_type=equipment.device_type)',
    content
)

# Salvar
with open('api/views.py', 'w') as f:
    f.write(content)

print("views.py atualizado com sucesso!")
PYTHON_SCRIPT

echo "4. Reiniciando serviço..."
if command -v systemctl &> /dev/null; then
    sudo systemctl restart lorcgr-backend 2>/dev/null || sudo systemctl restart gunicorn
elif command -v supervisorctl &> /dev/null; then
    sudo supervisorctl restart lorcgr-backend
else
    echo "Reinicie manualmente o serviço Django"
fi

echo ""
echo "=== CONCLUÍDO ==="
echo "Grupos Zabbix configurados:"
echo "  - Network Devices (ID: 22)"
echo ""
echo "Templates por Vendor:"
echo "  - Huawei: 10229 (Huawei VRP by SNMP)"
echo "  - Cisco: 10218 (Cisco IOS by SNMP)"
echo "  - Juniper: 10231 (Juniper by SNMP)"
echo "  - Mikrotik: 10233 (Mikrotik by SNMP)"
echo "  - Default: 10226 (Network Generic Device by SNMP)"
echo ""
echo "Teste a sincronização com:"
echo "curl -X POST http://localhost/api/equipments/1/sync_to_zabbix/"
