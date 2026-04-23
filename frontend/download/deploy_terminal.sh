#!/bin/bash
echo "=========================================="
echo "DEPLOY TERMINAL MULTITERMINAL"
echo "=========================================="

# Parar serviços
systemctl stop lorcgr-frontend

# Backup do frontend atual
if [ -d "/opt/lorcgr-frontend" ]; then
    rm -rf /opt/lorcgr-frontend.backup
    cp -r /opt/lorcgr-frontend /opt/lorcgr-frontend.backup
fi

# Criar diretório
mkdir -p /opt/lorcgr-frontend

# Extrair novo frontend
cd /opt/lorcgr-frontend
tar -xzf /tmp/lorcgr-frontend.tar.gz

# Copiar arquivos públicos
cp -r /home/z/my-project/public /opt/lorcgr-frontend/ 2>/dev/null || true

# Criar .env
cat > /opt/lorcgr-frontend/.env << 'ENV'
NEXT_PUBLIC_API_URL=http://45.71.242.131:8000/api
NEXT_PUBLIC_WS_URL=ws://45.71.242.131:8001
ENV

# Iniciar serviços
systemctl start lorcgr-frontend

sleep 3
echo ""
echo "Status do Frontend:"
systemctl status lorcgr-frontend --no-pager | head -15

echo ""
echo "Status do WebSocket:"
systemctl status lorcgr-websocket --no-pager | head -10

echo ""
echo "=========================================="
echo "DEPLOY CONCLUÍDO!"
echo "=========================================="
echo "Acesse: http://45.71.242.131/"
