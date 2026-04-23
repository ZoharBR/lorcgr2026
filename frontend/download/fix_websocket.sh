#!/bin/bash
echo "=========================================="
echo "FIX WEBSOCKET - Django ASGI"
echo "=========================================="

cd /opt/lorcgr
source venv/bin/activate

# Check Django version
DJANGO_VERSION=$(python -c "import django; print('.'.join(map(str, django.VERSION[:2])))")
echo "Django version: $DJANGO_VERSION"

# Create correct asgi.py
cat > lorcgr_core/asgi.py << 'ASGI'
import os
import django
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'lorcgr_core.settings')
django.setup()

from terminal.routing import websocket_urlpatterns

application = ProtocolTypeRouter({
    "http": django.core.handlers.ASGIHandler(),
    "websocket": AuthMiddlewareStack(
        URLRouter(
            websocket_urlpatterns
        )
    ),
})
ASGI

echo "[1] asgi.py updated"

# Verify terminal app exists
if [ -d "terminal" ]; then
    echo "[2] Terminal app exists"
    
    # Check routing.py
    if [ -f "terminal/routing.py" ]; then
        echo "[3] routing.py exists"
    else
        echo "[3] Creating routing.py..."
        cat > terminal/routing.py << 'ROUTING'
from django.urls import re_path
from . import consumers

websocket_urlpatterns = [
    re_path(r'ws/terminal/(?P<device_id>\d+)/$', consumers.TerminalConsumer.as_asgi()),
]
ROUTING
    fi
    
    # Check consumers.py
    if [ -f "terminal/consumers.py" ]; then
        echo "[4] consumers.py exists"
    else
        echo "[4] Creating consumers.py..."
        cat > terminal/consumers.py << 'CONSUMER'
import json
import asyncio
import subprocess
import os
import pty
import select
import struct
import fcntl
import termios
from channels.generic.websocket import AsyncWebsocketConsumer

class TerminalConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.device_id = self.scope['url_route']['kwargs']['device_id']
        await self.accept()
        await self.send(text_data=json.dumps({
            'type': 'connected',
            'message': f'Connected to device {self.device_id}'
        }))

    async def disconnect(self, close_code):
        pass

    async def receive(self, text_data):
        data = json.loads(text_data)
        command_type = data.get('type', 'command')
        
        if command_type == 'resize':
            pass
        elif command_type == 'command':
            command = data.get('command', '')
            if command:
                result = await self.run_command(command)
                await self.send(text_data=json.dumps({
                    'type': 'output',
                    'output': result
                }))
    
    async def run_command(self, command):
        try:
            proc = await asyncio.create_subprocess_shell(
                command,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await proc.communicate()
            return stdout.decode() + stderr.decode()
        except Exception as e:
            return f"Error: {str(e)}"
CONSUMER
    fi
else
    echo "[ERROR] Terminal app not found!"
    exit 1
fi

# Add terminal to INSTALLED_APPS if not present
if ! grep -q "'terminal'" lorcgr_core/settings.py; then
    sed -i "/INSTALLED_APPS = \[/a\    'terminal'," lorcgr_core/settings.py
    echo "[5] Added terminal to INSTALLED_APPS"
else
    echo "[5] Terminal already in INSTALLED_APPS"
fi

# Restart websocket
echo "[6] Restarting websocket service..."
systemctl restart lorcgr-websocket
sleep 3

# Check status
echo ""
echo "Status:"
systemctl status lorcgr-websocket --no-pager -l

echo ""
echo "=========================================="
echo "FIX COMPLETE!"
echo "=========================================="
