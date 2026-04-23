#!/bin/bash
# ============================================
# Script de Deploy LOR-CGR Next.js Frontend
# ============================================

set -e

echo "🚀 Iniciando deploy do LOR-CGR Frontend..."

# Variáveis
FRONTEND_DIR="/opt/lorcgr/frontend"
SERVICE_NAME="nextjs-lorcgr"

# 1. Parar qualquer processo Next.js existente
echo "📌 Parando processos Next.js existentes..."
pkill -f "next-server" || true
pkill -f "next dev" || true
systemctl stop $SERVICE_NAME 2>/dev/null || true

# 2. Criar diretório do frontend
echo "📁 Criando diretório do frontend..."
mkdir -p $FRONTEND_DIR

# 3. Extrair o tarball (assumindo que está no diretório atual)
if [ -f "nextjs-standalone.tar.gz" ]; then
    echo "📦 Extraindo arquivos..."
    tar -xzf nextjs-standalone.tar.gz -C $FRONTEND_DIR
else
    echo "❌ Arquivo nextjs-standalone.tar.gz não encontrado!"
    echo "   Certifique-se de que o arquivo está no diretório atual."
    exit 1
fi

# 4. Verificar se o Node está instalado
if ! command -v node &> /dev/null; then
    echo "❌ Node.js não está instalado!"
    exit 1
fi

# 5. Instalar o serviço systemd
echo "⚙️  Configurando serviço systemd..."
if [ -f "nextjs-lorcgr.service" ]; then
    cp nextjs-lorcgr.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable $SERVICE_NAME
else
    echo "⚠️  Arquivo de serviço não encontrado, pulando..."
fi

# 6. Configurar Nginx
echo "🌐 Configurando Nginx..."
if [ -f "nginx-lorcgr.conf" ]; then
    # Remover configuração padrão se existir
    rm -f /etc/nginx/sites-enabled/default
    
    # Copiar nova configuração
    cp nginx-lorcgr.conf /etc/nginx/sites-available/lorcgr
    ln -sf /etc/nginx/sites-available/lorcgr /etc/nginx/sites-enabled/
    
    # Testar configuração
    nginx -t
    
    echo "✅ Configuração do Nginx aplicada!"
else
    echo "⚠️  Arquivo de configuração do Nginx não encontrado, pulando..."
fi

# 7. Reiniciar serviços
echo "🔄 Reiniciando serviços..."
systemctl start $SERVICE_NAME
systemctl restart nginx

# 8. Verificar status
sleep 3
echo ""
echo "📊 Status dos serviços:"
systemctl status $SERVICE_NAME --no-pager | head -10
echo ""
systemctl status nginx --no-pager | head -10

# 9. Testar conexão
echo ""
echo "🧪 Testando frontend..."
if curl -s http://localhost:3000 > /dev/null; then
    echo "✅ Frontend respondendo na porta 3000!"
else
    echo "⚠️  Frontend não está respondendo!"
fi

if curl -s http://localhost > /dev/null; then
    echo "✅ Nginx respondendo na porta 80!"
else
    echo "⚠️  Nginx não está respondendo!"
fi

echo ""
echo "======================================"
echo "✅ Deploy concluído!"
echo "======================================"
echo "🌐 Acesse: http://45.71.242.131"
echo ""
echo "Comandos úteis:"
echo "  Ver logs: journalctl -u $SERVICE_NAME -f"
echo "  Reiniciar: systemctl restart $SERVICE_NAME"
echo "  Status: systemctl status $SERVICE_NAME"
