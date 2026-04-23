#!/bin/bash
# ========================================
# DIAGNÓSTICO E CORREÇÃO - Inventário Vazio
# ========================================

echo "========================================"
echo "DIAGNÓSTICO - Inventário Vazio"
echo "========================================"

# 1. Verificar dados no banco
echo "[1] Verificando dados no PostgreSQL..."
echo ""
echo "Contagem de dispositivos:"
psql -U lorcgr -d lorcgr -c "SELECT COUNT(*) as total FROM devices;"

echo ""
echo "Lista de dispositivos:"
psql -U lorcgr -d lorcgr -c "SELECT id, name, ip, vendor, is_online FROM devices ORDER BY id;"

# 2. Verificar estrutura da tabela
echo ""
echo "[2] Estrutura da tabela devices:"
psql -U lorcgr -d lorcgr -c "\d devices"

# 3. Testar API diretamente
echo ""
echo "[3] Testando API Django..."
curl -s http://127.0.0.1:8000/api/devices/list/ | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if isinstance(data, list):
        print(f'API retornou {len(data)} dispositivos')
        for d in data[:5]:
            print(f\"  - ID {d.get('id')}: {d.get('hostname', 'N/A')} ({d.get('ip_address', 'N/A')})\")
    else:
        print('API retornou erro:', data)
except Exception as e:
    print('Erro ao parsear JSON:', e)
    print('Resposta bruta:', sys.stdin.read())
"

# 4. Verificar status dos serviços
echo ""
echo "[4] Status dos serviços:"
systemctl status lorcgr-backend --no-pager -l | head -10

# 5. Verificar logs recentes
echo ""
echo "[5] Logs recentes do backend:"
journalctl -u lorcgr-backend -n 10 --no-pager

# 6. Verificar se o views_simple.py está correto
echo ""
echo "[6] Verificando views_simple.py..."
head -50 /opt/lorcgr/devices/views_simple.py

echo ""
echo "========================================"
echo "FIM DO DIAGNÓSTICO"
echo "========================================"
