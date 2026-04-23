#!/bin/bash
# ============================================
# DEPLOY FRONTEND LOR-CGR
# ============================================
# Execute este script no servidor após fazer upload dos arquivos

set -e

echo "=== Verificando estrutura ==="
ls -la /opt/lorcgr/static/

echo ""
echo "=== Criando diretório do frontend ==="
mkdir -p /opt/lorcgr/static/lorcgr

echo ""
echo "=== Copiando arquivos (execute após upload) ==="
# Supondo que você fez upload dos arquivos para /tmp/lorcgr-frontend/
# cp -r /tmp/lorcgr-frontend/* /opt/lorcgr/static/lorcgr/

echo ""
echo "=== Criando tabela de sessões de terminal ==="
sudo -u postgres psql -d lorcgr << 'EOSQL'
CREATE TABLE IF NOT EXISTS terminal_sessions (
    id SERIAL PRIMARY KEY,
    session_id VARCHAR(100) UNIQUE,
    device_id INTEGER,
    device_name VARCHAR(100),
    started_at TIMESTAMP,
    ended_at TIMESTAMP,
    log TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);
GRANT ALL PRIVILEGES ON TABLE terminal_sessions TO lorcgr;
GRANT USAGE, SELECT ON SEQUENCE terminal_sessions_id_seq TO lorcgr;
EOSQL

echo "✅ Tabela criada"

echo ""
echo "=== Criando views do terminal ==="
cat > /opt/lorcgr/terminal/views.py << 'EOFVIEWS'
import json
import psycopg2
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from datetime import datetime

def get_db():
    return psycopg2.connect(dbname='lorcgr',user='lorcgr',password='Lor#Vision#2016',host='localhost')

@csrf_exempt
@require_http_methods(["GET"])
def list_sessions(request):
    try:
        conn = get_db()
        cur = conn.cursor()
        cur.execute("SELECT id, session_id, device_name, started_at, ended_at, LENGTH(log) FROM terminal_sessions ORDER BY started_at DESC LIMIT 100")
        sessions = [{'id':r[0],'session_id':r[1],'device_name':r[2],'started_at':r[3].isoformat()if r[3]else None,'ended_at':r[4].isoformat()if r[4]else None,'log_size':r[5]}for r in cur.fetchall()]
        conn.close()
        return JsonResponse({'sessions': sessions})
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

@csrf_exempt
@require_http_methods(["GET"])
def get_session_log(request, session_id):
    try:
        conn = get_db()
        cur = conn.cursor()
        cur.execute("SELECT session_id, device_name, started_at, ended_at, log FROM terminal_sessions WHERE session_id=%s OR id=%s", [session_id, session_id])
        r = cur.fetchone()
        conn.close()
        if not r: return JsonResponse({'error':'Nao encontrado'}, status=404)
        return JsonResponse({'session_id':r[0],'device_name':r[1],'started_at':r[2].isoformat()if r[2]else None,'ended_at':r[3].isoformat()if r[3]else None,'log':r[4]})
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

@csrf_exempt
@require_http_methods(["POST"])
def save_session(request):
    try:
        d = json.loads(request.body)
        conn = get_db()
        cur = conn.cursor()
        started = datetime.fromisoformat(d['started_at']) if d.get('started_at') else None
        ended = datetime.fromisoformat(d['ended_at']) if d.get('ended_at') else None
        cur.execute("INSERT INTO terminal_sessions(session_id,device_id,device_name,started_at,ended_at,log)VALUES(%s,%s,%s,%s,%s,%s)ON CONFLICT(session_id)DO UPDATE SET ended_at=%s,log=%s",
            [d['session_id'],d.get('device_id'),d.get('device_name'),started,ended,d.get('log',''),ended,d.get('log','')])
        conn.commit()
        conn.close()
        return JsonResponse({'status':'success'})
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

@csrf_exempt
@require_http_methods(["POST"])
def delete_session(request):
    try:
        d = json.loads(request.body)
        conn = get_db()
        cur = conn.cursor()
        cur.execute("DELETE FROM terminal_sessions WHERE session_id=%s OR id=%s", [d['session_id'],d['session_id']])
        conn.commit()
        conn.close()
        return JsonResponse({'status':'success'})
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)
EOFVIEWS

echo "✅ Views criadas"

echo ""
echo "=== Criando urls do terminal ==="
cat > /opt/lorcgr/terminal/urls.py << 'EOFURLS'
from django.urls import path
from . import views

urlpatterns = [
    path('sessions/', views.list_sessions, name='list_sessions'),
    path('sessions/save/', views.save_session, name='save_session'),
    path('sessions/delete/', views.delete_session, name='delete_session'),
    path('sessions/<str:session_id>/log/', views.get_session_log, name='get_session_log'),
]
EOFURLS

echo "✅ URLs criadas"

echo ""
echo "=== Adicionando rota no urls.py principal ==="
if ! grep -q "terminal" /opt/lorcgr/lorcgr_core/urls.py; then
    sed -i "s|path('api/audit/', include('audit.urls')),|path('api/audit/', include('audit.urls')),\n    path('api/terminal/', include('terminal.urls')),|" /opt/lorcgr/lorcgr_core/urls.py
    echo "✅ Rota adicionada"
else
    echo "ℹ️ Rota já existe"
fi

echo ""
echo "=== Reiniciando Django ==="
pkill -f gunicorn
cd /opt/lorcgr && source venv/bin/activate && gunicorn lorcgr_core.wsgi:application --bind 0.0.0.0:8000 --workers 2 --daemon
echo "✅ Django reiniciado"

echo ""
echo "=== Testando API ==="
sleep 2
curl -s http://localhost:8000/api/terminal/sessions/

echo ""
echo "============================================"
echo "✅ DEPLOY CONCLUÍDO!"
echo "============================================"
