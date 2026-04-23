#!/bin/bash
# ========================================
# ATUALIZAR WEBSOCKET - Terminal SSH Real
# ========================================

echo "========================================"
echo "Atualizando WebSocket para Terminal SSH"
echo "========================================"

# 1. Criar consumidor WebSocket melhorado
echo "[1] Criando consumer WebSocket..."
mkdir -p /opt/lorcgr/terminal

cat > /opt/lorcgr/terminal/__init__.py << 'EOF'
# Terminal app
EOF

cat > /opt/lorcgr/terminal/consumers.py << 'EOFCONSUMER'
import json
import asyncio
import paramiko
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
import psycopg2

class SSHTerminalConsumer(AsyncWebsocketConsumer):
    """WebSocket Consumer para SSH em tempo real"""

    async def connect(self):
        self.device_id = self.scope['url_route']['kwargs'].get('device_id')
        self.ssh_client = None
        self.channel = None
        self.connected = False

        await self.accept()
        
        # Buscar credenciais
        device = await self.get_device_credentials()
        
        if not device:
            await self.send(json.dumps({
                'type': 'error',
                'data': 'Dispositivo não encontrado'
            }))
            await self.close()
            return

        # Conectar SSH
        try:
            self.ssh_client = paramiko.SSHClient()
            self.ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

            # Determinar protocolo
            protocol = device.get('protocol', 'ssh')
            
            if protocol == 'telnet':
                # Telnet não suportado ainda
                await self.send(json.dumps({
                    'type': 'error',
                    'data': 'Telnet não suportado. Use SSH.'
                }))
                await self.close()
                return

            # SSH
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

            # Criar shell PTY
            self.channel = self.ssh_client.invoke_shell(
                term='xterm-256color',
                width=120,
                height=40
            )
            self.channel.setblocking(0)
            self.connected = True

            await self.send(json.dumps({
                'type': 'connected',
                'data': f'Conectado! Protocolo: SSH v{device.get("ssh_version", "2")}'
            }))

            # Iniciar leitura em background
            asyncio.create_task(self.read_ssh_output())

        except paramiko.AuthenticationException as e:
            await self.send(json.dumps({
                'type': 'error',
                'data': f'Falha na autenticação SSH: {str(e)}'
            }))
        except paramiko.SSHException as e:
            await self.send(json.dumps({
                'type': 'error',
                'data': f'Erro SSH: {str(e)}'
            }))
        except Exception as e:
            await self.send(json.dumps({
                'type': 'error',
                'data': f'Erro de conexão: {str(e)}'
            }))

    async def disconnect(self, close_code):
        self.connected = False
        if self.channel:
            try:
                self.channel.close()
            except:
                pass
        if self.ssh_client:
            try:
                self.ssh_client.close()
            except:
                pass

    async def receive(self, text_data):
        if not self.connected or not self.channel:
            return

        try:
            data = json.loads(text_data)
            
            if data.get('type') == 'input':
                # Enviar input diretamente
                self.channel.send(data.get('data', ''))
                
            elif data.get('type') == 'resize':
                cols = data.get('cols', 120)
                rows = data.get('rows', 40)
                if self.channel:
                    self.channel.resize_pty(width=cols, height=rows)
                    
        except Exception as e:
            print(f"Erro no receive: {e}")

    async def read_ssh_output(self):
        """Ler output do SSH continuamente"""
        while self.connected:
            try:
                if self.channel.recv_ready():
                    output = self.channel.recv(4096)
                    if output:
                        try:
                            text = output.decode('utf-8')
                        except:
                            text = output.decode('latin-1', errors='replace')
                        
                        await self.send(json.dumps({
                            'type': 'output',
                            'data': text
                        }))
                else:
                    await asyncio.sleep(0.005)
                
                if self.channel.closed:
                    self.connected = False
                    await self.send(json.dumps({
                        'type': 'disconnected',
                        'data': 'Conexão SSH encerrada'
                    }))
                    break
                    
            except Exception as e:
                print(f"Erro na leitura: {e}")
                await asyncio.sleep(0.1)

    @database_sync_to_async
    def get_device_credentials(self):
        try:
            conn = psycopg2.connect(
                dbname='lorcgr',
                user='lorcgr',
                password='lorcgr123',
                host='localhost'
            )
            cur = conn.cursor()
            cur.execute("""
                SELECT id, name, ip, port, username, password,
                       ssh_user, ssh_password, ssh_port, ssh_version,
                       protocol, telnet_enabled, telnet_port
                FROM devices WHERE id = %s
            """, [self.device_id])
            row = cur.fetchone()
            cur.close()
            conn.close()
            
            if row:
                return {
                    'id': row[0],
                    'name': row[1],
                    'ip': row[2],
                    'port': row[3],
                    'username': row[4],
                    'password': row[5],
                    'ssh_user': row[6],
                    'ssh_password': row[7],
                    'ssh_port': row[8],
                    'ssh_version': row[9],
                    'protocol': row[10],
                    'telnet_enabled': row[11],
                    'telnet_port': row[12]
                }
            return None
        except Exception as e:
            print(f"Erro ao buscar dispositivo: {e}")
            return None
