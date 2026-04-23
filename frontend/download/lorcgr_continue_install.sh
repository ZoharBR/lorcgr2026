#!/bin/bash
#################################################################
# LOR-CGR Network Management System - Continue Installation
# Server: 45.71.242.131
# Credentials: lorcgr / Lor#Cgr#2026
#################################################################

set -e

echo "=========================================="
echo "LOR-CGR Continue Installation Script"
echo "=========================================="

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root"
    exit 1
fi

#################################################################
# STEP 1: Fix PHP Configuration
#################################################################
log_info "Step 1: Configuring PHP 8.1..."

# Start PHP-FPM
systemctl start php8.1-fpm || true
systemctl enable php8.1-fpm

# Configure PHP settings for web applications
PHP_INI="/etc/php/8.1/fpm/php.ini"
if [ -f "$PHP_INI" ]; then
    sed -i 's/^max_execution_time = .*/max_execution_time = 300/' "$PHP_INI"
    sed -i 's/^max_input_time = .*/max_input_time = 300/' "$PHP_INI"
    sed -i 's/^memory_limit = .*/memory_limit = 512M/' "$PHP_INI"
    sed -i 's/^post_max_size = .*/post_max_size = 64M/' "$PHP_INI"
    sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 64M/' "$PHP_INI"
    sed -i 's/^;date.timezone =.*/date.timezone = America\/Lima/' "$PHP_INI"
    log_info "PHP configuration updated"
fi

# Restart PHP-FPM
systemctl restart php8.1-fpm
log_info "PHP 8.1 FPM status: $(systemctl is-active php8.1-fpm)"

#################################################################
# STEP 2: Install and Configure Nginx
#################################################################
log_info "Step 2: Configuring Nginx..."

# Ensure Nginx is installed
apt-get install -y nginx || true

# Create Nginx configuration directories
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled
mkdir -p /var/log/nginx
mkdir -p /var/cache/nginx

# Create main Nginx configuration
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
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    # Gzip Settings
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml application/json application/javascript application/xml;

    # Include site configurations
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

# Create LOR-CGR main configuration
cat > /etc/nginx/sites-available/lorcgr.conf << 'EOF'
# LOR-CGR Network Management System - Main Nginx Configuration
# Server: 45.71.242.131

# Upstream definitions
upstream django_api {
    server 127.0.0.1:8000;
}

upstream nextjs_frontend {
    server 127.0.0.1:3000;
}

upstream phpipam {
    server 127.0.0.1:8001;
}

