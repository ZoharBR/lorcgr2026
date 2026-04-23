# Django Views para Settings - LOR-CGR
# Adicione este código ao arquivo views.py do seu app principal

import os
import json
import subprocess
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from django.conf import settings

# Arquivo para salvar as configurações
SETTINGS_FILE = os.path.join(settings.BASE_DIR, 'settings.json')

# Configurações padrão
DEFAULT_SETTINGS = {
    'librenms_enabled': True,
    'librenms_url': '',
    'librenms_api_token': '',
    'phpipam_enabled': True,
    'phpipam_url': '',
    'phpipam_app_id': '',
    'phpipam_app_key': '',
    'phpipam_user': '',
    'phpipam_password': '',
    'ai_enabled': True,
    'ai_provider': 'groq',
    'groq_api_key': '',
    'groq_model': 'llama-3.3-70b-versatile',
    'ai_temperature': 0.7,
    'ai_max_tokens': 4096,
    'ai_system_prompt': '',
    'git_enabled': False,
    'git_token': '',
    'git_repo_url': '',
    'git_branch': 'main',
    'git_auto_backup': False,
    'git_backup_frequency': 'daily',
}


def load_settings():
    """Carrega configurações do arquivo JSON"""
    if os.path.exists(SETTINGS_FILE):
        try:
            with open(SETTINGS_FILE, 'r') as f:
                saved = json.load(f)
                # Merge com defaults para garantir que todos os campos existam
                return {**DEFAULT_SETTINGS, **saved}
        except Exception as e:
            print(f"Erro ao carregar settings: {e}")
    return DEFAULT_SETTINGS.copy()


def save_settings(settings_data):
    """Salva configurações no arquivo JSON"""
    try:
        with open(SETTINGS_FILE, 'w') as f:
            json.dump(settings_data, f, indent=2)
        return True
    except Exception as e:
        print(f"Erro ao salvar settings: {e}")
        return False


@csrf_exempt
@require_http_methods(["GET"])
def settings_get(request):
    """Retorna as configurações atuais"""
    settings_data = load_settings()
    # Não retorna tokens/senhas por segurança
    safe_settings = settings_data.copy()
    safe_settings['librenms_api_token'] = '***' if settings_data.get('librenms_api_token') else ''
    safe_settings['phpipam_app_key'] = '***' if settings_data.get('phpipam_app_key') else ''
    safe_settings['phpipam_password'] = '***' if settings_data.get('phpipam_password') else ''
    safe_settings['groq_api_key'] = '***' if settings_data.get('groq_api_key') else ''
    safe_settings['git_token'] = '***' if settings_data.get('git_token') else ''
    
    return JsonResponse({
        'success': True,
        'settings': safe_settings
    })


@csrf_exempt
@require_http_methods(["POST"])
def settings_save(request):
    """Salva as configurações"""
    try:
        data = json.loads(request.body)
        current_settings = load_settings()
        
        # Atualiza apenas os campos fornecidos
        for key in DEFAULT_SETTINGS.keys():
            if key in data:
                # Se o valor for '***', mantém o valor atual
                if data[key] == '***':
                    continue
                current_settings[key] = data[key]
        
        if save_settings(current_settings):
            return JsonResponse({
                'success': True,
                'message': 'Configurações salvas com sucesso!'
            })
        else:
            return JsonResponse({
                'success': False,
                'error': 'Erro ao salvar configurações'
            }, status=500)
    except Exception as e:
        return JsonResponse({
            'success': False,
            'error': str(e)
        }, status=400)


@csrf_exempt
@require_http_methods(["POST"])
def settings_test_librenms(request):
    """Testa conexão com LibreNMS"""
    try:
        data = json.loads(request.body)
        url = data.get('url', '')
        token = data.get('token', '')
        
        if not url or not token:
            # Usa configurações salvas
            settings_data = load_settings()
            url = url or settings_data.get('librenms_url', '')
            token = token or settings_data.get('librenms_api_token', '')
        
        import requests
        headers = {'X-Auth-Token': token}
        response = requests.get(f"{url.rstrip('/')}/api/v0/system", headers=headers, timeout=10)
        
        if response.status_code == 200:
            return JsonResponse({
                'success': True,
                'message': 'Conexão com LibreNMS estabelecida!'
            })
        else:
            return JsonResponse({
                'success': False,
                'error': f'Erro HTTP {response.status_code}'
            })
    except Exception as e:
        return JsonResponse({
            'success': False,
            'error': str(e)
        })


