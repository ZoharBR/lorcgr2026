#!/bin/bash
#################################################################
# LOR-CGR - Script de Correção
#################################################################

echo "=========================================="
echo "LOR-CGR - Corrigindo Problemas"
echo "=========================================="

VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
NC='\033[0m'

ok() { echo -e "${VERDE}[OK]${NC} $1"; }
erro() { echo -e "${VERMELHO}[ERRO]${NC} $1"; }

#################################################################
# 1. CORRIGIR POOL PHP-FPM
#################################################################
echo "[1] Corrigindo configuração PHP-FPM..."

# Remover pools com problemas
rm -f /etc/php/8.1/fpm/pool.d/phpipam.conf 2>/dev/null
rm -f /etc/php/8.1/fpm/pool.d/librenms.conf 2>/dev/null

# Verificar e corrigir www.conf
cat > /etc/php/8.1/fpm/pool.d/www.conf << 'EOF'
[www]
user = www-data
group = www-data
listen = /run/php/php8.1-fpm.sock
listen.owner = www-data
listen.group = www-data
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
pm.max_requests = 500
EOF

# Criar pool para LibreNMS
cat > /etc/php/8.1/fpm/pool.d/librenms.conf << 'EOF'
[librenms]
user = librenms
group = librenms
listen = /run/php/php8.1-fpm-librenms.sock
listen.owner = www-data
listen.group = www-data
pm = dynamic
pm.max_children = 30
pm.start_servers = 3
pm.min_spare_servers = 3
pm.max_spare_servers = 10
pm.max_requests = 500
EOF

# Criar pool para phpIPAM
cat > /etc/php/8.1/fpm/pool.d/phpipam.conf << 'EOF'
[phpipam]
user = www-data
group = www-data
listen = /run/php/php8.1-fpm-phpipam.sock
listen.owner = www-data
listen.group = www-data
pm = dynamic
pm.max_children = 30
pm.start_servers = 3
pm.min_spare_servers = 3
pm.max_spare_servers = 10
pm.max_requests = 500
EOF

systemctl restart php8.1-fpm
ok "PHP-FPM: $(systemctl is-active php8.1-fpm)"

#################################################################
# 2. CORRIGIR NGINX - CRIAR MIME.TYPES
#################################################################
echo "[2] Corrigindo configuração Nginx..."

# Criar arquivo mime.types
cat > /etc/nginx/mime.types << 'EOF'
types {
    text/html                             html htm shtml;
    text/css                              css;
    text/xml                              xml;
    image/gif                             gif;
    image/jpeg                            jpeg jpg;
    application/javascript                js;
    application/atom+xml                  atom;
    application/rss+xml                   rss;

    text/mathml                           mml;
    text/plain                            txt;
    text/vnd.sun.j2me.app-descriptor      jad;
    text/vnd.wap.wml                      wml;
    text/x-component                      htc;

    image/png                             png;
    image/tiff                            tif tiff;
    image/vnd.wap.wbmp                    wbmp;
    image/x-icon                          ico;
    image/x-jng                           jng;
    image/x-ms-bmp                        bmp;
    image/svg+xml                         svg svgz;
    image/webp                            webp;

    application/font-woff                 woff;
    application/java-archive              jar war ear;
    application/json                      json;
    application/mac-binhex40              hqx;
    application/msword                    doc;
    application/pdf                       pdf;
    application/postscript                ps eps ai;
    application/rtf                       rtf;
    application/vnd.apple.mpegurl         m3u8;
    application/vnd.ms-excel              xls;
    application/vnd.ms-fontobject         eot;
    application/vnd.ms-powerpoint         ppt;
    application/vnd.wap.wmlc              wmlc;
    application/vnd.google-earth.kml+xml  kml;
    application/vnd.google-earth.kmz      kmz;
    application/x-7z-compressed           7z;
    application/x-cocoa                   cco;
    application/x-java-archive-diff       jardiff;
    application/x-java-jnlp-file          jnlp;
    application/x-makeself                run;
    application/x-perl                    pl pm;
    application/x-pilot                   prc pdb;
    application/x-rar-compressed          rar;
    application/x-redhat-package-manager  rpm;
    application/x-sea                     sea;
    application/x-shockwave-flash         swf;
    application/x-stuffit                 sit;
    application/x-tcl                     tcl tk;
    application/x-x509-ca-cert            der pem crt;
    application/x-xpinstall               xpi;
    application/xhtml+xml                 xhtml;
    application/xspf+xml                  xspf;
    application/zip                       zip;

    application/octet-stream              bin exe dll;
    application/octet-stream              deb;
    application/octet-stream              dmg;
    application/octet-stream              iso img;
    application/octet-stream              msi msp msm;

    application/vnd.openxmlformats-officedocument.wordprocessingml.document    docx;
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet          xlsx;
    application/vnd.openxmlformats-officedocument.presentationml.presentation  pptx;

    audio/midi                            mid midi kar;
    audio/mpeg                            mp3;
    audio/ogg                             ogg;
    audio/x-m4a                           m4a;
    audio/x-realaudio                     ra;

    video/3gpp                            3gpp 3gp;
    video/mp2t                            ts;
    video/mp4                             mp4;
    video/mpeg                            mpeg mpg;
    video/quicktime                       mov;
    video/webm                            webm;
    video/x-flv                           flv;
    video/x-m4v                           m4v;
    video/x-mng                           mng;
    video/x-ms-asf                        asx asf;
    video/x-ms-wmv                        wmv;
    video/x-msvideo                       avi;
}
EOF