EOFCONSUMER

# 2. Atualizar routing
echo "[2] Atualizando routing..."
cat > /opt/lorcgr/lorcgr_core/routing.py << 'EOF'
from django.urls import re_path
from terminal.consumers import SSHTerminalConsumer

websocket_urlpatterns = [
    re_path(r'ws/terminal/(?P<device_id>\d+)/$', SSHTerminalConsumer.as_asgi()),
]
EOF

# 3. Verificar settings
echo "[3] Verificando settings.py..."
if ! grep -q "'channels'" /opt/lorcgr/lorcgr_core/settings.py; then
    sed -i "s/INSTALLED_APPS = \[/INSTALLED_APPS = [\n    'channels',\n    'terminal',/" /opt/lorcgr/lorcgr_core/settings.py
fi

if ! grep -q "ASGI_APPLICATION" /opt/lorcgr/lorcgr_core/settings.py; then
    cat >> /opt/lorcgr/lorcgr_core/settings.py << 'EOF'

# Django Channels
ASGI_APPLICATION = 'lorcgr_core.asgi.application'

CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels.layers.InMemoryChannelLayer'
    }
}
EOF
fi

# 4. Verificar ASGI
echo "[4] Verificando ASGI..."
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
    "websocket": AuthMiddlewareStack(
        URLRouter(websocket_urlpatterns)
    ),
})
EOF

# 5. Reiniciar serviços
echo "[5] Reiniciando serviços..."
systemctl daemon-reload
systemctl restart lorcgr-backend
systemctl restart lorcgr-websocket 2>/dev/null || echo "WebSocket service not found, starting manually..."

# Se não existir o serviço, criar
if ! systemctl is-active lorcgr-websocket &>/dev/null; then
    echo "[6] Criando serviço WebSocket..."
    cat > /etc/systemd/system/lorcgr-websocket.service << 'EOFSVC'
[Unit]
Description=LOR-CGR WebSocket Server (Daphne)
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
    systemctl daemon-reload
    systemctl enable lorcgr-websocket
    systemctl start lorcgr-websocket
fi

# 6. Atualizar Nginx para WebSocket
echo "[7] Verificando Nginx..."
if ! grep -q "/ws/" /etc/nginx/sites-available/lorcgr; then
    echo "Atualizando Nginx..."
    cat > /etc/nginx/sites-available/lorcgr << 'EOFNGINX'
upstream nextjs_backend { server 127.0.0.1:3000; }
upstream django_api { server 127.0.0.1:8000; }
upstream websocket { server 127.0.0.1:8001; }

server {
    listen 80 default_server;
    server_name lorcgr.xlab.online 45.71.242.131;

    access_log /var/log/nginx/lorcgr-access.log;
    error_log /var/log/nginx/lorcgr-error.log;
    client_max_body_size 50M;

    # WebSocket
    location /ws/ {
        proxy_pass http://websocket;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }

    # Django API
    location /api/ {
        proxy_pass http://django_api;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Django Admin
    location /admin/ {
        proxy_pass http://django_api;
        proxy_set_header Host $host;
    }

    location /static/ {
        alias /opt/lorcgr/static/;
    }

    # Next.js
    location / {
        proxy_pass http://nextjs_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /_next/static/ {
        proxy_pass http://nextjs_backend;
    }
}
EOFNGINX
    systemctl restart nginx
fi

sleep 3

# Verificar status
echo ""
echo "[8] Status dos serviços:"
echo "Backend:"
systemctl status lorcgr-backend --no-pager | head -5
echo ""
echo "WebSocket:"
systemctl status lorcgr-websocket --no-pager | head -5

echo ""
echo "========================================"
echo "WEBSOCKET ATUALIZADO!"
echo "========================================"
echo ""
echo "Teste o WebSocket:"
echo "  curl -v http://127.0.0.1:8001/ws/terminal/8/"
echo ""
