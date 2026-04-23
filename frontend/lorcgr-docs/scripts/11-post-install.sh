#!/bin/bash

################################################################################
# LOR-CGR Installation Script - Post Install Configuration
################################################################################

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  LOR-CGR - Pós-Instalação${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script deve ser executado como root!${NC}"
   exit 1
fi

#######################################
# Verificar todos os serviços
#######################################
echo -e "${YELLOW}>>> Verificando status de todos os serviços...${NC}"

services=(
    "nginx"
    "postgresql"
    "mariadb"
    "redis-server"
    "php8.3-fpm"
    "librenms"
    "zabbix-server"
    "zabbix-agent"
    "grafana-server"
    "lorcgr-api"
    "lorcgr-ws"
    "lorcgr-frontend"
)

all_ok=true
for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $service"
    else
        echo -e "${RED}✗${NC} $service (não está rodando)"
        all_ok=false
    fi
done

# Verificar Docker
if docker ps | grep -q nexterm; then
    echo -e "${GREEN}✓${NC} nexterm (docker)"
else
    echo -e "${RED}✗${NC} nexterm (docker não está rodando)"
    all_ok=false
fi

#######################################
# Verificar portas
#######################################
echo ""
echo -e "${YELLOW}>>> Verificando portas...${NC}"

ports=(80 3000 3001 5432 3306 6379 8000 8001 6989 8080)
for port in "${ports[@]}"; do
    if ss -tlnp | grep -q ":$port "; then
        echo -e "${GREEN}✓${NC} Porta $port em uso"
    else
        echo -e "${YELLOW}?${NC} Porta $port não está em uso"
    fi
done

#######################################
# Configurar firewall (ufw)
#######################################
echo ""
echo -e "${YELLOW}>>> Configurando firewall...${NC}"

if command -v ufw &> /dev/null; then
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing

    # SSH
    ufw allow 22/tcp

    # HTTP/HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp

    # SNMP (para LibreNMS)
    ufw allow 161/udp

    # Zabbix Agent
    ufw allow 10050/tcp

    ufw --force enable

    echo -e "${GREEN}Firewall configurado!${NC}"
else
    echo -e "${YELLOW}ufw não instalado, pulando firewall...${NC}"
fi

#######################################
# Configurar logrotate
#######################################
echo ""
echo -e "${YELLOW}>>> Configurando logrotate...${NC}"

cat > /etc/logrotate.d/lorcgr << 'EOF'
/var/log/lorcgr/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 lorcgr lorcgr
    sharedscripts
}
EOF

#######################################
# Criar script de backup
#######################################
echo -e "${YELLOW}>>> Criando script de backup do sistema...${NC}"

cat > /opt/lorcgr/backup.sh << 'EOF'
#!/bin/bash
# LOR-CGR Backup Script

BACKUP_DIR="/opt/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

echo "Iniciando backup - $DATE"

# Backup PostgreSQL
pg_dump -U lorcgr lorcgr > $BACKUP_DIR/lorcgr_$DATE.sql
pg_dump -U lorcgr grafana > $BACKUP_DIR/grafana_$DATE.sql

# Backup MariaDB
mysqldump -u lorcgr -p'Lor#Cgr#2026' librenms > $BACKUP_DIR/librenms_$DATE.sql
mysqldump -u lorcgr -p'Lor#Cgr#2026' phpipam > $BACKUP_DIR/phpipam_$DATE.sql

