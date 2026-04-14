"""
APIs de Backup, Restore e Gerenciamento de Servicos - LOR-CGR 2026
"""
import os
import subprocess
import json
import glob as glob_module
from datetime import datetime
from django.http import HttpResponse, JsonResponse, FileResponse
from django.views.decorators.csrf import csrf_exempt
from django.conf import settings
from rest_framework.decorators import api_view

BACKUP_DIR = "/opt/lorcgr/_zscripts/backups"
PROJECT_DIR = "/opt/lorcgr"

BACKUP_TYPES = {
    'postgresql_': 'postgresql',
    'frontend_': 'frontend',
    'backend_': 'backend',
    'configs_': 'configs',
    'manifest_': 'manifest'
}

def get_backup_info(filepath):
    try:
        stat = os.stat(filepath)
        filename = os.path.basename(filepath)
        backup_type = 'unknown'
        for prefix, type_name in BACKUP_TYPES.items():
            if filename.startswith(prefix):
                backup_type = type_name
                break
        return {
            'name': filename,
            'size': f"{stat.st_size / (1024*1024):.2f} MB" if stat.st_size > 1024*1024 else f"{stat.st_size / 1024:.1f} KB",
            'size_bytes': stat.st_size,
            'date': datetime.fromtimestamp(stat.st_mtime).strftime('%d/%m/%Y %H:%M'),
            'type': backup_type,
            'path': filepath
        }
    except Exception:
        return None

def check_port(port):
    import socket
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(1)
        r = s.connect_ex(("127.0.0.1", port))
        s.close()
        return r == 0
    except Exception:
        return False
@api_view(['GET'])
def list_backups(request):
    try:
        files = []
        for pattern in ['*.sql.gz', '*.tar.gz']:
            for filepath in sorted(glob_module.glob(os.path.join(BACKUP_DIR, pattern)), reverse=True):
                info = get_backup_info(filepath)
                if info:
                    files.append(info)
        files.sort(key=lambda x: x['date'], reverse=True)
        return JsonResponse({'success': True, 'files': files, 'total': len(files), 'backup_dir': BACKUP_DIR})
    except Exception as e:
        return JsonResponse({'success': False, 'error': str(e)}, status=500)

@csrf_exempt
@api_view(['POST'])
def create_backup(request):
    try:
        script_path = "/opt/lorcgr/_zscripts/backup_lorcgr.sh"
        if not os.path.exists(script_path):
            return JsonResponse({'success': False, 'error': 'Script nao encontrado'}, status=404)
        result = subprocess.run(['bash', script_path], capture_output=True, text=True, cwd=PROJECT_DIR, timeout=600)
        if result.returncode == 0:
            now = datetime.now()
            recent = []
            for p in ['*.sql.gz', '*.tar.gz']:
                for fp in glob_module.glob(os.path.join(BACKUP_DIR, p)):
                    if (now - datetime.fromtimestamp(os.path.getmtime(fp))).total_seconds() < 300:
                        info = get_backup_info(fp)
                        if info:
                            recent.append(info)
            return JsonResponse({'success': True, 'message': 'Backup concluido!', 'files_created': recent})
        else:
            return JsonResponse({'success': False, 'error': result.stderr}, status=500)
    except subprocess.TimeoutExpired:
        return JsonResponse({'success': False, 'error': 'Timeout'}, status=408)
    except Exception as e:
        return JsonResponse({'success': False, 'error': str(e)}, status=500)

@csrf_exempt
@api_view(['DELETE'])
def delete_backup(request, filename):
    try:
        safe = os.path.basename(filename)
        if safe != filename or '/' in filename or '..' in filename:
            return JsonResponse({'success': False, 'error': 'Nome invalido'}, status=400)
        fp = os.path.join(BACKUP_DIR, safe)
        if not os.path.exists(fp):
            return JsonResponse({'success': False, 'error': 'Nao encontrado'}, status=404)
        os.remove(fp)
        return JsonResponse({'success': True, 'message': f'{safe} deletado!'})
    except Exception as e:
        return JsonResponse({'success': False, 'error': str(e)}, status=500)

