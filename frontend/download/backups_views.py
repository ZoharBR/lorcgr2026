from django.http import JsonResponse, FileResponse, Http404
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from django.conf import settings
import os
import json
import psycopg2
from pathlib import Path

# Database connection
def get_db_connection():
    return psycopg2.connect(
        dbname='lorcgr',
        user='lorcgr',
        password='Lor#Vision#2016',
        host='localhost'
    )

# Backup directory
BACKUP_DIR = Path('/opt/lorcgr/backups')


@csrf_exempt
@require_http_methods(["GET"])
def list_backups(request):
    """Lista todos os backups do banco de dados"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT id, device_name, filename, size_bytes, created_at, status
            FROM device_backups
            ORDER BY created_at DESC
        """)
        rows = cursor.fetchall()
        conn.close()

        backups = []
        for row in rows:
            backups.append({
                'id': row[0],
                'device_name': row[1],
                'filename': row[2],
                'size_bytes': row[3],
                'created_at': row[4].isoformat() if row[4] else None,
                'status': row[5]
            })

        return JsonResponse({'backups': backups})
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
@require_http_methods(["GET"])
def download_backup(request):
    """Download de um arquivo de backup específico"""
    try:
        backup_id = request.GET.get('id')

        if not backup_id:
            return JsonResponse({'error': 'ID do backup é obrigatório'}, status=400)

        # Buscar informações do backup no banco
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT device_name, filename FROM device_backups WHERE id = %s
        """, [backup_id])
        row = cursor.fetchone()
        conn.close()

        if not row:
            return JsonResponse({'error': 'Backup não encontrado'}, status=404)

        device_name, filename = row

        # Procurar o arquivo nos diretórios de backup
        # Tenta vários padrões de nomenclatura
        possible_paths = [
            BACKUP_DIR / device_name / filename,
            BACKUP_DIR / device_name.lower() / filename,
            BACKUP_DIR / device_name.upper() / filename,
        ]

        # Também procura recursivamente
        for backup_subdir in BACKUP_DIR.iterdir():
            if backup_subdir.is_dir():
                possible_paths.append(backup_subdir / filename)

        file_path = None
        for path in possible_paths:
            if path.exists() and path.is_file():
                file_path = path
                break

        if not file_path:
            # Listar arquivos disponíveis para debug
            available_files = []
            for backup_subdir in BACKUP_DIR.iterdir():
                if backup_subdir.is_dir():
                    for f in backup_subdir.glob('*.cfg'):
                        available_files.append(str(f))

            return JsonResponse({
                'error': f'Arquivo não encontrado: {filename}',
                'searched_paths': [str(p) for p in possible_paths[:3]],
                'available_files': available_files[:20]
            }, status=404)

        # Retornar o arquivo
        response = FileResponse(
            open(file_path, 'rb'),
            as_attachment=True,
            filename=filename
        )
        response['Content-Type'] = 'text/plain; charset=utf-8'
        return response

    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
@require_http_method(["POST"])
def delete_backup(request):
    """Deleta um backup do banco e arquivo"""
    try:
        data = json.loads(request.body)
        backup_id = data.get('id')

        if not backup_id:
            return JsonResponse({'error': 'ID do backup é obrigatório'}, status=400)

        # Buscar informações do backup
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT device_name, filename FROM device_backups WHERE id = %s
        """, [backup_id])
        row = cursor.fetchone()

        if not row:
            conn.close()
            return JsonResponse({'error': 'Backup não encontrado'}, status=404)

        device_name, filename = row

        # Deletar arquivo físico
        possible_paths = [
            BACKUP_DIR / device_name / filename,
            BACKUP_DIR / device_name.lower() / filename,
        ]

        for path in possible_paths:
            if path.exists():
                path.unlink()
                break

        # Deletar do banco
        cursor.execute("DELETE FROM device_backups WHERE id = %s", [backup_id])
        conn.commit()
        conn.close()

        return JsonResponse({'status': 'success', 'message': 'Backup removido'})

    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)
