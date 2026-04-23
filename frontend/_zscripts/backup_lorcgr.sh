#!/bin/bash
# =============================================================================
# LOR-CGR 2026 - Script de Backup Completo
# =============================================================================
# Descrição: Realiza backup completo do sistema LOR-CGR
# Autor: Leonardo (ZoharBR)
# Data: 09/04/2026
# Versão: 1.0.0
# =============================================================================

# ===========================================
# CONFIGURAÇÕES
# ===========================================

# Diretórios do projeto
PROJECT_DIR="/opt/lorcgr"
BACKUP_DIR="/opt/lorcgr/_zscripts/backups"
LOG_FILE="$BACKUP_DIR/backup.log"

# Configurações do banco de dados PostgreSQL
DB_NAME="lorcgr"
DB_USER="lorcgr"
DB_HOST="localhost"
DB_PORT="5432"

# Configurações de retenção (dias para manter backups)
RETENTION_DAYS=30

# Data/hora atual para nome do arquivo
DATE=$(date +%Y%m%d_%H%M%S)
DATE_PRETTY=$(date '+%d/%m/%Y %H:%M:%S')

# ===========================================
# FUNÇÕES
# ===========================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_disk_space() {
    # Verificar espaço em disco mínimo necessário (500MB)
    REQUIRED_SPACE_KB=512000
    AVAILABLE_SPACE=$(df -k "$BACKUP_DIR" | tail -1 | awk '{print $4}')
    
    if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE_KB" ]; then
        log "❌ ERRO: Espaço em disco insuficiente!"
        log "   Disponível: $((AVAILABLE_SPACE / 1024)) MB"
        log   "Necessário: $((REQUIRED_SPACE_KB / 1024)) MB"
        exit 1
    fi
    
    log "✅ Espaço em disco OK: $((AVAILABLE_SPACE / 1024)) MB disponível"
}

backup_postgresql() {
    log "📦 Iniciando backup do PostgreSQL ($DB_NAME)..."
    
    local PG_DUMP_FILE="$BACKUP_DIR/postgresql_${DB_NAME}_${DATE}.sql.gz"
    
    # Executar pg_dump com compressão
    PGPASSWORD="Lor#Cgr#2026" pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
        -F p -Z 9 -f "$PG_DUMP_FILE" "$DB_NAME"
    
    if [ $? -eq 0 ]; then
        local FILE_SIZE=$(du -h "$PG_DUMP_FILE" | cut -f1)
        log "✅ Backup PostgreSQL concluído: $PG_DUMP_FILE ($FILE_SIZE)"
        echo "$PG_DUMP_FILE"
    else
        log "❌ ERRO no backup PostgreSQL!"
        return 1
    fi
}

backup_frontend() {
    log "🎨 Iniciando backup do Frontend (Next.js)..."
    
    local FRONTEND_BACKUP="$BACKUP_DIR/frontend_${DATE}.tar.gz"
    
    # Backup do frontend (excluindo node_modules e .next)
    tar -czf "$FRONTEND_BACKUP" \
        --exclude='node_modules' \
        --exclude='.next' \
        --exclude='.git' \
        -C "$PROJECT_DIR" frontend 2>/dev/null
    
    if [ $? -eq 0 ]; then
        local FILE_SIZE=$(du -h "$FRONTEND_BACKUP" | cut -f1)
        log "✅ Backup Frontend concluído: $FRONTEND_BACKUP ($FILE_SIZE)"
        echo "$FRONTEND_BACKUP"
    else
        log "❌ ERRO no backup Frontend!"
        return 1
    fi
}

backup_backend() {
    log "🐍 Iniciando backup do Backend (Django)..."
    
    local BACKEND_BACKUP="$BACKUP_DIR/backend_${DATE}.tar.gz"
    
    # Backup do backend (excluindo venv, __pycache__, etc.)
    tar -czf "$BACKEND_BACKUP" \
        --exclude='venv' \
        --exclude='__pycache__' \
        --exclude='*.pyc' \
        --exclude='.git' \
        --exclude='staticfiles' \
        -C "$PROJECT_DIR" backend 2>/dev/null
    
    if [ $? -eq 0 ]; then
        local FILE_SIZE=$(du -h "$BACKEND_BACKUP" | cut -f1)
        log "✅ Backup Backend concluído: $BACKEND_BACKUP ($FILE_SIZE)"
        echo "$BACKEND_BACKUP"
    else
        log "❌ ERRO no backup Backend!"
        return 1
    fi
}

backup_configs() {
    log "⚙️ Iniciando backup das Configurações..."
    
    local CONFIGS_BACKUP="$BACKUP_DIR/configs_${DATE}.tar.gz"
    
    # Backup de arquivos de configuração importantes
    tar -czf "$CONFIGS_BACKUP" \
        -C "$PROJECT_DIR" \
        .env \
        CREDENCIAIS-PADRAO.md \
        _zscripts 2>/dev/null
    
    if [ $? -eq 0 ]; then
        local FILE_SIZE=$(du -h "$CONFIGS_BACKUP" | cut -f1)
        log "✅ Backup Configurações concluído: $CONFIGS_BACKUP ($FILE_SIZE)"
        echo "$CONFIGS_BACKUP"
    else
        log "⚠️ Aviso: Alguns arquivos de config não encontrados"
        echo ""
    fi
}

