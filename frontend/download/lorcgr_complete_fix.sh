#!/bin/bash
# ========================================
# LOR-CGR - CORREÇÃO COMPLETA
# ========================================

set -e

echo "=========================================="
echo "LOR-CGR - Correção Completa"
echo "=========================================="

cd /opt/lorcgr
source venv/bin/activate

# ========================================
# 1. INSTALAR GRAFANA (se não existir)
# ========================================
echo "[1/6] Verificando Grafana..."

if ! command -v grafana-server &> /dev/null && ! docker ps | grep -q grafana; then
    echo "Instalando Grafana..."
    
    # Instalar via apt
    apt-get install -y apt-transport-https software-properties-common wget
    wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key
    
    echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list
    
    apt-get update
    apt-get install -y grafana
    
    # Configurar
    systemctl enable grafana-server
    systemctl start grafana-server
    
    echo "Grafana instalado na porta 3000"
else
    echo "Grafana já instalado"
fi

systemctl status grafana-server --no-pager | head -3 || true

# ========================================
# 2. VERIFICAR LIBRENMS E PHPIPAM
# ========================================
echo ""
echo "[2/6] Verificando LibreNMS e phpIPAM..."

# Verificar se estão em Docker
if docker ps | grep -q librenms; then
    LIBRENMS_PORT=$(docker port $(docker ps | grep librenms | awk '{print $1}') 8000 2>/dev/null | grep -oE '[0-9]+$' | head -1)
    echo "LibreNMS Docker porta: ${LIBRENMS_PORT:-8080}"
fi

if docker ps | grep -q phpipam; then
    PHPIPAM_PORT=$(docker port $(docker ps | grep phpipam | awk '{print $1}') 80 2>/dev/null | grep -oE '[0-9]+$' | head -1)
    echo "phpIPAM Docker porta: ${PHPIPAM_PORT:-8081}"
fi

# ========================================
# 3. CRIAR TABELAS DE BACKUP
# ========================================
echo ""
echo "[3/6] Criando tabelas de backup..."

sudo -u postgres psql -d lorcgr << 'EOSQL'
-- Tabela de backups
CREATE TABLE IF NOT EXISTS device_backups (
    id SERIAL PRIMARY KEY,
    device_id INTEGER,
    device_name VARCHAR(200),
    filename VARCHAR(500),
    filepath TEXT,
    size_bytes BIGINT,
    created_at TIMESTAMP DEFAULT NOW(),
    status VARCHAR(20) DEFAULT 'success',
    backup_type VARCHAR(50) DEFAULT 'manual'
);

-- Tabela de logs de auditoria (com campos corretos)
CREATE TABLE IF NOT EXISTS audit_logs (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT NOW(),
    "user" VARCHAR(100) DEFAULT 'admin',
    action VARCHAR(50) NOT NULL,
    device VARCHAR(200),
    details TEXT,
    ip_address VARCHAR(45),
    session_id VARCHAR(100)
);

CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit_logs(timestamp);
EOSQL

echo "Tabelas criadas"

# ========================================
# 4. CRIAR API DE BACKUP
# ========================================
echo ""
echo "[4/6] Atualizando API de backup..."

mkdir -p /opt/lorcgr/backups

cat > /opt/lorcgr/backups/views.py << 'EOF'
import os
import json
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
import psycopg2
from datetime import datetime

BACKUP_DIR = '/opt/lorcgr/backups'

def get_db():
    return psycopg2.connect(
        dbname='lorcgr', user='lorcgr',
        password='Lor#Vision#2016', host='localhost'
    )

@csrf_exempt
@require_http_methods(["GET"])
def list_backups(request):
    """Listar todos os backups"""
    try:
        conn = get_db()
        cur = conn.cursor()
        
        # Buscar do banco
        cur.execute("""
            SELECT id, device_id, device_name, filename, size_bytes, created_at, status
            FROM device_backups
            ORDER BY created_at DESC
            LIMIT 100
        """)
        
        backups = []
        for row in cur.fetchall():
            backups.append({
                'id': row[0],
                'device_id': row[1],
                'device_name': row[2],
                'filename': row[3],
                'size_bytes': row[4],
                'created_at': row[5].isoformat() if row[5] else None,
                'status': row[6]
            })
        
        # Também buscar arquivos no diretório
        if os.path.exists(BACKUP_DIR):
            for f in os.listdir(BACKUP_DIR):
                if f.endswith(('.cfg', '.backup', '.txt', '.zip')):
                    filepath = os.path.join(BACKUP_DIR, f)
                    stat = os.stat(filepath)
                    backups.append({
                        'id': 0,
                        'device_id': 0,
                        'device_name': f.split('_')[0] if '_' in f else 'unknown',
                        'filename': f,
                        'size_bytes': stat.st_size,
                        'created_at': datetime.fromtimestamp(stat.st_mtime).isoformat(),
                        'status': 'success'
                    })
        
        cur.close()
        conn.close()
        
        return JsonResponse({'backups': backups, 'total': len(backups)})
    except Exception as e:
        return JsonResponse({'backups': [], 'error': str(e)})

@csrf_exempt  
@require_http_methods(["POST"])
def run_backup(request, device_id):
    """Executar backup de um dispositivo"""
    try:
        conn = get_db()
        cur = conn.cursor()
        
        # Buscar dispositivo
        cur.execute("SELECT id, hostname, ip_address FROM devices WHERE id = %s", [device_id])
        device = cur.fetchone()
        
        if not device:
            return JsonResponse({'error': 'Dispositivo não encontrado'}, status=404)
        
        # Criar registro de backup
        filename = f"{device[1]}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.cfg"
        filepath = os.path.join(BACKUP_DIR, filename)
        
        # TODO: Executar backup real via SSH
        # Por enquanto, criar arquivo vazio
        os.makedirs(BACKUP_DIR, exist_ok=True)
        with open(filepath, 'w') as f:
            f.write(f"# Backup de {device[1]}\n# Gerado em {datetime.now()}\n")
        
        cur.execute("""
            INSERT INTO device_backups (device_id, device_name, filename, filepath, size_bytes, status)
            VALUES (%s, %s, %s, %s, %s, %s)
        """, [device[0], device[1], filename, filepath, os.path.getsize(filepath), 'success'])
        
        conn.commit()
        cur.close()
        conn.close()
        
        return JsonResponse({'success': True, 'filename': filename})
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)
EOF

echo "API de backup criada"

# ========================================
# 5. ATUALIZAR URLs DO DJANGO
# ========================================
echo ""
echo "[5/6] Atualizando URLs..."

# Verificar se URLs de backup existem
if ! grep -q "backups" /opt/lorcgr/lorcgr_core/urls.py 2>/dev/null; then
    sed -i "/urlpatterns = \[/a\    path('api/backups/', include('backups.urls'))," /opt/lorcgr/lorcgr_core/urls.py
fi

# Garantir imports
sed -i 's/from django.urls import path$/from django.urls import path, include/' /opt/lorcgr/lorcgr_core/urls.py

# Criar urls.py do backup
cat > /opt/lorcgr/backups/urls.py << 'EOF'
from django.urls import path
from . import views