# Recriar configuração do Nginx
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
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

# Criar configuração do site
mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled

cat > /etc/nginx/sites-available/lorcgr.conf << 'EOF'
# LOR-CGR - Configuração Principal

upstream django_api {
    server 127.0.0.1:8000;
}

upstream nextjs_frontend {
    server 127.0.0.1:3000;
}

server {
    listen 80 default_server;
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
        proxy_set_header X-Real-IP $remote_addr;
        proxy_cache_bypass $http_upgrade;
    }

    # Django API
    location /api/ {
        proxy_pass http://django_api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # LibreNMS
    location /librenms/ {
        alias /opt/librenms/html/;
        index index.php;

        location ~ \.php$ {
            fastcgi_pass unix:/run/php/php8.1-fpm-librenms.sock;
            fastcgi_param SCRIPT_FILENAME $request_filename;
            include fastcgi_params;
        }
    }

    # phpIPAM
    location /phpipam/ {
        alias /opt/phpipam/;
        index index.php;

        location ~ \.php$ {
            fastcgi_pass unix:/run/php/php8.1-fpm-phpipam.sock;
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
        proxy_set_header X-Real-IP $remote_addr;
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
        return 200 'LOR-CGR OK';
        add_header Content-Type text/plain;
    }
}
EOF

# Ativar site
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/lorcgr.conf /etc/nginx/sites-enabled/lorcgr.conf

# Testar e reiniciar
nginx -t && systemctl restart nginx
ok "Nginx: $(systemctl is-active nginx)"

#################################################################
# 3. INSTALAR EXTENSÕES PHP FALTANTES
#################################################################
echo "[3] Instalando extensões PHP..."

apt-get update
apt-get install -y php8.1-phar php8.1-mbstring php8.1-iconv php8.1-xml php8.1-curl php8.1-zip php8.1-gd php8.1-mysql php8.1-sqlite3 php8.1-bcmath php8.1-intl php8.1-opcache

systemctl restart php8.1-fpm
ok "Extensões PHP instaladas"

#################################################################
# 4. INSTALAR COMPOSER E CONFIGURAR LIBRENMS
#################################################################
echo "[4] Configurando LibreNMS..."

# Instalar composer se não existir
if ! command -v composer &> /dev/null; then
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
fi

cd /opt/librenms

# Instalar dependências
if [ -f "composer.json" ]; then
    sudo -u librenms composer install --no-interaction --no-dev --prefer-dist || true
fi

# Configurar .env
cat > .env << 'EOF'
APP_ENV=production
APP_DEBUG=false
APP_URL=http://45.71.242.131/librenms
DB_HOST=127.0.0.1
DB_DATABASE=librenms
DB_USERNAME=lorcgr
DB_PASSWORD=Lor#Cgr#2026
EOF

chown -R librenms:librenms /opt/librenms
chmod -R 775 /opt/librenms

ok "LibreNMS configurado"

#################################################################
# 5. REINICIAR TODOS OS SERVIÇOS
#################################################################
echo "[5] Reiniciando serviços..."

systemctl restart postgresql
systemctl restart mariadb
systemctl restart redis-server
systemctl restart php8.1-fpm
systemctl restart nginx
systemctl restart zabbix-server
systemctl restart grafana-server

# Reiniciar containers Docker
cd /opt/nexterm && docker compose up -d 2>/dev/null || docker start nexterm 2>/dev/null || true

#################################################################
# 6. STATUS FINAL
#################################################################
echo ""
echo "=========================================="
echo "  STATUS FINAL DO SISTEMA"
echo "=========================================="

for servico in postgresql mariadb redis-server php8.1-fpm nginx zabbix-server grafana-server docker; do
    status=$(systemctl is-active $servico 2>/dev/null || echo "parado")
    if [ "$status" = "active" ]; then
        echo -e "✓ $servico: ${VERDE}OK${NC}"
    else
        echo -e "✗ $servico: ${VERMELHO}FALHOU${NC}"
    fi
done

# Verificar container Nexterm
if docker ps | grep -q nexterm; then
    echo -e "✓ nexterm: ${VERDE}OK${NC}"
else
    echo -e "✗ nexterm: ${VERMELHO}FALHOU${NC}"
fi

echo ""
echo "=========================================="
echo "  URLs DE ACESSO"
echo "=========================================="
echo "Dashboard:     http://45.71.242.131/"
echo "API:           http://45.71.242.131/api/"
echo "LibreNMS:      http://45.71.242.131/librenms/"
echo "phpIPAM:       http://45.71.242.131/phpipam/"
echo "Zabbix:        http://45.71.242.131/zabbix/"
echo "Grafana:       http://45.71.242.131/grafana/"
echo "Nexterm:       http://45.71.242.131/nexterm/"
echo ""
echo "Credenciais: lorcgr / Lor#Cgr#2026"
echo "=========================================="
