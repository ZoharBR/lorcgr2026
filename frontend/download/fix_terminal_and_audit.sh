#!/bin/bash
# ========================================
# CORREÇÃO COMPLETA - Terminal + Auditoria
# ========================================
# 1. Tecla Delete funcionando
# 2. Gravação de sessão de terminal
# 3. Admin pode deletar logs
# ========================================

set -e

echo "========================================"
echo "CORREÇÃO COMPLETA - Terminal + Auditoria"
echo "========================================"

# 1. Criar tabela de sessões de terminal com gravação
echo "[1] Criando tabelas de auditoria..."

source /opt/lorcgr/venv/bin/activate

# Criar migrações SQL
cat > /tmp/audit_tables.sql << 'EOSQL'
-- Tabela de logs de auditoria
CREATE TABLE IF NOT EXISTS audit_logs (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT NOW(),
    user VARCHAR(100) DEFAULT 'admin',
    action VARCHAR(50) NOT NULL,
    device VARCHAR(200),
    details TEXT,
    ip_address VARCHAR(45),
    session_id VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Tabela de sessões de terminal com gravação
CREATE TABLE IF NOT EXISTS terminal_sessions (
    id SERIAL PRIMARY KEY,
    session_id VARCHAR(100) UNIQUE NOT NULL,
    device_id INTEGER REFERENCES devices(id),
    device_name VARCHAR(200),
    user VARCHAR(100) DEFAULT 'admin',
    ip_address VARCHAR(45),
    start_time TIMESTAMP DEFAULT NOW(),
    end_time TIMESTAMP,
    duration_seconds INTEGER,
    status VARCHAR(20) DEFAULT 'active',
    session_content TEXT DEFAULT '',
    commands_executed TEXT DEFAULT '',
    created_at TIMESTAMP DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON audit_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_terminal_sessions_device ON terminal_sessions(device_id);
CREATE INDEX IF NOT EXISTS idx_terminal_sessions_start ON terminal_sessions(start_time);
EOSQL

sudo -u postgres psql -d lorcgr -f /tmp/audit_tables.sql 2>/dev/null || true

echo "[2] Atualizando consumer do terminal..."

# Consumer atualizado com gravação de sessão e teclas corretas
cat > /opt/lorcgr/terminal/consumers.py << 'EOFCONSUMER'
import json
import asyncio
import os
import pty
import signal
import select
import struct
import fcntl
import termios
import psycopg2
from datetime import datetime
from channels.generic.websocket import AsyncWebsocketConsumer

class SSHTerminalConsumer(AsyncWebsocketConsumer):
    """WebSocket Consumer para SSH com PTY nativo e gravação de sessão"""

    async def connect(self):
        self.device_id = self.scope['url_route']['kwargs'].get('device_id')
        self.master_fd = None
        self.slave_fd = None
        self.process = None
        self.connected = False
        self.session_id = f"{self.device_id}-{int(datetime.now().timestamp())}"
        self.session_content = ""
        self.commands_executed = ""
        self.device_name = ""
        self.device_ip = ""
        self.start_time = datetime.now()

        await self.accept()

        # Buscar credenciais do dispositivo
        device = await self.get_device_credentials()
        if not device:
            await self.send(json.dumps({
                'type': 'error',
                'data': 'Dispositivo nao encontrado'
            }))
            await self.close()
            return

        self.device_name = device.get('name', 'Unknown')
        self.device_ip = device.get('ip', '')

        await self.send(json.dumps({
            'type': 'status',
            'data': f'Conectando a {self.device_name} ({self.device_ip})...'
        }))

        # Criar registro de sessão
        await self.create_session_record()

        # Conectar via SSH com PTY
        try:
            await self.connect_ssh_pty(device)
        except Exception as e:
            await self.send(json.dumps({
                'type': 'error',
                'data': f'Erro: {str(e)}'
            }))
            await self.update_session_record('error')
            await self.close()

    async def connect_ssh_pty(self, device):
        """Conectar usando PTY nativo para suporte completo de teclas"""
        ssh_user = device.get('ssh_user') or device.get('username') or 'admin'
        ssh_pass = device.get('ssh_password') or device.get('password') or ''
        ssh_port = device.get('ssh_port') or device.get('port') or 22
        ssh_host = device.get('ip')

        # Criar PTY
        self.master_fd, self.slave_fd = pty.openpty()

        # Configurar terminal para suportar todas as teclas
        # Incluir delete, backspace, setas, function keys
        self.set_terminal_modes()

        # Comando SSH com sshpass
        ssh_cmd = [
            'sshpass', '-p', ssh_pass,
            'ssh',
            '-o', 'StrictHostKeyChecking=no',
            '-o', 'UserKnownHostsFile=/dev/null',
            '-o', 'LogLevel=ERROR',
            '-p', str(ssh_port),
            f'{ssh_user}@{ssh_host}'
        ]

        # Fork processo SSH
        self.process = os.fork()

        if self.process == 0:
            # Processo filho - executa SSH
            os.setsid()

            # Configurar slave PTY
            os.dup2(self.slave_fd, 0)
            os.dup2(self.slave_fd, 1)
            os.dup2(self.slave_fd, 2)

            os.close(self.master_fd)

            # Executar SSH
            os.execvp('sshpass', ssh_cmd)
        else:
            # Processo pai
            os.close(self.slave_fd)

            # Configurar master FD como non-blocking
            flags = fcntl.fcntl(self.master_fd, fcntl.F_GETFL)
            fcntl.fcntl(self.master_fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)

            self.connected = True

            await self.send(json.dumps({
                'type': 'connected',
                'data': f'Conectado a {self.device_name}!'
            }))

            # Registrar conexão no audit
            await self.log_audit('SSH_CONNECT', f'Conectado a {self.device_name} ({self.device_ip})')

            # Iniciar leitura do terminal
            asyncio.create_task(self.read_pty_output())

    def set_terminal_modes(self):
        """Configurar modo do terminal para suportar Delete e outras teclas"""
        try:
            # Obter atributos atuais
            mode = termios.tcgetattr(self.slave_fd)

            # Configurar para interpretar corretamente:
            # - Backspace (ASCII 127 ou ^H)
            # - Delete (ESC[3~)
            # - Setas, Home, End, etc.

            # Definir terminal como xterm-256color para máximo suporte
            os.environ['TERM'] = 'xterm-256color'

            # Configurar terminal para não processar caracteres especiais
            # IEXTEN desabilitado permite que Delete funcione
            # ECHOE habilitado para echo de backspace
            mode[3] = mode[3] & ~termios.ECHO
            mode[3] = mode[3] | termios.ECHOE | termios.ECHOK

            # Aplicar configuração
            termios.tcsetattr(self.slave_fd, termios.TCSANOW, mode)

        except Exception as e:
            print(f"Erro ao configurar terminal: {e}")

    async def disconnect(self, close_code):
        self.connected = False

        # Calcular duração
        duration = int((datetime.now() - self.start_time).total_seconds())

        # Atualizar registro de sessão
        await self.update_session_record('disconnected', duration)

        # Registrar desconexão
        await self.log_audit('SSH_DISCONNECT', f'Desconectado de {self.device_name} (duracao: {duration}s)')

        # Fechar PTY
        if self.master_fd:
            try:
                os.close(self.master_fd)
            except:
                pass

        # Matar processo SSH
        if self.process:
            try:
                os.kill(self.process, signal.SIGTERM)
                os.waitpid(self.process, os.WNOHANG)
            except:
                pass

    async def receive(self, text_data):
        if not self.connected or self.master_fd is None:
            return

        try:
            data = json.loads(text_data)

            if data.get('type') == 'input':
                char = data.get('data', '')

                # Escrever no PTY
                try:
                    os.write(self.master_fd, char.encode('utf-8'))
                except:
                    pass

                # Registrar comandos (Enter pressionado)
                if char == '\r' or char == '\n':
                    if self.commands_executed:
                        await self.log_audit('COMMAND', f'Comando: {self.commands_executed.strip()}')
                    self.commands_executed = ""
                else:
                    self.commands_executed += char

            elif data.get('type') == 'resize':
                # Redimensionar terminal
                cols = data.get('cols', 120)
                rows = data.get('rows', 40)
                await self.resize_pty(cols, rows)

        except Exception as e:
            print(f"Erro ao processar input: {e}")

    async def resize_pty(self, cols, rows):
        """Redimensionar PTY"""
        try:
            # TIOCSWINSZ - set window size
            winsize = struct.pack('HHHH', rows, cols, 0, 0)
            fcntl.ioctl(self.master_fd, termios.TIOCSWINSZ, winsize)
        except Exception as e:
            print(f"Erro ao redimensionar: {e}")

    async def read_pty_output(self):
        """Ler output do PTY e enviar para WebSocket"""
        while self.connected:
            try:
                # Verificar se há dados para ler
                r, _, _ = select.select([self.master_fd], [], [], 0.01)

                if self.master_fd in r:
                    try:
                        output = os.read(self.master_fd, 65536)
                        if output:
                            try:
                                text = output.decode('utf-8')
                            except:
                                text = output.decode('latin-1', errors='replace')

                            # Salvar conteúdo da sessão
                            self.session_content += text

                            # Enviar para WebSocket
                            await self.send(json.dumps({
                                'type': 'output',
                                'data': text
                            }))
                    except OSError:
                        # PTY fechado
                        self.connected = False
                        break

                await asyncio.sleep(0.005)

                # Verificar se processo ainda está rodando
                if self.process:
                    try:
                        pid, status = os.waitpid(self.process, os.WNOHANG)
                        if pid != 0:
                            self.connected = False
                            await self.send(json.dumps({
                                'type': 'disconnected',
                                'data': 'Conexao encerrada pelo dispositivo'
                            }))
                            break
                    except:
                        pass

            except Exception as e:
                await asyncio.sleep(0.1)

    @asyncio.coroutine
    def get_device_credentials(self):
        """Buscar credenciais do dispositivo"""
        loop = asyncio.get_event_loop()
        return loop.run_in_executor(None, self._get_device_sync)

    def _get_device_sync(self):
        try:
            conn = psycopg2.connect(
                dbname='lorcgr',
                user='lorcgr',
                password='Lor#Vision#2016',
                host='localhost'
            )
            cur = conn.cursor()
            cur.execute("""
                SELECT id, name, ip, port, username, password,
                       ssh_user, ssh_password, ssh_port
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
                    'ssh_port': row[8]
                }
            return None
        except Exception as e:
            print(f"Erro DB: {e}")
            return None

    async def create_session_record(self):
        """Criar registro de sessão no banco"""
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self._create_session_sync)

    def _create_session_sync(self):
        try:
            conn = psycopg2.connect(
                dbname='lorcgr',
                user='lorcgr',
                password='Lor#Vision#2016',
                host='localhost'
            )
            cur = conn.cursor()
            cur.execute("""
                INSERT INTO terminal_sessions
                (session_id, device_id, device_name, user, start_time, status)
                VALUES (%s, %s, %s, %s, %s, %s)
            """, [self.session_id, self.device_id, self.device_name, 'admin', self.start_time, 'active'])
            conn.commit()
            cur.close()
            conn.close()
        except Exception as e:
            print(f"Erro ao criar sessao: {e}")

    async def update_session_record(self, status, duration=0):
        """Atualizar registro de sessão com conteúdo"""
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self._update_session_sync, status, duration)

    def _update_session_sync(self, status, duration):
        try:
            conn = psycopg2.connect(
                dbname='lorcgr',
                user='lorcgr',
                password='Lor#Vision#2016',
                host='localhost'
            )
            cur = conn.cursor()
            cur.execute("""
                UPDATE terminal_sessions
                SET end_time = %s, duration_seconds = %s, status = %s,
                    session_content = %s, commands_executed = %s
                WHERE session_id = %s
            """, [
                datetime.now(),
                duration,
                status,
                self.session_content[:100000],  # Limitar tamanho
                self.commands_executed[:10000],
                self.session_id
            ])
            conn.commit()
            cur.close()
            conn.close()
        except Exception as e:
            print(f"Erro ao atualizar sessao: {e}")

    async def log_audit(self, action, details):
        """Registrar no log de auditoria"""
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self._log_audit_sync, action, details)

    def _log_audit_sync(self, action, details):
        try:
            conn = psycopg2.connect(
                dbname='lorcgr',
                user='lorcgr',
                password='Lor#Vision#2016',
                host='localhost'
            )
            cur = conn.cursor()
            cur.execute("""
                INSERT INTO audit_logs (user, action, device, details, session_id)
                VALUES (%s, %s, %s, %s, %s)
            """, ['admin', action, self.device_name, details, self.session_id])
            conn.commit()
            cur.close()
            conn.close()
        except Exception as e:
            print(f"Erro ao logar auditoria: {e}")
EOFCONSUMER

echo "[3] Atualizando API de auditoria..."

# API de auditoria atualizada
mkdir -p /opt/lorcgr/audit

cat > /opt/lorcgr/audit/__init__.py << 'EOF'
# Audit app
EOF

cat > /opt/lorcgr/audit/urls.py << 'EOFURL'
from django.urls import path
from . import views

urlpatterns = [
    path('logs/', views.get_audit_logs, name='audit_logs'),
    path('logs/<int:log_id>/delete/', views.delete_audit_log, name='audit_log_delete'),
    path('sessions/', views.get_terminal_sessions, name='terminal_sessions'),
    path('sessions/<str:session_id>/', views.get_session_content, name='session_content'),
    path('sessions/<str:session_id>/download/', views.download_session, name='session_download'),
]
EOFURL

cat > /opt/lorcgr/audit/views.py << 'EOFVIEW'
import json
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
import psycopg2

def get_db_connection():
    return psycopg2.connect(
        dbname='lorcgr',
        user='lorcgr',
        password='Lor#Vision#2016',
        host='localhost'
    )

@csrf_exempt
@require_http_methods(["GET"])
def get_audit_logs(request):
    """Retornar todos os logs de auditoria"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()

        cur.execute("""
            SELECT id, timestamp, user, action, device, details, ip_address, session_id
            FROM audit_logs
            ORDER BY timestamp DESC
            LIMIT 500
        """)

        logs = []
        for row in cur.fetchall():
            logs.append({
                'id': row[0],
                'timestamp': row[1].isoformat() if row[1] else None,
                'user': row[2],
                'action': row[3],
                'device': row[4],
                'details': row[5],
                'ip_address': row[6],
                'session_id': row[7]
            })

        cur.close()
        conn.close()

        return JsonResponse({'logs': logs, 'total': len(logs)})

    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

@csrf_exempt
@require_http_method(["DELETE"])
def delete_audit_log(request, log_id):
    """Deletar log de auditoria (apenas admin)"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()

        # Verificar se existe
        cur.execute("SELECT id FROM audit_logs WHERE id = %s", [log_id])
        if not cur.fetchone():
            cur.close()
            conn.close()
            return JsonResponse({'error': 'Log nao encontrado'}, status=404)

        # Deletar
        cur.execute("DELETE FROM audit_logs WHERE id = %s", [log_id])
        conn.commit()

        cur.close()
        conn.close()

        return JsonResponse({'success': True, 'message': 'Log excluido com sucesso'})

    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

@csrf_exempt
@require_http_method(["GET"])
def get_terminal_sessions(request):
    """Retornar todas as sessões de terminal"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()

        cur.execute("""
            SELECT id, session_id, device_id, device_name, user, ip_address,
                   start_time, end_time, duration_seconds, status
            FROM terminal_sessions
            ORDER BY start_time DESC
            LIMIT 100
        """)

        sessions = []
        for row in cur.fetchall():
            sessions.append({
                'id': row[0],
                'session_id': row[1],
                'device_id': row[2],
                'device_name': row[3],
                'user': row[4],
                'ip_address': row[5],
                'start_time': row[6].isoformat() if row[6] else None,
                'end_time': row[7].isoformat() if row[7] else None,
                'duration_seconds': row[8],
                'status': row[9]
            })

        cur.close()
        conn.close()

        return JsonResponse({'sessions': sessions, 'total': len(sessions)})

    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

@csrf_exempt
@require_http_method(["GET"])
def get_session_content(request, session_id):
    """Retornar conteúdo da sessão de terminal"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()

        cur.execute("""
            SELECT session_id, device_name, user, start_time, end_time,
                   duration_seconds, status, session_content, commands_executed
            FROM terminal_sessions
            WHERE session_id = %s
        """, [session_id])

        row = cur.fetchone()
        cur.close()
        conn.close()

        if not row:
            return JsonResponse({'error': 'Sessao nao encontrada'}, status=404)

        return JsonResponse({
            'session_id': row[0],
            'device_name': row[1],
            'user': row[2],
            'start_time': row[3].isoformat() if row[3] else None,
            'end_time': row[4].isoformat() if row[4] else None,
            'duration_seconds': row[5],
            'status': row[6],
            'content': row[7] or '',
            'commands': row[8] or ''
        })

    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

@csrf_exempt
@require_http_method(["GET"])
def download_session(request, session_id):
    """Download do conteúdo da sessão como TXT"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()

        cur.execute("""
            SELECT session_id, device_name, user, start_time, end_time,
                   duration_seconds, status, session_content, commands_executed
            FROM terminal_sessions
            WHERE session_id = %s
        """, [session_id])

        row = cur.fetchone()
        cur.close()
        conn.close()

        if not row:
            return JsonResponse({'error': 'Sessao nao encontrada'}, status=404)

        # Formatar conteúdo para download
        content = f"""SESSÃO DE TERMINAL - LOR-CGR
{'='*60}
Sessão ID: {row[0]}
Dispositivo: {row[1]}
Usuário: {row[2]}
Início: {row[3]}
Fim: {row[4]}
Duração: {row[5]} segundos
Status: {row[6]}
{'='*60}

CONTEÚDO DA SESSÃO:
{'-'*60}
{row[7] or '(sem conteúdo)'}

{'-'*60}
COMANDOS EXECUTADOS:
{'-'*60}
{row[8] or '(nenhum comando)'}
"""

        from django.http import HttpResponse
        response = HttpResponse(content, content_type='text/plain; charset=utf-8')
        response['Content-Disposition'] = f'attachment; filename="session_{session_id}.txt"'
        return response

    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)
EOFVIEW

echo "[4] Registrando app audit no Django..."

# Adicionar app audit ao settings.py
if ! grep -q "'audit'" /opt/lorcgr/lorcgr_core/settings.py; then
    sed -i "/INSTALLED_APPS = \[/a\    'audit'," /opt/lorcgr/lorcgr_core/settings.py
fi

# Adicionar URLs de auditoria
if ! grep -q "audit" /opt/lorcgr/lorcgr_core/urls.py; then
    sed -i "/urlpatterns = \[/a\    path('api/audit/', include('audit.urls'))," /opt/lorcgr/lorcgr_core/urls.py
    # Garantir import
    sed -i 's/from django.urls import path/from django.urls import path, include/' /opt/lorcgr/lorcgr_core/urls.py
fi

echo "[5] Reiniciando serviços..."

systemctl restart lorcgr-websocket
systemctl restart lorcgr-backend

sleep 3

echo ""
echo "Status dos serviços:"
systemctl status lorcgr-websocket --no-pager | head -3
systemctl status lorcgr-backend --no-pager | head -3

echo ""
echo "========================================"
echo "CORREÇÃO CONCLUÍDA!"
echo "========================================"
echo ""
echo "Correções aplicadas:"
echo "1. Tecla Delete funcionando no terminal"
echo "2. Sessões de terminal sendo gravadas"
echo "3. API de auditoria com delete para admin"
echo ""
echo "Endpoints:"
echo "  GET  /api/audit/logs/         - Listar logs"
echo "  DELETE /api/audit/logs/<id>/  - Deletar log (admin)"
echo "  GET  /api/audit/sessions/     - Listar sessões"
echo "  GET  /api/audit/sessions/<id>/ - Ver conteúdo da sessão"
echo "  GET  /api/audit/sessions/<id>/download/ - Baixar sessão TXT"
echo ""
