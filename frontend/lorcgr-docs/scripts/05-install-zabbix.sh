#!/bin/bash

################################################################################
# LOR-CGR Installation Script - Part 5: Zabbix
################################################################################

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Credenciais padrão
DB_USER="lorcgr"
DB_PASS="Lor#Cgr#2026"
ADMIN_PASS="Lor#Cgr#2026"

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  LOR-CGR - Instalação do Zabbix${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script deve ser executado como root!${NC}"
   exit 1
fi

PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")

#######################################
# Adicionar repositório Zabbix
#######################################
echo -e "${YELLOW}>>> Adicionando repositório Zabbix...${NC}"
wget -q https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-2+ubuntu24.04_all.deb -O /tmp/zabbix-release.deb
dpkg -i /tmp/zabbix-release.deb
apt-get update

#######################################
# Instalar Zabbix Server + Frontend + Agent
#######################################
echo -e "${YELLOW}>>> Instalando Zabbix Server (MySQL)...${NC}"
apt-get install -y \
    zabbix-server-mysql \
    zabbix-frontend-php \
    zabbix-nginx-conf \
    zabbix-sql-scripts \
    zabbix-agent

#######################################
# Configurar banco de dados
#######################################
echo -e "${YELLOW}>>> Configurando banco de dados Zabbix...${NC}"
mysql -u ${DB_USER} -p"${DB_PASS}" << EOF
CREATE DATABASE IF NOT EXISTS zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
GRANT ALL PRIVILEGES ON zabbix.* TO '${DB_USER}'@'localhost';
SET GLOBAL log_bin_trust_function_creators = 1;
FLUSH PRIVILEGES;
EOF

# Importar schema
echo -e "${YELLOW}>>> Importando schema (pode demorar)...${NC}"
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -u ${DB_USER} -p"${DB_PASS}" zabbix

mysql -u ${DB_USER} -p"${DB_PASS}" -e "SET GLOBAL log_bin_trust_function_creators = 0;"

#######################################
# Configurar Zabbix Server
#######################################
echo -e "${YELLOW}>>> Configurando Zabbix Server...${NC}"
sed -i "s/^# DBPassword=/DBPassword=${DB_PASS}/" /etc/zabbix/zabbix_server.conf
sed -i "s/^DBUser=.*/DBUser=${DB_USER}/" /etc/zabbix/zabbix_server.conf
sed -i "s/^DBName=.*/DBName=zabbix/" /etc/zabbix/zabbix_server.conf
sed -i "s/^# DBHost=.*/DBHost=localhost/" /etc/zabbix/zabbix_server.conf

#######################################
# Configurar PHP para Zabbix
#######################################
echo -e "${YELLOW}>>> Configurando PHP para Zabbix...${NC}"
cat > /etc/zabbix/web/zabbix.conf.php << EOF
<?php
// Zabbix GUI configuration file.

\$DB['TYPE']     = 'MYSQL';
\$DB['SERVER']   = 'localhost';
\$DB['PORT']     = '0';
\$DB['DATABASE'] = 'zabbix';
\$DB['USER']     = '${DB_USER}';
\$DB['PASSWORD'] = '${DB_PASS}';

// Schema name. Used for IBM DB2 and PostgreSQL.
\$DB['SCHEMA'] = '';

\$ZBX_SERVER      = 'localhost';
\$ZBX_SERVER_PORT = '10051';
\$ZBX_SERVER_NAME = 'LOR-CGR Zabbix';

\$IMAGE_FORMAT_DEFAULT = IMAGE_FORMAT_PNG;
EOF

#######################################
# Configurar Nginx para Zabbix
#######################################
echo -e "${YELLOW}>>> Configurando Nginx para Zabbix...${NC}"
# Editar config do Zabbix
cat > /etc/zabbix/nginx.conf << 'EOF'
server {
    listen 8080;
    server_name _;
    root /usr/share/zabbix;
    index index.php;

    access_log /var/log/nginx/zabbix_access.log;
    error_log /var/log/nginx/zabbix_error.log;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_param PHP_VALUE "
            max_execution_time = 300
            memory_limit = 256M
            post_max_size = 32M
            upload_max_filesize = 16M
            max_input_vars = 10000
            date.timezone = America/Sao_Paulo
        ";
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# Remover default se existir
rm -f /etc/zabbix/nginx.conf.d/default 2>/dev/null || true

#######################################
# Atualizar senha do Admin
#######################################
echo -e "${YELLOW}>>> Configurando usuário admin...${NC}"
# A senha será atualizada via API após o Zabbix iniciar

#######################################
# Iniciar serviços
#######################################
echo -e "${YELLOW}>>> Iniciando serviços...${NC}"
systemctl restart zabbix-server zabbix-agent
systemctl enable zabbix-server zabbix-agent

# Aguardar Zabbix iniciar
sleep 5

#######################################
# Atualizar senha do Admin via API
#######################################
echo -e "${YELLOW}>>> Atualizando senha do Admin via API...${NC}"

# Primeiro, fazer login e obter token
API_RESPONSE=$(curl -s -X POST http://localhost:8080/api_jsonrpc.php \
    -H "Content-Type: application/json-rpc" \
    -d '{
        "jsonrpc": "2.0",
        "method": "user.login",
        "params": {
            "username": "Admin",
            "password": "zabbix"
        },
        "id": 1
    }')

AUTH_TOKEN=$(echo $API_RESPONSE | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

if [ -n "$AUTH_TOKEN" ]; then
    # Atualizar senha
    curl -s -X POST http://localhost:8080/api_jsonrpc.php \
        -H "Content-Type: application/json-rpc" \
        -d "{
            \"jsonrpc\": \"2.0\",
            \"method\": \"user.update\",
            \"params\": {
                \"userid\": \"1\",
                \"passwd\": \"${ADMIN_PASS}\"
            },
            \"auth\": \"${AUTH_TOKEN}\",
            \"id\": 2
        }" > /dev/null

    # Logout
    curl -s -X POST http://localhost:8080/api_jsonrpc.php \
        -H "Content-Type: application/json-rpc" \
        -d "{
            \"jsonrpc\": \"2.0\",
            \"method\": \"user.logout\",
            \"params\": [],
            \"auth\": \"${AUTH_TOKEN}\",
            \"id\": 3
        }" > /dev/null

    echo -e "${GREEN}Senha do Admin atualizada!${NC}"
