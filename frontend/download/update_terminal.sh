#!/bin/bash
# ============================================
# ATUALIZAR TERMINAL - LOR-CGR
# ============================================

set -e

echo "=== 1. Criar tabela de sessões no PostgreSQL ==="
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
echo "=== 2. Criar views do terminal ==="
cat > /opt/lorcgr/terminal/views.py << 'EOFVIEWS'
import json
import psycopg2
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from datetime import datetime

def get_db_connection():
    return psycopg2.connect(
        dbname='lorcgr',
        user='lorcgr',
        password='Lor#Vision#2016',
        host='localhost'
    )

@csrf_exempt
@require_http_methods(["GET"])
def list_sessions(request):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT id, session_id, device_id, device_name, started_at, ended_at, created_at,
                   LENGTH(log) as log_size
            FROM terminal_sessions
            ORDER BY started_at DESC
            LIMIT 100
        """)
        rows = cursor.fetchall()
        conn.close()
        sessions = [{
            'id': r[0],
            'session_id': r[1],
            'device_id': r[2],
            'device_name': r[3],
            'started_at': r[4].isoformat() if r[4] else None,
            'ended_at': r[5].isoformat() if r[5] else None,
            'created_at': r[6].isoformat() if r[6] else None,
            'log_size': r[7]
        } for r in rows]
        return JsonResponse({'sessions': sessions})
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

@csrf_exempt
@require_http_methods(["GET"])
def get_session_log(request, session_id):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT session_id, device_name, started_at, ended_at, log
            FROM terminal_sessions
            WHERE session_id = %s OR id = %s
        """, [session_id, session_id])
        row = cursor.fetchone()
        conn.close()
        if not row:
            return JsonResponse({'error': 'Sessao nao encontrada'}, status=404)
        return JsonResponse({
            'session_id': row[0],
            'device_name': row[1],
            'started_at': row[2].isoformat() if row[2] else None,
            'ended_at': row[3].isoformat() if row[3] else None,
            'log': row[4]
        })
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

@csrf_exempt
@require_http_methods(["POST"])
def save_session(request):
    try:
        data = json.loads(request.body)
        session_id = data.get('session_id')
        device_id = data.get('device_id')
        device_name = data.get('device_name')
        started_at = data.get('started_at')
        ended_at = data.get('ended_at')
        log = data.get('log', '')
        if not session_id:
            return JsonResponse({'error': 'session_id obrigatorio'}, status=400)
        conn = get_db_connection()
        cursor = conn.cursor()
        started = datetime.fromisoformat(started_at) if started_at else None
        ended = datetime.fromisoformat(ended_at) if ended_at else None
        cursor.execute("""
            INSERT INTO terminal_sessions (session_id, device_id, device_name, started_at, ended_at, log)
            VALUES (%s, %s, %s, %s, %s, %s)
            ON CONFLICT (session_id)
            DO UPDATE SET ended_at = %s, log = %s
        """, [session_id, device_id, device_name, started, ended, log, ended, log])
        conn.commit()
        conn.close()
        return JsonResponse({'status': 'success', 'session_id': session_id})
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

@csrf_exempt
@require_http_methods(["POST"])
def delete_session(request):
    try:
        data = json.loads(request.body)
        session_id = data.get('session_id')
        if not session_id:
            return JsonResponse({'error': 'session_id obrigatorio'}, status=400)
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM terminal_sessions WHERE session_id = %s OR id = %s", [session_id, session_id])
        conn.commit()
        deleted = cursor.rowcount
        conn.close()
        if deleted == 0:
            return JsonResponse({'error': 'Sessao nao encontrada'}, status=404)
        return JsonResponse({'status': 'success', 'deleted': deleted})
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)
EOFVIEWS

echo "✅ Views criadas"


echo ""
echo "=== 3. Criar/Atualizar urls.py do terminal ==="
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
echo "=== 4. Verificar urls.py principal ==="
cat /opt/lorcgr/lorcgr_core/urls.py


echo ""
echo "=== 5. Adicionar rota de terminal se não existir ==="
if ! grep -q "terminal" /opt/lorcgr/lorcgr_core/urls.py; then
    # Adicionar a rota de terminal
    sed -i "s|path('api/audit/', include('audit.urls')),|path('api/audit/', include('audit.urls')),\n    path('api/terminal/', include('terminal.urls')),|" /opt/lorcgr/lorcgr_core/urls.py
    echo "✅ Rota adicionada"
else
    echo "ℹ️ Rota já existe"
fi

cat /opt/lorcgr/lorcgr_core/urls.py


echo ""
echo "=== 6. Reiniciar Django ==="
pkill -f gunicorn
cd /opt/lorcgr && source venv/bin/activate && gunicorn lorcgr_core.wsgi:application --bind 0.0.0.0:8000 --workers 2 --daemon
echo "✅ Django reiniciado"


echo ""
echo "=== 7. Testar API ==="
sleep 2
curl -s http://localhost:8000/api/terminal/sessions/


echo ""
echo "============================================"
echo "✅ TERMINAL ATUALIZADO!"
echo "============================================"
