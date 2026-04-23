# GUIA RÁPIDO - Instalação LOR-CGR

## PASSO 1: Baixar os Scripts no Servidor

Conecte ao servidor e execute:

```bash
ssh root@45.71.242.131

# Criar diretório
mkdir -p /opt/lorcgr-scripts
cd /opt/lorcgr-scripts
```

Agora você tem duas opções para obter os scripts:

### Opção A: Copiar via SCP (da sua máquina local)

```bash
# Na sua máquina LOCAL, execute:
scp /home/z/my-project/download/lorcgr-install-scripts.tar.gz root@45.71.242.131:/opt/lorcgr-scripts/

# De volta no servidor:
cd /opt/lorcgr-scripts
tar -xzvf lorcgr-install-scripts.tar.gz
chmod +x scripts/*.sh
```

### Opção B: Criar scripts manualmente (copiar e colar)

Para cada arquivo de script, execute `vim nome-do-arquivo.sh` e cole o conteúdo.

---

## PASSO 2: Executar a Instalação

### Se quiser RESETAR o servidor completamente:

```bash
cd /opt/lorcgr-scripts/scripts
./00-reset-server.sh
# Após o reboot, continue do passo 2
```

### Instalação normal (sem reset):

```bash
cd /opt/lorcgr-scripts/scripts
./install-all.sh
```

OU execute cada script individualmente:

```bash
./01-prepare-server.sh
./02-install-databases.sh
./03-install-librenms.sh
./04-install-phpipam.sh
./05-install-zabbix.sh
./06-install-grafana.sh
./07-install-nexterm.sh
./08-install-nginx.sh
./09-install-django.sh
./10-install-nextjs.sh
./11-post-install.sh
```

---

## PASSO 3: Verificar Instalação

```bash
# Verificar serviços
systemctl status nginx lorcgr-api lorcgr-frontend

# Verificar portas
ss -tlnp | grep -E ':80|:3001|:8000'

# Ver logs
tail -f /var/log/lorcgr/api_error.log
```

---

## CREDENCIAIS

| Sistema | URL | Usuário | Senha |
|---------|-----|---------|-------|
| LOR-CGR | http://IP/ | lorcgr | Lor#Cgr#2026 |
| LibreNMS | http://IP/librenms/ | lorcgr | Lor#Cgr#2026 |
| phpIPAM | http://IP/phpipam/ | Admin | Lor#Cgr#2026 |
| Zabbix | http://IP/zabbix/ | Admin | Lor#Cgr#2026 |
| Grafana | http://IP/grafana/ | lorcgr | Lor#Cgr#2026 |
| Nexterm | http://IP:6989 | lorcgr | Lor#Cgr#2026 |

---

## PRÓXIMOS PASSOS APÓS INSTALAÇÃO

1. **Configurar API do LibreNMS**
   - Acesse LibreNMS > Settings > API > Create Token
   - Copie o token para /opt/lorcgr/.env

2. **Configurar GROQ AI**
   - Acesse https://console.groq.com
   - Crie uma API Key gratuita
   - Adicione ao /opt/lorcgr/.env

3. **Adicionar equipamentos**
   - Acesse o LOR-CGR
   - Cadastre equipamentos de teste

---

## COMANDOS ÚTEIS

```bash
# Reiniciar tudo
systemctl restart nginx lorcgr-api lorcgr-ws lorcgr-frontend

# Ver status
systemctl status nginx postgresql mariadb

# Backup manual
/opt/lorcgr/backup.sh

# Logs
tail -f /var/log/nginx/error.log
tail -f /var/log/lorcgr/api_error.log

# Docker Nexterm
docker logs nexterm -f
docker restart nexterm
```

---

## SOLUÇÃO DE PROBLEMAS

### Nginx não inicia
```bash
nginx -t  # Testar configuração
systemctl status nginx
```

### Django não conecta ao banco
```bash
psql -U lorcgr -d lorcgr -h localhost -W
# Senha: Lor#Cgr#2026
```

### Nexterm não acessível
```bash
docker ps -a | grep nexterm
docker restart nexterm
```
