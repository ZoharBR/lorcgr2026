#!/bin/bash

################################################################################
# LOR-CGR Installation Script - Part 9: Django Backend
################################################################################

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Credenciais
DB_USER="lorcgr"
DB_PASS="Lor#Cgr#2026"

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  LOR-CGR - Instalação do Django${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script deve ser executado como root!${NC}"
   exit 1
fi

#######################################
# Instalar Python e dependências
#######################################
echo -e "${YELLOW}>>> Instalando Python e dependências...${NC}"
apt-get install -y python3 python3-pip python3-venv python3-dev libpq-dev build-essential

#######################################
# Criar ambiente virtual
#######################################
echo -e "${YELLOW}>>> Criando ambiente virtual...${NC}"
mkdir -p /opt/lorcgr/backend
cd /opt/lorcgr/backend

python3 -m venv venv
source venv/bin/activate

#######################################
# Instalar pacotes Python
#######################################
echo -e "${YELLOW}>>> Instalando pacotes Python...${NC}"
pip install --upgrade pip
pip install \
    django \
    djangorestframework \
    django-cors-headers \
    psycopg2-binary \
    channels \
    daphne \
    gunicorn \
    python-dotenv \
    requests \
    paramiko \
    netmiko \
    pysnmp \
    groq

#######################################
# Criar projeto Django
#######################################
echo -e "${YELLOW}>>> Criando projeto Django...${NC}"
cd /opt/lorcgr/backend
django-admin startproject lorcgr .
python manage.py startapp api
python manage.py startapp equipments
python manage.py startapp users
python manage.py startapp backups
python manage.py startapp logs
python manage.py startapp integrations

#######################################
# Criar estrutura de diretórios
#######################################
mkdir -p /opt/lorcgr/backend/integrations
mkdir -p /opt/lorcgr/backend/static
mkdir -p /opt/lorcgr/backend/media
mkdir -p /var/log/lorcgr

#######################################
# Criar settings.py
#######################################
echo -e "${YELLOW}>>> Configurando Django...${NC}"

cat > /opt/lorcgr/backend/lorcgr/settings.py << 'PYEOF'
"""
Django settings for LOR-CGR project.
"""

import os
from pathlib import Path
from dotenv import load_dotenv

# Carregar variáveis de ambiente
load_dotenv('/opt/lorcgr/.env')

BASE_DIR = Path(__file__).resolve().parent.parent

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = os.environ.get('DJANGO_SECRET_KEY', 'django-insecure-change-this-in-production')

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = os.environ.get('DEBUG', 'False').lower() == 'true'

ALLOWED_HOSTS = ['*']

# Application definition
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',

    # Third party
    'rest_framework',
    'corsheaders',
    'channels',

    # Local apps
    'api',
    'equipments',
    'users',
    'backups',
    'logs',
    'integrations',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'lorcgr.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'lorcgr.wsgi.application'
ASGI_APPLICATION = 'lorcgr.asgi.application'

# Database
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

# Redis para Channels
CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels_redis.core.RedisChannelLayer',
        'CONFIG': {
            'hosts': [('127.0.0.1', 6379)],
        },
    },
}

# Password validation
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

# Internationalization
LANGUAGE_CODE = 'pt-br'
TIME_ZONE = 'America/Sao_Paulo'
USE_I18N = True
USE_TZ = True

# Static files
STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
STATICFILES_DIRS = [BASE_DIR / 'static']

MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

# Default primary key field type
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# CORS
CORS_ALLOWED_ORIGINS = [
    'http://localhost:3001',
    'http://127.0.0.1:3001',
]

CORS_ALLOW_ALL_ORIGINS = True

# REST Framework
REST_FRAMEWORK = {
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework.authentication.SessionAuthentication',
        'rest_framework.authentication.BasicAuthentication',
    ],
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 50,
}

# ==========================================
# INTEGRATIONS CONFIGURATION
# ==========================================

# LibreNMS
LIBRENMS_URL = os.environ.get('LIBRENMS_URL', 'http://localhost/librenms/api/v0')
LIBRENMS_TOKEN = os.environ.get('LIBRENMS_TOKEN', '')

