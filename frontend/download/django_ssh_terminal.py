# ========================================
# DJANGO CHANNELS - SSH Terminal WebSocket
# ========================================
#
# Este arquivo implementa terminal SSH em tempo real via WebSocket
# Instale no servidor: pip install channels paramiko
#
# Estrutura de arquivos a criar no servidor:
# /opt/lorcgr/lorcgr_core/routing.py
# /opt/lorcgr/terminal/consumers.py
# /opt/lorcgr/terminal/__init__.py
#
# ========================================

# ==========================================
# 1. /opt/lorcgr/lorcgr_core/routing.py
# ==========================================
ROUTING_PY = '''
from django.urls import re_path
from terminal.consumers import SSHTerminalConsumer

websocket_urlpatterns = [
    re_path(r'ws/terminal/(?P<device_id>\d+)/$', SSHTerminalConsumer.as_asgi()),
]
'''

# ==========================================
# 2. /opt/lorcgr/terminal/__init__.py
# ==========================================
TERMINAL_INIT = '''
# Terminal app for SSH WebSocket
'''

# ==========================================
# 3. /opt/lorcgr/terminal/consumers.py
# ==========================================
CONSUMERS_PY = '''
import json
import asyncio
import paramiko
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
import psycopg2

class SSHTerminalConsumer(AsyncWebsocketConsumer):
    """WebSocket Consumer para SSH em tempo real"""

    async def connect(self):
        self.device_id = self.scope['url_route']['kwargs']['device_id']
        self.ssh_client = None
        self.channel = None
        self.connected = False

        await self.accept()
        await self.send(text_data=json.dumps({
            'type': 'status',
            'data': 'Conectando ao dispositivo...'
        }))

        # Buscar credenciais do dispositivo
        device = await self.get_device_credentials()

        if not device:
            await self.send(text_data=json.dumps({
                'type': 'error',
                'data': 'Dispositivo não encontrado'
            }))
            await self.close()
            return

        # Conectar via SSH
        try:
            self.ssh_client = paramiko.SSHClient()
            self.ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

            self.ssh_client.connect(
                hostname=device['ip'],
                port=device.get('ssh_port', device.get('port', 22)),
                username=device.get('ssh_user', device.get('username', 'admin')),
                password=device.get('ssh_password', device.get('password', '')),
                timeout=10,
                look_for_keys=False,
                allow_agent=False
            )

            # Criar shell interativo
            self.channel = self.ssh_client.invoke_shell(
                term='xterm',
                width=120,
                height=40
            )
            self.channel.setblocking(0)
            self.connected = True

            await self.send(text_data=json.dumps({
                'type': 'connected',
                'data': f'Conectado a {device["name"]} ({device["ip"]})'
            }))

            # Iniciar loop de leitura do SSH
            asyncio.create_task(self.read_ssh_output())

        except paramiko.AuthenticationException:
            await self.send(text_data=json.dumps({
                'type': 'error',
                'data': 'Falha na autenticação SSH. Verifique usuário e senha.'
            }))
        except paramiko.SSHException as e:
            await self.send(text_data=json.dumps({
                'type': 'error',
                'data': f'Erro SSH: {str(e)}'
            }))
        except Exception as e:
            await self.send(text_data=json.dumps({
                'type': 'error',
                'data': f'Erro de conexão: {str(e)}'
            }))

    async def disconnect(self, close_code):
        self.connected = False
        if self.channel:
            self.channel.close()
        if self.ssh_client:
            self.ssh_client.close()

    async def receive(self, text_data):
        """Receber dados do WebSocket (input do usuário)"""
        if not self.connected or not self.channel:
            return

        try:
            data = json.loads(text_data)

            if data.get('type') == 'input':
                # Enviar input para o SSH
                self.channel.send(data.get('data', ''))

            elif data.get('type') == 'resize':
                # Redimensionar terminal
                cols = data.get('cols', 120)
                rows = data.get('rows', 40)
                if self.channel:
                    self.channel.resize_pty(width=cols, height=rows)

        except Exception as e:
            print(f"Erro ao processar input: {e}")

    async def read_ssh_output(self):
        """Ler output do SSH e enviar para WebSocket"""
        while self.connected:
            try:
                if self.channel.recv_ready():
                    output = self.channel.recv(4096)
                    if output:
                        # Tentar decodificar como UTF-8
                        try:
                            text = output.decode('utf-8')
                        except:
                            text = output.decode('latin-1')

                        await self.send(text_data=json.dumps({
                            'type': 'output',
                            'data': text
                        }))
                else:
                    await asyncio.sleep(0.01)

                # Verificar se o canal está fechado
                if self.channel.closed:
                    self.connected = False
                    await self.send(text_data=json.dumps({
                        'type': 'disconnected',
                        'data': 'Conexão SSH encerrada'
                    }))
                    break

            except Exception as e:
                print(f"Erro ao ler output SSH: {e}")
                await asyncio.sleep(0.1)

    @database_sync_to_async
    def get_device_credentials(self):
        """Buscar credenciais do dispositivo no banco"""
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
                       ssh_user, ssh_password, ssh_port, protocol
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
                    'protocol': row[9]
                }
            return None
        except Exception as e:
            print(f"Erro ao buscar dispositivo: {e}")
            return None
'''

# ==========================================
# 4. /opt/lorcgr/lorcgr_core/asgi.py
# ==========================================
ASGI_PY = '''
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
'''

# ==========================================
# 5. Atualizações no settings.py
# ==========================================
SETTINGS_ADD = '''
# Adicionar ao settings.py:

INSTALLED_APPS = [
    # ... apps existentes ...
    'channels',
    'terminal',
]

ASGI_APPLICATION = 'lorcgr_core.asgi.application'

CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels.layers.InMemoryChannelLayer'
    }
}
'''

print("=" * 60)
print("ARQUIVOS PARA DJANGO CHANNELS - SSH TERMINAL")
print("=" * 60)
print("\n1. routing.py:")
print(ROUTING_PY)
print("\n2. consumers.py:")
print(CONSUMERS_PY)
print("\n3. asgi.py:")
print(ASGI_PY)
print("\n4. settings.py - adicionar:")
print(SETTINGS_ADD)