@csrf_exempt
@api_view(['GET'])
def download_backup(request, filename):
    try:
        safe = os.path.basename(filename)
        if safe != filename or '/' in filename or '..' in filename:
            return HttpResponse('Nome invalido', status=400)
        fp = os.path.join(BACKUP_DIR, safe)
        if not os.path.exists(fp):
            return HttpResponse('Nao encontrado', status=404)
        return FileResponse(open(fp, 'rb'), as_attachment=True, filename=safe)
    except Exception as e:
        return HttpResponse(f'Erro: {str(e)}', status=500)

@csrf_exempt
@api_view(['POST'])
def restore_backup(request):
    try:
        data = json.loads(request.body)
        filename = data.get('filename')
        if not filename:
            return JsonResponse({'success': False, 'error': 'Filename nao fornecido'}, status=400)
        safe = os.path.basename(filename)
        fp = os.path.join(BACKUP_DIR, safe)
        if not os.path.exists(fp):
            return JsonResponse({'success': False, 'error': 'Nao encontrado'}, status=404)
        cmd = ''
        if safe.startswith('postgresql_'):
            cmd = f'cd /opt/lorcgr && gunzip -c "{fp}" | PGPASSWORD="Lor#Cgr#2026" psql -h localhost -U lorcgr -d lorcgr'
        elif safe.startswith('frontend_'):
            cmd = f'cd /opt/lorcgr && tar -xzf "{fp}" && cd frontend && npm run build && fuser -k 3000/tcp; npm run start &'
        elif safe.startswith('backend_'):
            cmd = f'cd /opt/lorcgr && tar -xzf "{fp}" && kill -HUP $(pgrep -f gunicorn)'
        elif safe.startswith('configs_'):
            cmd = f'cd /opt/lorcgr && tar -xzf "{fp}"'
        else:
            return JsonResponse({'success': False, 'error': 'Tipo desconhecido'}, status=400)
        subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=PROJECT_DIR)
        return JsonResponse({'success': True, 'message': f'Restauracao de {safe} iniciada!'})
    except json.JSONDecodeError:
        return JsonResponse({'success': False, 'error': 'JSON invalido'}, status=400)
    except Exception as e:
        return JsonResponse({'success': False, 'error': str(e)}, status=500)

@csrf_exempt
@api_view(['POST'])
def restart_django(request):
    try:
        subprocess.run(['pkill', '-HUP', '-f', 'gunicorn'], capture_output=True)
        return JsonResponse({'success': True, 'message': 'Django reiniciado!'})
    except Exception as e:
        return JsonResponse({'success': False, 'error': str(e)}, status=500)

@csrf_exempt
@api_view(['POST'])
def restart_nextjs(request):
    try:
        subprocess.run(['fuser', '-k', '3000/tcp'], capture_output=True)
        import time
        time.sleep(2)
        subprocess.Popen('npm run start', shell=True, cwd='/opt/lorcgr/frontend',
            stdout=open('/tmp/nextjs.log', 'w'), stderr=open('/tmp/nextjs.log', 'w'),
            env={**os.environ, 'PORT': '3000'})
        return JsonResponse({'success': True, 'message': 'Next.js reiniciado!'})
    except Exception as e:
        return JsonResponse({'success': False, 'error': str(e)}, status=500)

@csrf_exempt
@api_view(['GET'])
def service_status(request):
    try:
        services = {
            'nextjs': {'running': check_port(3000), 'port': 3000},
            'django': {'running': check_port(8000), 'port': 8000},
            'postgresql': {'running': check_port(5432), 'port': 5432},
        }
        return JsonResponse({
            'success': True,
            'services': services,
            'checked_at': datetime.now().isoformat()
        })
    except Exception as e:
        return JsonResponse({'success': False, 'error': str(e)}, status=500)
