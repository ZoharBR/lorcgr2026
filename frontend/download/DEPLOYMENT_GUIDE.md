# LOR-CGR Deployment Guide

## Visão Geral

Este guia descreve como fazer o deploy da aplicação LOR-CGR (Next.js frontend + Django backend) em um servidor de produção.

## Estrutura do Projeto

```
/opt/
├── lorcgr-frontend/          # Next.js standalone
│   ├── .next/
│   │   └── static/           # Arquivos estáticos
│   ├── public/               # Arquivos públicos
│   ├── server.js             # Servidor Node.js
│   └── node_modules/
│
└── lorcgr/                   # Django backend (se aplicável)
    ├── backend/
    ├── frontend/
    └── venv/
```

## Pré-requisitos

1. **Node.js 18+** instalado no servidor
2. **Nginx** ou **Caddy** como reverse proxy
3. **systemd** para gerenciar os serviços
4. **PostgreSQL** (se usando Django com PostgreSQL)

## Passo a Passo

### 1. Instalar Node.js no Servidor

```bash
# Ubuntu/Debian
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verificar instalação
node --version
npm --version
```

### 2. Criar Diretório de Deploy

```bash
sudo mkdir -p /opt/lorcgr-frontend/{.next/static,public}
sudo chown -R www-data:www-data /opt/lorcgr-frontend
```

### 3. Copiar Arquivos de Build

Execute o script de deploy local:

```bash
./deploy_nextjs.sh 45.71.242.131 root
```

Ou manualmente:

```bash
# No servidor, criar estrutura
mkdir -p /opt/lorcgr-frontend/{.next/static,public}

# Copiar arquivos standalone (do seu ambiente de build)
scp -r .next/standalone/* root@45.71.242.131:/opt/lorcgr-frontend/
scp -r .next/static/* root@45.71.242.131:/opt/lorcgr-frontend/.next/static/
scp -r public/* root@45.71.242.131:/opt/lorcgr-frontend/public/
```

### 4. Configurar Systemd Service

```bash
# Copiar arquivo de service
sudo cp lorcgr-frontend.service /etc/systemd/system/

# Recarregar systemd
sudo systemctl daemon-reload

# Habilitar e iniciar
sudo systemctl enable lorcgr-frontend
sudo systemctl start lorcgr-frontend

# Verificar status
sudo systemctl status lorcgr-frontend
```

### 5. Configurar Reverse Proxy

#### Opção A: Nginx

```bash
# Copiar configuração
sudo cp nginx-lorcgr.conf /etc/nginx/sites-available/lorcgr
sudo ln -s /etc/nginx/sites-available/lorcgr /etc/nginx/sites-enabled/

# Testar configuração
sudo nginx -t

# Recarregar Nginx
sudo systemctl reload nginx
```

#### Opção B: Caddy

```bash
# Copiar Caddyfile
sudo cp Caddyfile-production /etc/caddy/Caddyfile

# Reiniciar Caddy
sudo systemctl restart caddy
```

### 6. Configurar Firewall

```bash
# Ubuntu/Debian com ufw
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 3000/tcp  # Apenas para debug, remova em produção
```

### 7. Configurar SSL (HTTPS)

#### Com Let's Encrypt (Certbot):

```bash
# Instalar certbot
sudo apt install certbot python3-certbot-nginx

# Obter certificado
sudo certbot --nginx -d lorcgr.xlab.online

# Renovação automática
sudo systemctl enable certbot.timer
```

#### Com Caddy:

O Caddy obtém certificados automaticamente quando o domínio está configurado corretamente.

## Resolução de Problemas

### Frontend não carrega (404 em arquivos estáticos)

```bash
# Verificar se os arquivos existem
ls -la /opt/lorcgr-frontend/.next/static/

# Verificar permissões
sudo chown -R www-data:www-data /opt/lorcgr-frontend
sudo chmod -R 755 /opt/lorcgr-frontend

# Verificar logs
sudo journalctl -u lorcgr-frontend -f
sudo tail -f /var/log/nginx/error.log
```

### Serviço não inicia

```bash
# Verificar se Node.js está instalado
which node
node --version

# Verificar se o arquivo server.js existe
ls -la /opt/lorcgr-frontend/server.js

# Verificar logs do systemd
sudo journalctl -u lorcgr-frontend -n 50
```

### Erro de CORS

Adicione ao Django settings.py:

```python
CORS_ALLOWED_ORIGINS = [
    "http://lorcgr.xlab.online",
    "http://45.71.242.131",
    "http://localhost:3000",
]
```

### Erro "COOP header ignored"

Este erro aparece quando usando HTTP (não HTTPS). Para resolver:

1. Configure HTTPS com certificado SSL válido
2. Ou acesse via localhost
3. Ou use o domínio configurado com DNS

## Monitoramento

### Verificar Status dos Serviços

```bash
# Frontend
sudo systemctl status lorcgr-frontend

# Backend Django (se aplicável)
sudo systemctl status lorcgr

# Nginx
sudo systemctl status nginx

# Caddy
sudo systemctl status caddy
```

### Logs em Tempo Real

```bash
# Logs do frontend
sudo journalctl -u lorcgr-frontend -f

# Logs do Nginx
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

## Atualização

Para atualizar a aplicação:

```bash
# Localmente, fazer novo build
bun run build

# Executar script de deploy
./deploy_nextjs.sh

# Ou manualmente no servidor
sudo systemctl restart lorcgr-frontend
```

## Contatos

Para suporte, contacte a equipe de desenvolvimento.