# Zabbix
ZABBIX_URL = os.environ.get('ZABBIX_URL', 'http://localhost:8080/api_jsonrpc.php')
ZABBIX_USER = os.environ.get('ZABBIX_USER', 'Admin')
ZABBIX_PASSWORD = os.environ.get('ZABBIX_PASSWORD', 'Lor#Cgr#2026')

# phpIPAM
PHPIPAM_URL = os.environ.get('PHPIPAM_URL', 'http://localhost/phpipam/api')
PHPIPAM_APP_ID = os.environ.get('PHPIPAM_APP_ID', 'lorcgr')
PHPIPAM_KEY = os.environ.get('PHPIPAM_KEY', '')

# Grafana
GRAFANA_URL = os.environ.get('GRAFANA_URL', 'http://localhost:3000')
GRAFANA_USER = os.environ.get('GRAFANA_USER', 'lorcgr')
GRAFANA_PASSWORD = os.environ.get('GRAFANA_PASSWORD', 'Lor#Cgr#2026')
GRAFANA_API_KEY = os.environ.get('GRAFANA_API_KEY', '')

# Nexterm
NEXTERM_URL = os.environ.get('NEXTERM_URL', 'http://localhost:6989')
NEXTERM_ENCRYPTION_KEY = os.environ.get('NEXTERM_ENCRYPTION_KEY', '0e61a0c2072c1c8191ca085d5191269897b5281ab25571f7239dfe5d7e094573')

# GROQ AI
GROQ_API_KEY = os.environ.get('GROQ_API_KEY', '')
GROQ_MODEL = os.environ.get('GROQ_MODEL', 'llama3-70b-8192')

# SNMP
SNMP_COMMUNITY = os.environ.get('SNMP_COMMUNITY', 'lorcgrpublic')
PYEOF

#######################################
# Criar .env
#######################################
echo -e "${YELLOW}>>> Criando arquivo .env...${NC}"
cat > /opt/lorcgr/.env << EOF
# Django
DJANGO_SECRET_KEY=$(python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')
DEBUG=False

# Database
DB_NAME=lorcgr
DB_USER=lorcgr
DB_PASSWORD=Lor#Cgr#2026
DB_HOST=localhost
DB_PORT=5432

# Integrations
LIBRENMS_URL=http://localhost/librenms/api/v0
LIBRENMS_TOKEN=

ZABBIX_URL=http://localhost:8080/api_jsonrpc.php
ZABBIX_USER=Admin
ZABBIX_PASSWORD=Lor#Cgr#2026

PHPIPAM_URL=http://localhost/phpipam/api
PHPIPAM_APP_ID=lorcgr
PHPIPAM_KEY=

GRAFANA_URL=http://localhost:3000
GRAFANA_USER=lorcgr
GRAFANA_PASSWORD=Lor#Cgr#2026

NEXTERM_URL=http://localhost:6989
NEXTERM_ENCRYPTION_KEY=0e61a0c2072c1c8191ca085d5191269897b5281ab25571f7239dfe5d7e094573

# GROQ AI
GROQ_API_KEY=
GROQ_MODEL=llama3-70b-8192
EOF

chmod 600 /opt/lorcgr/.env

#######################################
# Criar models de equipamentos
#######################################
echo -e "${YELLOW}>>> Criando models...${NC}"

cat > /opt/lorcgr/backend/equipments/models.py << 'PYEOF'
from django.db import models
from django.contrib.auth.models import User

class Vendor(models.Model):
    """Fabricante de equipamentos"""
    name = models.CharField(max_length=100, unique=True)
    slug = models.SlugField(max_length=100, unique=True)
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name

class EquipmentType(models.Model):
    """Tipo de equipamento"""
    name = models.CharField(max_length=100)
    slug = models.SlugField(max_length=100, unique=True)
    description = models.TextField(blank=True)
    icon = models.CharField(max_length=50, default='server')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name

class Equipment(models.Model):
    """Equipamento de rede"""
    STATUS_CHOICES = [
        ('active', 'Ativo'),
        ('inactive', 'Inativo'),
        ('maintenance', 'Em Manutenção'),
        ('unknown', 'Desconhecido'),
    ]

    PROTOCOL_CHOICES = [
        ('ssh', 'SSH'),
        ('telnet', 'Telnet'),
        ('snmp', 'SNMP'),
        ('api', 'API'),
    ]

    # Identificação
    name = models.CharField(max_length=200)
    hostname = models.CharField(max_length=200, blank=True)

    # Classificação
    vendor = models.ForeignKey(Vendor, on_delete=models.SET_NULL, null=True, blank=True)
    equipment_type = models.ForeignKey(EquipmentType, on_delete=models.SET_NULL, null=True, blank=True)
    model = models.CharField(max_length=200, blank=True)
    os_version = models.CharField(max_length=100, blank=True)
    serial_number = models.CharField(max_length=100, blank=True)

    # Conectividade
    ip_address = models.GenericIPAddressField()
    mac_address = models.CharField(max_length=17, blank=True)
    port = models.IntegerField(default=22)
    protocol = models.CharField(max_length=10, choices=PROTOCOL_CHOICES, default='ssh')

    # SNMP
    snmp_community = models.CharField(max_length=100, default='public')
    snmp_version = models.CharField(max_length=5, default='2c')

    # Credenciais (criptografadas)
    username = models.CharField(max_length=100, blank=True)
    password = models.TextField(blank=True)  # Criptografado
    enable_password = models.TextField(blank=True)  # Criptografado

    # Localização
    location = models.CharField(max_length=200, blank=True)
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    rack = models.CharField(max_length=50, blank=True)
    position = models.IntegerField(null=True, blank=True)

    # Status
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='unknown')
    last_seen = models.DateTimeField(null=True, blank=True)

    # Integrações
    librenms_id = models.IntegerField(null=True, blank=True)
    zabbix_id = models.IntegerField(null=True, blank=True)
    phpipam_id = models.IntegerField(null=True, blank=True)

    # Metadados
    description = models.TextField(blank=True)
    notes = models.TextField(blank=True)
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return f"{self.name} ({self.ip_address})"

