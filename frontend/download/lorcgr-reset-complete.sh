#!/bin/bash

################################################################################
# LOR-CGR - Script de RESET COMPLETO do Servidor
# AVISO: Este scriptRemove TUDO do servidor!
# Execute ANTES do script de instalação
################################################################################

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║              ⚠️  ATENÇÃO - RESET COMPLETO  ⚠️                ║"
echo "║                                                              ║"
echo "║     Este script vai REMOVER TODOS os serviços e dados!       ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Execute como root!${NC}"
   exit 1
fi

echo ""
echo -e "${YELLOW}Serão removidos:${NC}"
echo "  • Todos os containers Docker e imagens"
echo "  • LibreNMS, phpIPAM, Zabbix, Grafana, Nexterm"
echo "  • PostgreSQL, MariaDB/MySQL, Redis"
echo "  • Django, Next.js, Nginx"
echo "  • TODOS os bancos de dados"
echo "  • TODOS os arquivos de configuração"
echo "  • TODOS os dados em /opt e /var/lib"
echo ""
echo -e "${RED}⚠️  ESTA AÇÃO NÃO PODE SER DESFEITA! ⚠️${NC}"
echo ""
read -p "Digite 'RESETAR' para confirmar: " confirm

if [[ "$confirm" != "RESETAR" ]]; then
    echo "Operação cancelada."
    exit 0
fi

echo ""
echo -e "${BLUE}══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  INICIANDO RESET COMPLETO DO SERVIDOR${NC}"
echo -e "${BLUE}══════════════════════════════════════════════════════════${NC}"
echo ""

# ============================================
# 1. PARAR TODOS OS SERVIÇOS
# ============================================
echo -e "${YELLOW}[1/8] Parando todos os serviços...${NC}"

services=(
    "nginx"
    "postgresql"
    "mariadb"
    "mysql"
    "redis-server"
    "redis"
    "zabbix-server"
    "zabbix-agent"
    "grafana-server"
    "librenms"
    "librenms-scheduler"
    "lorcgr-api"
    "lorcgr-frontend"
    "lorcgr-ws"
    "php8.3-fpm"
    "php8.2-fpm"
    "php8.1-fpm"
    "php*fpm"
    "docker"
    "snapd"
)

for service in "${services[@]}"; do
    systemctl stop "$service" 2>/dev/null || true
    systemctl disable "$service" 2>/dev/null || true
done

# Parar todos os containers Docker
docker stop $(docker ps -aq) 2>/dev/null || true

echo -e "${GREEN}✓ Serviços parados${NC}"

# ============================================
# 2. REMOVER DOCKER COMPLETAMENTE
# ============================================
echo -e "${YELLOW}[2/8] Removendo Docker completamente...${NC}"

# Remover containers
docker rm -f $(docker ps -aq) 2>/dev/null || true

# Remover imagens
docker rmi -f $(docker images -q) 2>/dev/null || true

# Remover volumes
docker volume rm $(docker volume ls -q) 2>/dev/null || true

# Remover redes
docker network prune -f 2>/dev/null || true

# Desinstalar Docker
apt-get remove --purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras 2>/dev/null || true
apt-get autoremove -y 2>/dev/null || true

# Remover arquivos do Docker
rm -rf /var/lib/docker
rm -rf /var/lib/containerd
rm -rf /etc/docker
rm -rf ~/.docker

echo -e "${GREEN}✓ Docker removido${NC}"

# ============================================
# 3. REMOVER BANCOS DE DADOS
# ============================================
echo -e "${YELLOW}[3/8] Removendo bancos de dados...${NC}"

# PostgreSQL
echo "  Removendo PostgreSQL..."
apt-get remove --purge -y postgresql* 2>/dev/null || true
rm -rf /var/lib/postgresql
rm -rf /etc/postgresql
rm -rf /var/run/postgresql

# MariaDB/MySQL
echo "  Removendo MariaDB/MySQL..."
apt-get remove --purge -y mariadb* mysql* 2>/dev/null || true
rm -rf /var/lib/mysql
rm -rf /var/lib/mariadb
rm -rf /etc/mysql
rm -rf /etc/mariadb

# Redis
echo "  Removendo Redis..."
apt-get remove --purge -y redis* 2>/dev/null || true
rm -rf /var/lib/redis
rm -rf /etc/redis

echo -e "${GREEN}✓ Bancos de dados removidos${NC}"

# ============================================
# 4. REMOVER APLICAÇÕES DE MONITORAMENTO
# ============================================
echo -e "${YELLOW}[4/8] Removendo aplicações de monitoramento...${NC}"

# LibreNMS
echo "  Removendo LibreNMS..."
apt-get remove --purge -y librenms 2>/dev/null || true
rm -rf /opt/librenms
rm -f /etc/systemd/system/librenms*
rm -rf /var/log/librenms

# phpIPAM
echo "  Removendo phpIPAM..."
rm -rf /opt/phpipam

