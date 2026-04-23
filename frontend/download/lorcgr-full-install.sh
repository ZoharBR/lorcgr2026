#!/bin/bash

################################################################################
# LOR-CGR - Script de Instalação Completo (Tudo em Um)
# Versão: 1.0.0
# Data: Março 2026
#
# Este script instala TODOS os componentes do LOR-CGR de uma vez
# Execute como root: bash lorcgr-full-install.sh
################################################################################

set -e

# ============================================
# CONFIGURAÇÕES GLOBAIS
# ============================================
DB_USER="lorcgr"
DB_PASS="Lor#Cgr#2026"
ADMIN_USER="lorcgr"
ADMIN_PASS="Lor#Cgr#2026"
ENCRYPTION_KEY="0e61a0c2072c1c8191ca085d5191269897b5281ab25571f7239dfe5d7e094573"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================
# FUNÇÕES AUXILIARES
# ============================================
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "\n${BLUE}════════════════════════════════════════${NC}\n${BLUE}  $1${NC}\n${BLUE}════════════════════════════════════════${NC}\n"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Execute como root!"
        exit 1
    fi
}

# ============================================
# INÍCIO
# ============================================
clear
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║              LOR-CGR Network Management System               ║"
echo "║                    Instalação Completa                       ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

check_root

log_info "Este script vai instalar:"
echo "  • PostgreSQL, MariaDB, Redis"
echo "  • LibreNMS, phpIPAM, Zabbix, Grafana"
echo "  • Nexterm (Docker)"
echo "  • Django API + Next.js Frontend"
echo "  • Nginx Reverse Proxy"
echo ""
log_info "Credenciais padrão para TODOS os sistemas:"
echo "  Usuário: ${DB_USER}"
echo "  Senha: ${DB_PASS}"
echo ""
read -p "Continuar? (yes/no): " confirm
[[ "$confirm" != "yes" ]] && exit 0

# ============================================
# 1. PREPARAÇÃO DO SISTEMA
# ============================================
log_step "1. Preparação do Sistema"

log_info "Atualizando sistema..."
apt-get update -qq
apt-get upgrade -y -qq

log_info "Instalando pacotes essenciais..."
apt-get install -y -qq curl wget git vim htop net-tools dnsutils \
    unzip software-properties-common apt-transport-https \
    ca-certificates gnupg lsb-release python3-pip python3-venv \
    build-essential libpq-dev acl rrdtool snmp snmpd fping \
    nmap whois graphviz imagemagick mtr-tiny > /dev/null

log_info "Configurando timezone..."
timedatectl set-timezone America/Sao_Paulo

log_info "Criando usuário lorcgr..."
id "lorcgr" &>/dev/null || useradd -m -s /bin/bash lorcgr
echo "lorcgr:${DB_PASS}" | chpasswd
usermod -aG sudo lorcgr

mkdir -p /opt/lorcgr /var/log/lorcgr /opt/nexterm/data
chown -R lorcgr:lorcgr /opt/lorcgr /var/log/lorcgr

log_info "✓ Sistema preparado!"

# ============================================
# 2. BANCOS DE DADOS
# ============================================
log_step "2. Instalando Bancos de Dados"

# PostgreSQL
log_info "Instalando PostgreSQL..."
apt-get install -y -qq postgresql postgresql-contrib > /dev/null
systemctl start postgresql
systemctl enable postgresql

log_info "Configurando PostgreSQL..."
su - postgres << EOF
psql -c "CREATE USER ${DB_USER} WITH SUPERUSER CREATEDB CREATEROLE PASSWORD '${DB_PASS}';" 2>/dev/null || true
psql -c "CREATE DATABASE lorcgr OWNER ${DB_USER};" 2>/dev/null || true
psql -c "CREATE DATABASE grafana OWNER ${DB_USER};" 2>/dev/null || true
psql -c "CREATE DATABASE zabbix OWNER ${DB_USER};" 2>/dev/null || true
EOF

