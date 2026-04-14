#!/bin/bash
# =============================================================================
# LOR-CGR 2026 - Script de RESTAURAÇÃO Completo
# =============================================================================
# Descrião: Restaura o sistema LOR-CGR a partir de backups
# Autor: Leonardo (ZoharBR)
# Data: 10/04/2026
# Versão: 1.0.0
# Uso: ./restore_lorcgr.sh [opções]
# =============================================================================

# ===========================================
# CONFIGURAÇÕES
# ===========================================

PROJECT_DIR="/opt/lorcgr"
BACKUP_DIR="/opt/lorcgr/_zscripts/backups"
LOG_FILE="$BACKUP_DIR/restore.log"

# Configurações PostgreSQL
DB_NAME="lorcgr"
DB_USER="lorcgr"
DB_HOST="localhost"
DB_PORT="5432"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ===========================================
# FUNÇÕES AUXILIARES
# ===========================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

print_header() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} $1"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
    log "✅ $1"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    log "❌ $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    log "⚠️  $1"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

confirmacao() {
    echo ""
    read -p "$(echo -e ${YELLOW}Deseja continuar? (s/N): ${NC})" resposta
    if [[ "$resposta" != "s" && "$resposta" != "S" ]]; then
        print_warning "Operação cancelada pelo usuário!"
        exit 1
    fi
}

# ===========================================
# FUNÇÕES DE RESTAURAÇÃO
# ===========================================

