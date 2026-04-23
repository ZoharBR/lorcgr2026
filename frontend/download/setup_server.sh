#!/bin/bash
#
# Server-side setup script for LOR-CGR Next.js Frontend
# Run this script ON THE SERVER after uploading the build files
#
# Usage: sudo ./setup_server.sh
#

set -e

echo "================================================"
echo "LOR-CGR Server Setup Script"
echo "================================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo ./setup_server.sh)"
    exit 1
fi

FRONTEND_PATH="/opt/lorcgr-frontend"
USE_NGINX="${USE_NGINX:-true}"

# 1. Install Node.js if not installed
echo "[1/6] Checking Node.js installation..."
if ! command -v node &> /dev/null; then
    echo "Installing Node.js 20..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
fi
echo "Node.js version: $(node --version)"
echo "npm version: $(npm --version)"

# 2. Create directory structure
echo "[2/6] Creating directory structure..."
mkdir -p ${FRONTEND_PATH}/{.next/static,public}
mkdir -p /var/log/lorcgr

# 3. Set permissions
echo "[3/6] Setting permissions..."
if id "www-data" &>/dev/null; then
    chown -R www-data:www-data ${FRONTEND_PATH}
    chown -R www-data:www-data /var/log/lorcgr
else
    echo "Warning: www-data user not found, skipping permission changes"
fi
chmod -R 755 ${FRONTEND_PATH}

# 4. Create systemd service
echo "[4/6] Creating systemd service..."
cat > /etc/systemd/system/lorcgr-frontend.service << 'EOF'
[Unit]
Description=LOR-CGR Next.js Frontend
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/lorcgr-frontend
Environment=NODE_ENV=production
Environment=PORT=3000
Environment=HOSTNAME=0.0.0.0
ExecStart=/usr/bin/node /opt/lorcgr-frontend/server.js
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=lorcgr-frontend

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable lorcgr-frontend

# 5. Configure Nginx or Caddy
echo "[5/6] Configuring reverse proxy..."

if command -v nginx &> /dev/null && [ "$USE_NGINX" = "true" ]; then
    echo "Configuring Nginx..."
    
    cat > /etc/nginx/sites-available/lorcgr << 'EOF'
server {
    listen 80;
    server_name _;
    
    # Next.js Frontend
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
    
    # Next.js static files
    location /_next/static {
        alias /opt/lorcgr-frontend/.next/static;
        expires 365d;
        add_header Cache-Control "public, max-age=31536000, immutable";
    }
    
    # Django Backend API
    location /api {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    
    # Django Admin
    location /admin {
        proxy_pass http://127.0.0.1:8000;
    }
    
    # Django static files
    location /static {
        proxy_pass http://127.0.0.1:8000;
    }
    
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
}
EOF

    ln -sf /etc/nginx/sites-available/lorcgr /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    nginx -t && systemctl reload nginx
    echo "Nginx configured successfully!"
    
elif command -v caddy &> /dev/null; then
    echo "Configuring Caddy..."
    
    cat > /etc/caddy/Caddyfile << 'EOF'
http://:80 {
    # Django API
    handle /api/* {
        reverse_proxy localhost:8000
    }
    
    handle /admin/* {
        reverse_proxy localhost:8000
    }
    
    handle /static/* {
        reverse_proxy localhost:8000
    }
    
    # Next.js Frontend
    handle {
        reverse_proxy localhost:3000
    }
    
    encode gzip
}
EOF

    systemctl reload caddy
    echo "Caddy configured successfully!"
else
    echo "Warning: Neither Nginx nor Caddy found. Please configure reverse proxy manually."
fi

# 6. Start the service
echo "[6/6] Starting lorcgr-frontend service..."
systemctl start lorcgr-frontend

# Show status
echo ""
echo "================================================"
echo "Setup Complete!"
echo "================================================"
echo ""
systemctl status lorcgr-frontend --no-pager || true
echo ""
echo "Your application is now available at:"
echo "  http://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP')"
echo ""
echo "Useful commands:"
echo "  - Check status: sudo systemctl status lorcgr-frontend"
echo "  - View logs:    sudo journalctl -u lorcgr-frontend -f"
echo "  - Restart:      sudo systemctl restart lorcgr-frontend"
echo ""
