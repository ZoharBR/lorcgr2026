#!/bin/bash
# Script para diagnosticar e corrigir o problema de flickering no dashboard
# Execute no servidor: bash fix_flickering.sh

echo "=========================================="
echo "DIAGNOSTICO DO PROBLEMA DE FLICKERING"
echo "=========================================="

# Verificar se os serviços estão rodando
echo -e "\n[1] Status dos serviços:"
systemctl status lorcgr-frontend --no-pager -l | head -10
systemctl status lorcgr-backend --no-pager -l | head -10

# Verificar logs recentes
echo -e "\n[2] Logs do backend (últimas 20 linhas):"
journalctl -u lorcgr-backend --no-pager -n 20

# Testar APIs diretamente
echo -e "\n[3] Testando APIs:"
echo "API list:"
curl -s http://127.0.0.1:8000/api/devices/list/ | python3 -m json.tool 2>/dev/null | head -30

echo -e "\nAPI dashboard:"
curl -s http://127.0.0.1:8000/api/devices/dashboard/

echo -e "\n\nAPI interfaces/stats:"
curl -s http://127.0.0.1:8000/api/devices/interfaces/stats/

# Verificar se Nginx está passando as requisições corretamente
echo -e "\n\n[4] Testando via Nginx (externo):"
curl -s http://45.71.242.131/api/devices/list/ | python3 -m json.tool 2>/dev/null | head -30

echo -e "\n\n[5] Verificar views_simple.py atual:"
cat /opt/lorcgr/devices/views_simple.py | head -100

echo -e "\n=========================================="
echo "FIM DO DIAGNOSTICO"
echo "=========================================="