class EquipmentGroup(models.Model):
    """Grupo de equipamentos"""
    name = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    equipments = models.ManyToManyField(Equipment, related_name='groups')
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name

class EquipmentBackup(models.Model):
    """Backup de configuração de equipamento"""
    equipment = models.ForeignKey(Equipment, on_delete=models.CASCADE, related_name='backups')
    config_text = models.TextField()
    backup_type = models.CharField(max_length=20, default='manual')
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    file_path = models.CharField(max_length=500, blank=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Backup de {self.equipment.name} - {self.created_at}"
PYEOF

#######################################
# Criar serializers
#######################################
mkdir -p /opt/lorcgr/backend/equipments

cat > /opt/lorcgr/backend/equipments/serializers.py << 'PYEOF'
from rest_framework import serializers
from .models import Vendor, EquipmentType, Equipment, EquipmentGroup, EquipmentBackup

class VendorSerializer(serializers.ModelSerializer):
    class Meta:
        model = Vendor
        fields = '__all__'

class EquipmentTypeSerializer(serializers.ModelSerializer):
    class Meta:
        model = EquipmentType
        fields = '__all__'

class EquipmentSerializer(serializers.ModelSerializer):
    vendor_name = serializers.CharField(source='vendor.name', read_only=True)
    type_name = serializers.CharField(source='equipment_type.name', read_only=True)

    class Meta:
        model = Equipment
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at', 'last_seen']

class EquipmentListSerializer(serializers.ModelSerializer):
    vendor_name = serializers.CharField(source='vendor.name', read_only=True)
    type_name = serializers.CharField(source='equipment_type.name', read_only=True)

    class Meta:
        model = Equipment
        fields = ['id', 'name', 'ip_address', 'vendor_name', 'type_name', 'status', 'location']

class EquipmentGroupSerializer(serializers.ModelSerializer):
    equipment_count = serializers.SerializerMethodField()

    class Meta:
        model = EquipmentGroup
        fields = '__all__'

    def get_equipment_count(self, obj):
        return obj.equipments.count()

class EquipmentBackupSerializer(serializers.ModelSerializer):
    equipment_name = serializers.CharField(source='equipment.name', read_only=True)

    class Meta:
        model = EquipmentBackup
        fields = '__all__'
        read_only_fields = ['created_at']
PYEOF

#######################################
# Criar views
#######################################
cat > /opt/lorcgr/backend/equipments/views.py << 'PYEOF'
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django.shortcuts import get_object_or_404

from .models import Vendor, EquipmentType, Equipment, EquipmentGroup, EquipmentBackup
from .serializers import (
    VendorSerializer, EquipmentTypeSerializer, EquipmentSerializer,
    EquipmentListSerializer, EquipmentGroupSerializer, EquipmentBackupSerializer
)

class VendorViewSet(viewsets.ModelViewSet):
    queryset = Vendor.objects.all()
    serializer_class = VendorSerializer

class EquipmentTypeViewSet(viewsets.ModelViewSet):
    queryset = EquipmentType.objects.all()
    serializer_class = EquipmentTypeSerializer

class EquipmentViewSet(viewsets.ModelViewSet):
    queryset = Equipment.objects.all()

    def get_serializer_class(self):
        if self.action == 'list':
            return EquipmentListSerializer
        return EquipmentSerializer

    @action(detail=True, methods=['post'])
    def backup(self, request, pk=None):
        """Executa backup do equipamento"""
        equipment = self.get_object()
        # TODO: Implementar backup real
        return Response({'message': f'Backup iniciado para {equipment.name}'})

    @action(detail=True, methods=['post'])
    def sync(self, request, pk=None):
        """Sincroniza com LibreNMS/Zabbix"""
        equipment = self.get_object()
        # TODO: Implementar sincronização
        return Response({'message': f'Sincronização iniciada para {equipment.name}'})

    @action(detail=True, methods=['get'])
    def status(self, request, pk=None):
        """Retorna status atual do equipamento"""
        equipment = self.get_object()
        return Response({
            'id': equipment.id,
            'name': equipment.name,
            'status': equipment.status,
            'last_seen': equipment.last_seen
        })

class EquipmentGroupViewSet(viewsets.ModelViewSet):
    queryset = EquipmentGroup.objects.all()
    serializer_class = EquipmentGroupSerializer

class EquipmentBackupViewSet(viewsets.ModelViewSet):
    queryset = EquipmentBackup.objects.all()
    serializer_class = EquipmentBackupSerializer

    def get_queryset(self):
        queryset = super().get_queryset()
        equipment_id = self.request.query_params.get('equipment')
        if equipment_id:
            queryset = queryset.filter(equipment_id=equipment_id)
        return queryset
PYEOF

#######################################
# Criar URLs
#######################################
cat > /opt/lorcgr/backend/equipments/urls.py << 'PYEOF'
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import VendorViewSet, EquipmentTypeViewSet, EquipmentViewSet, EquipmentGroupViewSet, EquipmentBackupViewSet

router = DefaultRouter()
router.register(r'vendors', VendorViewSet)
router.register(r'types', EquipmentTypeViewSet)
router.register(r'list', EquipmentViewSet)
router.register(r'groups', EquipmentGroupViewSet)
router.register(r'backups', EquipmentBackupViewSet)

urlpatterns = [
    path('', include(router.urls)),
]
PYEOF

#######################################
# Configurar URLs principal
#######################################
cat > /opt/lorcgr/backend/lorcgr/urls.py << 'PYEOF'
from django.contrib import admin
from django.urls import path, include
from rest_framework.routers import DefaultRouter

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/equipment/', include('equipments.urls')),
    path('api/', include('api.urls')),
]
PYEOF