# MariaDB
log_info "Instalando MariaDB..."
apt-get install -y -qq mariadb-server mariadb-client > /dev/null
systemctl start mariadb
systemctl enable mariadb

mysql -u root << EOF
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON *.* TO '${DB_USER}'@'localhost' WITH GRANT OPTION;
CREATE DATABASE IF NOT EXISTS librenms CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS phpipam CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON librenms.* TO '${DB_USER}'@'localhost';
GRANT ALL PRIVILEGES ON phpipam.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

# Redis
log_info "Instalando Redis..."
apt-get install -y -qq redis-server > /dev/null
sed -i 's/^supervised .*/supervised systemd/' /etc/redis/redis.conf
systemctl start redis-server
systemctl enable redis-server

log_info "✓ Bancos de dados instalados!"

# ============================================
# 3. PHP
# ============================================
log_step "3. Instalando PHP"

log_info "Instalando PHP e extensões..."
apt-get install -y -qq php php-cli php-curl php-fpm php-gd php-gmp php-intl \
    php-json php-mbstring php-mysql php-xml php-zip php-ldap php-bcmath \
    php-snmp php-xmlrpc php-memcached > /dev/null

PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
sed -i 's/;date.timezone =/date.timezone = America\/Sao_Paulo/' /etc/php/${PHP_VERSION}/fpm/php.ini
sed -i 's/max_execution_time = 30/max_execution_time = 300/' /etc/php/${PHP_VERSION}/fpm/php.ini
sed -i 's/memory_limit = 128M/memory_limit = 512M/' /etc/php/${PHP_VERSION}/fpm/php.ini

systemctl restart php${PHP_VERSION}-fpm

log_info "✓ PHP ${PHP_VERSION} instalado!"

# ============================================
# 4. LIBRENMS
# ============================================
log_step "4. Instalando LibreNMS"

log_info "Criando usuário librenms..."
id "librenms" &>/dev/null || useradd librenms -d /opt/librenms -M -r -s /bin/bash

log_info "Baixando LibreNMS..."
cd /opt
git clone https://github.com/librenms/librenms.git librenms 2>/dev/null || log_warn "Diretório já existe"

chown -R librenms:librenms /opt/librenms
chmod 770 /opt/librenms
setfacl -d -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/ 2>/dev/null
setfacl -R -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/ 2>/dev/null

log_info "Configurando LibreNMS..."
su - librenms << 'LIBRENMS_SETUP'
cd /opt/librenms
cp .env.example .env
cat > .env << EOF
APP_ENV=production
APP_DEBUG=false
APP_URL=http://localhost/librenms
DB_HOST=localhost
DB_DATABASE=librenms
DB_USERNAME=lorcgr
DB_PASSWORD=Lor#Cgr#2026
REDIS_HOST=127.0.0.1
EOF
./scripts/composer_wrapper.php install --no-dev 2>/dev/null
php artisan key:generate --force 2>/dev/null
php artisan migrate --force 2>/dev/null
LIBRENMS_SETUP

mysql -u ${DB_USER} -p"${DB_PASS}" -e "SET GLOBAL log_bin_trust_function_creators = 1;" 2>/dev/null
su - librenms -c "cd /opt/librenms && php artisan user:add --email=admin@lorcgr.local --password=${ADMIN_PASS} --role=admin --username=${ADMIN_USER} --no-interaction" 2>/dev/null || true
mysql -u ${DB_USER} -p"${DB_PASS}" -e "SET GLOBAL log_bin_trust_function_creators = 0;" 2>/dev/null

# PHP-FPM pool for LibreNMS
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
EOF

# Systemd services
cp /opt/librenms/misc/librenms.service /etc/systemd/system/ 2>/dev/null
cp /opt/librenms/misc/librenms-scheduler.service /etc/systemd/system/ 2>/dev/null
cp /opt/librenms/misc/librenms-scheduler.timer /etc/systemd/system/ 2>/dev/null

systemctl daemon-reload
systemctl enable librenms librenms-scheduler.timer
systemctl start librenms librenms-scheduler.timer
systemctl restart php${PHP_VERSION}-fpm

