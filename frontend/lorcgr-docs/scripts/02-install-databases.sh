#!/bin/bash

################################################################################
# LOR-CGR Installation Script - Part 2: Databases (PostgreSQL + MariaDB)
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
echo -e "${GREEN}  LOR-CGR - Instalação de Bancos${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script deve ser executado como root!${NC}"
   exit 1
fi

#######################################
# PostgreSQL
#######################################
echo ""
echo -e "${YELLOW}>>> Instalando PostgreSQL...${NC}"
apt-get install -y postgresql postgresql-contrib

echo -e "${YELLOW}>>> Configurando PostgreSQL...${NC}"
# Iniciar e habilitar
systemctl start postgresql
systemctl enable postgresql

# Configurar acesso
cat >> /etc/postgresql/16/main/pg_hba.conf << EOF

# LOR-CGR Access
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
EOF

# Reiniciar PostgreSQL
systemctl restart postgresql

# Criar usuário e bancos
echo -e "${YELLOW}>>> Criando usuário e bancos PostgreSQL...${NC}"
su - postgres << EOF
psql -c "CREATE USER ${DB_USER} WITH SUPERUSER CREATEDB CREATEROLE PASSWORD '${DB_PASS}';"
psql -c "CREATE DATABASE lorcgr OWNER ${DB_USER};"
psql -c "CREATE DATABASE grafana OWNER ${DB_USER};"
psql -c "CREATE DATABASE zabbix OWNER ${DB_USER};"
EOF

echo -e "${GREEN}PostgreSQL configurado com sucesso!${NC}"

#######################################
# MariaDB (para LibreNMS e phpIPAM)
#######################################
echo ""
echo -e "${YELLOW}>>> Instalando MariaDB...${NC}"
apt-get install -y mariadb-server mariadb-client

echo -e "${YELLOW}>>> Configurando MariaDB...${NC}"
# Iniciar e habilitar
systemctl start mariadb
systemctl enable mariadb

# Secure installation automático
mysql -u root << EOF
-- Remove anonymous users
DELETE FROM mysql.user WHERE User='';

-- Remove test database
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

-- Disallow root remote login
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');

-- Create lorcgr user
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON *.* TO '${DB_USER}'@'localhost' WITH GRANT OPTION;

-- Create databases
CREATE DATABASE IF NOT EXISTS librenms CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS phpipam CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Grant privileges
GRANT ALL PRIVILEGES ON librenms.* TO '${DB_USER}'@'localhost';
GRANT ALL PRIVILEGES ON phpipam.* TO '${DB_USER}'@'localhost';

FLUSH PRIVILEGES;
EOF

# Configurar MariaDB para LibreNMS
cat > /etc/mysql/mariadb.conf.d/99-librenms.cnf << 'EOF'
[mysqld]
innodb_file_per_table=1
lower_case_table_names=0
EOF

systemctl restart mariadb

echo -e "${GREEN}MariaDB configurado com sucesso!${NC}"

#######################################
# Redis (para caching)
#######################################
echo ""
echo -e "${YELLOW}>>> Instalando Redis...${NC}"
apt-get install -y redis-server

# Configurar
sed -i 's/^supervised .*/supervised systemd/' /etc/redis/redis.conf

systemctl start redis-server
systemctl enable redis-server

echo -e "${GREEN}Redis configurado com sucesso!${NC}"

#######################################
# Verificação
#######################################
echo ""
echo -e "${YELLOW}>>> Testando conexões...${NC}"

# Testar PostgreSQL
if PGPASSWORD="${DB_PASS}" psql -h localhost -U ${DB_USER} -d lorcgr -c "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PostgreSQL conectado com sucesso!${NC}"
else
    echo -e "${RED}✗ Erro ao conectar PostgreSQL${NC}"
fi

# Testar MariaDB
if mysql -u ${DB_USER} -p"${DB_PASS}" -e "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ MariaDB conectado com sucesso!${NC}"
else
    echo -e "${RED}✗ Erro ao conectar MariaDB${NC}"
fi

# Testar Redis
if redis-cli ping | grep -q "PONG"; then
    echo -e "${GREEN}✓ Redis conectado com sucesso!${NC}"
else
    echo -e "${RED}✗ Erro ao conectar Redis${NC}"
fi

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  Bancos de dados instalados!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "Bancos PostgreSQL criados:"
echo "  - lorcgr (principal)"
echo "  - grafana"
echo "  - zabbix"
echo ""
echo "Bancos MariaDB criados:"
echo "  - librenms"
echo "  - phpipam"
echo ""
echo "Credenciais de acesso:"
echo "  Usuário: ${DB_USER}"
echo "  Senha: ${DB_PASS}"
echo ""
echo "Próximo passo: Execute o script 03-install-librenms.sh"