#######################################
# Executar migrações
#######################################
echo -e "${YELLOW}>>> Executando migrações...${NC}"
cd /opt/lorcgr/backend
source venv/bin/activate
python manage.py makemigrations
python manage.py migrate

#######################################
# Criar superusuário
#######################################
echo -e "${YELLOW}>>> Criando superusuário...${NC}"
python manage.py shell << 'DJSHELL'
from django.contrib.auth.models import User
if not User.objects.filter(username='lorcgr').exists():
    User.objects.create_superuser('lorcgr', 'admin@lorcgr.local', 'Lor#Cgr#2026')
    print('Superusuário criado!')
else:
    print('Superusuário já existe!')
DJSHELL

#######################################
# Criar vendors iniciais
#######################################
echo -e "${YELLOW}>>> Criando vendors iniciais...${NC}"
python manage.py shell << 'DJSHELL'
from equipments.models import Vendor, EquipmentType

vendors = [
    ('Juniper', 'juniper'),
    ('Huawei', 'huawei'),
    ('Cisco', 'cisco'),
    ('Mikrotik', 'mikrotik'),
    ('Ubiquiti', 'ubiquiti'),
    ('FiberHome', 'fiberhome'),
    ('Dell', 'dell'),
    ('HP/HPE', 'hp'),
    ('ZTE', 'zte'),
    ('Nokia', 'nokia'),
]

