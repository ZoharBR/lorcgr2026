#!/bin/bash

################################################################################
# LOR-CGR Master Installation Script
# Este script executa toda a instalação de forma automatizada
################################################################################

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║              LOR-CGR Network Management System               ║"
echo "║                    Instalação Automatizada                   ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script deve ser executado como root!${NC}"
   echo "Execute: sudo bash $0"
   exit 1
fi

# Diretório dos scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo -e "${YELLOW}Este script vai instalar o LOR-CGR completo.${NC}"
echo ""
echo "Componentes a instalar:"
echo "  • PostgreSQL + MariaDB + Redis"
echo "  • LibreNMS (monitoramento)"
echo "  • phpIPAM (IP management)"
echo "  • Zabbix (monitoramento avançado)"
echo "  • Grafana (dashboards)"
echo "  • Nexterm (terminal/RDP)"
echo "  • Django Backend API"
echo "  • Next.js Frontend"
echo "  • Nginx (reverse proxy)"
echo ""
echo "Credenciais padrão para TODOS os sistemas:"
echo "  Usuário: lorcgr / Admin"
echo "  Senha: Lor#Cgr#2026"
echo ""
read -p "Continuar com a instalação? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo "Instalação cancelada."
    exit 0
fi

# Função para executar script com tratamento de erro
run_script() {
    local script=$1
    local name=$2

    echo ""
    echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Executando: $name${NC}"
    echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"

    if [[ -f "$script" ]]; then
        chmod +x "$script"
        if bash "$script"; then
            echo -e "${GREEN}✓ $name concluído com sucesso!${NC}"
            return 0
        else
            echo -e "${RED}✗ Erro ao executar $name${NC}"
            read -p "Continuar mesmo assim? (yes/no): " continue_on_error
            if [[ "$continue_on_error" != "yes" ]]; then
                exit 1
            fi
            return 1
        fi
    else
        echo -e "${RED}Script não encontrado: $script${NC}"
        return 1
    fi
}

# Lista de scripts em ordem
scripts=(
    "01-prepare-server.sh:Preparação do Servidor"
    "02-install-databases.sh:Instalação de Bancos de Dados"
    "03-install-librenms.sh:Instalação do LibreNMS"
    "04-install-phpipam.sh:Instalação do phpIPAM"
    "05-install-zabbix.sh:Instalação do Zabbix"
    "06-install-grafana.sh:Instalação do Grafana"
    "07-install-nexterm.sh:Instalação do Nexterm"
    "08-install-nginx.sh:Configuração do Nginx"
    "09-install-django.sh:Instalação do Django Backend"
    "10-install-nextjs.sh:Instalação do Next.js Frontend"
    "11-post-install.sh:Pós-Instalação"
)

# Executar cada script
for script_info in "${scripts[@]}"; do
    IFS=':' read -r script name <<< "$script_info"
    run_script "$SCRIPT_DIR/$script" "$name"
done

echo ""
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║            INSTALAÇÃO CONCLUÍDA COM SUCESSO!                ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo "Acesse: http://$(curl -s ifconfig.me 2>/dev/null || echo 'SEU_IP')/"
echo ""
echo "Credenciais: lorcgr / Lor#Cgr#2026"
echo ""
