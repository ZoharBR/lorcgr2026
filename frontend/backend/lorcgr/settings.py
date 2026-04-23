"""
Configurações do Django - LOR-CGR 2026
======================================
Seguro, flexível e gerenciável via Admin
"""

import os
from pathlib import Path
from dotenv import load_dotenv

# Carregar variáveis de ambiente do arquivo .env
load_dotenv(BASE_DIR / '.env' if 'BASE_DIR' in dir() else Path(__file__).resolve().parent.parent / '.env')

BASE_DIR = Path(__file__).resolve().parent.parent

# ===========================================
# SEGURANÇA BÁSICA
# ===========================================
SECRET_KEY = os.environ.get('DJANGO_SECRET_KEY', 'lorcgr-secret-key-2026-change-in-production')
DEBUG = os.environ.get('DJANGO_DEBUG', 'True') == 'True'

# ALLOWED_HOSTS - Pode ser modificado via Admin (SystemSettings)
# Formato: IP ou domínios separados por vírgula no .env
ALLOWED_HOSTS_ENV = os.environ.get('ALLOWED_HOSTS', '*')
if ALLOWED_HOSTS_ENV == '*':
    ALLOWED_HOSTS = ['*']
else:
    ALLOWED_HOSTS = [host.strip() for host in ALLOWED_HOSTS_ENV.split(',')]

# ===========================================
# APLICAÇÕES INSTALADAS
# ===========================================
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'corsheaders',
    'channels',
    'api',
    'equipments',
]

# ===========================================
# MIDDLEWARE
# ===========================================
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
]

ROOT_URLCONF = 'lorcgr.urls'

# ===========================================
# TEMPLATES
# ===========================================
TEMPLATES = [{
    'BACKEND': 'django.template.backends.django.DjangoTemplates',
    'DIRS': [],
    'APP_DIRS': True,
    'OPTIONS': {
        'context_processors': [
            'django.template.context_processors.debug',
            'django.template.context_processors.request',
            'django.contrib.auth.context_processors.auth',
            'django.contrib.messages.context_processors.messages',
        ],
    },
}]

WSGI_APPLICATION = 'lorcgr.wsgi.application'

# ===========================================
# BANCO DE DADOS - Lendo do .env
# ===========================================
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.environ.get('DB_NAME', 'lorcgr'),
        'USER': os.environ.get('DB_USER', 'lorcgr'),
        'PASSWORD': os.environ.get('DB_PASSWORD', 'Lor#Cgr#2026'),
        'HOST': os.environ.get('DB_HOST', 'localhost'),
        'PORT': os.environ.get('DB_PORT', '5432'),
    }
}

# ===========================================
# ARQUIVOS ESTÁTICOS
# ===========================================
STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# ===========================================
# LOCALIZAÇÃO
# ===========================================
LANGUAGE_CODE = 'pt-br'
TIME_ZONE = 'America/Sao_Paulo'
USE_I18N = True
USE_TZ = True

# ===========================================
# CORS - Configuração de Segurança
# ===========================================
# Opção 1: Ler do .env (recomendado para produção)
CORS_ENV = os.environ.get('CORS_ALLOWED_ORIGINS', '')

if CORS_ENV:
    # Formato: http://localhost:3000,http://45.71.242.131:3000
    CORS_ALLOWED_ORIGINS = [origin.strip() for origin in CORS_ENV.split(',') if origin.strip()]
    CORS_ALLOW_ALL_ORIGINS = False
else:
    # Desenvolvimento: permitir todos (alterar via Admin em produção!)
    CORS_ALLOW_ALL_ORIGINS = True
    CORS_ALLOWED_ORIGINS = []

# Cors settings adicionais
CORS_ALLOW_CREDENTIALS = True
CORS_ALLOW_HEADERS = [
    'accept',
    'accept-encoding',
    'authorization',
    'content-type',
    'dnt',
    'origin',
    'user-agent',
    'x-csrftoken',
    'x-requested-with',
]

# ===========================================
# REST FRAMEWORK
# ===========================================
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework.authentication.SessionAuthentication',
        'rest_framework.authentication.BasicAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticatedOrReadOnly',
    ],
}

# ===========================================
# LOGGING (Para debug e monitoramento)
# ===========================================
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {message}',
            'style': '{',
        },
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'verbose',
        },
    },
    'root': {
        'handlers': ['console'],
        'level': 'INFO',
    },
}