else
    echo -e "${YELLOW}Não foi possível atualizar senha via API. Faça manualmente.${NC}"
fi

#######################################
# Criar arquivo de configuração
#######################################
echo -e "${YELLOW}>>> Salvando configurações...${NC}"
cat > /opt/lorcgr/zabbix_api.conf << EOF
# Zabbix API Configuration
# Gerado automaticamente pelo instalador LOR-CGR

ZABBIX_URL=http://localhost:8080/api_jsonrpc.php
ZABBIX_WEB=http://localhost:8080
ZABBIX_USER=Admin
ZABBIX_PASS=${ADMIN_PASS}
EOF

chown lorcgr:lorcgr /opt/lorcgr/zabbix_api.conf
chmod 600 /opt/lorcgr/zabbix_api.conf

#######################################
# Verificar status
#######################################
echo ""
echo -e "${YELLOW}>>> Verificando status...${NC}"
if systemctl is-active --quiet zabbix-server; then
    echo -e "${GREEN}✓ Zabbix Server está rodando${NC}"
else
    echo -e "${RED}✗ Zabbix Server não está rodando${NC}"
fi

if systemctl is-active --quiet zabbix-agent; then
    echo -e "${GREEN}✓ Zabbix Agent está rodando${NC}"
else
    echo -e "${RED}✗ Zabbix Agent não está rodando${NC}"
fi

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  Zabbix instalado com sucesso!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "Acesso web: http://seu-ip:8080"
echo "Usuário: Admin"
echo "Senha: ${ADMIN_PASS}"
echo ""
echo "Configurações salvas em: /opt/lorcgr/zabbix_api.conf"
echo ""
echo "Próximo passo: Execute o script 06-install-grafana.sh"
