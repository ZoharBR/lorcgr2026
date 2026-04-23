#!/bin/bash

################################################################################
# LOR-CGR Installation Script - Part 1: Server Reset
# Execute este script para limpar e preparar o servidor
################################################################################

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  LOR-CGR - Reset do Servidor${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script deve ser executado como root!${NC}"
   exit 1
fi

echo -e "${YELLOW}ATENÇÃO: Este script vai REMOVER todos os serviços e dados!${NC}"
read -p "Tem certeza que deseja continuar? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo "Operação cancelada."
    exit 0
fi

echo ""
echo -e "${YELLOW}>>> Parando serviços...${NC}"

# Parar todos os serviços
systemctl stop nginx 2>/dev/null || true
systemctl stop postgresql 2>/dev/null || true
systemctl stop mariadb 2>/dev/null || true
systemctl stop mysql 2>/dev/null || true
systemctl stop redis-server 2>/dev/null || true
systemctl stop zabbix-server 2>/dev/null || true
systemctl stop zabbix-agent 2>/dev/null || true
systemctl stop grafana-server 2>/dev/null || true
systemctl stop librenms 2>/dev/null || true
systemctl stop docker 2>/dev/null || true
systemctl stop lorcgr-api 2>/dev/null || true
systemctl stop lorcgr-frontend 2>/dev/null || true

echo -e "${YELLOW}>>> Removendo pacotes instalados...${NC}"

# Remover pacotes
apt-get remove --purge -y nginx nginx-common postgresql* redis* zabbix* grafana* docker* containerd* librenms* phpipam* 2>/dev/null || true
apt-get autoremove --purge -y

echo -e "${YELLOW}>>> Removendo dados e configurações...${NC}"

# Remover diretórios de dados
rm -rf /opt/librenms 2>/dev/null || true
rm -rf /opt/phpipam 2>/dev/null || true
rm -rf /opt/lorcgr 2>/dev/null || true
rm -rf /opt/nexterm 2>/dev/null || true
rm -rf /var/lib/zabbix 2>/dev/null || true
rm -rf /var/lib/grafana 2>/dev/null || true
rm -rf /var/lib/postgresql 2>/dev/null || true
rm -rf /var/lib/mysql 2>/dev/null || true
rm -rf /var/lib/docker 2>/dev/null || true

# Remover configurações
rm -rf /etc/nginx 2>/dev/null || true
rm -rf /etc/zabbix 2>/dev/null || true
rm -rf /etc/grafana 2>/dev/null || true
rm -rf /etc/postgresql 2>/dev/null || true
rm -rf /etc/mysql 2>/dev/null || true
rm -rf /etc/docker 2>/dev/null || true

# Remover serviços systemd
rm -f /etc/systemd/system/lorcgr*.service 2>/dev/null || true
rm -f /etc/systemd/system/librenms*.service 2>/dev/null || true
systemctl daemon-reload

echo -e "${YELLOW}>>> Limpando pacotes órfãos...${NC}"
apt-get autoremove -y
apt-get autoclean

echo ""
echo -e "${GREEN}>>> Servidor resetado com sucesso!${NC}"
echo -e "${GREEN}>>> Reiniciando em 5 segundos...${NC}"
sleep 5
reboot