cleanup_old_backups() {
    log "🧹 Limpando backups antigos (mais de $RETENTION_DAYS dias)..."
    
    local DELETED=0
    local FOUND=$(find "$BACKUP_DIR" -name "*.tar.gz" -o -name "*.sql.gz" -mtime +$RETENTION_DAYS 2>/dev/null)
    
    if [ -n "$FOUND" ]; then
        echo "$FOUND" | while read -r FILE; do
            rm -f "$FILE"
            ((DELETED++))
            log "   🗑️ Removido: $(basename "$FILE")"
        done
        log "✅ Limpeza concluída: $DELETED arquivos removidos"
    else
        log "✅ Nenhum arquivo antigo para remover"
    fi
}

create_backup_manifest() {
    log "📋 Criando manifesto do backup..."
    
    local MANIFEST_FILE="$BACKUP_DIR/manifest_${DATE}.txt"
    
    cat > "$MANIFEST_FILE" << EOF
=============================================================================
LOR-CGR 2026 - MANIFESTO DE BACKUP
=============================================================================
Data/Hora:       $DATE_PRETTY
Servidor:        $(hostname -I | awk '{print $1}')
Sistema Operacional: $(lsb_release -ds 2>/dev/null || uname -s)

ARQUIVOS DE BACKUP GERADOS:
------------------------------------------------------------------------------
EOF

    # Listar todos os arquivos gerados neste backup
    for FILE in "$BACKUP_DIR"/*_"${DATE}".*; do
        if [ -f "$FILE" ]; then
            local SIZE=$(du -h "$FILE" | cut -f1)
            local MD5=$(md5sum "$FILE" | awk '{print $1}')
            echo "- $(basename "$FILE") [$SIZE] MD5: $MD5" >> "$MANIFEST_FILE"
        fi
    done
    
    cat >> "$MANIFEST_FILE" << EOF

ESTRUTURA DE DIRETÓRIOS:
------------------------------------------------------------------------------
 $(tree -L 2 "$PROJECT_DIR" -I 'node_modules|venv|.next|__pycache__|*.pyc|staticfiles|.git' 2>/dev/null || ls -la "$PROJECT_DIR")

VERSÕES:
------------------------------------------------------------------------------
PostgreSQL:     $(psql --version 2>/dev/null | head -1 || echo "N/A")
Python:         $(python3 --version 2>/dev/null || echo "N/A")
Django:         $(python3 -c "import django; print(django.VERSION)" 2>/dev/null || echo "N/A")
Node.js:        $(node --version 2>/dev/null || echo "N/A")
Next.js:        $(cat "$PROJECT_DIR/frontend/package.json" 2>/dev/null | grep version | head -1 || echo "N/A")

=============================================================================
FIM DO MANIFESTO
=============================================================================
EOF
    
    log "✅ Manifesto criado: $MANIFEST_FILE"
}

# ===========================================
# EXECUÇÃO PRINCIPAL
# ===========================================

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           LOR-CGR 2026 - SISTEMA DE BACKUP COMPLETO           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

log "========================================"
log "INICIANDO BACKUP COMPLETO DO LOR-CGR"
log "Data/Hora: $DATE_PRETTY"
log "========================================"

# Criar diretório de logs se não existir
mkdir -p "$BACKUP_DIR" 2>/dev/null

# Verificar espaço em disco
check_disk_space

# Array para armazenar arquivos de backup
declare -a BACKUP_FILES

# Executar backups individuais
echo ""
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
PG_FILE=$(backup_postgresql)
if [ -n "$PG_FILE" ]; then
    BACKUP_FILES+=("$PG_FILE")
fi

FE_FILE=$(backup_frontend)
if [ -n "$FE_FILE" ]; then
    BACKUP_FILES+=("$FE_FILE")
fi

BE_FILE=$(backup_backend)
if [ -n "$BE_FILE" ]; then
    BACKUP_FILES+=("$BE_FILE")
fi

CF_FILE=$(backup_configs)
if [ -n "$CF_FILE" ]; then
    BACKUP_FILES+=("$CF_FILE")
fi

# Criar manifesto
create_backup_manifest

# Limpar backups antigos (DESABILITADO - rodar manualmente quando necessário)
# Para ativar, descomente a linha abaixo:
# cleanup_old_backups

# Resumo final
echo ""
log "========================================"
log "RESUMO DO BACKUP"
log "========================================"
log "Data/Hora: $DATE_PRETTY"
log "Total de arquivos: ${#BACKUP_FILES[@]}"

TOTAL_SIZE=0
for FILE in "${BACKUP_FILES[@]}"; do
    if [ -f "$FILE" ]; then
        SIZE=$(du -k "$FILE" | cut -f1)
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
        log "  ✅ $(basename "$FILE") ($(du -h "$FILE" | cut -f1))"
    fi
done

log ""
log "Tamanho total do backup: $((TOTAL_SIZE / 1024)) MB"
log "Localização: $BACKUP_DIR"
log "Log detalhado: $LOG_FILE"
log "========================================"
log "BACKUP CONCLUÍDO COM SUCESSO! ✅"
log "========================================"
echo ""

# Exportar variável com caminhos dos arquivos (útil para scripts externos)
export BACKUP_FILES_ARRAY="${BACKUP_FILES[*]}"
