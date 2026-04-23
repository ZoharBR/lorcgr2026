# Scripts de Instalação LOR-CGR

## Como Usar

### Opção 1: Instalação Completa Automatizada

```bash
# Conectar ao servidor
ssh root@45.71.242.131

# Baixar e executar o script mestre
# (Você precisará transferir os scripts para o servidor)

# Dar permissão e executar
chmod +x install-all.sh
./install-all.sh
```

### Opção 2: Executar Scripts Individualmente

```bash
# 1. Preparar servidor (após reset)
./01-prepare-server.sh

# 2. Instalar bancos de dados
./02-install-databases.sh

# 3. Instalar LibreNMS
./03-install-librenms.sh

# 4. Instalar phpIPAM
./04-install-phpipam.sh

# 5. Instalar Zabbix
./05-install-zabbix.sh

# 6. Instalar Grafana
./06-install-grafana.sh

# 7. Instalar Nexterm
./07-install-nexterm.sh

# 8. Configurar Nginx
./08-install-nginx.sh

# 9. Instalar Django Backend
./09-install-django.sh

# 10. Instalar Next.js Frontend
./10-install-nextjs.sh

# 11. Pós-instalação
./11-post-install.sh
```

## Como Transferir Scripts para o Servidor

### Método 1: SCP (Recomendado)

Na sua máquina local:
```bash
# Copiar todos os scripts
scp -r /home/z/my-project/lorcgr-docs/scripts/* root@45.71.242.131:/opt/lorcgr-scripts/
```

### Método 2: Criar no Servidor

Conecte ao servidor e crie cada arquivo manualmente:
```bash
ssh root@45.71.242.131
mkdir -p /opt/lorcgr-scripts
cd /opt/lorcgr-scripts
# Cole o conteúdo de cada script
vim 01-prepare-server.sh
# ... etc
```

### Método 3: Download via curl

Se você hospedar os scripts em um servidor web ou GitHub:
```bash
curl -O https://seu-servidor/scripts/install-all.sh
```

## Ordem de Execução

| # | Script | Descrição |
|---|--------|-----------|
| 00 | 00-reset-server.sh | **OPCIONAL** - Reseta servidor completamente |
| 01 | 01-prepare-server.sh | Atualiza sistema, cria usuário, instala pacotes base |
| 02 | 02-install-databases.sh | PostgreSQL, MariaDB, Redis |
| 03 | 03-install-librenms.sh | LibreNMS + dependências PHP |
| 04 | 04-install-phpipam.sh | phpIPAM |
| 05 | 05-install-zabbix.sh | Zabbix Server + Agent + Frontend |
| 06 | 06-install-grafana.sh | Grafana + plugins |
| 07 | 07-install-nexterm.sh | Nexterm (Docker) |
| 08 | 08-install-nginx.sh | Nginx reverse proxy |
| 09 | 09-install-django.sh | Django REST API |
| 10 | 10-install-nextjs.sh | Next.js Frontend |
| 11 | 11-post-install.sh | Configurações finais, firewall, backup |

## Tempo Estimado

- Instalação completa: ~30-45 minutos
- Dependendo da velocidade da internet e hardware do servidor

## Requisitos

- Ubuntu Server 24.04 LTS
- Mínimo 4GB RAM
- Mínimo 50GB disco
- Acesso root

## Troubleshooting

### Se um script falhar:

1. Verifique os logs:
   ```bash
   # Logs gerais
   tail -f /var/log/syslog

   # Logs específicos
   journalctl -u nome-do-servico -f
   ```

2. Verifique se as portas estão livres:
   ```bash
   ss -tlnp
   ```

3. Execute o script novamente após corrigir o problema

### Reiniciar serviços:

```bash
# Todos os serviços LOR-CGR
systemctl restart nginx lorcgr-api lorcgr-ws lorcgr-frontend

# Bancos de dados
systemctl restart postgresql mariadb redis-server

# Monitoramento
systemctl restart librenms zabbix-server grafana-server
```

## Após Instalação

1. Acesse `http://SEU_IP/`
2. Configure as APIs em Configurações
3. Adicione equipamentos
4. Configure backups

## Suporte

Se encontrar problemas, verifique:
- `/var/log/lorcgr/` - Logs do LOR-CGR
- `/var/log/nginx/` - Logs do Nginx
- `/opt/lorcgr/INSTALACAO.txt` - Resumo da instalação