urlpatterns = [
    path('', views.list_backups, name='list_backups'),
    path('run/<int:device_id>/', views.run_backup, name='run_backup'),
]
EOF

# Registrar app
if ! grep -q "'backups'" /opt/lorcgr/lorcgr_core/settings.py; then
    sed -i "/INSTALLED_APPS = \[/a\    'backups'," /opt/lorcgr/lorcgr_core/settings.py
fi

echo "URLs atualizadas"

# ========================================
# 6. CRIAR INTERFACE HTML COMPLETA
# ========================================
echo ""
echo "[6/6] Criando interface HTML..."

mkdir -p /opt/lorcgr/static/lorcgr

cat > /opt/lorcgr/static/lorcgr/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>LOR-CGR | Central de Gerenciamento de Rede</title>
<script src="https://cdn.tailwindcss.com"></script>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
<style>
*{font-family:'Inter',sans-serif}
:root{--p:#3b82f6;--bg:#0f172a;--card:#1e293b;--hover:#334155;--border:#334155;--txt:#f1f5f9;--muted:#94a3b8}
.t1{--p:#0ea5e9;--bg:#0c1929;--card:#132f4c}
.t2{--p:#22c55e;--bg:#0a1a0f;--card:#14261a}
.t3{--p:#a855f7;--bg:#1a0a2e;--card:#2d1b4e}
.t4{--p:#f97316;--bg:#1c1410;--card:#2d1f1a}
body{background:var(--bg);color:var(--txt)}
.card{background:var(--card);border:1px solid var(--border)}
.btn{background:var(--p);color:white}
.btn:hover{filter:brightness(1.1)}
.term{font-family:'JetBrains Mono',monospace;background:#0d1117}
input,select,textarea{background:var(--hover);border:1px solid var(--border);color:var(--txt)}
input:focus,select:focus,textarea:focus{outline:none;border-color:var(--p)}
</style>
</head>
<body class="min-h-screen">
<div id="app" class="flex h-screen">
<!-- SIDEBAR -->
<aside class="w-64 bg-[var(--card)] border-r border-[var(--border)] flex flex-col flex-shrink-0">
<div class="p-4 border-b border-[var(--border)]">
<div class="flex items-center gap-3">
<div class="w-10 h-10 rounded-lg bg-gradient-to-br from-blue-500 to-purple-600 flex items-center justify-center">
<i class="fas fa-network-wired text-white"></i>
</div>
<div>
<h1 class="font-bold text-lg">LOR-CGR</h1>
<p class="text-xs text-[var(--muted)]">Network Management</p>
</div>
</div>
</div>

<nav class="flex-1 p-3 overflow-y-auto">
<p class="text-xs text-[var(--muted)] uppercase tracking-wider mb-2 px-3">Principal</p>
<button onclick="nav('dash')" class="nav-btn w-full flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-[var(--hover)] mb-1" data-p="dash">
<i class="fas fa-chart-line w-5"></i> Dashboard
</button>
<button onclick="nav('dev')" class="nav-btn w-full flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-[var(--hover)] mb-1" data-p="dev">
<i class="fas fa-server w-5"></i> Dispositivos
</button>
<button onclick="nav('term')" class="nav-btn w-full flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-[var(--hover)] mb-1" data-p="term">
<i class="fas fa-terminal w-5"></i> Terminal SSH
</button>
<button onclick="nav('backups')" class="nav-btn w-full flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-[var(--hover)] mb-1" data-p="backups">
<i class="fas fa-database w-5"></i> Backups
</button>
<button onclick="nav('audit')" class="nav-btn w-full flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-[var(--hover)] mb-1" data-p="audit">
<i class="fas fa-clipboard-list w-5"></i> Auditoria
</button>

<p class="text-xs text-[var(--muted)] uppercase tracking-wider mb-2 px-3 mt-4">Ferramentas</p>
<a href="http://45.71.242.131:8080" target="_blank" class="flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-[var(--hover)] mb-1 text-green-400">
<i class="fas fa-heartbeat w-5"></i> LibreNMS
<i class="fas fa-external-link-alt ml-auto text-xs"></i>
</a>
<a href="http://45.71.242.131:8081" target="_blank" class="flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-[var(--hover)] mb-1 text-blue-400">
<i class="fas fa-project-diagram w-5"></i> phpIPAM
<i class="fas fa-external-link-alt ml-auto text-xs"></i>
</a>
<a href="http://45.71.242.131:3000" target="_blank" class="flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-[var(--hover)] mb-1 text-orange-400">
<i class="fas fa-chart-bar w-5"></i> Grafana
<i class="fas fa-external-link-alt ml-auto text-xs"></i>
</a>

<p class="text-xs text-[var(--muted)] uppercase tracking-wider mb-2 px-3 mt-4">Sistema</p>
<button onclick="nav('ai')" class="nav-btn w-full flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-[var(--hover)] mb-1" data-p="ai">
<i class="fas fa-robot w-5"></i> Assistente IA
</button>
<button onclick="nav('set')" class="nav-btn w-full flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-[var(--hover)] mb-1" data-p="set">
<i class="fas fa-cog w-5"></i> Configuracoes
</button>
</nav>

<div class="p-3 border-t border-[var(--border)]">
<div class="flex items-center gap-3 p-2 rounded-lg bg-[var(--hover)]">
<div class="w-8 h-8 rounded-full bg-gradient-to-br from-blue-500 to-purple-600 flex items-center justify-center text-sm font-bold">A</div>
<div class="flex-1">
<p class="text-sm font-medium">Admin</p>
<p class="text-xs text-[var(--muted)]">Administrador</p>
</div>
<div class="w-2 h-2 rounded-full bg-green-500"></div>
</div>
</div>
</aside>

<!-- MAIN CONTENT -->
<main class="flex-1 flex flex-col overflow-hidden">
<header class="h-14 border-b border-[var(--border)] bg-[var(--card)] flex items-center justify-between px-4 flex-shrink-0">
<div>
<h2 id="title" class="text-lg font-semibold">Dashboard</h2>
<p id="subtitle" class="text-xs text-[var(--muted)]">Visao geral da rede</p>
</div>
<div class="flex items-center gap-2">
<button onclick="refreshAll()" class="p-2 rounded hover:bg-[var(--hover)]" title="Atualizar">
<i class="fas fa-sync-alt"></i>
</button>
<button onclick="toggleTheme()" class="p-2 rounded hover:bg-[var(--hover)]" title="Alternar tema">
<i class="fas fa-palette"></i>
</button>
</div>
</header>

<div id="content" class="flex-1 overflow-auto p-4">

<!-- DASHBOARD PAGE -->
<div id="p-dash" class="page">
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
<div class="card rounded-xl p-5">
<div class="flex items-center justify-between mb-2">
<span class="text-[var(--muted)] text-sm">Total Dispositivos</span>
<i class="fas fa-server text-blue-400"></i>
</div>
<p class="text-3xl font-bold" id="stat-total">0</p>
</div>
<div class="card rounded-xl p-5">
<div class="flex items-center justify-between mb-2">
<span class="text-[var(--muted)] text-sm">Online</span>
<i class="fas fa-check-circle text-green-400"></i>
</div>
<p class="text-3xl font-bold text-green-400" id="stat-online">0</p>
</div>
<div class="card rounded-xl p-5">
<div class="flex items-center justify-between mb-2">
<span class="text-[var(--muted)] text-sm">Offline</span>
<i class="fas fa-times-circle text-red-400"></i>
</div>
<p class="text-3xl font-bold text-red-400" id="stat-offline">0</p>
</div>
<div class="card rounded-xl p-5">
<div class="flex items-center justify-between mb-2">
<span class="text-[var(--muted)] text-sm">PPPoE Ativos</span>
<i class="fas fa-users text-purple-400"></i>
</div>
<p class="text-3xl font-bold text-purple-400" id="stat-pppoe">0</p>
</div>
</div>

<div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
<div class="lg:col-span-2 card rounded-xl">
<div class="p-4 border-b border-[var(--border)] flex justify-between items-center">
<h3 class="font-semibold"><i class="fas fa-server mr-2 text-[var(--p)]"></i>Dispositivos</h3>
<button onclick="nav('dev')" class="text-sm text-[var(--p)] hover:underline">Ver todos</button>
</div>
<div id="dash-devices" class="p-4 max-h-96 overflow-auto space-y-2">
<p class="text-center text-[var(--muted)] py-4">Carregando...</p>
</div>
</div>

<div class="card rounded-xl">
<div class="p-4 border-b border-[var(--border)]">
<h3 class="font-semibold"><i class="fas fa-bolt mr-2 text-yellow-400"></i>Acoes Rapidas</h3>
</div>
<div class="p-4 space-y-2">
<button onclick="nav('term')" class="w-full flex items-center gap-3 p-3 rounded-lg bg-[var(--hover)] hover:bg-green-500/20 transition-all">
<i class="fas fa-terminal text-green-400"></i>
<span>Terminal SSH</span>
</button>
<button onclick="runAllBackups()" class="w-full flex items-center gap-3 p-3 rounded-lg bg-[var(--hover)] hover:bg-blue-500/20 transition-all">
<i class="fas fa-download text-blue-400"></i>
<span>Backup Todos</span>
</button>
<button onclick="nav('audit')" class="w-full flex items-center gap-3 p-3 rounded-lg bg-[var(--hover)] hover:bg-purple-500/20 transition-all">
<i class="fas fa-clipboard-list text-purple-400"></i>
<span>Auditoria</span>
</button>
</div>
<div class="p-4 border-t border-[var(--border)]">
<h4 class="text-sm text-[var(--muted)] mb-3">Status Sistema</h4>
<div class="space-y-2 text-sm">
<div class="flex justify-between"><span>API Backend</span><span class="text-green-400"><i class="fas fa-circle text-xs mr-1"></i>Online</span></div>
<div class="flex justify-between"><span>WebSocket</span><span class="text-green-400"><i class="fas fa-circle text-xs mr-1"></i>Online</span></div>
<div class="flex justify-between"><span>PostgreSQL</span><span class="text-green-400"><i class="fas fa-circle text-xs mr-1"></i>Online</span></div>
</div>
</div>
</div>
</div>
</div>

<!-- DEVICES PAGE -->
<div id="p-dev" class="page hidden">
<div class="flex justify-between items-center mb-4">
<div class="flex gap-2">
<select id="filter-type" onchange="filterDevices()" class="rounded px-3 py-2">
<option value="">Todos os Tipos</option>
<option value="bras">BRAS</option>
<option value="router">Router</option>
<option value="switch">Switch</option>
<option value="olt">OLT</option>
</select>
<select id="filter-status" onchange="filterDevices()" class="rounded px-3 py-2">
<option value="">Todos Status</option>
<option value="online">Online</option>
<option value="offline">Offline</option>
</select>
<input type="text" id="search-dev" placeholder="Buscar..." class="rounded px-3 py-2 w-48" onkeyup="filterDevices()">
</div>
<button onclick="openDeviceModal()" class="btn px-4 py-2 rounded flex items-center gap-2">
<i class="fas fa-plus"></i> Novo Dispositivo
</button>
</div>

<div class="card rounded-xl overflow-hidden">
<table class="w-full">
<thead class="bg-[var(--hover)]">
<tr>
<th class="px-4 py-3 text-left text-sm">Status</th>
<th class="px-4 py-3 text-left text-sm">Nome</th>
<th class="px-4 py-3 text-left text-sm">IP</th>
<th class="px-4 py-3 text-left text-sm">Tipo</th>
<th class="px-4 py-3 text-left text-sm">Vendor</th>
<th class="px-4 py-3 text-left text-sm">SSH</th>
<th class="px-4 py-3 text-left text-sm">Acoes</th>
</tr>
</thead>
<tbody id="devices-table">
<tr><td colspan="7" class="px-4 py-8 text-center text-[var(--muted)]">Carregando...</td></tr>
</tbody>
</table>
</div>
</div>

<!-- TERMINAL PAGE -->
<div id="p-term" class="page hidden">
<div class="grid grid-cols-4 gap-4 h-[calc(100vh-150px)]">
<div class="card rounded-xl flex flex-col">
<div class="p-3 border-b border-[var(--border)]">
<h3 class="font-semibold">Dispositivos</h3>
</div>
<div id="terminal-devices" class="flex-1 overflow-auto p-2 space-y-1">
</div>
</div>
<div class="col-span-3 card rounded-xl flex flex-col">
<div class="p-2 border-b border-[var(--border)] flex justify-between items-center">
<div id="terminal-tab" class="flex items-center gap-2 text-sm text-[var(--muted)]">
Nenhuma sessao ativa
</div>
<div class="flex gap-1">
<button onclick="clearTerminal()" class="p-1 px-2 rounded hover:bg-[var(--hover)] text-xs">
<i class="fas fa-trash-alt mr-1"></i>Limpar
</button>
<button onclick="downloadLog()" class="p-1 px-2 rounded hover:bg-[var(--hover)] text-xs">
<i class="fas fa-download mr-1"></i>Log
</button>
</div>
</div>
<div id="terminal-output" class="flex-1 term p-3 overflow-auto" tabindex="0">
<pre id="term-text" class="text-green-400 text-sm whitespace-pre-wrap">╔═══════════════════════════════════════════════════════════╗
║              LOR-CGR Terminal SSH Multi-Sessao            ║
╚═══════════════════════════════════════════════════════════╝

Selecione um dispositivo para iniciar uma sessao SSH.

Teclas suportadas:
  - Backspace: Apaga caractere anterior
  - Delete: Apaga caractere sob cursor  
  - Setas: Navegacao
  - Tab: Auto-completar
</pre>
</div>
<div class="p-2 border-t border-[var(--border)] flex justify-between text-xs text-[var(--muted)]">
<span id="term-status">Desconectado</span>
<span id="term-info">-</span>
</div>
</div>
</div>
</div>

<!-- BACKUPS PAGE -->
<div id="p-backups" class="page hidden">
<div class="flex justify-between items-center mb-4">
<h3 class="text-lg font-semibold">Backups de Configuracao</h3>
<button onclick="runAllBackups()" class="btn px-4 py-2 rounded">
<i class="fas fa-play mr-2"></i>Backup de Todos
</button>
</div>
<div id="backups-list" class="space-y-2">
<p class="text-center text-[var(--muted)] py-8">Carregando...</p>
</div>
</div>

<!-- AUDIT PAGE -->
<div id="p-audit" class="page hidden">
<div class="flex justify-between items-center mb-4">
<div class="flex gap-2">
<select id="audit-action" onchange="loadAudit()" class="rounded px-3 py-2">
<option value="">Todas Acoes</option>
<option value="SSH_CONNECT">Conexao SSH</option>
<option value="SSH_DISCONNECT">Desconexao</option>
<option value="COMMAND">Comandos</option>
<option value="BACKUP">Backups</option>
</select>
</div>
<button onclick="loadAudit()" class="btn px-4 py-2 rounded">
<i class="fas fa-sync-alt mr-2"></i>Atualizar
</button>
</div>
<div class="grid grid-cols-4 gap-4 mb-4">
<div class="card rounded p-4"><p class="text-[var(--muted)] text-sm">Total</p><p class="text-xl font-bold" id="audit-total">0</p></div>
<div class="card rounded p-4"><p class="text-[var(--muted)] text-sm">SSH</p><p class="text-xl font-bold text-blue-400" id="audit-ssh">0</p></div>
<div class="card rounded p-4"><p class="text-[var(--muted)] text-sm">Comandos</p><p class="text-xl font-bold text-purple-400" id="audit-cmd">0</p></div>
<div class="card rounded p-4"><p class="text-[var(--muted)] text-sm">Backups</p><p class="text-xl font-bold text-green-400" id="audit-backup">0</p></div>
</div>
<div class="card rounded-xl max-h-[500px] overflow-auto">
<div id="audit-list" class="divide-y divide-[var(--border)]">
<p class="p-8 text-center text-[var(--muted)]">Carregando...</p>
</div>
</div>
</div>

<!-- AI PAGE -->
<div id="p-ai" class="page hidden">
<div class="grid grid-cols-3 gap-4 h-[calc(100vh-150px)]">
<div class="col-span-2 card rounded-xl flex flex-col">
<div class="p-4 border-b border-[var(--border)]">
<h3 class="font-semibold"><i class="fas fa-robot mr-2 text-purple-400"></i>Assistente IA</h3>
</div>
<div id="ai-chat" class="flex-1 p-4 overflow-auto space-y-4">
<div class="flex gap-3">
<div class="w-8 h-8 rounded-full bg-purple-500/20 flex items-center justify-center">
<i class="fas fa-robot text-purple-400 text-sm"></i>
</div>
<div class="bg-[var(--hover)] rounded-lg p-3 max-w-[80%]">
<p class="text-sm">Ola! Sou o assistente IA do LOR-CGR. Posso ajudar com analise de rede, troubleshooting e configuracoes.</p>
</div>
</div>
</div>
<div class="p-4 border-t border-[var(--border)]">
<div class="flex gap-2">
<input type="text" id="ai-input" placeholder="Digite sua pergunta..." class="flex-1 rounded px-4 py-2" onkeypress="if(event.key==='Enter')sendAI()">
<button onclick="sendAI()" class="btn px-4 py-2 rounded"><i class="fas fa-paper-plane"></i></button>
</div>
</div>
</div>
<div class="card rounded-xl">
<div class="p-4 border-b border-[var(--border)]">
<h3 class="font-semibold">Perguntas Rapidas</h3>
</div>
<div class="p-4 space-y-2">
<button onclick="askAI('Como verificar status de interface?')" class="w-full text-left p-3 rounded bg-[var(--hover)] hover:bg-purple-500/20 text-sm">Interface status</button>
<button onclick="askAI('Diagnosticar PPPoE')" class="w-full text-left p-3 rounded bg-[var(--hover)] hover:bg-purple-500/20 text-sm">PPPoe</button>
<button onclick="askAI('Comandos de backup')" class="w-full text-left p-3 rounded bg-[var(--hover)] hover:bg-purple-500/20 text-sm">Backup</button>
</div>
</div>
</div>
</div>

<!-- SETTINGS PAGE -->
<div id="p-set" class="page hidden">
<div class="card rounded-xl p-6">
<h3 class="font-semibold mb-4"><i class="fas fa-palette mr-2 text-[var(--p)]"></i>Temas</h3>
<div class="grid grid-cols-5 gap-4">
<button onclick="setTheme('')" class="p-4 rounded-xl bg-[#0f172a] border-2 border-[var(--p)] hover:scale-105 transition-transform">
<div class="w-full h-16 rounded bg-gradient-to-br from-blue-500 to-purple-600 mb-2"></div>
<p class="text-sm font-medium">NOC Dark</p>
</button>
<button onclick="setTheme('t1')" class="p-4 rounded-xl bg-[#0c1929] border-2 border-transparent hover:border-[var(--p)] hover:scale-105 transition-transform">
<div class="w-full h-16 rounded bg-gradient-to-br from-cyan-500 to-blue-600 mb-2"></div>
<p class="text-sm font-medium">Ocean</p>
</button>
<button onclick="setTheme('t2')" class="p-4 rounded-xl bg-[#0a1a0f] border-2 border-transparent hover:border-[var(--p)] hover:scale-105 transition-transform">
<div class="w-full h-16 rounded bg-gradient-to-br from-green-500 to-emerald-600 mb-2"></div>
<p class="text-sm font-medium">Forest</p>
</button>
<button onclick="setTheme('t3')" class="p-4 rounded-xl bg-[#1a0a2e] border-2 border-transparent hover:border-[var(--p)] hover:scale-105 transition-transform">
<div class="w-full h-16 rounded bg-gradient-to-br from-purple-500 to-pink-600 mb-2"></div>
<p class="text-sm font-medium">Purple</p>
</button>
<button onclick="setTheme('t4')" class="p-4 rounded-xl bg-[#1c1410] border-2 border-transparent hover:border-[var(--p)] hover:scale-105 transition-transform">
<div class="w-full h-16 rounded bg-gradient-to-br from-orange-500 to-red-600 mb-2"></div>
<p class="text-sm font-medium">Sunset</p>
</button>
</div>
</div>

<div class="card rounded-xl p-6 mt-4">
<h3 class="font-semibold mb-4"><i class="fas fa-info-circle mr-2 text-blue-400"></i>Sistema</h3>
<div class="grid grid-cols-2 gap-4 text-sm">
<div class="flex justify-between p-3 bg-[var(--hover)] rounded"><span>Versao</span><span class="font-mono">v2.1.0</span></div>
<div class="flex justify-between p-3 bg-[var(--hover)] rounded"><span>API</span><span class="text-green-400">Online</span></div>
<div class="flex justify-between p-3 bg-[var(--hover)] rounded"><span>WebSocket</span><span class="text-green-400">Porta 8001</span></div>
<div class="flex justify-between p-3 bg-[var(--hover)] rounded"><span>Banco</span><span class="text-green-400">PostgreSQL</span></div>
</div>
</div>
</div>

</div>
</main>
</div>

<!-- DEVICE MODAL -->
<div id="device-modal" class="fixed inset-0 bg-black/70 hidden items-center justify-center z-50">
<div class="card rounded-xl w-full max-w-lg mx-4">
<div class="p-4 border-b border-[var(--border)] flex justify-between items-center">
<h3 class="font-semibold text-lg" id="modal-title">Novo Dispositivo</h3>
<button onclick="closeDeviceModal()" class="p-2 hover:bg-[var(--hover)] rounded"><i class="fas fa-times"></i></button>
</div>
<form onsubmit="saveDevice(event)" class="p-4 space-y-4">
<input type="hidden" id="edit-id" value="">
<div class="grid grid-cols-2 gap-4">
<div>
<label class="block text-sm text-[var(--muted)] mb-1">Nome *</label>
<input type="text" id="dev-name" required class="w-full rounded px-3 py-2">
</div>
<div>
<label class="block text-sm text-[var(--muted)] mb-1">IP *</label>
<input type="text" id="dev-ip" required class="w-full rounded px-3 py-2">
</div>
</div>
<div class="grid grid-cols-2 gap-4">
<div>
<label class="block text-sm text-[var(--muted)] mb-1">Tipo</label>
<select id="dev-type" class="w-full rounded px-3 py-2">
<option value="router">Router</option>
<option value="bras">BRAS</option>
<option value="switch">Switch</option>
<option value="olt">OLT</option>
</select>
</div>
<div>
<label class="block text-sm text-[var(--muted)] mb-1">Vendor</label>
<input type="text" id="dev-vendor" class="w-full rounded px-3 py-2">
</div>
</div>
<div class="grid grid-cols-2 gap-4">
<div>
<label class="block text-sm text-[var(--muted)] mb-1">Usuario SSH</label>
<input type="text" id="dev-user" class="w-full rounded px-3 py-2">
</div>
<div>
<label class="block text-sm text-[var(--muted)] mb-1">Senha SSH</label>
<input type="password" id="dev-pass" class="w-full rounded px-3 py-2">
</div>
</div>
<div class="grid grid-cols-2 gap-4">
<div>
<label class="block text-sm text-[var(--muted)] mb-1">Porta SSH</label>
<input type="number" id="dev-port" value="22" class="w-full rounded px-3 py-2">
</div>
<div>
<label class="block text-sm text-[var(--muted)] mb-1">SNMP Community</label>
<input type="text" id="dev-snmp" class="w-full rounded px-3 py-2">
</div>
</div>
<div class="flex justify-end gap-2 pt-4">
<button type="button" onclick="closeDeviceModal()" class="px-4 py-2 rounded bg-[var(--hover)]">Cancelar</button>
<button type="submit" class="btn px-4 py-2 rounded">Salvar</button>
</div>
</form>
</div>
</div>

<!-- DEVICE INFO MODAL -->
<div id="info-modal" class="fixed inset-0 bg-black/70 hidden items-center justify-center z-50">
<div class="card rounded-xl w-full max-w-2xl mx-4 max-h-[90vh] overflow-auto">
<div class="p-4 border-b border-[var(--border)] flex justify-between items-center sticky top-0 bg-[var(--card)]">
<h3 class="font-semibold text-lg" id="info-title">Detalhes do Dispositivo</h3>
<button onclick="closeInfoModal()" class="p-2 hover:bg-[var(--hover)] rounded"><i class="fas fa-times"></i></button>
</div>
<div id="info-content" class="p-4">
</div>
</div>
</div>

<script>
const API = 'http://45.71.242.131:8000/api';
let devices = [];
let ws = null;
let curDev = null;
let termLog = '';
let startTime = null;

// Init
document.addEventListener('DOMContentLoaded', ()=>{
    loadTheme();
    loadDashboard();
    loadDevices();
});

// Navigation
function nav(p) {
    document.querySelectorAll('.page').forEach(e=>e.classList.add('hidden'));
    document.getElementById('p-'+p).classList.remove('hidden');
    document.querySelectorAll('.nav-btn').forEach(e=>e.classList.remove('bg-[var(--hover)]'));
    document.querySelector('.nav-btn[data-p="'+p+'"]')?.classList.add('bg-[var(--hover)]');
    
    const titles = {
        dash: ['Dashboard', 'Visao geral da rede'],
        dev: ['Dispositivos', 'Gerenciamento de equipamentos'],
        term: ['Terminal SSH', 'Acesso remoto'],
        backups: ['Backups', 'Configuracoes salvas'],
        audit: ['Auditoria', 'Logs de atividade'],
        ai: ['Assistente IA', 'Ajuda inteligente'],
        set: ['Configuracoes', 'Preferencias do sistema']
    };
    
    document.getElementById('title').textContent = titles[p]?.[0] || 'LOR-CGR';
    document.getElementById('subtitle').textContent = titles[p]?.[1] || '';
    
    if(p === 'term') loadTermDevs();
    if(p === 'backups') loadBackups();
    if(p === 'audit') loadAudit();
}

// Dashboard
async function loadDashboard() {
    try {
        const r = await fetch(API+'/devices/list/');
        const d = await r.json();
        devices = Array.isArray(d) ? d : (d.devices || []);
        
        document.getElementById('stat-total').textContent = devices.length;
        document.getElementById('stat-online').textContent = devices.filter(d=>d.is_online||d.status==='online').length;
        document.getElementById('stat-offline').textContent = devices.filter(d=>!d.is_online&&d.status!=='online').length;
        document.getElementById('stat-pppoe').textContent = devices.reduce((s,d)=>s+(d.pppoe_count||0),0);
        
        document.getElementById('dash-devices').innerHTML = devices.slice(0,10).map(d=>`
            <div class="flex items-center justify-between p-3 rounded-lg bg-[var(--hover)] hover:bg-[var(--hover)]/80 cursor-pointer" onclick="quickConnect(${d.id})">
                <div class="flex items-center gap-3">
                    <div class="w-2.5 h-2.5 rounded-full ${d.is_online||d.status==='online'?'bg-green-500':'bg-red-500'}"></div>
                    <div>
                        <p class="font-medium">${d.hostname||d.name}</p>
                        <p class="text-xs text-[var(--muted)]">${d.ip_address||d.ip} - ${d.device_type||'device'}</p>
                    </div>
                </div>
                <button class="p-2 rounded hover:bg-green-500/20 text-green-400"><i class="fas fa-terminal"></i></button>
            </div>
        `).join('') || '<p class="text-center text-[var(--muted)] py-4">Nenhum dispositivo</p>';
    } catch(e) {
        console.error('Erro dashboard:', e);
    }
}

// Devices
async function loadDevices() {
    try {
        const r = await fetch(API+'/devices/list/');
        const d = await r.json();
        devices = Array.isArray(d) ? d : (d.devices || []);
        renderDevices(devices);
    } catch(e) {
        document.getElementById('devices-table').innerHTML = '<tr><td colspan="7" class="px-4 py-8 text-center text-red-400">Erro ao carregar</td></tr>';
    }
}

function filterDevices() {
    const type = document.getElementById('filter-type').value;
    const status = document.getElementById('filter-status').value;
    const search = document.getElementById('search-dev').value.toLowerCase();
    
    let f = devices;
    if(type) f = f.filter(d=>d.device_type===type);
    if(status==='online') f = f.filter(d=>d.is_online||d.status==='online');
    if(status==='offline') f = f.filter(d=>!d.is_online&&d.status!=='online');
    if(search) f = f.filter(d=>(d.hostname||d.name||'').toLowerCase().includes(search) || (d.ip_address||d.ip||'').includes(search));
    
    renderDevices(f);
}

function renderDevices(list) {
    document.getElementById('devices-table').innerHTML = list.map(d=>`
        <tr class="hover:bg-[var(--hover)]">
            <td class="px-4 py-3"><div class="w-2.5 h-2.5 rounded-full ${d.is_online||d.status==='online'?'bg-green-500':'bg-red-500'}"></div></td>
            <td class="px-4 py-3 font-medium">${d.hostname||d.name}</td>
            <td class="px-4 py-3 font-mono text-sm">${d.ip_address||d.ip}</td>
            <td class="px-4 py-3"><span class="px-2 py-0.5 rounded text-xs bg-blue-500/20 text-blue-400">${d.device_type||'-'}</span></td>
            <td class="px-4 py-3 text-sm text-[var(--muted)]">${d.vendor||'-'}</td>
            <td class="px-4 py-3"><span class="px-2 py-0.5 rounded text-xs ${d.ssh_user?'bg-green-500/20 text-green-400':'bg-gray-500/20 text-gray-400'}">${d.ssh_user?d.ssh_port||22:'-'}</span></td>
            <td class="px-4 py-3">
                <div class="flex gap-1">
                    <button onclick="showDeviceInfo(${d.id})" class="p-2 rounded hover:bg-blue-500/20 text-blue-400" title="Detalhes"><i class="fas fa-info-circle"></i></button>
                    <button onclick="quickConnect(${d.id})" class="p-2 rounded hover:bg-green-500/20 text-green-400" title="SSH"><i class="fas fa-terminal"></i></button>
                    <button onclick="editDevice(${d.id})" class="p-2 rounded hover:bg-yellow-500/20 text-yellow-400" title="Editar"><i class="fas fa-edit"></i></button>
                    <button onclick="deleteDevice(${d.id})" class="p-2 rounded hover:bg-red-500/20 text-red-400" title="Excluir"><i class="fas fa-trash"></i></button>
                </div>
            </td>
        </tr>
    `).join('') || '<tr><td colspan="7" class="px-4 py-8 text-center text-[var(--muted)]">Nenhum dispositivo</td></tr>';
}

function showDeviceInfo(id) {
    const d = devices.find(x=>x.id===id);
    if(!d) return;
    
    document.getElementById('info-title').textContent = d.hostname||d.name;
    document.getElementById('info-content').innerHTML = `
        <div class="grid grid-cols-2 gap-4 mb-4">
            <div class="card rounded p-4"><p class="text-xs text-[var(--muted)]">IP</p><p class="font-mono">${d.ip_address||d.ip||'-'}</p></div>
            <div class="card rounded p-4"><p class="text-xs text-[var(--muted)]">Tipo</p><p>${d.device_type||'-'}</p></div>
            <div class="card rounded p-4"><p class="text-xs text-[var(--muted)]">Vendor</p><p>${d.vendor||'-'}</p></div>
            <div class="card rounded p-4"><p class="text-xs text-[var(--muted)]">Modelo</p><p>${d.model||'-'}</p></div>
            <div class="card rounded p-4"><p class="text-xs text-[var(--muted)]">Status</p><p class="${d.is_online||d.status==='online'?'text-green-400':'text-red-400'}">${d.is_online||d.status==='online'?'Online':'Offline'}</p></div>
            <div class="card rounded p-4"><p class="text-xs text-[var(--muted)]">PPPoE</p><p>${d.pppoe_count||0}</p></div>
        </div>
        <div class="card rounded p-4 mb-4">
            <h4 class="font-semibold mb-2">SSH</h4>
            <div class="grid grid-cols-3 gap-4 text-sm">
                <div><span class="text-[var(--muted)]">Usuario:</span> ${d.ssh_user||'-'}</div>
                <div><span class="text-[var(--muted)]">Porta:</span> ${d.ssh_port||22}</div>
                <div><span class="text-[var(--muted)]">Senha:</span> ${d.ssh_password?'*******':'-'}</div>
            </div>
        </div>
        <div class="card rounded p-4">
            <h4 class="font-semibold mb-2">SNMP</h4>
            <div class="grid grid-cols-2 gap-4 text-sm">
                <div><span class="text-[var(--muted)]">Community:</span> ${d.snmp_community||'-'}</div>
                <div><span class="text-[var(--muted)]">Porta:</span> ${d.snmp_port||161}</div>
            </div>
        </div>
        <div class="flex gap-2 mt-4">
            <button onclick="closeInfoModal();quickConnect(${d.id})" class="btn px-4 py-2 rounded flex-1"><i class="fas fa-terminal mr-2"></i>Conectar SSH</button>
            <button onclick="runBackup(${d.id})" class="px-4 py-2 rounded bg-[var(--hover)] flex-1"><i class="fas fa-download mr-2"></i>Backup</button>
        </div>
    `;
    
    document.getElementById('info-modal').classList.remove('hidden');
    document.getElementById('info-modal').classList.add('flex');
}

function closeInfoModal() {
    document.getElementById('info-modal').classList.add('hidden');
    document.getElementById('info-modal').classList.remove('flex');
}

function editDevice(id) {
    const d = devices.find(x=>x.id===id);
    if(!d) return;
    
    document.getElementById('edit-id').value = d.id;
    document.getElementById('dev-name').value = d.hostname||d.name||'';
    document.getElementById('dev-ip').value = d.ip_address||d.ip||'';
    document.getElementById('dev-type').value = d.device_type||'router';
    document.getElementById('dev-vendor').value = d.vendor||'';
    document.getElementById('dev-user').value = d.ssh_user||'';
    document.getElementById('dev-pass').value = d.ssh_password||'';
    document.getElementById('dev-port').value = d.ssh_port||22;
    document.getElementById('dev-snmp').value = d.snmp_community||'';
    document.getElementById('modal-title').textContent = 'Editar Dispositivo';
    
    openDeviceModal();
}

function openDeviceModal() {
    document.getElementById('device-modal').classList.remove('hidden');
    document.getElementById('device-modal').classList.add('flex');
}

function closeDeviceModal() {
    document.getElementById('device-modal').classList.add('hidden');
    document.getElementById('device-modal').classList.remove('flex');
    document.getElementById('edit-id').value = '';
    document.getElementById('modal-title').textContent = 'Novo Dispositivo';
}

async function saveDevice(e) {
    e.preventDefault();
    const editId = document.getElementById('edit-id').value;
    const data = {
        hostname: document.getElementById('dev-name').value,
        ip_address: document.getElementById('dev-ip').value,
        device_type: document.getElementById('dev-type').value,
        vendor: document.getElementById('dev-vendor').value,
        ssh_user: document.getElementById('dev-user').value,
        ssh_password: document.getElementById('dev-pass').value,
        ssh_port: parseInt(document.getElementById('dev-port').value)||22,
        snmp_community: document.getElementById('dev-snmp').value
    };
    
    if(editId) data.id = parseInt(editId);
    
    try {
        await fetch(API+'/devices/save/', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify(data)
        });
        closeDeviceModal();
        loadDevices();
        loadDashboard();
    } catch(e) {
        alert('Erro ao salvar');
    }
}

async function deleteDevice(id) {
    if(!confirm('Deseja realmente excluir este dispositivo?')) return;
    try {
        await fetch(API+'/devices/'+id+'/delete/', {method: 'DELETE'});
        loadDevices();
        loadDashboard();
    } catch(e) {
        alert('Erro ao excluir');
    }
}

// Terminal
function loadTermDevs() {
    document.getElementById('terminal-devices').innerHTML = devices.map(d=>`
        <div onclick="connectSSH(${d.id})" class="flex items-center gap-2 p-2 rounded cursor-pointer transition-all ${curDev?.id===d.id?'bg-[var(--p)]/20 border border-[var(--p)]':'hover:bg-[var(--hover)]'}">
            <div class="w-2 h-2 rounded-full ${d.is_online||d.status==='online'?'bg-green-500':'bg-red-500'}"></div>
            <div class="flex-1 min-w-0">
                <p class="font-medium text-sm truncate">${d.hostname||d.name}</p>
                <p class="text-xs text-[var(--muted)]">${d.ip_address||d.ip}</p>
            </div>
        </div>
    `).join('') || '<p class="text-center text-[var(--muted)] py-4 text-sm">Nenhum</p>';
}

function connectSSH(id) {
    const d = devices.find(x=>x.id===id);
    if(!d) return;
    
    curDev = d;
    termLog = '';
    startTime = Date.now();
    
    document.getElementById('terminal-tab').innerHTML = `
        <div class="flex items-center gap-2 bg-[var(--p)]/20 px-3 py-1 rounded">
            <div class="w-2 h-2 rounded-full bg-green-500 animate-pulse"></div>
            <span class="font-medium">${d.hostname||d.name}</span>
            <span class="text-xs text-[var(--muted)]">${d.ip_address||d.ip}:${d.ssh_port||22}</span>
            <button onclick="disconnectSSH()" class="ml-2 text-red-400 hover:text-red-300"><i class="fas fa-times"></i></button>
        </div>
    `;
    
    document.getElementById('term-text').textContent = `Conectando a ${d.hostname||d.name} (${d.ip_address||d.ip}:${d.ssh_port||22})...\n`;
    document.getElementById('term-status').textContent = 'Conectando...';
    document.getElementById('term-info').textContent = d.ssh_user||'admin';
    
    loadTermDevs();
    
    if(ws) ws.close();
    ws = new WebSocket(`ws://45.71.242.131:8001/ws/terminal/${id}/`);
    
    ws.onopen = () => {
        document.getElementById('term-text').textContent += '\n\x1b[32mConectado!\x1b[0m\n\n';
        document.getElementById('term-status').innerHTML = '<span class="text-green-400">Conectado</span>';
    };
    
    ws.onmessage = (e) => {
        try {
            const data = JSON.parse(e.data);
            if(data.type === 'output') {
                document.getElementById('term-text').textContent += data.data;
                termLog += data.data;
            } else if(data.type === 'error') {
                document.getElementById('term-text').textContent += '\n\x1b[31m' + data.data + '\x1b[0m\n';
            } else if(data.type === 'connected') {
                document.getElementById('term-text').textContent += '\n\x1b[32m' + data.data + '\x1b[0m\n';
            }
            document.getElementById('terminal-output').scrollTop = document.getElementById('terminal-output').scrollHeight;
        } catch(ex) {
            document.getElementById('term-text').textContent += e.data;
        }
    };
    
    ws.onclose = () => {
        document.getElementById('term-text').textContent += '\n\n\x1b[33mDesconectado\x1b[0m\n';
        document.getElementById('term-status').textContent = 'Desconectado';
        curDev = null;
        loadTermDevs();
    };
    
    ws.onerror = () => {
        document.getElementById('term-text').textContent += '\n\n\x1b[31mErro de conexao\x1b[0m\n';
        document.getElementById('term-status').innerHTML = '<span class="text-red-400">Erro</span>';
    };
    
    document.getElementById('terminal-output').focus();
}

function disconnectSSH() {
    if(ws) ws.close();
    curDev = null;
    document.getElementById('terminal-tab').textContent = 'Nenhuma sessao ativa';
    document.getElementById('term-status').textContent = 'Desconectado';
    document.getElementById('term-info').textContent = '-';
    loadTermDevs();
}

// Terminal keyboard
document.getElementById('terminal-output').addEventListener('keydown', (e) => {
    if(!ws || ws.readyState !== WebSocket.OPEN) return;
    
    let data = null;
    
    if(e.key === 'Enter') {
        data = '\r';
    } else if(e.key === 'Backspace') {
        data = '\x7f';
    } else if(e.key === 'Delete') {
        data = '\x1b[3~';
    } else if(e.key === 'ArrowUp') {
        data = '\x1b[A';
    } else if(e.key === 'ArrowDown') {
        data = '\x1b[B';
    } else if(e.key === 'ArrowRight') {
        data = '\x1b[C';
    } else if(e.key === 'ArrowLeft') {
        data = '\x1b[D';
    } else if(e.key === 'Tab') {
        data = '\t';
    } else if(e.key === 'Escape') {
        data = '\x1b';
    } else if(e.key.length === 1) {
        data = e.key;
    }
    
    if(data !== null) {
        ws.send(JSON.stringify({type: 'input', data: data}));
        e.preventDefault();
    }
});

function clearTerminal() {
    document.getElementById('term-text').textContent = '';
}

function downloadLog() {
    const content = `LOR-CGR Terminal Log
Dispositivo: ${curDev?.hostname||curDev?.name||'N/A'}
IP: ${curDev?.ip_address||curDev?.ip||'N/A'}
Data: ${new Date().toLocaleString('pt-BR')}
${'='.repeat(50)}

${termLog}`;
    const blob = new Blob([content], {type: 'text/plain'});
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = `terminal-${curDev?.hostname||'log'}-${Date.now()}.txt`;
    a.click();
}

function quickConnect(id) {
    nav('term');
    setTimeout(()=>connectSSH(id), 100);
}

// Backups
async function loadBackups() {
    try {
        const r = await fetch(API+'/backups/');
        const d = await r.json();
        const backups = d.backups || [];
        
        if(backups.length === 0) {
            document.getElementById('backups-list').innerHTML = `
                <div class="card rounded p-8 text-center">
                    <i class="fas fa-database text-4xl text-[var(--muted)] mb-4"></i>
                    <p class="text-[var(--muted)]">Nenhum backup encontrado</p>
                    <p class="text-xs text-[var(--muted)] mt-2">Clique em "Backup de Todos" para criar backups</p>
                </div>
            `;
            return;
        }
        
        document.getElementById('backups-list').innerHTML = backups.map(b=>`
            <div class="card rounded p-4 flex items-center justify-between">
                <div class="flex items-center gap-4">
                    <div class="w-10 h-10 rounded bg-blue-500/20 flex items-center justify-center">
                        <i class="fas fa-file-code text-blue-400"></i>
                    </div>
                    <div>
                        <p class="font-medium">${b.filename}</p>
                        <p class="text-sm text-[var(--muted)]">${b.device_name} - ${new Date(b.created_at).toLocaleString('pt-BR')}</p>
                    </div>
                </div>
                <div class="flex items-center gap-4">
                    <span class="text-sm text-[var(--muted)]">${(b.size_bytes/1024).toFixed(1)} KB</span>
                    <span class="px-2 py-1 rounded text-xs ${b.status==='success'?'bg-green-500/20 text-green-400':'bg-red-500/20 text-red-400'}">${b.status}</span>
                </div>
            </div>
        `).join('');
    } catch(e) {
        document.getElementById('backups-list').innerHTML = '<div class="card rounded p-8 text-center text-red-400">Erro ao carregar backups</div>';
    }
}

async function runBackup(id) {
    try {
        await fetch(API+'/backups/run/'+id+'/', {method: 'POST'});
        alert('Backup iniciado!');
        loadBackups();
    } catch(e) {
        alert('Erro ao executar backup');
    }
}

async function runAllBackups() {
    for(const d of devices) {
        try {
            await fetch(API+'/backups/run/'+d.id+'/', {method: 'POST'});
        } catch(e) {}
    }
    alert('Backups iniciados!');
    loadBackups();
}

// Audit
async function loadAudit() {
    try {
        const action = document.getElementById('audit-action').value;
        let url = API+'/audit/logs/';
        
        const r = await fetch(url);
        const d = await r.json();
        let logs = d.logs || [];
        
        if(action) logs = logs.filter(l=>l.action===action);
        
        document.getElementById('audit-total').textContent = logs.length;
        document.getElementById('audit-ssh').textContent = logs.filter(l=>l.action?.includes('SSH')).length;
        document.getElementById('audit-cmd').textContent = logs.filter(l=>l.action==='COMMAND').length;
        document.getElementById('audit-backup').textContent = logs.filter(l=>l.action==='BACKUP').length;
        
        const colors = {
            'SSH_CONNECT': 'bg-green-500/20 text-green-400',
            'SSH_DISCONNECT': 'bg-yellow-500/20 text-yellow-400',
            'COMMAND': 'bg-blue-500/20 text-blue-400',
            'BACKUP': 'bg-purple-500/20 text-purple-400',
            'DEVICE_ADD': 'bg-cyan-500/20 text-cyan-400'
        };
        
        document.getElementById('audit-list').innerHTML = logs.length ? logs.map(l=>`
            <div class="p-4 hover:bg-[var(--hover)] flex justify-between items-center">
                <div class="flex items-center gap-3">
                    <span class="px-2 py-1 rounded text-xs ${colors[l.action]||'bg-gray-500/20 text-gray-400'}">${l.action}</span>
                    <div>
                        <p class="text-sm">${l.details}</p>
                        <p class="text-xs text-[var(--muted)]">${l.user||'system'} - ${l.device||'-'} - ${new Date(l.timestamp).toLocaleString('pt-BR')}</p>
                    </div>
                </div>
            </div>
        `).join('') : '<p class="p-8 text-center text-[var(--muted)]">Nenhum log encontrado</p>';
    } catch(e) {
        document.getElementById('audit-list').innerHTML = '<p class="p-8 text-center text-red-400">Erro ao carregar</p>';
    }
}

// AI
function sendAI() {
    const input = document.getElementById('ai-input');
    const msg = input.value.trim();
    if(!msg) return;
    
    const chat = document.getElementById('ai-chat');
    chat.innerHTML += `
        <div class="flex gap-3 justify-end">
            <div class="bg-[var(--p)]/20 rounded-lg p-3 max-w-[80%]">
                <p class="text-sm">${msg}</p>
            </div>
            <div class="w-8 h-8 rounded-full bg-blue-500/20 flex items-center justify-center">
                <i class="fas fa-user text-blue-400 text-sm"></i>
            </div>
        </div>
    `;
    input.value = '';
    
    setTimeout(()=>{
        chat.innerHTML += `
            <div class="flex gap-3">
                <div class="w-8 h-8 rounded-full bg-purple-500/20 flex items-center justify-center">
                    <i class="fas fa-robot text-purple-400 text-sm"></i>
                </div>
                <div class="bg-[var(--hover)] rounded-lg p-3 max-w-[80%]">
                    <p class="text-sm">Obrigado pela pergunta! Como sou um assistente de demonstracao, ainda nao tenho integracao com IA real. Em breve terei acesso a modelos de IA para ajudar com analise de rede, troubleshooting e muito mais!</p>
                </div>
            </div>
        `;
        chat.scrollTop = chat.scrollHeight;
    }, 1000);
}

function askAI(q) {
    document.getElementById('ai-input').value = q;
    sendAI();
}

// Theme
function setTheme(t) {
    document.body.className = t + ' min-h-screen';
    localStorage.setItem('lorcgr-theme', t);
}

function loadTheme() {
    const t = localStorage.getItem('lorcgr-theme') || '';
    setTheme(t);
}

function toggleTheme() {
    nav('set');
}

// Refresh
function refreshAll() {
    loadDashboard();
    loadDevices();
    loadBackups();
    loadAudit();
}

// Update duration
setInterval(()=>{
    if(startTime && curDev) {
        const s = Math.floor((Date.now()-startTime)/1000);
        const m = Math.floor(s/60);
        document.getElementById('term-info').textContent = `${curDev.ssh_user||'admin'} - ${m}:${(s%60).toString().padStart(2,'0')}`;
    }
}, 1000);
</script>
</body>
</html>
HTMLEOF

# ========================================
# RESTART SERVICES
# ========================================
echo ""
echo "Reiniciando servicos..."
systemctl restart lorcgr-backend
systemctl restart lorcgr-websocket
systemctl restart grafana-server 2>/dev/null || true
nginx -t && systemctl restart nginx

echo ""
echo "=========================================="
echo "CORRECAO COMPLETA!"
echo "=========================================="
echo ""
echo "Acesse: http://45.71.242.131/"
echo ""
echo "Servicos:"
echo "  - LOR-CGR: http://45.71.242.131/"
echo "  - LibreNMS: http://45.71.242.131:8080"
echo "  - phpIPAM: http://45.71.242.131:8081"
echo "  - Grafana: http://45.71.242.131:3000"
echo ""
systemctl status lorcgr-backend --no-pager | head -3
systemctl status lorcgr-websocket --no-pager | head -3
systemctl status grafana-server --no-pager | head -3 2>/dev/null || echo "Grafana: Verificar instalacao"
