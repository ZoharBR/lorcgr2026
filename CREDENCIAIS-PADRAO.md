# 🔐 Credenciais Padrão - LOR-CGR 2026

> ⚠️ **IMPORTANTE:** Altere estas credenciais após a instalação!

---

## 👤 Acesso ao Sistema Admin (Django)

| Campo | Valor Padrão |
|-------|--------------|
| **URL** | `http://SEU-IP/admin/` |
| **Usuário** | `leonardo` |
| **Senha** | `Lor#Vision#2016` |
| **Email** | `zoharbr@gmail.com` |

---

## 🗄️ Banco de Dados PostgreSQL

| Campo | Valor Padrão |
|-------|--------------|
| **Host** | `localhost` |
| **Porta** | `5432` |
| **Banco** | `lorcgr` |
| **Usuário** | `lorcgr` |
| **Senha** | `Lorcgr2026` |

---

## 🌐 Serviços Integrados

### LibreNMS (Monitoramento de Rede)
- **URL:** http://SEU-IP:8080
- **Usuário:** admin
- **Senha:** Lorcgr2026

### phpIPAM (Gerenciamento de IP)
- **URL:** http://SEU-IP/phpipam
- **Usuário:** Admin
- **Senha:** ipamadmin

### Zabbix (Monitoramento)
- **URL:** http://SEU-IP/zabbix
- **Usuário:** Admin
- **Senha:** zabbix

### Grafana (Dashboards)
- **URL:** http://SEU-IP/grafana
- **Usuário:** admin
- **Senha:** admin

### Nexterm (Terminal Web)
- **URL:** http://SEU-IP:6989

---

## 🔧 Como Alterar Credenciais

1. Acesse: http://SEU-IP/admin/
2. Faça login como Admin
3. Vá em: API → Service configs
4. Clique no serviço e altere as credenciais
5. Salve as alterações

---

**Versão:** 1.0.0  
**Projeto:** LOR-CGR 2026





---

# 🛡️ Configurações de Segurança - Guia Completo

> ✅ **NOVIDADE v1.1:** Gerenciamento de CORS e Allowed Hosts via interface web!

---

## 🔒 Acessando as Configurações de Segurança

### **Método 1: Via Interface Web LOR-CGR (Recomendado)**

1. Acesse o sistema: `http://SEU-IP` (porta 80 ou 3000)
2. Faça login com suas credenciais
3. No menu lateral, clique em **"Configurações"** (ícone ⚙️)
4. Expanda o submenu e clique em **"🔒 Segurança"**
5. Será aberta automaticamente a aba de **Configurações de Segurança**

### **Método 2: Via Admin Django**

1. Acesse: `http://SEU-IP/admin/`
2. Faça login como Admin (`leonardo`)
3. Vá em: **API → Configurações de segurança**
4. Clique na configuração que deseja editar

---

## 🌐 CORS - Origens Permitidas (Cross-Origin Resource Sharing)

### **O que é CORS?**
Controla quais domínios/sites podem fazer requisições à API do LOR-CGR.

### **Configuração Padrão:**
| Campo | Valor |
|-------|-------|
| **Status** | Inativo (Modo Desenvolvimento) |
| **Origens configuradas** | `http://localhost:3000`, `http://45.71.242.131:3000` |

### **Como Alterar via Interface:**

1. Na aba **"CORS - Origens Permitidas"**
2. Use o toggle **"Ativo"** para ativar/desativar restrições
3. Para **adicionar uma origem**:
   - Digite no campo (ex: `https://meusite.com.br`)
   - Clique no botão **+** (plus)
   - A origem aparece como um badge/tag
4. Para **remover uma origem**:
   - Clique no **X** vermelho no badge da origem
5. Clique em **"Salvar Configuração CORS"**

### **Exemplos de Origens Válidas:**
