#!/bin/bash
# ========================================
# DEPLOY COMPLETO - Terminal Profissional
# ========================================

set -e

FRONTEND_URL="https://files.catbox.moe/awnl3o.gz"
STATIC_URL="https://files.catbox.moe/6nr2vz.gz"

echo "========================================"
echo "DEPLOY COMPLETO - Terminal Profissional"
echo "========================================"

# 1. Instalar dependências Python
echo "[1] Instalando dependências..."
source /opt/lorcgr/venv/bin/activate
pip install channels paramiko daphne -q

# 2. Criar app terminal
echo "[2] Criando app terminal..."
mkdir -p /opt/lorcgr/terminal

cat > /opt/lorcgr/terminal/__init__.py << 'EOF'
EOF

cat > /opt/lorcgr/terminal/consumers.py << 'EOFCONSUMER'
import json
import asyncio
import paramiko
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
import psycopg2

class SSHTerminalConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.device_id = self.scope['url_route']['kwargs'].get('device_id')
        self.ssh_client = None
        self.channel = None
        self.connected = False

        await self.accept()
        device = await self.get_device_credentials()
        
        if not device:
            await self.send(json.dumps({'type': 'error', 'data': 'Dispositivo nao encontrado'}))
            await self.close()
            return

        try:
            self.ssh_client = paramiko.SSHClient()
            self.ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

            ssh_user = device.get('ssh_user') or device.get('username') or 'admin'
            ssh_pass = device.get('ssh_password') or device.get('password') or ''
            ssh_port = device.get('ssh_port') or device.get('port') or 22

            await self.send(json.dumps({
                'type': 'status',
                'data': f'Conectando a {device["name"]} ({device["ip"]}:{ssh_port})...'
            }))

            self.ssh_client.connect(
                hostname=str(device['ip']),
                port=ssh_port,
                username=ssh_user,
                password=ssh_pass,
                timeout=15,
                look_for_keys=False,
                allow_agent=False
            )

            self.channel = self.ssh_client.invoke_shell(
                term='xterm-256color', width=120, height=40
            )
            self.channel.setblocking(0)
            self.connected = True

            await self.send(json.dumps({
                'type': 'connected',
                'data': f'Conectado! Usuario: {ssh_user}'
            }))

            asyncio.create_task(self.read_ssh_output())

        except Exception as e:
            await self.send(json.dumps({'type': 'error', 'data': f'Erro: {str(e)}'}))

    async def disconnect(self, close_code):
        self.connected = False
        if self.channel:
            try: self.channel.close()
            except: pass
        if self.ssh_client:
            try: self.ssh_client.close()
            except: pass

    async def receive(self, text_data):
        if not self.connected or not self.channel:
            return
        try:
            data = json.loads(text_data)
            if data.get('type') == 'input':
                self.channel.send(data.get('data', ''))
            elif data.get('type') == 'resize':
                self.channel.resize_pty(width=data.get('cols', 120), height=data.get('rows', 40))
        except Exception as e:
            print(f"Erro: {e}")

    async def read_ssh_output(self):
        while self.connected:
            try:
                if self.channel.recv_ready():
                    output = self.channel.recv(4096)
                    if output:
                        try:
                            text = output.decode('utf-8')
                        except:
                            text = output.decode('latin-1', errors='replace')
                        await self.send(json.dumps({'type': 'output', 'data': text}))
                else:
                    await asyncio.sleep(0.005)
                if self.channel.closed:
                    self.connected = False
                    await self.send(json.dumps({'type': 'disconnected', 'data': 'Conexao encerrada'}))
                    break
            except Exception as e:
                await asyncio.sleep(0.1)

    @database_sync_to_async
    def get_device_credentials(self):
        try:
            conn = psycopg2.connect(dbname='lorcgr', user='lorcgr', password='lorcgr123', host='localhost')
            cur = conn.cursor()
            cur.execute("SELECT id, name, ip, port, username, password, ssh_user, ssh_password, ssh_port FROM devices WHERE id = %s", [self.device_id])
            row = cur.fetchone()
            cur.close()
            conn.close()
            if row:
                return {'id': row[0], 'name': row[1], 'ip': row[2], 'port': row[3], 'username': row[4], 'password': row[5], 'ssh_user': row[6], 'ssh_password': row[7], 'ssh_port': row[8]}
            return None
        except Exception as e:
            print(f"Erro DB: {e}")
            return None
