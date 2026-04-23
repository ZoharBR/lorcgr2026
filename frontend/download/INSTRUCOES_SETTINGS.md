# ============================================
# INSTRUÇÕES PARA INTEGRAR SETTINGS
# NO FRONTEND REACT EXISTENTE
# ============================================

## Arquivos Criados

1. `/home/z/my-project/download/Settings.js` - Componente React completo
2. `/home/z/my-project/download/settings_views.py` - Views Django backend
3. `/home/z/my-project/download/deploy_settings_complete.sh` - Script de deploy

## Deploy Passo a Passo

### OPÇÃO 1: Deploy Automático (Recomendado)

Execute no SERVIDOR (45.71.242.131):

```bash
# Copie o script para o servidor
scp /home/z/my-project/download/deploy_settings_complete.sh root@45.71.242.131:/opt/lorcgr/

# Execute o script
ssh root@45.71.242.131
cd /opt/lorcgr
chmod +x deploy_settings_complete.sh
./deploy_settings_complete.sh
```

### OPÇÃO 2: Deploy Manual

#### 1. Copiar Settings.js para o frontend

```bash
scp /home/z/my-project/download/Settings.js root@45.71.242.131:/opt/lorcgr/frontend/src/components/
```

#### 2. Copiar settings_views.py para o backend

```bash
scp /home/z/my-project/download/settings_views.py root@45.71.242.131:/opt/lorcgr/
```

#### 3. Editar o App.js do frontend

No arquivo `/opt/lorcgr/frontend/src/App.js`, adicione:

**Import no topo:**
```javascript
import Settings from './components/Settings';
```

**No array de menuItems:**
```javascript
{ id: 'settings', label: 'Configurações', icon: SettingsIcon }
```

**No switch/case de renderização:**
```javascript
case 'settings':
  return <Settings />;
```

#### 4. Adicionar URLs ao Django

No arquivo `/opt/lorcgr/lorcgr/urls.py`, adicione no final:

```python
# Settings API
from settings_views import (
    settings_get, settings_save, settings_test_librenms, settings_test_phpipam,
    settings_test_groq, settings_git_status, settings_git_logs, settings_git_backup, settings_git_pull
)

urlpatterns += [
    path('api/settings/get/', settings_get, name='settings_get'),
    path('api/settings/save/', settings_save, name='settings_save'),
    path('api/settings/test/librenms/', settings_test_librenms, name='settings_test_librenms'),
    path('api/settings/test/phpipam/', settings_test_phpipam, name='settings_test_phpipam'),
    path('api/settings/test/groq/', settings_test_groq, name='settings_test_groq'),
    path('api/settings/git/status/', settings_git_status, name='settings_git_status'),
    path('api/settings/git/logs/', settings_git_logs, name='settings_git_logs'),
    path('api/settings/git/backup/', settings_git_backup, name='settings_git_backup'),
    path('api/settings/git/pull/', settings_git_pull, name='settings_git_pull'),
]
```

#### 5. Reconstruir o frontend

```bash
cd /opt/lorcgr/frontend
npm run build
```

#### 6. Reiniciar o serviço

```bash
systemctl restart lorcgr
```

## Funcionalidades do Settings

### Aba APIs Externas
- LibreNMS: URL + Token + Teste de conexão
- phpIPAM: URL + App ID/Key + Usuário/Senha + Teste

### Aba IA (Groq)
- Provedor: Groq, OpenAI, Anthropic
- Modelo: Llama 3.3 70B, Mixtral, Gemma
- API Key + Temperatura + Max Tokens

### Aba Git/Backup
- GitHub Token (PAT)
- URL do Repositório
- Branch
- Backup Automático (ON/OFF)
- Frequência: horário/diário/semanal/mensal
- Botão Pull (baixar)
- Botão Backup Agora (enviar)
- Status do repositório (branch, ahead/behind, arquivos)
- Histórico de commits

## Estilo Visual

O componente Settings foi criado no mesmo estilo visual da interface atual:
- Fundo escuro (bg-gray-800)
- Cards com border border-gray-700
- Gradientes coloridos nos botões
- Toggles personalizados
- Inputs com fundo bg-gray-700
- Ícones coloridos (lucide-react)

## Manutenção das Funcionalidades Existentes

O componente Settings é independente e não afeta nenhuma funcionalidade existente:
- Dashboard
- Inventário
- Terminal SSH
- Comandos em Massa
- Backups
- Logs (Auditoria)
- IA
- Todas as outras funcionalidades permanecem intactas
