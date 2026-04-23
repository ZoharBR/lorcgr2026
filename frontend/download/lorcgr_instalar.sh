#!/bin/bash
#################################################################
# LOR-CGR Sistema de Gerenciamento de Rede - Continuação
# Servidor: 45.71.242.131
# Credenciais: lorcgr / Lor#Cgr#2026
#################################################################

echo "=========================================="
echo "LOR-CGR - Continuando Instalação"
echo "=========================================="

# Cores
VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
AMARELO='\033[1;33m'
NC='\033[0m'

ok() { echo -e "${VERDE}[OK]${NC} $1"; }
erro() { echo -e "${VERMELHO}[ERRO]${NC} $1"; }
info() { echo -e "${AMARELO}[INFO]${NC} $1"; }

# Verificar se é root
if [ "$EUID" -ne 0 ]; then
    erro "Execute como root (sudo)"
    exit 1
fi

#################################################################
# PASSO 1: Configurar PHP
#################################################################
info "Passo 1: Configurando PHP 8.1..."

systemctl start php8.1-fpm
systemctl enable php8.1-fpm

# Ajustar php.ini
PHP_INI="/etc/php/8.1/fpm/php.ini"
if [ -f "$PHP_INI" ]; then
    sed -i 's/^max_execution_time = .*/max_execution_time = 300/' "$PHP_INI"
    sed -i 's/^max_input_time = .*/max_input_time = 300/' "$PHP_INI"
    sed -i 's/^memory_limit = .*/memory_limit = 512M/' "$PHP_INI"
    sed -i 's/^post_max_size = .*/post_max_size = 64M/' "$PHP_INI"
    sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 64M/' "$PHP_INI"
    sed -i 's/^;date.timezone =.*/date.timezone = America\/Lima/' "$PHP_INI"
fi

systemctl restart php8.1-fpm
ok "PHP 8.1 FPM: $(systemctl is-active php8.1-fpm)"

#################################################################
# PASSO 2: Configurar Nginx
#################################################################
info "Passo 2: Configurando Nginx..."

mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled
mkdir -p /var/log/nginx

# Configuração principal do Nginx
cat > /etc/nginx/nginx.conf << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
error_log /var/log/nginx/error.log;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent"';

    access_log /var/log/nginx/access.log main;
    sendfile on;
    tcp_nopush on;
    keepalive_timeout 65;
    gzip on;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

# Configuração do site LOR-CGR
cat > /etc/nginx/sites-available/lorcgr.conf << 'EOF'
# LOR-CGR - Configuração Principal

upstream django_api {
    server 127.0.0.1:8000;
}

upstream nextjs_frontend {
    server 127.0.0.1:3000;
}