EOFCONSUMER

# 3. Routing
cat > /opt/lorcgr/lorcgr_core/routing.py << 'EOF'
from django.urls import re_path
from terminal.consumers import SSHTerminalConsumer
websocket_urlpatterns = [
    re_path(r'ws/terminal/(?P<device_id>\d+)/$', SSHTerminalConsumer.as_asgi()),
]
EOF

# 4. ASGI
cat > /opt/lorcgr/lorcgr_core/asgi.py << 'EOF'
import os
import django
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'lorcgr_core.settings')
django.setup()

from lorcgr_core.routing import websocket_urlpatterns

application = ProtocolTypeRouter({
    "http": django.core.asgi.get_asgi_application(),
    "websocket": AuthMiddlewareStack(URLRouter(websocket_urlpatterns)),
})
EOF

# 5. Settings
if ! grep -q "'channels'" /opt/lorcgr/lorcgr_core/settings.py; then
    sed -i "s/INSTALLED_APPS = \[/INSTALLED_APPS = [\n    'channels',\n    'terminal',/" /opt/lorcgr/lorcgr_core/settings.py
fi

if ! grep -q "ASGI_APPLICATION" /opt/lorcgr/lorcgr_core/settings.py; then
    echo '
ASGI_APPLICATION = "lorcgr_core.asgi.application"
CHANNEL_LAYERS = {"default": {"BACKEND": "channels.layers.InMemoryChannelLayer"}}' >> /opt/lorcgr/lorcgr_core/settings.py
fi

# 6. Serviço WebSocket
cat > /etc/systemd/system/lorcgr-websocket.service << 'EOFSVC'
[Unit]
Description=LOR-CGR WebSocket Server
After=network.target postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/lorcgr
Environment="PATH=/opt/lorcgr/venv/bin"
ExecStart=/opt/lorcgr/venv/bin/daphne -b 0.0.0.0 -p 8001 lorcgr_core.asgi:application
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOFSVC

# 7. Nginx
cat > /etc/nginx/sites-available/lorcgr << 'EOFNGINX'
upstream nextjs_backend { server 127.0.0.1:3000; }
upstream django_api { server 127.0.0.1:8000; }
upstream websocket { server 127.0.0.1:8001; }

server {
    listen 80 default_server;
    server_name lorcgr.xlab.online 45.71.242.131;

    client_max_body_size 50M;

    location /ws/ {
        proxy_pass http://websocket;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }

    location /api/ {
        proxy_pass http://django_api;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /admin/ {
        proxy_pass http://django_api;
        proxy_set_header Host $host;
    }

    location /static/ {
        alias /opt/lorcgr/static/;
    }

    location / {
        proxy_pass http://nextjs_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOFNGINX

# 8. Frontend
echo "[3] Instalando frontend..."
rm -rf /opt/lorcgr-frontend/*
mkdir -p /opt/lorcgr-frontend

cd /tmp
curl -sL "$FRONTEND_URL" -o frontend.tar.gz
tar -xzf frontend.tar.gz -C /opt/lorcgr-frontend/
rm frontend.tar.gz

mkdir -p /opt/lorcgr-frontend/.next/static
curl -sL "$STATIC_URL" -o static.tar.gz
tar -xzf static.tar.gz -C /opt/lorcgr-frontend/.next/static/
rm static.tar.gz

# 9. Reiniciar tudo
echo "[4] Reiniciando serviços..."
systemctl daemon-reload
systemctl enable lorcgr-websocket
systemctl restart lorcgr-backend
systemctl restart lorcgr-websocket
systemctl restart lorcgr-frontend
systemctl restart nginx

sleep 3

echo ""
echo "Status:"
systemctl status lorcgr-backend --no-pager | head -3
systemctl status lorcgr-websocket --no-pager | head -3
systemctl status lorcgr-frontend --no-pager | head -3

echo ""
echo "========================================"
echo "DEPLOY CONCLUIDO!"
echo "========================================"
echo ""
echo "Terminal SSH Profissional instalado!"
echo "Acesse: http://45.71.242.131/"
echo ""