@csrf_exempt
@require_http_methods(["POST"])
def settings_test_phpipam(request):
    """Testa conexão com phpIPAM"""
    try:
        data = json.loads(request.body)
        settings_data = load_settings()
        
        url = data.get('url') or settings_data.get('phpipam_url', '')
        app_id = data.get('app_id') or settings_data.get('phpipam_app_id', '')
        app_key = data.get('app_key') or settings_data.get('phpipam_app_key', '')
        
        import requests
        headers = {'token': app_key}
        response = requests.get(
            f"{url.rstrip('/')}/api/{app_id}/user/",
            headers=headers,
            timeout=10
        )
        
        if response.status_code == 200:
            return JsonResponse({
                'success': True,
                'message': 'Conexão com phpIPAM estabelecida!'
            })
        else:
            return JsonResponse({
                'success': False,
                'error': f'Erro HTTP {response.status_code}'
            })
    except Exception as e:
        return JsonResponse({
            'success': False,
            'error': str(e)
        })


@csrf_exempt
@require_http_methods(["POST"])
def settings_test_groq(request):
    """Testa conexão com Groq API"""
    try:
        data = json.loads(request.body)
        settings_data = load_settings()
        
        api_key = data.get('api_key') or settings_data.get('groq_api_key', '')
        model = data.get('model') or settings_data.get('groq_model', 'llama-3.3-70b-versatile')
        
        import requests
        headers = {
            'Authorization': f'Bearer {api_key}',
            'Content-Type': 'application/json'
        }
        test_data = {
            'model': model,
            'messages': [{'role': 'user', 'content': 'Hello'}],
            'max_tokens': 5
        }
        
        response = requests.post(
            'https://api.groq.com/openai/v1/chat/completions',
            headers=headers,
            json=test_data,
            timeout=30
        )
        
        if response.status_code == 200:
            return JsonResponse({
                'success': True,
                'message': 'Conexão com Groq API estabelecida!'
            })
        else:
            error_data = response.json() if response.headers.get('content-type', '').startswith('application/json') else {}
            return JsonResponse({
                'success': False,
                'error': error_data.get('error', {}).get('message', f'Erro HTTP {response.status_code}')
            })
    except Exception as e:
        return JsonResponse({
            'success': False,
            'error': str(e)
        })


@csrf_exempt
@require_http_methods(["GET"])
def settings_git_status(request):
    """Retorna status do repositório Git"""
    try:
        # Executa comandos git no diretório do projeto
        base_dir = settings.BASE_DIR
        
        def run_git(args):
            result = subprocess.run(
                ['git'] + args,
                cwd=base_dir,
                capture_output=True,
                text=True,
                timeout=30
            )
            return result.stdout.strip(), result.returncode
        
        # Branch atual
        branch, _ = run_git(['rev-parse', '--abbrev-ref', 'HEAD'])
        
        # Remote URL
        remote, _ = run_git(['config', '--get', 'remote.origin.url'])
        
        # Commits ahead/behind
        ahead_behind, _ = run_git(['rev-list', '--left-right', '--count', 'origin/' + branch + '...' + branch])
        ahead, behind = 0, 0
        if ahead_behind:
            parts = ahead_behind.split()
            if len(parts) == 2:
                behind, ahead = int(parts[0]), int(parts[1])
        
        # Último commit
        last_commit, _ = run_git(['rev-parse', 'HEAD'])
        last_commit_date, _ = run_git(['log', '-1', '--format=%ci'])
        
        # Status de arquivos
        status_output, _ = run_git(['status', '--porcelain'])
        staged = 0
        unstaged = 0
        untracked = 0
        
        for line in status_output.split('\n'):
            if not line:
                continue
            index = line[0]
            work_tree = line[1] if len(line) > 1 else ' '
            
            if index in 'MADRC':
                staged += 1
            elif work_tree in 'MD':
                unstaged += 1
            elif line.startswith('??'):
                untracked += 1
        
        return JsonResponse({
            'success': True,
            'branch': branch,
            'remote': remote,
            'ahead': ahead,
            'behind': behind,
            'last_commit': last_commit,
            'last_commit_date': last_commit_date,
            'staged': staged,
            'unstaged': unstaged,
            'untracked': untracked
        })
    except Exception as e:
        return JsonResponse({
            'success': False,
            'error': str(e)
        })


@csrf_exempt
@require_http_methods(["GET"])
def settings_git_logs(request):
    """Retorna histórico de commits"""
    try:
        base_dir = settings.BASE_DIR
        
        result = subprocess.run(
            ['git', 'log', '--oneline', '-20', '--format=%H|%s|%an|%ci'],
            cwd=base_dir,
            capture_output=True,
            text=True,
            timeout=30
        )
        
        commits = []
        for line in result.stdout.strip().split('\n'):
            if line:
                parts = line.split('|')
                if len(parts) >= 4:
                    commits.append({
                        'hash': parts[0],
                        'message': parts[1],
                        'author': parts[2],
                        'date': parts[3]
                    })
        
        return JsonResponse({
            'success': True,
            'commits': commits
        })
    except Exception as e:
        return JsonResponse({
            'success': False,
            'error': str(e)
        })


