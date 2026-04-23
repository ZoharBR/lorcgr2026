#!/bin/bash

################################################################################
# LOR-CGR Installation Script - Part 7: Nexterm
################################################################################

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Credenciais padrão
ADMIN_USER="lorcgr"
ADMIN_PASS="Lor#Cgr#2026"
ENCRYPTION_KEY="0e61a0c2072c1c8191ca085d5191269897b5281ab25571f7239dfe5d7e094573"

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  LOR-CGR - Instalação do Nexterm${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script deve ser executado como root!${NC}"
   exit 1
fi

#######################################
# Instalar Docker
#######################################
echo -e "${YELLOW}>>> Verificando Docker...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}>>> Instalando Docker...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh

    # Iniciar Docker
    systemctl start docker
    systemctl enable docker

    echo -e "${GREEN}Docker instalado com sucesso!${NC}"
else
    echo -e "${GREEN}Docker já está instalado.${NC}"
fi

#######################################
# Criar diretórios
#######################################
echo -e "${YELLOW}>>> Criando diretórios...${NC}"
mkdir -p /opt/nexterm/data

#######################################
# Parar container existente se houver
#######################################
echo -e "${YELLOW}>>> Verificando container existente...${NC}"
if docker ps -a | grep -q nexterm; then
    echo -e "${YELLOW}>>> Removendo container existente...${NC}"
    docker stop nexterm 2>/dev/null || true
    docker rm nexterm 2>/dev/null || true
fi

#######################################
# Executar Nexterm
#######################################
echo -e "${YELLOW}>>> Iniciando container Nexterm...${NC}"
docker run -d \
    --name nexterm \
    -p 6989:6989 \
    -v /opt/nexterm/data:/app/data \
    -e ENCRYPTION_KEY=${ENCRYPTION_KEY} \
    --restart unless-stopped \
    germannewsmaker/nexterm

#######################################
# Aguardar inicialização
#######################################
echo -e "${YELLOW}>>> Aguardando inicialização...${NC}"
sleep 10

#######################################
# Verificar status
#######################################
echo -e "${YELLOW}>>> Verificando status...${NC}"
if docker ps | grep -q nexterm; then
    echo -e "${GREEN}✓ Nexterm está rodando${NC}"
else
    echo -e "${RED}✗ Nexterm não está rodando${NC}"
    docker logs nexterm
fi

#######################################
# Salvar configurações
#######################################
echo -e "${YELLOW}>>> Salvando configurações...${NC}"
cat > /opt/lorcgr/nexterm.conf << EOF
# Nexterm Configuration
# Gerado automaticamente pelo instalador LOR-CGR

NEXTERM_URL=http://localhost:6989
NEXTERM_EXTERNAL_URL=/nexterm/
NEXTERM_ENCRYPTION_KEY=${ENCRYPTION_KEY}
NEXTERM_USER=${ADMIN_USER}
NEXTERM_PASS=${ADMIN_PASS}

# Docker container name: nexterm
# Data directory: /opt/nexterm/data
EOF

chown lorcgr:lorcgr /opt/lorcgr/nexterm.conf
chmod 600 /opt/lorcgr/nexterm.conf

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  Nexterm instalado com sucesso!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "Acesso web: http://seu-ip:6989"
echo ""
echo -e "${YELLOW}IMPORTANTE: Na primeira vez que acessar, crie o usuário:${NC}"
echo "  Usuário: ${ADMIN_USER}"
echo "  Senha: ${ADMIN_PASS}"
echo ""
echo "Configurações salvas em: /opt/lorcgr/nexterm.conf"
echo ""
echo "Próximo passo: Execute o script 08-install-nginx.sh"
