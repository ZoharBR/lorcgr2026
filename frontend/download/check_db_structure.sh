#!/bin/bash
# Verificar estrutura da tabela devices no PostgreSQL
# Execute no servidor

echo "Estrutura da tabela devices:"
psql -U lorcgr -d lorcgr -c "\d devices"

echo ""
echo "Dados atuais (campos de credenciais):"
psql -U lorcgr -d lorcgr -c "SELECT id, name, username, password, ssh_user, ssh_password, ssh_port, protocol FROM devices;"

echo ""
echo "Colunas disponíveis:"
psql -U lorcgr -d lorcgr -c "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'devices' ORDER BY ordinal_position;"