@csrf_exempt
@require_http_methods(["POST"])
def settings_git_backup(request):
    """Executa backup para GitHub"""
    try:
        data = json.loads(request.body)
        settings_data = load_settings()
        
        token = data.get('token') or settings_data.get('git_token', '')
        repo_url = data.get('repo_url') or settings_data.get('git_repo_url', '')
        branch = data.get('branch') or settings_data.get('git_branch', 'main')
        
        if not token or not repo_url:
            return JsonResponse({
                'success': False,
                'error': 'Token e URL do repositório são obrigatórios'
            })
        
        base_dir = settings.BASE_DIR
        
        def run_git(args, env=None):
            git_env = os.environ.copy()
            if env:
                git_env.update(env)
            result = subprocess.run(
                ['git'] + args,
                cwd=base_dir,
                capture_output=True,
                text=True,
                timeout=60,
                env=git_env
            )
            return result.stdout.strip(), result.stderr.strip(), result.returncode
        
        # Configura remote com token
        if 'github.com' in repo_url:
            # Parse URL para adicionar token
            if repo_url.startswith('https://'):
                auth_url = repo_url.replace('https://', f'https://{token}@')
            else:
                auth_url = repo_url
            
            # Atualiza remote
            run_git(['remote', 'set-url', 'origin', auth_url])
        
        # Adiciona todos os arquivos
        _, stderr, code = run_git(['add', '-A'])
        if code != 0:
            return JsonResponse({
                'success': False,
                'error': f'Erro no git add: {stderr}'
            })
        
        # Verifica se há mudanças
        status, _, _ = run_git(['status', '--porcelain'])
        if not status:
            return JsonResponse({
                'success': True,
                'message': 'Nenhuma mudança para commit',
                'commit_hash': ''
            })
        
        # Commit
        from datetime import datetime
        commit_message = f"Backup automático LOR-CGR - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
        _, stderr, code = run_git(['commit', '-m', commit_message])
        
        # Push
        _, stderr, code = run_git(['push', 'origin', branch])
        if code != 0:
            return JsonResponse({
                'success': False,
                'error': f'Erro no push: {stderr}'
            })
        
        # Pega hash do commit
        commit_hash, _, _ = run_git(['rev-parse', 'HEAD'])
        
        # Conta arquivos modificados
        files_changed = len(status.split('\n'))
        
        return JsonResponse({
            'success': True,
            'message': 'Backup enviado com sucesso!',
            'commit_hash': commit_hash,
            'files_changed': files_changed
        })
    except Exception as e:
        return JsonResponse({
            'success': False,
            'error': str(e)
        })


@csrf_exempt
@require_http_methods(["POST"])
def settings_git_pull(request):
    """Executa git pull do repositório"""
    try:
        base_dir = settings.BASE_DIR
        settings_data = load_settings()
        
        token = settings_data.get('git_token', '')
        repo_url = settings_data.get('git_repo_url', '')
        branch = settings_data.get('git_branch', 'main')
        
        if 'github.com' in repo_url and token:
            if repo_url.startswith('https://'):
                auth_url = repo_url.replace('https://', f'https://{token}@')
            else:
                auth_url = repo_url
            subprocess.run(
                ['git', 'remote', 'set-url', 'origin', auth_url],
                cwd=base_dir,
                capture_output=True,
                timeout=30
            )
        
        result = subprocess.run(
            ['git', 'pull', 'origin', branch],
            cwd=base_dir,
            capture_output=True,
            text=True,
            timeout=60
        )
        
        if result.returncode == 0:
            return JsonResponse({
                'success': True,
                'message': 'Atualizações baixadas com sucesso!'
            })
        else:
            return JsonResponse({
                'success': False,
                'error': result.stderr or 'Erro no pull'
            })
    except Exception as e:
        return JsonResponse({
            'success': False,
            'error': str(e)
        })


# ============================================
# URLs para adicionar ao urls.py:
# ============================================
"""
from django.urls import path
from . import views

urlpatterns = [
    # ... outras URLs ...
    
    # Settings
    path('api/settings/get/', views.settings_get, name='settings_get'),
    path('api/settings/save/', views.settings_save, name='settings_save'),
    path('api/settings/test/librenms/', views.settings_test_librenms, name='settings_test_librenms'),
    path('api/settings/test/phpipam/', views.settings_test_phpipam, name='settings_test_phpipam'),
    path('api/settings/test/groq/', views.settings_test_groq, name='settings_test_groq'),
    path('api/settings/git/status/', views.settings_git_status, name='settings_git_status'),
    path('api/settings/git/logs/', views.settings_git_logs, name='settings_git_logs'),
    path('api/settings/git/backup/', views.settings_git_backup, name='settings_git_backup'),
    path('api/settings/git/pull/', views.settings_git_pull, name='settings_git_pull'),
]
"""
