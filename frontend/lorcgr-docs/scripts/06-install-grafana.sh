#!/bin/bash

################################################################################
# LOR-CGR Installation Script - Part 6: Grafana
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
ADMIN_USER="lorcgr"
ADMIN_PASS="Lor#Cgr#2026"

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  LOR-CGR - Instalação do Grafana${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script deve ser executado como root!${NC}"
   exit 1
fi

#######################################
# Adicionar repositório Grafana
#######################################
echo -e "${YELLOW}>>> Adicionando repositório Grafana...${NC}"

# Instalar dependências
apt-get install -y apt-transport-https software-properties-common wget

# Adicionar chave GPG
wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key

# Adicionar repositório
echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list

apt-get update

#######################################
# Instalar Grafana
#######################################
echo -e "${YELLOW}>>> Instalando Grafana...${NC}"
apt-get install -y grafana

#######################################
# Configurar Grafana
#######################################
echo -e "${YELLOW}>>> Configurando Grafana...${NC}"

# Backup da configuração original
cp /etc/grafana/grafana.ini /etc/grafana/grafana.ini.bak

# Criar nova configuração
cat > /etc/grafana/grafana.ini << 'INIEOF'
[app_mode]
app_mode = production

[instance]
name = LOR-CGR Grafana

[paths]
data = /var/lib/grafana
logs = /var/log/grafana
plugins = /var/lib/grafana/plugins
provisioning = /etc/grafana/provisioning

[server]
http_addr = 127.0.0.1
http_port = 3000
domain = localhost
root_url = http://localhost/grafana/

[database]
type = postgres
host = localhost:5432
name = grafana
user = lorcgr
password = Lor#Cgr#2026
ssl_mode = disable

[security]
admin_user = lorcgr
admin_password = Lor#Cgr#2026
secret_key = SW2YcwTIb9zpOOhoPsMm
disable_gravatar = true

[users]
allow_sign_up = false
auto_assign_org = true
auto_assign_org_role = Viewer

[auth.anonymous]
enabled = false

[auth.basic]
enabled = true

[auth.proxy]
enabled = false

[dashboards]
default_home_dashboard_path = /var/lib/grafana/dashboards/home.json

[plugins]
allow_loading_unsigned_plugins =

[alerting]
enabled = true
execute_alerts = true

[snapshots]
external_enabled = false

[metrics]
enabled = true

[log]
mode = console file
level = info

[log.console]
level = info

[log.file]
level = info
log_rotate = true
max_lines = 1000000
max_size_shift = 28
daily_rotate = true
max_days = 7
INIEOF

#######################################
# Criar diretórios
#######################################
echo -e "${YELLOW}>>> Criando diretórios...${NC}"
mkdir -p /var/lib/grafana/dashboards
mkdir -p /etc/grafana/provisioning/datasources
mkdir -p /etc/grafana/provisioning/dashboards

chown -R grafana:grafana /var/lib/grafana
chown -R grafana:grafana /etc/grafana

#######################################
# Configurar datasources
#######################################
echo -e "${YELLOW}>>> Configurando datasources...${NC}"

cat > /etc/grafana/provisioning/datasources/datasources.yml << 'EOF'
apiVersion: 1

datasources:
  - name: PostgreSQL - LOR-CGR
    type: postgres
    access: proxy
    url: localhost:5432
    database: lorcgr
    user: lorcgr
    secureJsonData:
      password: Lor#Cgr#2026
    jsonData:
      sslmode: disable
      maxOpenConns: 10
      maxIdleConns: 5
      connMaxLifetime: 14400
      postgresVersion: 1600
      timescaledb: false
    isDefault: true

  - name: Zabbix
    type: alexanderzobnin-zabbix-datasource
    access: proxy
    url: http://localhost:8080/api_jsonrpc.php
    jsonData:
      username: Admin
      password: Lor#Cgr#2026
      trends: true
      trendsRange: 7d
    editable: true

  - name: InfluxDB (se disponível)
    type: influxdb
    access: proxy
    url: http://localhost:8086
    jsonData:
      version: Flux
      organization: lorcgr
      defaultBucket: metrics
    editable: true
EOF

#######################################
# Instalar plugins
#######################################
echo -e "${YELLOW}>>> Instalando plugins...${NC}"
grafana-cli plugins install alexanderzobnin-zabbix-app 2>/dev/null || echo "Plugin Zabbix já instalado ou não disponível"
grafana-cli plugins install grafana-clock-panel 2>/dev/null || true
grafana-cli plugins install grafana-worldmap-panel 2>/dev/null || true

#######################################
# Iniciar Grafana
#######################################
echo -e "${YELLOW}>>> Iniciando Grafana...${NC}"
systemctl daemon-reload
systemctl start grafana-server
systemctl enable grafana-server

# Aguardar Grafana iniciar
sleep 10

#######################################
# Verificar status
#######################################
echo -e "${YELLOW}>>> Verificando status...${NC}"
if systemctl is-active --quiet grafana-server; then
    echo -e "${GREEN}✓ Grafana está rodando${NC}"
else
    echo -e "${RED}✗ Grafana não está rodando${NC}"
    journalctl -u grafana-server --no-pager -n 20
fi

#######################################
# Criar API Key
#######################################
echo -e "${YELLOW}>>> Criando API Key para LOR-CGR...${NC}"

# Aguardar API estar disponível
sleep 5

# Criar API key via API
API_KEY_RESPONSE=$(curl -s -X POST http://localhost:3000/api/auth/keys \
    -u "${ADMIN_USER}:${ADMIN_PASS}" \
    -H "Content-Type: application/json" \
    -d '{"name":"lorcgr-api","role":"Admin"}' 2>/dev/null)

API_KEY=$(echo $API_KEY_RESPONSE | grep -o '"key":"[^"]*"' | cut -d'"' -f4)

if [ -n "$API_KEY" ]; then
    echo -e "${GREEN}API Key criada com sucesso!${NC}"
else
    echo -e "${YELLOW}Não foi possível criar API Key automaticamente. Crie manualmente.${NC}"
    API_KEY="criar_manualmente"
fi

#######################################
# Salvar configurações
#######################################
echo -e "${YELLOW}>>> Salvando configurações...${NC}"
cat > /opt/lorcgr/grafana_api.conf << EOF
# Grafana API Configuration
# Gerado automaticamente pelo instalador LOR-CGR

GRAFANA_URL=http://localhost:3000
GRAFANA_USER=${ADMIN_USER}
GRAFANA_PASS=${ADMIN_PASS}
GRAFANA_API_KEY=${API_KEY}
EOF

chown lorcgr:lorcgr /opt/lorcgr/grafana_api.conf
chmod 600 /opt/lorcgr/grafana_api.conf

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  Grafana instalado com sucesso!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "Acesso web: http://seu-ip/grafana"
echo "Usuário: ${ADMIN_USER}"
echo "Senha: ${ADMIN_PASS}"
echo ""
if [ -n "$API_KEY" ] && [ "$API_KEY" != "criar_manualmente" ]; then
    echo "API Key: ${API_KEY}"
fi
echo ""
echo "Configurações salvas em: /opt/lorcgr/grafana_api.conf"
echo ""
echo "Próximo passo: Execute o script 07-install-nexterm.sh"
