# GUIA DE INSTALAÇÃO - LOR-CGR

## ⚠️ ORDEM CORRETA DE EXECUÇÃO

### PASSO 1: RESET COMPLETO (remover tudo)
```bash
ssh root@45.71.242.131
# Cole e execute o script lorcgr-reset-complete.sh
# Digite 'RESETAR' para confirmar
# Reinicie o servidor
reboot
```

### PASSO 2: INSTALAÇÃO (após o reboot)
```bash
ssh root@45.71.242.131
# Cole e execute o script lorcgr-full-install.sh
# Digite 'yes' para confirmar
```

---

## 📋 ARQUIVOS NECESSÁRIOS

### 1. Script de RESET (lorcgr-reset-complete.sh)
Remove TUDO do servidor antes de instalar

### 2. Script de INSTALAÇÃO (lorcgr-full-install.sh)
Instala todos os componentes do zero

---

## ⏱️ TEMPO ESTIMADO

- Reset: ~5 minutos
- Reboot: ~2 minutos
- Instalação: ~30-45 minutos

---

## 🔐 CREDENCIAIS (todos os sistemas)

```
Usuário: lorcgr (ou Admin)
Senha: Lor#Cgr#2026
```

---

## 🌐 URLs APÓS INSTALAÇÃO

| Sistema | URL |
|---------|-----|
| LOR-CGR | http://SEU_IP/ |
| LibreNMS | http://SEU_IP/librenms/ |
| phpIPAM | http://SEU_IP/phpipam/ |
| Zabbix | http://SEU_IP/zabbix/ |
| Grafana | http://SEU_IP/grafana/ |
| Nexterm | http://SEU_IP/nexterm/ |

---

## ✅ CHECKLIST

- [ ] Conectar ao servidor
- [ ] Executar script de RESET
- [ ] Digitar 'RESETAR' para confirmar
- [ ] Reiniciar servidor
- [ ] Reconectar após reboot
- [ ] Executar script de INSTALAÇÃO
- [ ] Aguardar conclusão (~30-45 min)
- [ ] Acessar LOR-CGR no navegador
- [ ] Configurar APIs em Configurações

---

## 📞 SUPORTE

Se algo der errado:
1. Verifique os logs: `journalctl -xe`
2. Reinicie o serviço: `systemctl restart NOME_DO_SERVICO`
3. Verifique as portas: `ss -tlnp`
