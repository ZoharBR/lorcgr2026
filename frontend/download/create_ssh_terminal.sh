#!/bin/bash
# Create proper SSH Terminal Consumer with PTY support

cd /opt/lorcgr
source venv/bin/activate

# Create the consumers.py with real SSH support
mkdir -p terminal
cat > terminal/consumers.py << 'CONSUMER'
import json
import asyncio
import os
import pty
import select
import struct
import fcntl
import termios
import subprocess
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from devices.models import Device

class TerminalConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.device_id = self.scope['url_route']['kwargs']['device_id']
        self.device = await self.get_device()
        self.pty_fd = None
        self.child_pid = None
        
        await self.accept()
        
        if not self.device:
            await self.send(text_data=json.dumps({
                'type': 'error',
                'data': f'Device {self.device_id} not found'
            }))
            await self.close()
            return
        
        await self.send(text_data=json.dumps({
            'type': 'connected',
            'data': f'Connecting to {self.device.name}...'
        }))
        
        # Start SSH connection
        await self.start_ssh()

    @database_sync_to_async
    def get_device(self):
        try:
            return Device.objects.get(id=self.device_id)
        except Device.DoesNotExist:
            return None

    async def start_ssh(self):
        """Start SSH connection using PTY"""
        try:
            ip = self.device.ip
            port = self.device.ssh_port or 22
            user = self.device.ssh_user or 'root'
            
            # Build SSH command
            ssh_cmd = [
                'ssh',
                '-o', 'StrictHostKeyChecking=no',
                '-o', 'UserKnownHostsFile=/dev/null',
                '-o', 'LogLevel=ERROR',
                '-p', str(port),
                f'{user}@{ip}'
            ]
            
            # Create PTY
            self.child_pid, self.pty_fd = pty.fork()
            
            if self.child_pid == 0:
                # Child process - exec SSH
                os.execvp('ssh', ssh_cmd)
            else:
                # Parent process - read from PTY
                await self.send(text_data=json.dumps({
                    'type': 'connected',
                    'data': f'SSH connection to {self.device.name} ({ip}:{port})'
                }))
                
                # Start reading from PTY
                asyncio.create_task(self.read_pty())
                
        except Exception as e:
            await self.send(text_data=json.dumps({
                'type': 'error',
                'data': f'SSH connection failed: {str(e)}'
            }))

    async def read_pty(self):
        """Read output from PTY and send to WebSocket"""
        while self.pty_fd is not None:
            try:
                r, _, _ = select.select([self.pty_fd], [], [], 0.1)
                if self.pty_fd in r:
                    output = os.read(self.pty_fd, 4096)
                    if output:
                        await self.send(text_data=json.dumps({
                            'type': 'output',
                            'data': output.decode('utf-8', errors='replace')
                        }))
                    else:
                        break
                await asyncio.sleep(0.01)
            except Exception as e:
                break
        
        await self.send(text_data=json.dumps({
            'type': 'disconnected',
            'data': 'Connection closed'
        }))

    async def disconnect(self, close_code):
        """Clean up on disconnect"""
        if self.child_pid:
            try:
                os.kill(self.child_pid, 9)
            except:
                pass
        if self.pty_fd:
            try:
                os.close(self.pty_fd)
            except:
                pass

    async def receive(self, text_data):
        """Handle input from WebSocket"""
        try:
            data = json.loads(text_data)
            
            if data.get('type') == 'input' and self.pty_fd:
                # Write input to PTY
                os.write(self.pty_fd, data.get('data', '').encode())
                
            elif data.get('type') == 'resize' and self.pty_fd:
                # Resize PTY
                cols = data.get('cols', 80)
                rows = data.get('rows', 24)
                winsize = struct.pack('HHHH', rows, cols, 0, 0)
                fcntl.ioctl(self.pty_fd, termios.TIOCSWINSZ, winsize)
                
        except Exception as e:
            await self.send(text_data=json.dumps({
                'type': 'error',
                'data': str(e)
            }))
CONSUMER

echo "[1] consumers.py created with SSH PTY support"

# Create routing.py
cat > terminal/routing.py << 'ROUTING'
from django.urls import re_path
from . import consumers

websocket_urlpatterns = [
    re_path(r'ws/terminal/(?P<device_id>\d+)/$', consumers.TerminalConsumer.as_asgi()),
]
ROUTING

echo "[2] routing.py created"

# Create __init__.py
touch terminal/__init__.py

# Add terminal to INSTALLED_APPS if needed
if ! grep -q "'terminal'" lorcgr_core/settings.py; then
    sed -i "/INSTALLED_APPS = \[/a\    'terminal'," lorcgr_core/settings.py
    echo "[3] Added terminal to INSTALLED_APPS"
else
    echo "[3] Terminal already in INSTALLED_APPS"
fi

# Create apps.py if not exists
cat > terminal/apps.py << 'APPS'
from django.apps import AppConfig

class TerminalConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'terminal'
APPS

echo "[4] apps.py created"

# Restart services
systemctl restart lorcgr-backend
systemctl restart lorcgr-websocket
sleep 2

echo ""
echo "=========================================="
echo "SSH Terminal Installed!"
echo "=========================================="
echo ""
echo "Status:"
systemctl status lorcgr-websocket --no-pager | head -15
