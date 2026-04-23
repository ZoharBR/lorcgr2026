# Manual de Instalação - LOR-CGR

## Índice

1. [Reset do Servidor Ubuntu](#1-reset-do-servidor-ubuntu)
2. [Instalação do PostgreSQL](#2-instalação-do-postgresql)
3. [Instalação do LibreNMS](#3-instalação-do-librenms)
4. [Instalação do phpIPAM](#4-instalação-do-phpipam)
5. [Instalação do Zabbix](#5-instalação-do-zabbix)
6. [Instalação do Grafana](#6-instalação-do-grafana)
7. [Instalação do Nexterm](#7-instalação-do-nexterm)
8. [Instalação do Django Backend](#8-instalação-do-django-backend)
9. [Instalação do Next.js Frontend](#9-instalação-do-nextjs-frontend)
10. [Configuração do Nginx](#10-configuração-do-nginx)
11. [Configuração de Integrações](#11-configuração-de-integrações)
12. [Primeiro Acesso](#12-primeiro-acesso)

---

## Informações do Servidor

- **IP**: 45.71.242.131
- **Sistema**: Ubuntu Server 24.04 LTS
- **Credenciais Padrão**:
  - Usuário: `lorcgr`
  - Senha: `Lor#Cgr#2026`

---

## 1. Reset do Servidor Ubuntu

### 1.1 Backup de Dados Importantes (SE NECESSÁRIO)

```bash
# Fazer backup antes de resetar (se houver dados importantes)
# Conectar ao servidor
ssh root@45.71.242.131

# Backup de bancos de dados
pg_dumpall -U postgres > /tmp/pg_backup_all.sql

# Backup de configurações
tar -czvf /tmp/configs_backup.tar.gz /etc/nginx /opt/lorcgr /etc/zabbix

# Transferir para máquina local
scp root@45.71.242.131:/tmp/*.sql /tmp/*.tar.gz ~/backups/
```

### 1.2 Reset Completo do Servidor

**OPÇÃO A: Via Provider (Recomendado)**

Se o servidor está em um provedor de cloud (DigitalOcean, Vultr, Hetzner, etc.):
1. Acesse o painel do provedor
2. Vá até a instância do servidor
3. Procure por "Rebuild" ou "Reset"
4. Selecione Ubuntu Server 24.04 LTS
5. Confirme a reinstalação

**OPÇÃO B: Reset Manual**

```bash
# Conectar como root
ssh root@45.71.242.131

# ATENÇÃO: Isso remove TODOS os pacotes instalados
# NÃO EXECUTE via SSH - use console do provider

# Parar todos os serviços
systemctl stop nginx postgresql redis-server zabbix-server

# Remover pacotes instalados
apt-get remove --purge -y nginx nginx-common postgresql* redis* zabbix* librenms* phpipam* grafana* docker* containerd*
apt-get autoremove --purge -y

# Remover configurações e dados
rm -rf /opt/librenms /opt/phpipam /opt/lorcgr /var/lib/zabbix /var/lib/grafana /var/lib/postgresql

# Limpar configurações
rm -rf /etc/nginx /etc/zabbix /etc/grafana /etc/phpipam

# Reiniciar para garantir estado limpo
reboot
```

### 1.3 Pós-Reset - Atualização Inicial

```bash
# Conectar após reset
ssh root@45.71.242.131

# Atualizar sistema
apt-get update && apt-get upgrade -y

# Instalar pacotes essenciais
apt-get install -y curl wget git vim htop net-tools dnsutils unzip software-properties-common apt-transport-https ca-certificates gnupg lsb-release

# Configurar timezone
timedatectl set-timezone America/Sao_Paulo

# Criar usuário lorcgr (se não existir)
useradd -m -s /bin/bash lorcgr
echo "lorcgr:Lor#Cgr#2026" | chpasswd
usermod -aG sudo lorcgr

# Configurar SSH (opcional - segurança)
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd
```

---

## 2. Instalação do PostgreSQL

### 2.1 Instalar PostgreSQL

```bash
# Instalar PostgreSQL
apt-get install -y postgresql postgresql-contrib

# Iniciar e habilitar
systemctl start postgresql
systemctl enable postgresql
```

### 2.2 Configurar Usuário e Bancos

```bash
# Acessar PostgreSQL
sudo -u postgres psql

# Criar usuário lorcgr com senha
CREATE USER lorcgr WITH SUPERUSER CREATEDB CREATEROLE PASSWORD 'Lor#Cgr#2026';

# Criar banco principal LOR-CGR
CREATE DATABASE lorcgr OWNER lorcgr;

# Criar bancos para cada aplicação (opcional - alguns apps usam banco próprio)
CREATE DATABASE librenms OWNER lorcgr;
CREATE DATABASE phpipam OWNER lorcgr;
CREATE DATABASE zabbix OWNER lorcgr;
CREATE DATABASE grafana OWNER lorcgr;

# Sair
\q
```

### 2.3 Configurar Acesso

```bash
# Editar pg_hba.conf
vim /etc/postgresql/16/main/pg_hba.conf

# Adicionar linha para permitir conexões locais com senha
# local   all             all                                     md5
# host    all             all             127.0.0.1/32            md5

# Reiniciar PostgreSQL
systemctl restart postgresql
```

### 2.4 Verificar Conexão

```bash
# Testar conexão
psql -h localhost -U lorcgr -d lorcgr -W
# Senha: Lor#Cgr#2026

# Se conectar, está funcionando
\q
```

---

## 3. Instalação do LibreNMS

### 3.1 Instalar Dependências

```bash
# Instalar dependências
apt-get install -y acl curl fping git graphviz imagemagick mariadb-client mtr-tiny nginx-full nmap python3-dotenv python3-pip python3-pymysql python3-redis python3-setuptools python3-systemd python3-virtualenv rrdtool snmp snmpd whois unzip python3-venv python3-mysqldb

# Instalar PHP e extensões
apt-get install -y php php-cli php-curl php-fpm php-gd php-gmp php-intl php-json php-mbstring php-mysql php-xml php-zip php-ldap
```

### 3.2 Criar Usuário LibreNMS

```bash
# Criar usuário
useradd librenms -d /opt/librenms -M -r -s /bin/bash

# Criar diretório
mkdir /opt/librenms
chown librenms:librenms /opt/librenms
```

### 3.3 Baixar LibreNMS

```bash
# Clonar repositório
cd /opt
git clone https://github.com/librenms/librenms.git librenms

# Ajustar permissões
chown -R librenms:librenms /opt/librenms
chmod 770 /opt/librenms
setfacl -d -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
setfacl -R -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
```

### 3.4 Configurar Banco de Dados (MySQL/MariaDB)

```bash
# Instalar MariaDB
apt-get install -y mariadb-server mariadb-client

# Configurar MariaDB
mysql -u root

# No MySQL:
CREATE DATABASE librenms CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'lorcgr'@'localhost' IDENTIFIED BY 'Lor#Cgr#2026';
GRANT ALL PRIVILEGES ON librenms.* TO 'lorcgr'@'localhost';
FLUSH PRIVILEGES;
EXIT;

# Reiniciar MariaDB
systemctl restart mariadb
systemctl enable mariadb
```

### 3.5 Configurar LibreNMS

```bash
# Copiar configuração
cd /opt/librenms
cp .env.example .env

# Editar configuração
vim /opt/librenms/.env

# Configurar:
DB_HOST=localhost
DB_DATABASE=librenms
DB_USERNAME=lorcgr
DB_PASSWORD=Lor#Cgr#2026

# Instalar dependências PHP
su - librenms
./scripts/composer_wrapper.php install --no-dev
exit

# Gerar chave da aplicação
su - librenms
php artisan key:generate
exit

# Criar banco
su - librenms
php artisan migrate
exit
```

### 3.6 Criar Usuário Admin

```bash
su - librenms
php artisan user:add
# Nome: Admin
# Email: admin@lorcgr.local
# Senha: Lor#Cgr#2026
# Role: admin
exit
```

### 3.7 Configurar PHP-FPM

```bash
# Copiar configuração
cp /opt/librenms/misc/librenms.service /etc/systemd/system/
cp /opt/librenms/misc/librenms-scheduler.service /etc/systemd/system/
cp /opt/librenms/misc/librenms-scheduler.timer /etc/systemd/system/

# Habilitar serviços
systemctl enable librenms
systemctl enable librenms-scheduler.timer
systemctl start librenms
systemctl start librenms-scheduler.timer
```

---

## 4. Instalação do phpIPAM

### 4.1 Instalar Dependências

```bash
# Dependências já instaladas com LibreNMS
# Verificar PHP
php -v
```

### 4.2 Baixar phpIPAM

```bash
cd /opt
git clone https://github.com/phpipam/phpipam.git phpipam
cd phpipam
```

### 4.3 Configurar Banco de Dados

```bash
# Criar banco para phpIPAM
mysql -u root -e "CREATE DATABASE phpipam CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -u root -e "GRANT ALL PRIVILEGES ON phpipam.* TO 'lorcgr'@'localhost' IDENTIFIED BY 'Lor#Cgr#2026';"
mysql -u root -e "FLUSH PRIVILEGES;"
```

### 4.4 Configurar phpIPAM

```bash
cd /opt/phpipam
cp config.dist.php config.php

# Editar config.php
vim config.php

# Configurar:
$db['host'] = 'localhost';
$db['user'] = 'lorcgr';
$db['pass'] = 'Lor#Cgr#2026';
$db['name'] = 'phpipam';
```

### 4.5 Configurar Permissões

```bash
chown -R www-data:www-data /opt/phpipam
chmod -R 755 /opt/phpipam
```

---

## 5. Instalação do Zabbix

### 5.1 Adicionar Repositório Zabbix

```bash
# Baixar e instalar repositório
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-2+ubuntu24.04_all.deb
dpkg -i zabbix-release_7.0-2+ubuntu24.04_all.deb
apt-get update
```

### 5.2 Instalar Zabbix Server + Frontend

```bash
# Instalar Zabbix com MySQL
apt-get install -y zabbix-server-mysql zabbix-frontend-php zabbix-nginx-conf zabbix-sql-scripts zabbix-agent

# Ou com PostgreSQL
apt-get install -y zabbix-server-pgsql zabbix-frontend-php zabbix-nginx-conf zabbix-sql-scripts zabbix-agent
```

### 5.3 Configurar Banco de Dados

```bash
# Com MySQL
mysql -uroot -e "create database zabbix character set utf8mb4 collate utf8mb4_bin;"
mysql -uroot -e "create user lorcgr@localhost identified by 'Lor#Cgr#2026';"
mysql -uroot -e "grant all privileges on zabbix.* to lorcgr@localhost;"
mysql -uroot -e "set global log_bin_trust_function_creators = 1;"

# Importar schema
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -D zabbix -ulorcgr -p'Lor#Cgr#2026'

# Desabilitar log_bin_trust_function_creators
mysql -uroot -e "set global log_bin_trust_function_creators = 0;"
```

### 5.4 Configurar Zabbix Server

```bash
# Editar configuração
vim /etc/zabbix/zabbix_server.conf

# Configurar:
DBHost=localhost
DBName=zabbix
DBUser=lorcgr
DBPassword=Lor#Cgr#2026
```

### 5.5 Configurar PHP Frontend

```bash
# Editar configuração Nginx do Zabbix
vim /etc/zabbix/nginx.conf

# Descomentar e configurar:
listen 8080;
server_name zabbix.lorcgr.local;

# Configurar PHP
vim /etc/zabbix/web/zabbix.conf.php

$DB['TYPE']     = 'MYSQL';
$DB['SERVER']   = 'localhost';
$DB['PORT']     = '0';
$DB['DATABASE'] = 'zabbix';
$DB['USER']     = 'lorcgr';
$DB['PASSWORD'] = 'Lor#Cgr#2026';
```

### 5.6 Iniciar Serviços

```bash
systemctl restart zabbix-server zabbix-agent nginx php8.3-fpm
systemctl enable zabbix-server zabbix-agent
```

---

## 6. Instalação do Grafana

### 6.1 Adicionar Repositório

```bash
# Adicionar chave GPG
wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key

# Adicionar repositório
echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

apt-get update
```

### 6.2 Instalar Grafana

```bash
apt-get install -y grafana

# Iniciar e habilitar
systemctl daemon-reload
systemctl start grafana-server
systemctl enable grafana-server
```

### 6.3 Configurar Grafana

```bash
# Editar configuração
vim /etc/grafana/grafana.ini

# Configurar:
[database]
type = postgres
host = localhost:5432
name = grafana
user = lorcgr
password = Lor#Cgr#2026

[security]
admin_user = lorcgr
admin_password = Lor#Cgr#2026

[server]
http_port = 3000
domain = lorcgr.local
root_url = http://lorcgr.local/grafana/

# Reiniciar
systemctl restart grafana-server
```

---

## 7. Instalação do Nexterm

### 7.1 Instalar Docker

```bash
# Instalar Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Adicionar usuário ao grupo docker
usermod -aG docker lorcgr
```

### 7.2 Executar Nexterm

```bash
# Criar diretório para dados
mkdir -p /opt/nexterm/data

# Executar container
docker run -d \
  --name nexterm \
  -p 6989:6989 \
  -v /opt/nexterm/data:/app/data \
  -e ENCRYPTION_KEY=0e61a0c2072c1c8191ca085d5191269897b5281ab25571f7239dfe5d7e094573 \
  --restart unless-stopped \
  germannewsmaker/nexterm

# Verificar status
docker ps | grep nexterm
```

### 7.3 Configurar Nexterm

```bash
# Acessar via navegador: http://45.71.242.131:6989
# Criar primeiro usuário:
# Usuário: lorcgr
# Senha: Lor#Cgr#2026
```

---

## 8. Instalação do Django Backend

### 8.1 Preparar Ambiente

```bash
# Criar diretório
mkdir -p /opt/lorcgr
cd /opt/lorcgr

# Criar ambiente virtual
python3 -m venv venv
source venv/bin/activate

# Instalar dependências
pip install django djangorestframework django-cors-headers psycopg2-binary channels daphne gunicorn
```

### 8.2 Criar Projeto Django

```bash
django-admin startproject lorcgr_backend .
python manage.py startapp api
python manage.py startapp equipments
python manage.py startapp users
python manage.py startapp backups
python manage.py startapp logs
```

### 8.3 Configurar settings.py

```python
# /opt/lorcgr/lorcgr_backend/settings.py

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
    'users',
    'backups',
    'logs',
]

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'lorcgr',
        'USER': 'lorcgr',
        'PASSWORD': 'Lor#Cgr#2026',
        'HOST': 'localhost',
        'PORT': '5432',
    }
}

CORS_ALLOWED_ORIGINS = [
    "http://localhost:3001",
    "http://45.71.242.131",
    "http://lorcgr.local",
]

# LibreNMS API
LIBRENMS_URL = 'http://localhost/librenms/api/v0'
LIBRENMS_TOKEN = 'SEU_TOKEN_AQUI'

# Zabbix API
ZABBIX_URL = 'http://localhost:8080/api_jsonrpc.php'
ZABBIX_USER = 'lorcgr'
ZABBIX_PASSWORD = 'Lor#Cgr#2026'

# phpIPAM API
PHPIPAM_URL = 'http://localhost/phpipam/api'
PHPIPAM_APP_ID = 'lorcgr'
PHPIPAM_KEY = 'SUA_KEY_AQUI'

# Grafana API
GRAFANA_URL = 'http://localhost:3000'
GRAFANA_USER = 'lorcgr'
GRAFANA_PASSWORD = 'Lor#Cgr#2026'

# GROQ AI
GROQ_API_KEY = 'SUA_GROQ_KEY_AQUI'
GROQ_MODEL = 'llama3-70b-8192'

# Nexterm
NEXTERM_URL = 'http://localhost:6989'
NEXTERM_ENCRYPTION_KEY = '0e61a0c2072c1c8191ca085d5191269897b5281ab25571f7239dfe5d7e094573'
```

### 8.4 Executar Migrações

```bash
cd /opt/lorcgr
source venv/bin/activate
python manage.py migrate
python manage.py createsuperuser
# Usuário: lorcgr
# Senha: Lor#Cgr#2026
```

### 8.5 Configurar Serviço Systemd

```bash
# Criar serviço Gunicorn
cat > /etc/systemd/system/lorcgr-api.service << 'EOF'
[Unit]
Description=LOR-CGR Django API
After=network.target postgresql.service

[Service]
Type=notify
User=lorcgr
Group=lorcgr
WorkingDirectory=/opt/lorcgr
Environment="PATH=/opt/lorcgr/venv/bin"
ExecStart=/opt/lorcgr/venv/bin/gunicorn \
    --workers 3 \
    --bind 127.0.0.1:8000 \
    --timeout 120 \
    --access-logfile /var/log/lorcgr/access.log \
    --error-logfile /var/log/lorcgr/error.log \
    lorcgr_backend.wsgi:application
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Criar diretório de logs
mkdir -p /var/log/lorcgr
chown lorcgr:lorcgr /var/log/lorcgr

# Habilitar e iniciar
systemctl daemon-reload
systemctl enable lorcgr-api
systemctl start lorcgr-api
```

---

## 9. Instalação do Next.js Frontend

### 9.1 Instalar Node.js

```bash
# Instalar Node.js 20 LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Verificar versão
node --version
npm --version
```

### 9.2 Criar Projeto

```bash
# Criar projeto
cd /opt/lorcgr
npx create-next-app@latest frontend --typescript --tailwind --eslint --app --src-dir

# Configurações:
# - TypeScript: Yes
# - ESLint: Yes
# - Tailwind CSS: Yes
# - src/ directory: Yes
# - App Router: Yes
# - Import alias: @/*
```

### 9.3 Instalar Dependências

```bash
cd /opt/lorcgr/frontend
npm install axios react-query lucide-react recharts @tanstack/react-table date-fns
npm install -D @types/node
```

### 9.4 Build e Deploy

```bash
# Build de produção
npm run build

# Criar serviço systemd
cat > /etc/systemd/system/lorcgr-frontend.service << 'EOF'
[Unit]
Description=LOR-CGR Next.js Frontend
After=network.target

[Service]
Type=simple
User=lorcgr
WorkingDirectory=/opt/lorcgr/frontend
Environment="NODE_ENV=production"
ExecStart=/usr/bin/node /opt/lorcgr/frontend/.next/standalone/server.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable lorcgr-frontend
systemctl start lorcgr-frontend
```

---

## 10. Configuração do Nginx

### 10.1 Configuração Principal

```nginx
# /etc/nginx/sites-available/lorcgr

server {
    listen 80;
    server_name 45.71.242.131 lorcgr.local;

    # LOR-CGR Frontend
    location / {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # Django API
    location /api/ {
        proxy_pass http://127.0.0.1:8000/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300;
    }

    # WebSocket
    location /ws/ {
        proxy_pass http://127.0.0.1:8001/ws/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }

    # Grafana
    location /grafana/ {
        proxy_pass http://127.0.0.1:3000/;
        proxy_set_header Host $host;
    }

    # LibreNMS
    location /librenms/ {
        alias /opt/librenms/public/;
        index index.php;
        try_files $uri $uri/ /librenms/index.php?$query_string;
        
        location ~ \.php {
            include fastcgi.conf;
            fastcgi_param SCRIPT_FILENAME $request_filename;
            fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        }
    }

    # phpIPAM
    location /phpipam/ {
        alias /opt/phpipam/;
        index index.php;
        try_files $uri $uri/ /phpipam/index.php?$query_string;
        
        location ~ \.php {
            include fastcgi.conf;
            fastcgi_param SCRIPT_FILENAME $request_filename;
            fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        }
    }

    # Zabbix
    location /zabbix/ {
        alias /usr/share/zabbix/;
        index index.php;
        try_files $uri $uri/ /zabbix/index.php?$query_string;
        
        location ~ \.php {
            include fastcgi.conf;
            fastcgi_param SCRIPT_FILENAME $request_filename;
            fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        }
    }

    # Nexterm
    location /nexterm/ {
        proxy_pass http://127.0.0.1:6989/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }
}
```

### 10.2 Ativar Configuração

```bash
# Remover default
rm /etc/nginx/sites-enabled/default

# Criar link
ln -s /etc/nginx/sites-available/lorcgr /etc/nginx/sites-enabled/

# Testar configuração
nginx -t

# Reiniciar Nginx
systemctl restart nginx
systemctl enable nginx
```

---

## 11. Configuração de Integrações

### 11.1 LibreNMS API Token

```bash
# Acessar LibreNMS como admin
# Settings > API > Create API Token

# Adicionar ao settings.py do Django:
LIBRENMS_TOKEN = 'seu_token_aqui'
```

### 11.2 Zabbix API

```bash
# Usar credenciais configuradas:
ZABBIX_USER = 'lorcgr'
ZABBIX_PASSWORD = 'Lor#Cgr#2026'
```

### 11.3 phpIPAM API

```bash
# Criar API App no phpIPAM:
# Administration > API > Create API App

# App ID: lorcgr
# App Code: gerar código
```

### 11.4 Grafana API

```bash
# Usar credenciais admin:
GRAFANA_USER = 'lorcgr'
GRAFANA_PASSWORD = 'Lor#Cgr#2026'
```

### 11.5 GROQ AI

```bash
# Obter API Key em: https://console.groq.com/
# Plano gratuito com limites generosos

GROQ_API_KEY = 'sua_key_aqui'
```

---

## 12. Primeiro Acesso

### 12.1 URLs de Acesso

| Serviço | URL |
|---------|-----|
| LOR-CGR | http://45.71.242.131 |
| LibreNMS | http://45.71.242.131/librenms |
| phpIPAM | http://45.71.242.131/phpipam |
| Zabbix | http://45.71.242.131/zabbix |
| Grafana | http://45.71.242.131/grafana |
| Nexterm | http://45.71.242.131/nexterm |

### 12.2 Credenciais

Todas as aplicações utilizam:
- **Usuário**: `lorcgr`
- **Senha**: `Lor#Cgr#2026`

---

## Troubleshooting

### Verificar Status dos Serviços

```bash
# Verificar todos os serviços
systemctl status nginx postgresql mariadb
systemctl status lorcgr-api lorcgr-frontend
systemctl status librenms zabbix-server grafana-server
docker ps | grep nexterm

# Verificar portas
ss -tlnp | grep -E ':(80|443|3000|3001|5432|3306|8000|6989|8080)'
```

### Verificar Logs

```bash
# Logs do LOR-CGR
tail -f /var/log/lorcgr/error.log
tail -f /var/log/nginx/error.log

# Logs do PostgreSQL
tail -f /var/log/postgresql/postgresql-16-main.log

# Logs do Zabbix
tail -f /var/log/zabbix/zabbix_server.log

# Logs do Grafana
journalctl -u grafana-server -f

# Logs do Nexterm
docker logs nexterm -f
```

---

**Documento em construção - Atualizado conforme instalação**
