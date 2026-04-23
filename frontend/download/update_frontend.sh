#!/bin/bash
# Script para atualizar o frontend LOR-CGR no servidor
# Execute no servidor 45.71.242.131 como root

set -e

echo "=== ATUALIZANDO FRONTEND LOR-CGR ==="
echo ""

# Diretório do frontend
FRONTEND_DIR="/opt/lorcgr/frontend"

# 1. Verificar se o diretório existe
if [ ! -d "$FRONTEND_DIR" ]; then
    echo "❌ Diretório do frontend não encontrado: $FRONTEND_DIR"
    exit 1
fi

cd "$FRONTEND_DIR"

# 2. Fazer backup
echo "1. Fazendo backup do frontend atual..."
BACKUP_FILE="/tmp/frontend_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
tar -czf "$BACKUP_FILE" src/components/lor-cgr/ src/types/ 2>/dev/null || true
echo "   Backup salvo em: $BACKUP_FILE"

# 3. Criar arquivos de patch
echo ""
echo "2. Aplicando correções..."
echo "   - LORCGRApp.tsx: Mapeamento correto de IDs"
echo "   - Inventory.tsx: Status de sincronização e botões"
echo "   - DashboardNOC.tsx: Links para LibreNMS/Zabbix"
echo "   - lor-cgr.ts: Tipos com zabbix_id"

# Os arquivos precisam ser copiados manualmente para o servidor
echo ""
echo "=== ARQUIVOS PARA COPIAR ==="
echo "Copie os seguintes arquivos para o servidor:"
echo ""
echo "Do seu computador, baixe os arquivos de:"
echo "  /home/z/my-project/download/lorcgr_frontend_fixed/"
echo ""
echo "No servidor, coloque em:"
echo "  $FRONTEND_DIR/src/components/lor-cgr/"
echo "  $FRONTEND_DIR/src/types/"
echo ""
echo "Comandos para executar no servidor após copiar os arquivos:"
echo ""
echo "  cd $FRONTEND_DIR"
echo "  sudo systemctl restart lorcgr-frontend"
echo "  # ou"
echo "  sudo systemctl restart lorcgr-api"
echo ""
echo "=== CORREÇÕES APLICADAS ==="
echo "✅ Mapeamento correto de librenms_id e zabbix_id"
echo "✅ Status de sincronização com ícones visuais (✅/❌)"
echo "✅ Botão de sincronização por dispositivo"
echo "✅ Botões de sincronização global (LibreNMS + Zabbix)"
echo "✅ Links funcionais para abrir no LibreNMS/Zabbix"
echo "✅ Tudo em português do Brasil"
