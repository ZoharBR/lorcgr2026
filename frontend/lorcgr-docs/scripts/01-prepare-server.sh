#!/bin/bash

################################################################################
# LOR-CGR Installation Script - Part 2: Server Preparation
# Execute após o reboot do script 00-reset-server.sh
################################################################################

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Credenciais padrão
DB_USER="lorcgr"
DB_PASS="Lor#Cgr#2026"

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  LOR-CGR - Preparação do Servidor${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script deve ser executado como root!${NC}"
   exit 1
fi

echo -e "${YELLOW}>>> Atualizando sistema...${NC}"
apt-get update
apt-get upgrade -y

echo -e "${YELLOW}>>> Instalando pacotes essenciais...${NC}"
apt-get install -y \
    curl wget git vim htop net-tools dnsutils \
    unzip software-properties-common apt-transport-https \
    ca-certificates gnupg lsb-release python3-pip \
    python3-venv build-essential libpq-dev \
    acl rrdtool snmp snmpd fping nmap whois \
    graphviz imagemagick mtr-tiny

echo -e "${YELLOW}>>> Configurando timezone...${NC}"
timedatectl set-timezone America/Sao_Paulo

echo -e "${YELLOW}>>> Criando usuário lorcgr...${NC}"
if ! id "lorcgr" &>/dev/null; then
    useradd -m -s /bin/bash lorcgr
    echo "lorcgr:${DB_PASS}" | chpasswd
    usermod -aG sudo lorcgr
    echo -e "${GREEN}Usuário lorcgr criado com sucesso!${NC}"
else
    echo -e "${YELLOW}Usuário lorcgr já existe.${NC}"
fi

echo -e "${YELLOW}>>> Criando diretórios do projeto...${NC}"
mkdir -p /opt/lorcgr
mkdir -p /var/log/lorcgr
mkdir -p /opt/nexterm/data
chown -R lorcgr:lorcgr /opt/lorcgr
chown -R lorcgr:lorcgr /var/log/lorcgr

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  Servidor preparado com sucesso!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "Próximo passo: Execute o script 02-install-databases.sh"