# Zabbix
echo "  Removendo Zabbix..."
apt-get remove --purge -y zabbix* 2>/dev/null || true
rm -rf /var/lib/zabbix
rm -rf /etc/zabbix
rm -rf /usr/share/zabbix
rm -f /etc/apt/sources.list.d/zabbix*

# Grafana
echo "  Removendo Grafana..."
apt-get remove --purge -y grafana* 2>/dev/null || true
rm -rf /var/lib/grafana
rm -rf /etc/grafana
rm -rf /usr/share/grafana
rm -f /etc/apt/sources.list.d/grafana*

# Nexterm (já removido com Docker)
rm -rf /opt/nexterm

echo -e "${GREEN}✓ Aplicações de monitoramento removidas${NC}"

# ============================================
# 5. REMOVER LOR-CGR
# ============================================
echo -e "${YELLOW}[5/8] Removendo LOR-CGR...${NC}"

# Django/Backend
rm -rf /opt/lorcgr

# Next.js
rm -rf /opt/lorcgr-frontend
rm -rf /opt/frontend

# Serviços systemd
rm -f /etc/systemd/system/lorcgr*

# Logs
rm -rf /var/log/lorcgr

echo -e "${GREEN}✓ LOR-CGR removido${NC}"

# ============================================
# 6. REMOVER NGINX E PHP
# ============================================
echo -e "${YELLOW}[6/8] Removendo Nginx e PHP...${NC}"

# Nginx
apt-get remove --purge -y nginx* 2>/dev/null || true
rm -rf /etc/nginx
rm -rf /var/log/nginx
rm -rf /var/lib/nginx

# PHP
apt-get remove --purge -y php* 2>/dev/null || true
rm -rf /etc/php
rm -rf /var/lib/php

# PHP-FPM
rm -rf /run/php

echo -e "${GREEN}✓ Nginx e PHP removidos${NC}"

# ============================================
# 7. REMOVER PACOTES ADICIONAIS
# ============================================
echo -e "${YELLOW}[7/8] Removendo pacotes adicionais...${NC}"

# Node.js
apt-get remove --purge -y nodejs npm 2>/dev/null || true
rm -rf /usr/lib/node_modules
rm -rf ~/.npm
rm -f /etc/apt/sources.list.d/nodesource*

# Python packages (do projeto)
rm -rf /opt/venv 2>/dev/null || true

# SNMP
apt-get remove --purge -y snmp snmpd 2>/dev/null || true
rm -rf /etc/snmp

# Outros
apt-get remove --purge -y fping nmap rrdtool 2>/dev/null || true

# Limpar pacotes órfãos
apt-get autoremove --purge -y 2>/dev/null || true
apt-get autoclean 2>/dev/null || true

echo -e "${GREEN}✓ Pacotes adicionais removidos${NC}"

# ============================================
# 8. LIMPEZA FINAL
# ============================================
echo -e "${YELLOW}[8/8] Limpeza final...${NC}"

# Recarregar systemd
systemctl daemon-reload
systemctl reset-failed

# Limpar diretórios
rm -rf /opt/* 2>/dev/null || true
mkdir -p /opt

# Limpar logs antigos
rm -rf /var/log/nginx 2>/dev/null || true
rm -rf /var/log/postgresql 2>/dev/null || true
rm -rf /var/log/mysql 2>/dev/null || true
rm -rf /var/log/zabbix 2>/dev/null || true
rm -rf /var/log/grafana 2>/dev/null || true

# Limpar tmp
rm -rf /tmp/* 2>/dev/null || true

# Limpar cache do apt
rm -rf /var/cache/apt/archives/*.deb
apt-get clean

# Remover repositórios extras
rm -f /etc/apt/sources.list.d/*.list
rm -f /etc/apt/sources.list.d/*.deb

# Restaurar sources.list original se não existir
if [ ! -f /etc/apt/sources.list ]; then
    cat > /etc/apt/sources.list << 'EOF'
deb http://archive.ubuntu.com/ubuntu noble main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu noble-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu noble-security main restricted universe multiverse
EOF
fi

# Atualizar lista de pacotes
apt-get update

echo -e "${GREEN}✓ Limpeza final concluída${NC}"

# ============================================
# RESUMO
# ============================================
echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  RESET COMPLETO CONCLUÍDO!${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
echo ""
echo "O servidor está agora LIMPO e pronto para uma nova instalação."
echo ""
echo -e "${YELLOW}Próximos passos:${NC}"
echo "  1. Reinicie o servidor: ${GREEN}reboot${NC}"
echo "  2. Após reiniciar, execute o script de instalação"
echo ""

read -p "Deseja reiniciar o servidor agora? (yes/no): " reboot_now
if [[ "$reboot_now" == "yes" ]]; then
    echo ""
    echo -e "${GREEN}Reiniciando em 5 segundos...${NC}"
    sleep 5
    reboot
else
    echo ""
    echo -e "${YELLOW}Lembre-se de reiniciar antes de instalar!${NC}"
    echo "Execute: ${GREEN}reboot${NC}"
fi