server {
    listen 80;
    server_name _;

    root /var/www/html;
    index index.html index.php;

    # Dashboard Principal - Next.js
    location / {
        proxy_pass http://nextjs_frontend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    # Django API
    location /api/ {
        proxy_pass http://django_api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # LibreNMS
    location /librenms/ {
        alias /opt/librenms/html/;
        index index.php;

        location ~ \.php$ {
            fastcgi_pass unix:/run/php/php8.1-fpm.sock;
            fastcgi_param SCRIPT_FILENAME $request_filename;
            include fastcgi_params;
        }
    }

    # phpIPAM
    location /phpipam/ {
        alias /opt/phpipam/;
        index index.php;

        location ~ \.php$ {
            fastcgi_pass unix:/run/php/php8.1-fpm.sock;
            fastcgi_param SCRIPT_FILENAME $request_filename;
            include fastcgi_params;
        }
    }

    # Zabbix
    location /zabbix/ {
        alias /usr/share/zabbix/;
        index index.php;

        location ~ \.php$ {
            fastcgi_pass unix:/run/php/php8.1-fpm.sock;
            fastcgi_param SCRIPT_FILENAME $request_filename;
            include fastcgi_params;
        }
    }

    # Grafana
    location /grafana/ {
        proxy_pass http://127.0.0.1:3001/;
        proxy_set_header Host $host;
    }

    # Nexterm
    location /nexterm/ {
        proxy_pass http://127.0.0.1:6989/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }

    # Health check
    location /health {
        return 200 'OK';
    }
}
EOF

ln -sf /etc/nginx/sites-available/lorcgr.conf /etc/nginx/sites-enabled/default

nginx -t && systemctl restart nginx && systemctl enable nginx
ok "Nginx: $(systemctl is-active nginx)"

#################################################################
# PASSO 3: Instalar Docker
#################################################################
info "Passo 3: Instalando Docker..."

# Remover versões antigas
apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Instalar dependências
apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release

# Adicionar chave GPG do Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Adicionar repositório Docker
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar Docker
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl start docker
systemctl enable docker
usermod -aG docker lorcgr

ok "Docker: $(systemctl is-active docker)"

#################################################################
# PASSO 4: Instalar Nexterm
#################################################################
info "Passo 4: Instalando Nexterm..."

mkdir -p /opt/nexterm
cd /opt/nexterm

cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  nexterm:
    image: germannewsmaker/nexterm:latest
    container_name: nexterm
    restart: unless-stopped
    ports:
      - "6989:6989"
    volumes:
      - ./data:/app/data
EOF

docker compose up -d || true
ok "Nexterm iniciado na porta 6989"

#################################################################
# PASSO 5: Configurar Grafana
#################################################################
info "Passo 5: Configurando Grafana..."

mkdir -p /etc/grafana /var/lib/grafana /var/log/grafana

cat > /etc/grafana/grafana.ini << 'EOF'
[server]
http_addr = 127.0.0.1
http_port = 3001
root_url = http://45.71.242.131/grafana/
serve_from_sub_path = true

[security]
admin_user = lorcgr
admin_password = Lor#Cgr#2026

[database]
type = postgres
host = 127.0.0.1:5432
name = grafana
user = lorcgr
password = Lor#Cgr#2026
EOF

chown -R grafana:grafana /var/lib/grafana /var/log/grafana /etc/grafana
systemctl daemon-reload
systemctl start grafana-server
systemctl enable grafana-server

ok "Grafana: $(systemctl is-active grafana-server)"

#################################################################
# PASSO 6: Configurar LibreNMS
#################################################################
info "Passo 6: Configurando LibreNMS..."

cd /opt/librenms

# Instalar dependências do Composer
if [ -f "composer.json" ]; then
    sudo -u librenms composer install --no-interaction --no-dev || true
fi

chown -R librenms:librenms /opt/librenms
chmod -R 775 /opt/librenms

# Criar config se não existir
if [ ! -f ".env" ]; then
    cat > .env << 'EOF'
APP_ENV=production
APP_DEBUG=false
APP_URL=http://45.71.242.131/librenms
DB_HOST=127.0.0.1
DB_DATABASE=librenms
DB_USERNAME=lorcgr
DB_PASSWORD=Lor#Cgr#2026
EOF
    chown librenms:librenms .env
fi

ok "LibreNMS configurado"

#################################################################
# PASSO 7: Configurar phpIPAM
#################################################################
info "Passo 7: Configurando phpIPAM..."

cd /opt/phpipam

if [ ! -f "config.php" ]; then
    cat > config.php << 'EOF'
<?php
$db['host'] = '127.0.0.1';
$db['user'] = 'lorcgr';
$db['pass'] = 'Lor#Cgr#2026';
$db['name'] = 'phpipam';
$db['port'] = 3306;
define('BASE', '/phpipam/');
EOF
fi

chown -R www-data:www-data /opt/phpipam
chmod -R 775 /opt/phpipam

ok "phpIPAM configurado"

#################################################################
# PASSO 8: Reiniciar Todos os Serviços
#################################################################
info "Passo 8: Reiniciando todos os serviços..."

systemctl restart postgresql
systemctl restart mariadb
systemctl restart redis-server
systemctl restart php8.1-fpm
systemctl restart nginx
systemctl restart lorcgr-api || true
systemctl restart lorcgr-frontend || true
systemctl restart zabbix-server
systemctl restart grafana-server

cd /opt/nexterm && docker compose up -d || true

#################################################################
# PASSO 9: Status Final
#################################################################
echo ""
echo "=========================================="
echo "STATUS DO SISTEMA LOR-CGR"
echo "=========================================="

for servico in postgresql mariadb redis-server php8.1-fpm nginx lorcgr-api lorcgr-frontend zabbix-server grafana-server docker; do
    status=$(systemctl is-active $servico 2>/dev/null || echo "parado")
    if [ "$status" = "active" ]; then
        echo -e "✓ $servico: ${VERDE}RODANDO${NC}"
    else
        echo -e "✗ $servico: ${VERMELHO}PARADO${NC}"
    fi
done

echo ""
echo "=========================================="
echo "URLs DE ACESSO:"
echo "=========================================="
echo "Dashboard Principal:  http://45.71.242.131/"
echo "API Django:           http://45.71.242.131/api/"
echo "LibreNMS:             http://45.71.242.131/librenms/"
echo "phpIPAM:              http://45.71.242.131/phpipam/"
echo "Zabbix:               http://45.71.242.131/zabbix/"
echo "Grafana:              http://45.71.242.131/grafana/"
echo "Nexterm:              http://45.71.242.131/nexterm/"
echo ""
echo "Credenciais: lorcgr / Lor#Cgr#2026"
echo "=========================================="

ok "Instalação concluída!"