listar_backups_disponiveis() {
    print_header "BACKUPS DISPONÍVEIS EM: $BACKUP_DIR"
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A $BACKUP_DIR/*.sql.gz $BACKUP_DIR/*.tar.gz 2>/dev/null)" ]; then
        print_error "Nenhum backup encontrado em $BACKUP_DIR!"
        exit 1
    fi
    
    echo ""
    echo "📦 Backups de Banco de Dados (PostgreSQL):"
    echo "-------------------------------------------"
    ls -lh $BACKUP_DIR/postgresql_*.sql.gz 2>/dev/null || echo "   Nenhum encontrado"
    
    echo ""
    echo "🎨 Backups do Frontend:"
    echo "--------------------------"
    ls -lh $BACKUP_DIR/frontend_*.tar.gz 2>/dev/null || echo "   Nenhum encontrado"
    
    echo ""
    echo "🐍 Backups do Backend:"
    echo "------------------------"
    ls -lh $BACKUP_DIR/backend_*.tar.gz 2>/dev/null || echo "   Nenhum encontrado"
    
    echo ""
    echo "⚙️ Backups de Configurações:"
    echo "----------------------------"
    ls -lh $BACKUP_DIR/configs_*.tar.gz 2>/dev/null || echo "   Nenhum encontrado"
    
    echo ""
    echo "📋 Manifestos de Backup:"
    echo "----------------------"
    ls -lh $BACKUP_DIR/manifest_*.txt 2>/dev/null || echo "   Nenhum encontrado"
}

restaurar_postgresql() {
    local BACKUP_FILE=$1
    
    print_header "RESTAURAÇÃO DO BANCO DE DADOS POSTGRESQL"
    
    if [ ! -f "$BACKUP_FILE" ]; then
        print_error "Arquivo de backup não encontrado: $BACKUP_FILE"
        return 1
    fi
    
    print_info "Arquivo de backup: $BACKUP_FILE"
    print_info "Tamanho: $(du -h $BACKUP_FILE | cut -f1)"
    print_info "Banco de destino: $DB_NAME"
    
    confirmacao
    
    # Verificar se banco existe
    psql -h $DB_HOST -p $DB_PORT -U $DB_USER -lqt | cut -d \| -f 1 | grep -qw $DB_NAME
    if [ $? -eq 0 ]; then
        print_warning "Banco '$DB_NAME' já existe!"
        read -p "$(echo -e ${YELLOW}Deseja deletar e recriar? Isso PERDERÁ todos os dados atuais! (s/N): ${NC})" drop_confirm
        if [[ "$drop_confirm" == "s" || "$drop_confirm" == "S" ]]; then
            log "Deletando banco existente..."
            PGPASSWORD="Lor#Cgr#2026" dropdb -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME
            if [ $? -ne 0 ]; then
                # Tentar forçar deleção (se houver conexões ativas)
                PGPASSWORD="Lor#Cgr#2026" dropdb -h $DB_HOST -p $DB_PORT -U $DB_USER --force $DB_NAME
            fi
        else
            print_warning "Restauração cancelada!"
            return 1
        fi
    fi
    
    # Criar banco vazio
    log "Criando banco de dados..."
    PGPASSWORD="Lor#Cgr#2026" createdb -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME
    
    if [ $? -ne 0 ]; then
        print_error "Erro ao criar banco de dados!"
        return 1
    fi
    
    print_success "Banco de dados criado: $DB_NAME"
    
    # Restaurar backup
    log "Iniciando restauração do backup..."
    print_info "Isso pode levar alguns minutos dependendo do tamanho..."
    
    gunzip -c "$BACKUP_FILE" | PGPASSWORD="Lor#Cgr#2026" psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME
    
    if [ $? -eq 0 ]; then
        print_success "Banco de dados restaurado com sucesso! ✅"
        
        # Aplicar migrações pendentes (se necessário)
        cd $PROJECT_DIR/backend
        source venv/bin/activate
        python manage.py migrate --run-syncdb 2>/dev/null || true
        
        print_success "Migrações aplicadas (se necessário)"
        return 0
    else
        print_error "Erro na restauração do banco de dados!"
        return 1
    fi
}

restaurar_frontend() {
    local BACKUP_FILE=$1
    
    print_header "RESTAURAÇÃO DO FRONTEND (NEXT.JS)"
    
    if [ ! -f "$BACKUP_FILE" ]; then
        print_error "Arquivo de backup não encontrado: $BACKUP_FILE"
        return 1
    fi
    
    print_info "Arquivo de backup: $BACKUP_FILE"
    print_info "Tamanho: $(du -h $BACKUP_FILE | cut -f1)"
    print_info "Destino: $PROJECT_DIR/frontend"
    
    confirmacao
    
    # Backup do frontend atual (por segurança)
    if [ -d "$PROJECT_DIR/frontend" ]; then
        print_info "Fazendo backup de segurança do frontend atual..."
        mv $PROJECT_DIR/frontend $PROJECT_DIR/frontend.bak.$(date +%Y%m%d_%H%M%S)
    fi
    
    # Extrair backup
    log "Extraindo backup do frontend..."
    tar -xzf "$BACKUP_FILE" -C "$PROJECT_DIR"
    
    if [ $? -eq 0 ]; then
        # Reinstalar dependências
        print_info "Reinstalando dependências npm..."
        cd $PROJECT_DIR/frontend
        
        if [ -f "package.json" ]; then
            npm install --production 2>&1 | tail -5
            
            # Rebuild do Next.js
            print_info "Reconstruindo aplicação Next.js..."
            npm run build 2>&1 | tail -10
            
            # Reiniciar serviço
            print_info "Reiniciando servidor Next.js..."
            fuser -k 3000/tcp 2>/dev/null
            sleep 2
            nohup npm run start > /tmp/nextjs_restore.log 2>&1 &
            
            print_success "Frontend restaurado e reiniciado! ✅"
            print_info "Acesse: http://$(hostname -I | awk '{print $1}') ou http://localhost:3000"
            return 0
        else
            print_error "package.json não encontrado no backup!"
            return 1
        fi
    else
        print_error "Erro ao extrair backup do frontend!"
        # Restaurar backup de segurança se existir
        if [ -d "$PROJECT_DIR/frontend.bak."* ]; then
            print_info "Restaurando backup de segurança..."
            mv $PROJECT_DIR/frontend.bak.* $PROJECT_DIR/frontend
        fi
        return 1
    fi
}

restaurar_backend() {
    local BACKUP_FILE=$1
    
    print_header "RESTAURAÇÃO DO BACKEND (DJANGO)"
    
    if [ ! -f "$BACKUP_FILE" ]; then
        print_error "Arquivo de backup não encontrado: $BACKUP_FILE"
        return 1
    fi
    
    print_info "Arquivo de backup: $BACKUP_FILE"
    print_info "Tamanho: $(du -h $BACKUP_FILE | cut -f1)"
    print_info "Destino: $PROJECT_DIR/backend"
    
    confirmacao
    
    # Backup do backend atual (por segurança)
    if [ -d "$PROJECT_DIR/backend" ]; then
        print_info "Fazendo backup de segurança do backend atual..."
        mv $PROJECT_DIR/backend $PROJECT_DIR/backend.bak.$(date +%Y%m%d_%H%M%S)
    fi
    
    # Extrair backup
    log "Extraindo backup do backend..."
    tar -xzf "$BACKUP_FILE" -C "$PROJECT_DIR"
    
    if [ $? -eq 0 ]; then
        # Reinstalar dependências Python
        print_info "Reinstalando dependências Python..."
        cd $PROJECT_DIR/backend
        
        if [ -d "venv" ]; then
            source venv/bin/activate
            pip install -q -r requirements.txt 2>/dev/null || true
        fi
        
        # Aplicar migrações
        print_info "Aplicando migrações do Django..."
        python manage.py migrate 2>&1 | tail -5
        
        # Reiniciar Gunicorn
        print_info "Reiniciando servidor Django/Gunicorn..."
        kill -HUP $(pgrep -f gunicorn) 2>/dev/null || true
        sleep 3
        
        print_success "Backend restaurado e reiniciado! ✅"
        print_info "API disponível em: http://$(hostname -I | awk '{print $1}'):8000/api/"
        return 0
    else
        print_error "Erro ao extrair backup do backend!"
        # Restaurar backup de segurança
        if [ -d "$PROJECT_DIR/backend.bak."* ]; then
            print_info "Restaurando backup de segurança..."
            mv $PROJECT_DIR/backend.bak.* $PROJECT_DIR/backend
        fi
        return 1
    fi
}

restaurar_configs() {
    local BACKUP_FILE=$1
    
    print_header "RESTAURAÇÃO DAS CONFIGURAÇÕES (.env, etc.)"
    
    if [ ! -f "$BACKUP_FILE" ]; then
        print_error "Arquivo de backup não encontrado: $BACKUP_FILE"
        return 1
    fi
    
    print_info "Arquivo de backup: $BACKUP_FILE"
    print_info "Conteúdo: .env, CREDENCIAIS-PADRAO.md, scripts"
    print_info "Destino: $PROJECT_DIR"
    
    print_warning "⚠️  ATENÇÃO: Isso vai sobrescrever seu arquivo .env atual!"
    confirmacao
    
    # Backup das configs atuais
    if [ -f "$PROJECT_DIR/.env" ]; then
        print_info "Fazendo backup do .env atual..."
        cp $PROJECT_DIR/.env $PROJECT_DIR/.env.bak.$(date +%Y%m%d_%H%M%S)
    fi
    
    # Extrair configs
    log "Extraindo configurações..."
    tar -xzf "$BACKUP_FILE" -C "$PROJECT_DIR"
    
    if [ $? -eq 0 ]; then
        print_success "Configurações restauradas! ✅"
        print_info "Arquivos restaurados:"
        tar -tzf "$BACKUP_FILE" | head -20
        
        print_warning "⚠️  Você pode precisar reiniciar os serviços para aplicar as novas configurações!"
        return 0
    else
        print_error "Erro ao extrair configurações!"
        # Restaurar backup
        if [ -f "$PROJECT_DIR/.env.bak."* ]; then
            print_info "Restorando .env do backup..."
            cp $PROJECT_DIR/.env.bak.* $PROJECT_DIR/.env
        fi
        return 1
    fi
}

restauracao_completa() {
    local DATE_PREFIX=$1
    
    print_header "🔄 RESTAURAÇÃO COMPLETA DO SISTEMA LOR-CGR"
    
    if [ -z "$DATE_PREFIX" ]; then
        # Encontrar o backup mais recente
        DATE_PREFIX=$(ls -t $BACKUP_DIR/postgresql_*.sql.gz 2>/dev/null | head -1 | grep -oP '\d{8}_\d{6}')
        print_info "Usando backup mais recente: $DATE_PREFIX"
    fi
    
    PG_BACKUP="$BACKUP_DIR/postgresql_lorcgr_${DATE_PREFIX}.sql.gz"
    FE_BACKUP="$BACKUP_DIR/frontend_${DATE_PREFIX}.tar.gz"
    BE_BACKUP="$BACKUP_DIR/backend_${DATE_PREFIX}.tar.gz"
    CF_BACKUP="$BACKUP_DIR/configs_${DATE_PREFIX}.tar.gz"
    
    # Verificar se todos os arquivos existem
    print_info "Verificando arquivos de backup..."
    
    for FILE in "$PG_BACKUP" "$FE_BACKUP" "$BE_BACKUP"; do
        if [ ! -f "$FILE" ]; then
            print_error "Arquivo não encontrado: $FILE"
            print_error "Restauração completa abortada!"
            return 1
        fi
        print_success "Encontrado: $(basename $FILE) ($(du -h $FILE | cut -f1))"
    done
    
    echo ""
    print_warning "⚠️  ATENÇÃO: A restauração completa vai:"
    echo "   1. Deletar e recriar o banco de dados PostgreSQL"
    echo "   2. Substituir todo o código do Frontend"
    echo "   3. Substituir todo o código do Backend"
    echo "   4. Restaurar arquivo .env do backup"
    echo ""
    
    confirmacao
    
    # 1. Restaurar PostgreSQL
    echo ""
    restaurar_postgresql "$PG_BACKUP"
    if [ $? -ne 0 ]; then
        print_error "Falha na restauração do PostgreSQL!"
        return 1
    fi
    
    # 2. Restaurar Backend
    echo ""
    restaurar_backend "$BE_BACKUP"
    if [ $? -ne 0 ]; then
        print_error "Falha na restauração do Backend!"
        return 1
    fi
    
    # 3. Restaurar Configs (.env)
    echo ""
    if [ -f "$CF_BACKUP" ]; then
        restaurar_configs "$CF_BACKUP"
    else
        print_warning "Backup de configs não encontrado, pulando..."
    fi
    
    # 4. Restaurar Frontend (por último)
    echo ""
    restaurar_frontend "$FE_BACKUP"
    if [ $? -ne 0 ]; then
        print_error "Falha na restauração do Frontend!"
        return 1
    fi
    
    print_header "✅ RESTAURAÇÃO COMPLETA FINALIZADA COM SUCESSO!"
    echo ""
    print_info "Próximos passos:"
    echo "   1. Teste o acesso ao sistema: http://$(hostname -I | awk '{print $1}')"
    echo "   2. Verifique se os serviços estão rodando:"
    echo "      - Frontend: ps aux | grep next"
    echo "      - Backend: ps aux | grep gunicorn"
    echo "      - PostgreSQL: systemctl status postgresql"
    echo "   3. Verifique os logs em caso de erros"
    echo ""
}

mostrar_ajuda() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║           LOR-CGR 2026 - GUIA DE RESTAURAÇÃO                ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "USO: $0 [opções] [arquivo]"
    echo ""
    echo "OPÇÕES:"
    echo "  -l, --list       Listar backups disponíveis"
    echo "  -db, --database  Restaurar apenas banco de dados PostgreSQL"
    echo "  -fe, --frontend  Restaurar apenas Frontend (Next.js)"
    echo "  -be, --backend   Restaurar apenas Backend (Django)"
    echo "  -cfg, --configs  Restaurar apenas configurações (.env)"
    echo "  -a, --all        Restauração completa (tudo)"
    echo "  -h, --help       Mostrar esta ajuda"
    echo ""
    echo "EXEMPLOS:"
    echo "  $0 -l                                    # Listar backups"
    echo "  $0 -db backups/postgresql_20260410.sql.gz  # Restaurar BD"
    echo "  $0 -a 20260410_080328                    # Restaurar tudo da data"
    echo "  $0 -a                                     # Restaurar tudo (mais recente)"
    echo ""
    echo "ARQUIVOS DE BACKUP:"
    echo "  Localização: $BACKUP_DIR"
    echo "  Formato: postgresql_lorcgr_AAAAMMDD_HHMMSS.sql.gz"
    echo "          frontend_AAAAMMDD_HHMMSS.tar.gz"
    echo "          backend_AAAAMMDD_HHMMSS.tar.gz"
    echo "          configs_AAAAMMDD_HHMMSS.tar.gz"
    echo ""
}

# ===========================================
# EXECUÇÃO PRINCIPAL
# ===========================================

case "$1" in
    -l|--list)
        listar_backups_disponiveis
        ;;
    -db|--database)
        if [ -z "$2" ]; then
            print_error "Especifique o arquivo de backup do PostgreSQL!"
            echo "Uso: $0 -db <arquivo_backup.sql.gz>"
            exit 1
        fi
        restaurar_postgresql "$2"
        ;;
    -fe|--frontend)
        if [ -z "$2" ]; then
            print_error "Especifique o arquivo de backup do Frontend!"
            echo "Uso: $0 -fe <arquivo_backup.tar.gz>"
            exit 1
        fi
        restaurar_frontend "$2"
        ;;
    -be|--backend)
        if [ -z "$2" ]; then
            print_error "Especifique o arquivo de backup do Backend!"
            echo "Uso: $0 -be <arquivo_backup.tar.gz>"
            exit 1
        fi
        restaurar_backend "$2"
        ;;
    -cfg|--configs)
        if [ -z "$2" ]; then
            print_error "Especifique o arquivo de backup das configurações!"
            echo "Uso: $0 -cfg <arquivo_backup.tar.gz>"
            exit 1
        fi
        restaurar_configs "$2"
        ;;
    -a|--all)
        restauracao_completa "$2"
        ;;
    -h|--help|*)
        mostrar_ajuda
        ;;
esac