# Main Dashboard - Next.js Frontend
server {
    listen 80;
    server_name _;

    root /var/www/html;
    index index.html index.php;

    # Main LOR-CGR Dashboard
    location / {
        proxy_pass http://nextjs_frontend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # Django API
    location /api/ {
        proxy_pass http://django_api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
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

        location ~ /\.ht {
            deny all;
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

        location ~ /\.ht {
            deny all;
        }
    }

    # Zabbix Web Interface
    location /zabbix/ {
        alias /usr/share/zabbix/;
        index index.php;

        location ~ \.php$ {
            fastcgi_pass unix:/run/php/php8.1-fpm.sock;
            fastcgi_param SCRIPT_FILENAME $request_filename;
            include fastcgi_params;
        }

        location ~ /\.ht {
            deny all;
        }
    }

    # Grafana
    location /grafana/ {
        proxy_pass http://127.0.0.1:3001/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Nexterm (Docker)
    location /nexterm/ {
        proxy_pass http://127.0.0.1:6989/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Health check endpoint
    location /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }
}
EOF

# Enable the site
ln -sf /etc/nginx/sites-available/lorcgr.conf /etc/nginx/sites-enabled/default

# Remove default site if exists
rm -f /etc/nginx/sites-enabled/default.bak

# Test and restart Nginx
nginx -t && systemctl restart nginx && systemctl enable nginx
log_info "Nginx status: $(systemctl is-active nginx)"

#################################################################
# STEP 3: Install Docker and Nexterm
#################################################################
log_info "Step 3: Installing Docker..."

# Remove old Docker if exists
apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Install Docker dependencies
apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start Docker
systemctl start docker
systemctl enable docker

# Add lorcgr user to docker group
usermod -aG docker lorcgr

log_info "Docker status: $(systemctl is-active docker)"

# Install Nexterm
log_info "Installing Nexterm..."
mkdir -p /opt/nexterm
cd /opt/nexterm

# Create Nexterm docker-compose
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
    environment:
      - NEXTERM_PUBLIC_URL=http://45.71.242.131/nexterm
EOF

# Start Nexterm
docker compose up -d || true
log_info "Nexterm started on port 6989"

#################################################################
# STEP 4: Configure Grafana
#################################################################
log_info "Step 4: Configuring Grafana..."

# Install Grafana if not installed
if ! command -v grafana-server &> /dev/null; then
    # Add Grafana GPG key
    wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key
    
    # Add Grafana repository
    echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list
    
    apt-get update
    apt-get install -y grafana
fi

# Create Grafana directories
mkdir -p /etc/grafana
mkdir -p /var/lib/grafana
mkdir -p /var/log/grafana

# Configure Grafana
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

[auth.anonymous]
enabled = false

[paths]
data = /var/lib/grafana
logs = /var/log/grafana
EOF

# Set permissions
chown -R grafana:grafana /var/lib/grafana /var/log/grafana /etc/grafana

# Start Grafana
systemctl daemon-reload
systemctl start grafana-server
systemctl enable grafana-server
log_info "Grafana status: $(systemctl is-active grafana-server)"

#################################################################
# STEP 5: Complete LibreNMS Setup
#################################################################
log_info "Step 5: Completing LibreNMS setup..."

cd /opt/librenms

# Install Composer dependencies
if [ -f "composer.json" ]; then
    # Try multiple composer install attempts
    for i in {1..3}; do
        log_info "Composer install attempt $i..."
        sudo -u librenms composer install --no-interaction --no-dev && break
        sleep 5
    done
fi

# Set permissions
chown -R librenms:librenms /opt/librenms
chmod -R 775 /opt/librenms

# Create LibreNMS config if not exists
if [ ! -f "/opt/librenms/.env" ]; then
    cat > /opt/librenms/.env << 'EOF'
APP_ENV=production
APP_DEBUG=false
APP_URL=http://45.71.242.131/librenms
DB_HOST=127.0.0.1
DB_DATABASE=librenms
DB_USERNAME=lorcgr
DB_PASSWORD=Lor#Cgr#2026
EOF
    chown librenms:librenms /opt/librenms/.env
fi

log_info "LibreNMS setup completed"

#################################################################
# STEP 6: Configure phpIPAM
#################################################################
log_info "Step 6: Configuring phpIPAM..."

cd /opt/phpipam

# Create phpIPAM config
if [ ! -f "config.php" ]; then
    cat > config.php << 'EOF'
<?php
/**
 * phpIPAM configuration file
 */

/**
 * database connection details
 ******************************/
$db['host'] = '127.0.0.1';
$db['user'] = 'lorcgr';
$db['pass'] = 'Lor#Cgr#2026';
$db['name'] = 'phpipam';
$db['port'] = 3306;

/**
 * Web display
 ******************************/
$phpipam_url = 'http://45.71.242.131/phpipam';
define('BASE', '/phpipam/');
EOF
fi

# Set permissions
chown -R www-data:www-data /opt/phpipam
chmod -R 775 /opt/phpipam

log_info "phpIPAM configured"

#################################################################
# STEP 7: Start All Services
#################################################################
log_info "Step 7: Starting all services..."

# Restart all services
systemctl restart postgresql
systemctl restart mariadb
systemctl restart redis-server
systemctl restart php8.1-fpm
systemctl restart nginx
systemctl restart lorcgr-api || true
systemctl restart lorcgr-frontend || true
systemctl restart zabbix-server
systemctl restart grafana-server

# Start Docker containers
cd /opt/nexterm && docker compose up -d || true

log_info "All services restarted"

#################################################################
# STEP 8: Final Status Check
#################################################################
log_info "Step 8: Checking service status..."

echo ""
echo "=========================================="
echo "LOR-CGR System Status"
echo "=========================================="

# Check services
services=(
    "postgresql"
    "mariadb"
    "redis-server"
    "php8.1-fpm"
    "nginx"
    "lorcgr-api"
    "lorcgr-frontend"
    "zabbix-server"
    "grafana-server"
    "docker"
)

for service in "${services[@]}"; do
    status=$(systemctl is-active $service 2>/dev/null || echo "inactive")
    if [ "$status" = "active" ]; then
        echo -e "✓ $service: ${GREEN}RUNNING${NC}"
    else
        echo -e "✗ $service: ${RED}STOPPED${NC}"
    fi
done

# Check Docker containers
echo ""
echo "Docker Containers:"
docker ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || echo "No containers running"

echo ""
echo "=========================================="
echo "Access URLs:"
echo "=========================================="
echo "Main Dashboard:    http://45.71.242.131/"
echo "Django API:        http://45.71.242.131/api/"
echo "LibreNMS:          http://45.71.242.131/librenms/"
echo "phpIPAM:           http://45.71.242.131/phpipam/"
echo "Zabbix:            http://45.71.242.131/zabbix/"
echo "Grafana:           http://45.71.242.131/grafana/"
echo "Nexterm:           http://45.71.242.131/nexterm/"
echo ""
echo "Credentials: lorcgr / Lor#Cgr#2026"
echo "=========================================="

log_info "Installation completed!"
EOF

chmod +x /home/z/my-project/download/lorcgr_continue_install.sh
