# Views para Terminal Sessions - Django
# Salvar em: /opt/lorcgr/terminal/views.py

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
    """Lista todas as sessões de terminal gravadas"""
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
@require_http_method(["GET"])
def get_session_log(request, session_id):
    """Obtém o log completo de uma sessão"""
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
            return JsonResponse({'error': 'Sessão não encontrada'}, status=404)

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
    """Salva o log de uma sessão de terminal"""
    try:
        data = json.loads(request.body)
        session_id = data.get('session_id')
        device_id = data.get('device_id')
        device_name = data.get('device_name')
        started_at = data.get('started_at')
        ended_at = data.get('ended_at')
        log = data.get('log', '')

        if not session_id:
            return JsonResponse({'error': 'session_id é obrigatório'}, status=400)

        conn = get_db_connection()
        cursor = conn.cursor()

        # Converter datas
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
    """Deleta uma sessão (apenas admin)"""
    try:
        data = json.loads(request.body)
        session_id = data.get('session_id')

        if not session_id:
            return JsonResponse({'error': 'session_id é obrigatório'}, status=400)

        # TODO: Verificar se usuário é admin

        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM terminal_sessions WHERE session_id = %s OR id = %s", [session_id, session_id])
        conn.commit()
        deleted = cursor.rowcount
        conn.close()

        if deleted == 0:
            return JsonResponse({'error': 'Sessão não encontrada'}, status=404)

        return JsonResponse({'status': 'success', 'deleted': deleted})
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)
