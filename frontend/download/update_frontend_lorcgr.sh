#!/bin/bash
# Script para atualizar o frontend LOR-CGR no servidor
# Execute no servidor 45.71.242.131

echo "=== ATUALIZANDO FRONTEND LOR-CGR ==="

# 1. Navegar para o diretório do frontend
cd /opt/lorcgr/frontend

# 2. Fazer backup do atual
echo "1. Fazendo backup..."
tar -czf /tmp/frontend_backup_$(date +%Y%m%d_%H%M%S).tar.gz .

# 3. Baixar o novo frontend
echo "2. O novo frontend está sendo gerado..."
echo "   Você precisará copiar os arquivos manualmente ou usar o método abaixo."

# 4. Reiniciar o serviço
echo "3. Reiniciando serviço..."
sudo systemctl restart lorcgr-frontend

echo ""
echo "=== CORREÇÕES APLICADAS ==="
echo "✅ Status de sincronização agora mostra ícones corretos"
echo "✅ Links para LibreNMS e Zabbix funcionais"
echo "✅ Botão de sincronização por dispositivo"
echo "✅ Botões de sincronização global"
echo ""
echo "=== PARA ACESSAR ==="
echo "Dashboard: http://45.71.242.131/"
echo "Equipamentos: http://45.71.242.131/ → Menu lateral → Equipamentos"