# Backup configs
tar -czf $BACKUP_DIR/configs_$DATE.tar.gz /opt/lorcgr/*.conf /opt/lorcgr/.env

# Limpar backups antigos (manter 30 dias)
find $BACKUP_DIR -name "*.sql" -mtime +30 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete

echo "Backup concluído!"
EOF

chmod +x /opt/lorcgr/backup.sh

#######################################
# Criar cron jobs
#######################################
echo -e "${YELLOW}>>> Configurando agendamentos...${NC}"

# Adicionar cron jobs
(crontab -l 2>/dev/null; cat << 'CRONEOF'
# LOR-CGR Backup diário
0 2 * * * /opt/lorcgr/backup.sh >> /var/log/lorcgr/backup.log 2>&1

# LibreNMS polling (já configurado pelo próprio)
# 0 0 * * * /opt/librenms/cronic /opt/librenms/discovery-wrapper.py 1 >> /dev/null 2>&1

# Limpeza de logs antigos
0 3 * * * find /var/log -name "*.log" -mtime +30 -delete
CRONEOF
) | crontab -

#######################################
# Gerar resumo
#######################################
echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  RESUMO DA INSTALAÇÃO${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# Obter IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "SEU_IP")

echo "URLs de Acesso:"
echo "  ┌─────────────────────────────────────────────"
echo "  │ LOR-CGR:    http://${SERVER_IP}/"
echo "  │ LibreNMS:   http://${SERVER_IP}/librenms/"
echo "  │ phpIPAM:    http://${SERVER_IP}/phpipam/"
echo "  │ Zabbix:     http://${SERVER_IP}/zabbix/"
echo "  │ Grafana:    http://${SERVER_IP}/grafana/"
echo "  │ Nexterm:    http://${SERVER_IP}/nexterm/"
echo "  └─────────────────────────────────────────────"
echo ""

echo "Credenciais (todos os sistemas):"
echo "  ┌─────────────────────────────────────────────"
echo "  │ Usuário: lorcgr (ou Admin para alguns)"
echo "  │ Senha:   Lor#Cgr#2026"
echo "  └─────────────────────────────────────────────"
echo ""

echo "Arquivos de Configuração:"
echo "  • /opt/lorcgr/.env              - Configurações Django"
echo "  • /opt/lorcgr/phpipam_api.conf  - API phpIPAM"
echo "  • /opt/lorcgr/zabbix_api.conf   - API Zabbix"
echo "  • /opt/lorcgr/grafana_api.conf  - API Grafana"
echo "  • /opt/lorcgr/nexterm.conf      - Nexterm"
echo ""

echo "Próximos Passos:"
echo "  1. Acesse o LOR-CGR e configure as APIs em Configurações"
echo "  2. Obtenha API Token do LibreNMS (Settings > API)"
echo "  3. Crie API Key no Grafana (Configuration > API Keys)"
echo "  4. Configure GROQ API Key para IA (https://console.groq.com)"
echo "  5. Adicione equipamentos para testar"
echo ""

echo "Comandos Úteis:"
echo "  • Verificar serviços: systemctl status lorcgr-*"
echo "  • Ver logs: tail -f /var/log/lorcgr/api_error.log"
echo "  • Backup manual: /opt/lorcgr/backup.sh"
echo "  • Reiniciar tudo: systemctl restart nginx lorcgr-api lorcgr-frontend"
echo ""

# Salvar resumo em arquivo
cat > /opt/lorcgr/INSTALACAO.txt << EOF
LOR-CGR - Resumo da Instalação
Data: $(date)

URLs:
- LOR-CGR:    http://${SERVER_IP}/
- LibreNMS:   http://${SERVER_IP}/librenms/
- phpIPAM:    http://${SERVER_IP}/phpipam/
- Zabbix:     http://${SERVER_IP}/zabbix/
- Grafana:    http://${SERVER_IP}/grafana/
- Nexterm:    http://${SERVER_IP}/nexterm/

Credenciais:
- Usuário: lorcgr / Admin
- Senha: Lor#Cgr#2026

Bancos de Dados:
- PostgreSQL: lorcgr, grafana, zabbix
- MariaDB: librenms, phpipam

Configurações:
- Django:  /opt/lorcgr/.env
- LibreNMS: /opt/librenms/.env
- phpIPAM:  /opt/phpipam/config.php
- Zabbix:   /etc/zabbix/zabbix_server.conf
- Grafana:  /etc/grafana/grafana.ini

Serviços:
- nginx, postgresql, mariadb, redis
- librenms, zabbix-server, grafana-server
- lorcgr-api, lorcgr-ws, lorcgr-frontend
- nexterm (docker)
EOF

echo -e "${GREEN}Resumo salvo em: /opt/lorcgr/INSTALACAO.txt${NC}"
echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  INSTALAÇÃO CONCLUÍDA COM SUCESSO!${NC}"
echo -e "${GREEN}======================================${NC}"
