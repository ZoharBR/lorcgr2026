#!/bin/bash

################################################################################
# LOR-CGR Installation Script - Part 8: Nginx Reverse Proxy
################################################################################

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  LOR-CGR - Configuração do Nginx${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script deve ser executado como root!${NC}"
   exit 1
fi

PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")

#######################################
# Instalar Nginx
#######################################
echo -e "${YELLOW}>>> Instalando Nginx...${NC}"
apt-get install -y nginx

#######################################
# Criar configuração principal
#######################################
echo -e "${YELLOW}>>> Criando configuração do LOR-CGR...${NC}"

cat > /etc/nginx/sites-available/lorcgr << 'NGINXEOF'
# LOR-CGR - Network Management System
# Nginx Reverse Proxy Configuration

# Upstream para Django API
upstream django_api {
    server 127.0.0.1:8000;
    keepalive 32;
}

# Upstream para Next.js
upstream nextjs {
    server 127.0.0.1:3001;
    keepalive 32;
}

# Upstream para WebSocket
upstream websocket {
    server 127.0.0.1:8001;
}

# Upstream para Grafana
upstream grafana {
    server 127.0.0.1:3000;
}

# Upstream para Nexterm
upstream nexterm {
    server 127.0.0.1:6989;
}

# Upstream para Zabbix
upstream zabbix {
    server 127.0.0.1:8080;
}

server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    # Logging
    access_log /var/log/nginx/lorcgr_access.log;
    error_log /var/log/nginx/lorcgr_error.log;

    # Client max body size
    client_max_body_size 100M;

    # ==========================================
    # LOR-CGR Frontend (Next.js) - ROTA PRINCIPAL
    # ==========================================
    location / {
        proxy_pass http://nextjs;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }

    # ==========================================
    # Django API
    # ==========================================
    location /api/ {
        proxy_pass http://django_api/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }

    # ==========================================
    # Django Admin e Static
    # ==========================================
    location /admin/ {
        proxy_pass http://django_api/admin/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /static/ {
        alias /opt/lorcgr/static/;
        expires 30d;
    }

    # ==========================================
    # WebSocket
    # ==========================================
    location /ws/ {
        proxy_pass http://websocket/ws/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 86400;
    }

    # ==========================================
    # Grafana
    # ==========================================
    location /grafana/ {
        proxy_pass http://grafana/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # ==========================================
    # LibreNMS
    # ==========================================
    location /librenms/ {
        alias /opt/librenms/public/;
        index index.php index.html;

        try_files $uri $uri/ /librenms/index.php?$query_string;

        location ~ \.php$ {
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME $request_filename;
            fastcgi_pass unix:/run/php/librenms.sock;
            fastcgi_split_path_info ^(.+\.php)(/.+)$;
            fastcgi_param PATH_INFO $fastcgi_path_info;
        }

        location ~ /\.ht {
            deny all;
        }
    }

    # LibreNMS API
    location /librenms/api/ {
        alias /opt/librenms/public/api/v0/;
        try_files $uri $uri/ /librenms/index.php?$query_string;

        location ~ \.php$ {
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME $request_filename;
            fastcgi_pass unix:/run/php/librenms.sock;
        }
    }

    # ==========================================
    # phpIPAM
    # ==========================================
    location /phpipam/ {
        alias /opt/phpipam/;
        index index.php index.html;

        try_files $uri $uri/ /phpipam/index.php?$query_string;

        location ~ \.php$ {
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME $request_filename;
            fastcgi_pass unix:/run/php/phpipam.sock;
        }

        location ~ /\.ht {
            deny all;
        }
    }

    # ==========================================
    # Zabbix
    # ==========================================
    location /zabbix/ {
        proxy_pass http://zabbix/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        # Aumentar timeouts para Zabbix
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }

    # ==========================================
    # Nexterm (Terminal/RDP)
    # ==========================================
    location /nexterm/ {
        proxy_pass http://nexterm/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }

    # Nexterm WebSocket
    location /nexterm/ws {
        proxy_pass http://nexterm/ws;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 86400s;
    }

    # ==========================================
    # Health Check
    # ==========================================
    location /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }
}
NGINXEOF

#######################################
# Ativar site
#######################################
echo -e "${YELLOW}>>> Ativando site...${NC}"
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/lorcgr /etc/nginx/sites-enabled/lorcgr

#######################################
# Testar configuração
#######################################
echo -e "${YELLOW}>>> Testando configuração...${NC}"
nginx -t

#######################################
# Reiniciar Nginx
#######################################
echo -e "${YELLOW}>>> Reiniciando Nginx...${NC}"
systemctl restart nginx
systemctl enable nginx

#######################################
# Verificar status
#######################################
echo -e "${YELLOW}>>> Verificando status...${NC}"
if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✓ Nginx está rodando${NC}"
else
    echo -e "${RED}✗ Nginx não está rodando${NC}"
    journalctl -u nginx --no-pager -n 20
fi

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  Nginx configurado com sucesso!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "URLs de acesso:"
echo "  LOR-CGR:    http://seu-ip/"
echo "  LibreNMS:   http://seu-ip/librenms/"
echo "  phpIPAM:    http://seu-ip/phpipam/"
echo "  Zabbix:     http://seu-ip/zabbix/"
echo "  Grafana:    http://seu-ip/grafana/"
echo "  Nexterm:    http://seu-ip/nexterm/"
echo ""
echo "Próximo passo: Execute o script 09-install-django.sh"
