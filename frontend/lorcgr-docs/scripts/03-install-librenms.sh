#!/bin/bash

################################################################################
# LOR-CGR Installation Script - Part 3: LibreNMS
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
ADMIN_USER="lorcgr"
ADMIN_PASS="Lor#Cgr#2026"
ADMIN_EMAIL="admin@lorcgr.local"

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  LOR-CGR - Instalação do LibreNMS${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script deve ser executado como root!${NC}"
   exit 1
fi

#######################################
# Instalar dependências PHP
#######################################
echo -e "${YELLOW}>>> Instalando dependências PHP...${NC}"
apt-get install -y \
    php php-cli php-curl php-fpm php-gd php-gmp php-intl \
    php-json php-mbstring php-mysql php-xml php-zip php-ldap \
    php-bcmath php-snmp php-xmlrpc php-memcached

# Verificar versão do PHP
PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
echo "PHP Version: ${PHP_VERSION}"

#######################################
# Criar usuário LibreNMS
#######################################
echo -e "${YELLOW}>>> Criando usuário librenms...${NC}"
if ! id "librenms" &>/dev/null; then
    useradd librenms -d /opt/librenms -M -r -s /bin/bash
fi

#######################################
# Baixar LibreNMS
#######################################
echo -e "${YELLOW}>>> Baixando LibreNMS...${NC}"
cd /opt
git clone https://github.com/librenms/librenms.git librenms

#######################################
# Configurar permissões
#######################################
echo -e "${YELLOW}>>> Configurando permissões...${NC}"
chown -R librenms:librenms /opt/librenms
chmod 770 /opt/librenms
setfacl -d -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
setfacl -R -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/

#######################################
# Configurar banco de dados
#######################################
echo -e "${YELLOW}>>> Configurando banco de dados...${NC}"
mysql -u ${DB_USER} -p"${DB_PASS}" << EOF
SET GLOBAL log_bin_trust_function_creators = 1;
EOF

# Importar schema
echo -e "${YELLOW}>>> Importando schema do banco...${NC}"
su - librenms << 'INNERSCRIPT'
cd /opt/librenms
cp .env.example .env

# Configurar .env
cat > .env << EOF
APP_ENV=production
APP_DEBUG=false
APP_URL=http://localhost/librenms

DB_HOST=localhost
DB_DATABASE=librenms
DB_USERNAME=lorcgr
DB_PASSWORD=Lor#Cgr#2026

REDIS_HOST=127.0.0.1
INNERSCRIPT

# Instalar dependências
./scripts/composer_wrapper.php install --no-dev

# Gerar chave
php artisan key:generate --force

# Importar schema
php artisan migrate --force
INNERSCRIPT

mysql -u ${DB_USER} -p"${DB_PASS}" << EOF
SET GLOBAL log_bin_trust_function_creators = 0;
EOF

#######################################
# Criar usuário admin
#######################################
echo -e "${YELLOW}>>> Criando usuário admin...${NC}"
su - librenms << EOF
cd /opt/librenms
php artisan user:add --email=${ADMIN_EMAIL} --password=${ADMIN_PASS} --role=admin --username=${ADMIN_USER} --no-interaction
EOF

#######################################
# Configurar SNMP
#######################################
echo -e "${YELLOW}>>> Configurando SNMP...${NC}"
cp /opt/librenms/snmpd.conf.example /etc/snmp/snmpd.conf
sed -i 's/RANDOMSTRINGGOESHERE/lorcgrpublic/g' /etc/snmp/snmpd.conf

# Adicionar script de distro
curl -o /usr/bin/distro https://raw.githubusercontent.com/librenms/librenms-agent/master/snmp/distro
chmod +x /usr/bin/distro
systemctl restart snmpd

#######################################
# Configurar PHP-FPM
#######################################
echo -e "${YELLOW}>>> Configurando PHP-FPM...${NC}"
# Criar pool do LibreNMS
cat > /etc/php/${PHP_VERSION}/fpm/pool.d/librenms.conf << EOF
[librenms]
user = librenms
group = librenms
listen = /run/php/librenms.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 3
pm.max_spare_servers = 35
pm.max_requests = 500
php_admin_value[open_basedir] = /opt/librenms:/usr/bin/distro
EOF

# Ajustar configurações PHP
sed -i 's/;date.timezone =/date.timezone = America\/Sao_Paulo/' /etc/php/${PHP_VERSION}/fpm/php.ini
sed -i 's/max_execution_time = 30/max_execution_time = 300/' /etc/php/${PHP_VERSION}/fpm/php.ini
sed -i 's/memory_limit = 128M/memory_limit = 512M/' /etc/php/${PHP_VERSION}/fpm/php.ini

systemctl restart php${PHP_VERSION}-fpm

#######################################
# Configurar serviços systemd
#######################################
echo -e "${YELLOW}>>> Configurando serviços systemd...${NC}"

# Copiar arquivos de serviço
cp /opt/librenms/misc/librenms.service /etc/systemd/system/
cp /opt/librenms/misc/librenms-scheduler.service /etc/systemd/system/
cp /opt/librenms/misc/librenms-scheduler.timer /etc/systemd/system/

# Criar serviço de polling
cat > /etc/systemd/system/librenms-dispatcher.service << 'EOF'
[Unit]
Description=LibreNMS Dispatcher
After=network.target mariadb.service

[Service]
Type=simple
User=librenms
Group=librenms
WorkingDirectory=/opt/librenms
ExecStart=/opt/librenms/lnms dispatcher:start
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable librenms librenms-scheduler.timer librenms-dispatcher
systemctl start librenms librenms-scheduler.timer librenms-dispatcher

#######################################
# Configurar logrotate
#######################################
echo -e "${YELLOW}>>> Configurando logrotate...${NC}"
cp /opt/librenms/misc/librenms.logrotate /etc/logrotate.d/librenms

#######################################
# Gerar API Token
#######################################
echo -e "${YELLOW}>>> Gerando API Token...${NC}"
API_TOKEN=$(su - librenms -c "cd /opt/librenms && php artisan api:generate" 2>/dev/null || echo "")

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  LibreNMS instalado com sucesso!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "Acesso web: http://seu-ip/librenms"
echo "Usuário: ${ADMIN_USER}"
echo "Senha: ${ADMIN_PASS}"
echo ""
echo "Para obter API Token, acesse:"
echo "  LibreNMS > Settings > API > Create Token"
echo ""
echo "Próximo passo: Execute o script 04-install-phpipam.sh"