log_info "✓ LibreNMS instalado!"

# ============================================
# 5. PHPIPAM
# ============================================
log_step "5. Instalando phpIPAM"

log_info "Baixando phpIPAM..."
cd /opt
git clone https://github.com/phpipam/phpipam.git phpipam 2>/dev/null || log_warn "Diretório já existe"

cat > /opt/phpipam/config.php << EOF
<?php
\$db['host'] = 'localhost';
\$db['user'] = '${DB_USER}';
\$db['pass'] = '${DB_PASS}';
\$db['name'] = 'phpipam';
\$db['port'] = 3306;
\$debugging = false;
EOF

chown -R www-data:www-data /opt/phpipam
mysql -u ${DB_USER} -p"${DB_PASS}" phpipam < /opt/phpipam/db/SCHEMA.sql 2>/dev/null || true
mysql -u ${DB_USER} -p"${DB_PASS}" phpipam -e "UPDATE users SET password = MD5('${ADMIN_PASS}') WHERE username = 'Admin';" 2>/dev/null

# PHP-FPM pool
cat > /etc/php/${PHP_VERSION}/fpm/pool.d/phpipam.conf << EOF
[phpipam]
user = www-data
group = www-data
listen = /run/php/phpipam.sock
listen.owner = www-data
listen.group = www-data
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
EOF

systemctl restart php${PHP_VERSION}-fpm
log_info "✓ phpIPAM instalado!"

# ============================================
# 6. ZABBIX
# ============================================
log_step "6. Instalando Zabbix"

log_info "Adicionando repositório Zabbix..."
wget -q https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-2+ubuntu24.04_all.deb -O /tmp/zabbix.deb
dpkg -i /tmp/zabbix.deb > /dev/null 2>&1
apt-get update -qq

log_info "Instalando Zabbix..."
apt-get install -y -qq zabbix-server-mysql zabbix-frontend-php zabbix-nginx-conf zabbix-sql-scripts zabbix-agent > /dev/null

mysql -u ${DB_USER} -p"${DB_PASS}" << EOF
CREATE DATABASE IF NOT EXISTS zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
SET GLOBAL log_bin_trust_function_creators = 1;
EOF

log_info "Importando schema Zabbix (pode demorar)..."
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -u ${DB_USER} -p"${DB_PASS}" zabbix 2>/dev/null

mysql -u ${DB_USER} -p"${DB_PASS}" -e "SET GLOBAL log_bin_trust_function_creators = 0;"

# Config Zabbix
sed -i "s/^# DBPassword=/DBPassword=${DB_PASS}/" /etc/zabbix/zabbix_server.conf
sed -i "s/^DBUser=.*/DBUser=${DB_USER}/" /etc/zabbix/zabbix_server.conf

cat > /etc/zabbix/web/zabbix.conf.php << EOF
<?php
\$DB['TYPE'] = 'MYSQL';
\$DB['SERVER'] = 'localhost';
\$DB['DATABASE'] = 'zabbix';
\$DB['USER'] = '${DB_USER}';
\$DB['PASSWORD'] = '${DB_PASS}';
\$ZBX_SERVER = 'localhost';
\$ZBX_SERVER_PORT = '10051';
\$ZBX_SERVER_NAME = 'LOR-CGR Zabbix';
EOF

cat > /etc/zabbix/nginx.conf << 'EOF'
server {
    listen 8080;
    server_name _;
    root /usr/share/zabbix;
    index index.php;
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
    }
}
EOF

systemctl restart zabbix-server zabbix-agent
systemctl enable zabbix-server zabbix-agent