for name, slug in vendors:
    Vendor.objects.get_or_create(slug=slug, defaults={'name': name})

types = [
    ('Switch', 'switch', 'network-wired'),
    ('Router', 'router', 'router'),
    ('Firewall', 'firewall', 'shield'),
    ('OLT', 'olt', 'server'),
    ('ONU', 'onu', 'monitor'),
    ('Server', 'server', 'server'),
    ('Access Point', 'ap', 'wifi'),
    ('Load Balancer', 'loadbalancer', 'balance-scale'),
    ('Storage', 'storage', 'database'),
]

for name, slug, icon in types:
    EquipmentType.objects.get_or_create(slug=slug, defaults={'name': name, 'icon': icon})

print('Vendors e tipos criados!')
DJSHELL

#######################################
# Coletar estáticos
#######################################
echo -e "${YELLOW}>>> Coletando arquivos estáticos...${NC}"
python manage.py collectstatic --noinput

#######################################
# Criar serviços systemd
#######################################
echo -e "${YELLOW}>>> Criando serviços systemd...${NC}"

# Gunicorn
cat > /etc/systemd/system/lorcgr-api.service << 'EOF'
[Unit]
Description=LOR-CGR Django API
After=network.target postgresql.service redis.service

[Service]
Type=notify
User=lorcgr
Group=lorcgr
WorkingDirectory=/opt/lorcgr/backend
Environment="PATH=/opt/lorcgr/backend/venv/bin"
Environment="DJANGO_SETTINGS_MODULE=lorcgr.settings"
ExecStart=/opt/lorcgr/backend/venv/bin/gunicorn \
    --workers 3 \
    --threads 2 \
    --bind 127.0.0.1:8000 \
    --timeout 120 \
    --access-logfile /var/log/lorcgr/api_access.log \
    --error-logfile /var/log/lorcgr/api_error.log \
    --log-level info \
    lorcgr.wsgi:application
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Daphne (WebSocket)
cat > /etc/systemd/system/lorcgr-ws.service << 'EOF'
[Unit]
Description=LOR-CGR WebSocket Server
After=network.target redis.service

[Service]
Type=simple
User=lorcgr
Group=lorcgr
WorkingDirectory=/opt/lorcgr/backend
Environment="PATH=/opt/lorcgr/backend/venv/bin"
ExecStart=/opt/lorcgr/backend/venv/bin/daphne \
    --bind 127.0.0.1 \
    --port 8001 \
    --access-log /var/log/lorcgr/ws_access.log \
    lorcgr.asgi:application
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Ajustar permissões
chown -R lorcgr:lorcgr /opt/lorcgr
chown -R lorcgr:lorcgr /var/log/lorcgr

systemctl daemon-reload
systemctl enable lorcgr-api lorcgr-ws
systemctl start lorcgr-api lorcgr-ws

#######################################
# Verificar status
#######################################
echo -e "${YELLOW}>>> Verificando status...${NC}"
sleep 3

if systemctl is-active --quiet lorcgr-api; then
    echo -e "${GREEN}✓ Django API está rodando${NC}"
else
    echo -e "${RED}✗ Django API não está rodando${NC}"
    journalctl -u lorcgr-api --no-pager -n 20
fi

if systemctl is-active --quiet lorcgr-ws; then
    echo -e "${GREEN}✓ WebSocket está rodando${NC}"
else
    echo -e "${RED}✗ WebSocket não está rodando${NC}"
fi

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  Django instalado com sucesso!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "API: http://localhost:8000/api/"
echo "Admin: http://localhost:8000/admin/"
echo "WebSocket: ws://localhost:8001/ws/"
echo ""
echo "Usuário: lorcgr"
echo "Senha: Lor#Cgr#2026"
echo ""
echo "Próximo passo: Execute o script 10-install-nextjs.sh"
