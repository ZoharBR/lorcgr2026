#!/bin/bash

################################################################################
# LOR-CGR Installation Script - Part 4: phpIPAM
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
ADMIN_USER="Admin"
ADMIN_PASS="Lor#Cgr#2026"

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  LOR-CGR - Instalação do phpIPAM${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script deve ser executado como root!${NC}"
   exit 1
fi

PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")

#######################################
# Baixar phpIPAM
#######################################
echo -e "${YELLOW}>>> Baixando phpIPAM...${NC}"
cd /opt
git clone https://github.com/phpipam/phpipam.git phpipam
cd phpipam

# Checkout para versão estável
git checkout $(git tag | sort -V | tail -1) 2>/dev/null || echo "Using latest"

#######################################
# Configurar banco de dados
#######################################
echo -e "${YELLOW}>>> Configurando banco de dados...${NC}"
mysql -u ${DB_USER} -p"${DB_PASS}" << EOF
CREATE DATABASE IF NOT EXISTS phpipam CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON phpipam.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

#######################################
# Configurar phpIPAM
#######################################
echo -e "${YELLOW}>>> Configurando phpIPAM...${NC}"
cd /opt/phpipam

# Criar config.php
cat > config.php << EOF
<?php
/**
 * phpIPAM configuration
 */

/**
 * database connection details
 ******************************/
\$db['host'] = 'localhost';
\$db['user'] = '${DB_USER}';
\$db['pass'] = '${DB_PASS}';
\$db['name'] = 'phpipam';
\$db['port'] = 3306;

/**
 * Web SSL
 ******************************/
\$https = false;

/**
 * Debugging
 ******************************/
\$debugging = false;

/**
 * Session storage - files or database
 ******************************/
\$session_storage = "database";

/**
 * Cookie security
 ******************************/
\$cookie_secure = false;

/**
 * API
 ******************************/
\$api_allow_unsafe = false;
EOF

#######################################
# Configurar permissões
#######################################
echo -e "${YELLOW}>>> Configurando permissões...${NC}"
chown -R www-data:www-data /opt/phpipam
chmod -R 755 /opt/phpipam
chmod 644 /opt/phpipam/config.php

#######################################
# Importar schema inicial
#######################################
echo -e "${YELLOW}>>> Importando schema...${NC}"
mysql -u ${DB_USER} -p"${DB_PASS}" phpipam < /opt/phpipam/db/SCHEMA.sql

#######################################
# Atualizar usuário admin
#######################################
echo -e "${YELLOW}>>> Configurando usuário admin...${NC}"
# O phpIPAM cria um usuário Admin/ipamadmin por padrão
# Vamos atualizar a senha
mysql -u ${DB_USER} -p"${DB_PASS}" phpipam << EOF
-- Atualizar senha do admin
UPDATE users SET password = MD5('${ADMIN_PASS}') WHERE username = 'Admin';

-- Atualizar email do admin
UPDATE users SET email = 'admin@lorcgr.local' WHERE username = 'Admin';

-- Habilitar API
UPDATE settings SET api = 1;
EOF

#######################################
# Criar API App
#######################################
echo -e "${YELLOW}>>> Criando API App para LOR-CGR...${NC}"
APP_CODE=$(openssl rand -hex 32)

mysql -u ${DB_USER} -p"${DB_PASS}" phpipam << EOF
INSERT INTO api (app_id, app_code, app_permissions, app_comment, app_security)
VALUES ('lorcgr', '${APP_CODE}', '2', 'LOR-CGR Integration', 'none');
EOF

echo ""
echo "API App Code: ${APP_CODE}"
echo ""

#######################################
# Configurar PHP-FPM
#######################################
echo -e "${YELLOW}>>> Configurando PHP-FPM para phpIPAM...${NC}"
cat > /etc/php/${PHP_VERSION}/fpm/pool.d/phpipam.conf << EOF
[phpipam]
user = www-data
group = www-data
listen = /run/php/phpipam.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 3
pm.max_spare_servers = 35
pm.max_requests = 500
EOF

systemctl restart php${PHP_VERSION}-fpm

#######################################
# Criar arquivo de configuração de API
#######################################
echo -e "${YELLOW}>>> Salvando configurações de API...${NC}"
cat > /opt/lorcgr/phpipam_api.conf << EOF
# phpIPAM API Configuration
# Gerado automaticamente pelo instalador LOR-CGR

PHPIPAM_URL=http://localhost/phpipam
PHPIPAM_APP_ID=lorcgr
PHPIPAM_APP_CODE=${APP_CODE}
PHPIPAM_USER=Admin
PHPIPAM_PASS=${ADMIN_PASS}
EOF

chown lorcgr:lorcgr /opt/lorcgr/phpipam_api.conf
chmod 600 /opt/lorcgr/phpipam_api.conf

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  phpIPAM instalado com sucesso!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "Acesso web: http://seu-ip/phpipam"
echo "Usuário: Admin"
echo "Senha: ${ADMIN_PASS}"
echo ""
echo "API App ID: lorcgr"
echo "API App Code: ${APP_CODE}"
echo ""
echo "Configurações salvas em: /opt/lorcgr/phpipam_api.conf"
echo ""
echo "Próximo passo: Execute o script 05-install-zabbix.sh"