# Update Zabbix admin password
sleep 3
AUTH=$(curl -s -X POST http://localhost:8080/api_jsonrpc.php \
    -H "Content-Type: application/json-rpc" \
    -d '{"jsonrpc":"2.0","method":"user.login","params":{"username":"Admin","password":"zabbix"},"id":1}' | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

[ -n "$AUTH" ] && curl -s -X POST http://localhost:8080/api_jsonrpc.php \
    -H "Content-Type: application/json-rpc" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"user.update\",\"params\":{\"userid\":\"1\",\"passwd\":\"${ADMIN_PASS}\"},\"auth\":\"${AUTH}\",\"id\":2}" > /dev/null

log_info "✓ Zabbix instalado!"

# ============================================
# 7. GRAFANA
# ============================================
log_step "7. Instalando Grafana"

log_info "Adicionando repositório Grafana..."
wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key
echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main" > /etc/apt/sources.list.d/grafana.list
apt-get update -qq

log_info "Instalando Grafana..."
apt-get install -y -qq grafana > /dev/null

cat > /etc/grafana/grafana.ini << 'GRAFANAINI'
[server]
http_addr = 127.0.0.1
http_port = 3000
root_url = http://localhost/grafana/

[database]
type = postgres
host = localhost:5432
name = grafana
user = lorcgr
password = Lor#Cgr#2026

[security]
admin_user = lorcgr
admin_password = Lor#Cgr#2026

[users]
allow_sign_up = false
GRAFANAINI

systemctl start grafana-server
systemctl enable grafana-server

log_info "✓ Grafana instalado!"

# ============================================
# 8. DOCKER & NEXTERM
# ============================================
log_step "8. Instalando Docker e Nexterm"

log_info "Instalando Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh > /dev/null 2>&1
    systemctl start docker
    systemctl enable docker
fi

log_info "Instalando Nexterm..."
docker stop nexterm 2>/dev/null || true
docker rm nexterm 2>/dev/null || true
docker run -d --name nexterm -p 6989:6989 \
    -v /opt/nexterm/data:/app/data \
    -e ENCRYPTION_KEY=${ENCRYPTION_KEY} \
    --restart unless-stopped \
    germannewsmaker/nexterm > /dev/null

log_info "✓ Nexterm instalado!"

# ============================================
# 9. DJANGO BACKEND
# ============================================
log_step "9. Instalando Django Backend"

log_info "Criando ambiente Python..."
mkdir -p /opt/lorcgr/backend
cd /opt/lorcgr/backend
python3 -m venv venv
source venv/bin/activate

pip install --upgrade pip -q
pip install django djangorestframework django-cors-headers psycopg2-binary \
    channels daphne gunicorn python-dotenv requests paramiko netmiko groq -q

log_info "Criando projeto Django..."
django-admin startproject lorcgr . 2>/dev/null || true
python manage.py startapp api 2>/dev/null || true
python manage.py startapp equipments 2>/dev/null || true

# Create minimal models
cat > equipments/models.py << 'PYEOF'
from django.db import models
from django.contrib.auth.models import User

class Vendor(models.Model):
    name = models.CharField(max_length=100, unique=True)
    slug = models.SlugField(max_length=100, unique=True)
    def __str__(self): return self.name

class EquipmentType(models.Model):
    name = models.CharField(max_length=100)
    slug = models.SlugField(max_length=100, unique=True)
    icon = models.CharField(max_length=50, default='server')
    def __str__(self): return self.name

class Equipment(models.Model):
    STATUS_CHOICES = [('active','Ativo'),('inactive','Inativo'),('unknown','Desconhecido')]
    name = models.CharField(max_length=200)
    hostname = models.CharField(max_length=200, blank=True)
    vendor = models.ForeignKey(Vendor, on_delete=models.SET_NULL, null=True, blank=True)
    equipment_type = models.ForeignKey(EquipmentType, on_delete=models.SET_NULL, null=True, blank=True)
    ip_address = models.GenericIPAddressField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='unknown')
    location = models.CharField(max_length=200, blank=True)
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    snmp_community = models.CharField(max_length=100, default='public')
    username = models.CharField(max_length=100, blank=True)
    password = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    def __str__(self): return f"{self.name} ({self.ip_address})"
PYEOF

