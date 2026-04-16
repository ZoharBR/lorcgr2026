#!/bin/bash

# ============================================
# LOR-CGR 2026 - Script de Deploy Automatizado
# ============================================

set -e  # Parar se der erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}   LOR-CGR 2026 - DEPLOY AUTOMÁTICO${NC}"
echo -e "${GREEN}============================================${NC}"

# Diretório do projeto
PROJECT_DIR="/opt/lorcgr"
FRONTEND_DIR="$PROJECT_DIR/frontend"
BACKEND_DIR="$PROJECT_DIR/backend"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$PROJECT_DIR/_zscripts/backups/pre-deploy_$TIMESTAMP"

# Função de log
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

# ============================================
# PASSO 1: Backup pré-deploy
# ============================================
log "Criando backup pré-deploy..."
mkdir -p "$BACKUP_DIR"

# Backup do frontend (.next e código)
if [ -d "$FRONTEND_DIR/.next" ]; then
    cp -r "$FRONTEND_DIR/.next" "$BACKUP_DIR/" 2>/dev/null || true
fi

# Backup do backend (se houver mudanças)
if [ -d "$BACKEND_DIR" ]; then
    cp -r "$BACKEND_DIR/lorcgr" "$BACKUP_DIR/" 2>/dev/null || true
fi

log "✅ Backup criado em: $BACKUP_DIR"

# ============================================
# PASSO 2: Atualizar código do Git
# ============================================
log "Atualizando código do GitHub..."
cd "$PROJECT_DIR"

# Salvar mudanças locais (se houver)
git stash || true

# Pull das atualizações
git pull origin master

log "✅ Código atualizado!"

# ============================================
# PASSO 3: Deploy Frontend (Next.js)
# ============================================
log "Iniciando deploy do FRONTEND..."

# Parar serviço frontend
systemctl stop lorcgr-frontend.service 2>/dev/null || true
sleep 2

# Entrar no diretório frontend
cd "$FRONTEND_DIR"

# Limpar build antigo
rm -rf .next node_modules/.cache

# Instalar dependências
log "Instalando dependências (bun install)..."
bun install

# Build de produção
log "Compilando build de produção (pode demorar alguns minutos)..."
NODE_ENV=production bun run build

# Iniciar serviço
systemctl start lorcgr-frontend.service
sleep 5

# Verificar se subiu
if systemctl is-active --quiet lorcgr-frontend.service; then
    log "✅ Frontend deployed com sucesso!"
else
    error "❌ Falha ao iniciar frontend!"
    error "Verifique: journalctl -u lorcgr-frontend.service -n 50"
    exit 1
fi

# ============================================
# PASSO 4: Deploy Backend (Django) - Opcional
# ============================================
if [ -f "$BACKEND_DIR/manage.py" ]; then
    log "Iniciando deploy do BACKEND..."
    
    cd "$BACKEND_DIR"
    
    # Ativar venv e instalar deps
    source venv/bin/activate
    pip install -q -r requirements.txt 2>/dev/null || true
    
    # Migrar banco de dados
    python manage.py migrate --noinput
    
    # Coletar arquivos estáticos
    python manage.py collectstatic --noinput --clear 2>/dev/null || true
    
    # Reiniciar backend
    systemctl restart lorcgr-api.service 2>/dev/null || true
    
    sleep 3
    
    if systemctl is-active --quiet lorcgr-api.service; then
        log "✅ Backend deployed com sucesso!"
    else
        warn "⚠️ Backend pode precisar de atenção manual"
    fi
fi

# ============================================
# PASSO 5: Verificação final
# ============================================
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}       ✅ DEPLOY CONCLUÍDO COM SUCESSO!${NC}"
echo -e "${GREEN}============================================${NC}"

echo ""
log "Status dos serviços:"
echo "  • Frontend: $(systemctl is-active lorcgr-frontend.service)"
echo "  • Backend:  $(systemctl is-active lorcgr-api.service 2>/dev/null || echo 'não verificado')"

echo ""
log "Testes de conexão:"
if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200"; then
    echo "  • Frontend HTTP: ${GREEN}200 OK${NC}"
else
    echo "  • Frontend HTTP: ${RED}FALHOU${NC}"
fi

if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000 | grep -q "200\|302"; then
    echo "  • Backend HTTP:  ${GREEN}OK${NC}"
else
    echo "  • Backend HTTP:  ${YELLOW}não verificado${NC}"
fi

echo ""
log "Backup disponível em: $BACKUP_DIR"
log "Para rollback manual use os arquivos desse backup."
echo ""