# Settings
cat > lorcgr/settings.py << 'PYSETTINGS'
import os
from pathlib import Path
BASE_DIR = Path(__file__).resolve().parent.parent
SECRET_KEY = os.environ.get('DJANGO_SECRET_KEY', 'lorcgr-secret-key-change-in-production')
DEBUG = False
ALLOWED_HOSTS = ['*']
INSTALLED_APPS = [
    'django.contrib.admin','django.contrib.auth','django.contrib.contenttypes',
    'django.contrib.sessions','django.contrib.messages','django.contrib.staticfiles',
    'rest_framework','corsheaders','channels','api','equipments',
]
MIDDLEWARE = ['django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
]
ROOT_URLCONF = 'lorcgr.urls'
TEMPLATES = [{'BACKEND':'django.template.backends.django.DjangoTemplates','DIRS':[],'APP_DIRS':True,
    'OPTIONS':{'context_processors':['django.template.context_processors.debug',
    'django.template.context_processors.request','django.contrib.auth.context_processors.auth',
    'django.contrib.messages.context_processors.messages']},}]
WSGI_APPLICATION = 'lorcgr.wsgi.application'
DATABASES = {'default':{'ENGINE':'django.db.backends.postgresql','NAME':'lorcgr',
    'USER':'lorcgr','PASSWORD':'Lor#Cgr#2026','HOST':'localhost','PORT':'5432',}}
STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
LANGUAGE_CODE = 'pt-br'
TIME_ZONE = 'America/Sao_Paulo'
CORS_ALLOW_ALL_ORIGINS = True
PYSETTINGS

# URLs
cat > lorcgr/urls.py << 'PYURLS'
from django.contrib import admin
from django.urls import path, include
urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('api.urls')),
]
PYURLS

cat > api/urls.py << 'PYAPIURLS'
from django.urls import path
from django.http import JsonResponse
def health(request): return JsonResponse({'status':'ok','version':'1.0.0'})
urlpatterns = [path('health/', health)]
PYAPIURLS

# .env
cat > /opt/lorcgr/.env << EOF
DJANGO_SECRET_KEY=$(python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')
DEBUG=False
DB_NAME=lorcgr
DB_USER=lorcgr
DB_PASSWORD=Lor#Cgr#2026
DB_HOST=localhost
DB_PORT=5432
LIBRENMS_URL=http://localhost/librenms/api/v0
ZABBIX_URL=http://localhost:8080/api_jsonrpc.php
ZABBIX_USER=Admin
ZABBIX_PASSWORD=Lor#Cgr#2026
GRAFANA_URL=http://localhost:3000
GRAFANA_USER=lorcgr
GRAFANA_PASSWORD=Lor#Cgr#2026
NEXTERM_URL=http://localhost:6989
NEXTERM_ENCRYPTION_KEY=${ENCRYPTION_KEY}
EOF

# Migrate
python manage.py makemigrations 2>/dev/null
python manage.py migrate 2>/dev/null
python manage.py shell -c "from django.contrib.auth.models import User; User.objects.filter(username='lorcgr').exists() or User.objects.create_superuser('lorcgr','admin@lorcgr.local','${ADMIN_PASS}')" 2>/dev/null

# Add initial vendors/types
python manage.py shell << 'INITDATA'
from equipments.models import Vendor, EquipmentType
vendors = [('Juniper','juniper'),('Huawei','huawei'),('Cisco','cisco'),('Mikrotik','mikrotik'),
    ('Ubiquiti','ubiquiti'),('FiberHome','fiberhome'),('Dell','dell'),('HP','hp')]
for name, slug in vendors: Vendor.objects.get_or_create(slug=slug, defaults={'name':name})
types = [('Switch','switch'),('Router','router'),('Firewall','firewall'),('OLT','olt'),
    ('Server','server'),('Access Point','ap')]
for name, slug in types: EquipmentType.objects.get_or_create(slug=slug, defaults={'name':name})
INITDATA

python manage.py collectstatic --noinput 2>/dev/null

# Systemd services
cat > /etc/systemd/system/lorcgr-api.service << SYSDAPI
[Unit]
Description=LOR-CGR Django API
After=network.target postgresql.service

[Service]
Type=notify
User=lorcgr
Group=lorcgr
WorkingDirectory=/opt/lorcgr/backend
Environment="PATH=/opt/lorcgr/backend/venv/bin"
ExecStart=/opt/lorcgr/backend/venv/bin/gunicorn --workers 3 --bind 127.0.0.1:8000 --timeout 120 lorcgr.wsgi:application
Restart=always

[Install]
WantedBy=multi-user.target
SYSDAPI

chown -R lorcgr:lorcgr /opt/lorcgr
systemctl daemon-reload
systemctl enable lorcgr-api
systemctl start lorcgr-api

log_info "✓ Django Backend instalado!"

# ============================================
# 10. NODE.JS & NEXT.JS
# ============================================
log_step "10. Instalando Next.js Frontend"

log_info "Instalando Node.js..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash - > /dev/null 2>&1
apt-get install -y -qq nodejs > /dev/null

mkdir -p /opt/lorcgr/frontend
cd /opt/lorcgr/frontend

# package.json
cat > package.json << 'PKGJSON'
{
  "name": "lorcgr-frontend",
  "version": "1.0.0",
  "scripts": {
    "dev": "next dev -p 3001",
    "build": "next build",
    "start": "node .next/standalone/server.js"
  },
  "dependencies": {
    "next": "14.2.0",
    "react": "18.3.0",
    "react-dom": "18.3.0",
    "lucide-react": "0.359.0"
  },
  "devDependencies": {
    "@types/node": "20.11.0",
    "@types/react": "18.2.0",
    "typescript": "5.4.0",
    "tailwindcss": "3.4.0",
    "postcss": "8.4.0",
    "autoprefixer": "10.4.0"
  }
}
PKGJSON

npm install --silent 2>/dev/null

mkdir -p src/app src/components

# Config files
echo '{"compilerOptions":{"target":"es5","lib":["dom","esnext"],"jsx":"preserve","module":"esnext","moduleResolution":"bundler","strict":true,"paths":{"@/*":["./src/*"]}},"include":["next-env.d.ts","**/*.ts","**/*.tsx"]}' > tsconfig.json
echo '/** @type {import("next").NextConfig} */\nconst nextConfig = {output:"standalone"};\nmodule.exports = nextConfig;' > next.config.js
echo 'module.exports = {content:["./src/**/*.{js,ts,jsx,tsx}"],theme:{extend:{}},plugins:[]};' > tailwind.config.js
echo 'module.exports = {plugins:{tailwindcss:{},autoprefixer:{}}};' > postcss.config.js

# App files
cat > src/app/globals.css << 'CSS'
@tailwind base;
@tailwind components;
@tailwind utilities;
body { @apply bg-gray-900 text-gray-100; }
CSS

cat > src/app/layout.tsx << 'LAYOUT'
import './globals.css';
export const metadata = { title: 'LOR-CGR' };
export default function RootLayout({children}:{children:React.ReactNode}) {
  return <html lang="pt-BR"><body className="antialiased">{children}</body></html>
}
LAYOUT

cat > src/app/page.tsx << 'PAGE'
'use client';
import { useState } from 'react';
import { LayoutDashboard, Server, Terminal, HardDrive, Users, FileText, Settings, ExternalLink, Map, Menu, X, Activity, CheckCircle, AlertTriangle } from 'lucide-react';

const menuItems = [
  { id: 'dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { id: 'equipments', label: 'Equipamentos', icon: Server },
  { id: 'terminal', label: 'Terminal', icon: Terminal },
  { id: 'backups', label: 'Backups', icon: HardDrive },
  { id: 'users', label: 'Usuários', icon: Users },
  { id: 'logs', label: 'Logs', icon: FileText },
  { id: 'settings', label: 'Configurações', icon: Settings },
  { id: 'links', label: 'Links Externos', icon: ExternalLink },
  { id: 'maps', label: 'Mapas', icon: Map },
];

const externalLinks = [
  { name: 'LibreNMS', url: '/librenms/', color: 'bg-blue-600' },
  { name: 'Zabbix', url: '/zabbix/', color: 'bg-red-600' },
  { name: 'phpIPAM', url: '/phpipam/', color: 'bg-green-600' },
  { name: 'Grafana', url: '/grafana/', color: 'bg-orange-600' },
  { name: 'Nexterm', url: '/nexterm/', color: 'bg-purple-600' },
];

export default function Dashboard() {
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [activeMenu, setActiveMenu] = useState('dashboard');

  return (
    <div className="min-h-screen flex">
      <aside className={`${sidebarOpen ? 'w-64' : 'w-20'} bg-gray-800 border-r border-gray-700 transition-all`}>
        <div className="h-16 flex items-center justify-between px-4 border-b border-gray-700">
          {sidebarOpen && <span className="text-xl font-bold">LOR-CGR</span>}
          <button onClick={() => setSidebarOpen(!sidebarOpen)} className="p-2 rounded hover:bg-gray-700">
            {sidebarOpen ? <X size={20}/> : <Menu size={20}/>}
          </button>
        </div>
        <nav className="py-4">
          {menuItems.map(item => (
            <button key={item.id} onClick={() => setActiveMenu(item.id)}
              className={`w-full flex items-center gap-3 px-4 py-3 ${activeMenu === item.id ? 'bg-blue-600 text-white' : 'text-gray-300 hover:bg-gray-700'}`}>
              <item.icon size={20}/>
              {sidebarOpen && <span>{item.label}</span>}
            </button>
          ))}
        </nav>
        {sidebarOpen && (
          <div className="p-4 border-t border-gray-700">
            <p className="text-xs text-gray-500 mb-2">Links Rápidos</p>
            <div className="flex flex-wrap gap-2">
              {externalLinks.map(link => (
                <a key={link.name} href={link.url} target="_blank" className={`${link.color} text-white text-xs px-2 py-1 rounded`}>
                  {link.name}
                </a>
              ))}
            </div>
          </div>
        )}
      </aside>
      <main className="flex-1 flex flex-col">
        <header className="h-16 bg-gray-800 border-b border-gray-700 flex items-center px-6">
          <h1 className="text-xl font-semibold">Dashboard</h1>
        </header>
        <div className="flex-1 p-6">
          <div className="grid grid-cols-4 gap-6 mb-8">
            {[
              { label: 'Equipamentos Ativos', value: '127', icon: CheckCircle, color: 'text-green-500' },
              { label: 'Equipamentos Inativos', value: '8', icon: AlertTriangle, color: 'text-red-500' },
              { label: 'Alertas Ativos', value: '23', icon: Activity, color: 'text-yellow-500' },
              { label: 'Sistemas Integrados', value: '5', icon: Server, color: 'text-blue-500' },
            ].map((stat, i) => (
              <div key={i} className="bg-gray-800 rounded-lg p-6 border border-gray-700">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-gray-400 text-sm">{stat.label}</p>
                    <p className="text-2xl font-bold mt-1">{stat.value}</p>
                  </div>
                  <stat.icon size={24} className={stat.color}/>
                </div>
              </div>
            ))}
          </div>
          <div className="bg-gray-800 rounded-lg border border-gray-700 p-6">
            <h2 className="text-lg font-semibold mb-4">Status dos Sistemas</h2>
            <div className="grid grid-cols-5 gap-4">
              {['LibreNMS','Zabbix','phpIPAM','Grafana','Nexterm'].map(name => (
                <div key={name} className="flex items-center gap-3 p-3 bg-gray-900 rounded-lg">
                  <div className="w-3 h-3 rounded-full bg-green-500"/>
                  <span>{name}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
PAGE

npm run build 2>/dev/null

cat > /etc/systemd/system/lorcgr-frontend.service << SYSDFE
[Unit]
Description=LOR-CGR Frontend
After=network.target

[Service]
Type=simple
User=lorcgr
WorkingDirectory=/opt/lorcgr/frontend
Environment="NODE_ENV=production"
Environment="PORT=3001"
ExecStart=/usr/bin/node /opt/lorcgr/frontend/.next/standalone/server.js
Restart=always

[Install]
WantedBy=multi-user.target
SYSDFE

chown -R lorcgr:lorcgr /opt/lorcgr/frontend
systemctl daemon-reload
systemctl enable lorcgr-frontend
systemctl start lorcgr-frontend

log_info "✓ Next.js Frontend instalado!"

# ============================================
# 11. NGINX
# ============================================
log_step "11. Configurando Nginx"

apt-get install -y -qq nginx > /dev/null

cat > /etc/nginx/sites-available/lorcgr << 'NGINXCONF'
upstream django_api { server 127.0.0.1:8000; }
upstream nextjs { server 127.0.0.1:3001; }
upstream grafana { server 127.0.0.1:3000; }
upstream nexterm { server 127.0.0.1:6989; }
upstream zabbix { server 127.0.0.1:8080; }

server {
    listen 80 default_server;
    server_name _;
    client_max_body_size 100M;

    location / {
        proxy_pass http://nextjs;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
    }

    location /api/ {
        proxy_pass http://django_api;
        proxy_set_header Host $host;
        proxy_read_timeout 300s;
    }

    location /admin/ {
        proxy_pass http://django_api;
        proxy_set_header Host $host;
    }

    location /grafana/ {
        proxy_pass http://grafana/;
    }

    location /librenms/ {
        alias /opt/librenms/public/;
        index index.php;
        location ~ \.php$ {
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME $request_filename;
            fastcgi_pass unix:/run/php/librenms.sock;
        }
    }

    location /phpipam/ {
        alias /opt/phpipam/;
        index index.php;
        location ~ \.php$ {
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME $request_filename;
            fastcgi_pass unix:/run/php/phpipam.sock;
        }
    }

    location /zabbix/ {
        proxy_pass http://zabbix/;
    }

    location /nexterm/ {
        proxy_pass http://nexterm/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
NGINXCONF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/lorcgr /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx && systemctl enable nginx

log_info "✓ Nginx configurado!"

# ============================================
# FINAL
# ============================================
log_step "Instalação Concluída!"

SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "SEU_IP")

echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           LOR-CGR INSTALADO COM SUCESSO!                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo "Acesse: ${GREEN}http://${SERVER_IP}/${NC}"
echo ""
echo "Credenciais (todos os sistemas):"
echo "  Usuário: ${ADMIN_USER} ou Admin"
echo "  Senha: ${ADMIN_PASS}"
echo ""
echo "URLs:"
echo "  LOR-CGR:    http://${SERVER_IP}/"
echo "  LibreNMS:   http://${SERVER_IP}/librenms/"
echo "  phpIPAM:    http://${SERVER_IP}/phpipam/"
echo "  Zabbix:     http://${SERVER_IP}/zabbix/"
echo "  Grafana:    http://${SERVER_IP}/grafana/"
echo "  Nexterm:    http://${SERVER_IP}/nexterm/"
echo ""
echo "Resumo salvo em: /opt/lorcgr/INSTALACAO.txt"
echo ""

# Save summary
cat > /opt/lorcgr/INSTALACAO.txt << EOF
LOR-CGR - Instalação Concluída
Data: $(date)
IP: ${SERVER_IP}

URLs:
- LOR-CGR:    http://${SERVER_IP}/
- LibreNMS:   http://${SERVER_IP}/librenms/
- phpIPAM:    http://${SERVER_IP}/phpipam/
- Zabbix:     http://${SERVER_IP}/zabbix/
- Grafana:    http://${SERVER_IP}/grafana/
- Nexterm:    http://${SERVER_IP}/nexterm/

Credenciais:
- Usuário: lorcgr / Admin
- Senha: Lor#Cgr#2026
EOF
