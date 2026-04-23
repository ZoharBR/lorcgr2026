# LOR-CGR - Sistema de Gerenciamento de Rede

## Visão Geral

LOR-CGR é uma plataforma completa de gerenciamento de rede que integra múltiplas ferramentas de monitoramento, inventário e automação em uma única interface web moderna.

## Arquitetura

```
┌─────────────────────────────────────────────────────────────────┐
│                        LOR-CGR Platform                         │
├─────────────────────────────────────────────────────────────────┤
│  Frontend (Next.js)  ←→  Backend (Django REST API)             │
│         ↓                       ↓                               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              INTEGRAÇÕES                                │   │
│  │  • LibreNMS - Monitoramento SNMP                        │   │
│  │  • Zabbix - Monitoramento Avançado                      │   │
│  │  • phpIPAM - Gerenciamento de IP                        │   │
│  │  • Grafana - Dashboards e Visualização                  │   │
│  │  • Nexterm - Terminal/SSH/RDP/VNC                       │   │
│  │  • GROQ AI - Inteligência Artificial                    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                         ↓                                       │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              PostgreSQL Database                        │   │
│  │  • Banco principal LOR-CGR                              │   │
│  │  • Integração com bancos dos apps                       │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Componentes

| Componente | Porta | Descrição |
|------------|-------|-----------|
| Nginx | 80/443 | Reverse Proxy |
| Next.js | 3001 | Frontend Web |
| Django | 8000 | API REST |
| WebSocket | 8001 | Tempo Real |
| PostgreSQL | 5432 | Banco de Dados |
| LibreNMS | - | Monitoramento |
| Zabbix | - | Monitoramento |
| phpIPAM | - | IP Management |
| Grafana | 3000 | Dashboards |
| Nexterm | 6989 | Terminal/Web |

## Credenciais Padrão

Todas as aplicações e bancos de dados utilizam:
- **Usuário**: `lorcgr`
- **Senha**: `Lor#Cgr#2026`

## Módulos do Sistema

### 1. Dashboard
- Customizável com widgets
- Gráficos de monitoramento
- Status de equipamentos
- Alertas em tempo real

### 2. Equipamentos
- Cadastro completo de equipamentos
- Suporte a múltiplos vendors (Juniper, Huawei, FiberHome, Cisco, etc.)
- Tipos: Switch, Router, OLT, ONU, Server, etc.
- Sincronização automática com LibreNMS/Zabbix
- Coleta via SNMP/SSH/Telnet

### 3. Terminal
- Acesso SSH/Telnet integrado
- RDP/VNC via Nexterm
- Histórico de comandos

### 4. Backups
- Automático por equipamento
- Agendamento por grupos
- Backup manual sob demanda
- Versionamento de configurações

### 5. Usuários
- Roles: ADMIN, NOC, VIEW
- Sincronização com todos os apps integrados
- Logs de ações

### 6. Logs
- Logs de terminal
- Logs de sistema
- Auditoria de ações

### 7. Configurações
- APIs externas (LibreNMS, Zabbix, phpIPAM, Grafana, IXC, GROQ)
- Temas e personalização
- Métricas e thresholds
- Backup do sistema
- Integração com GitHub

### 8. Links Externos
- Acesso rápido aos apps integrados
- Abertura em nova aba ou iframe

### 9. Mapas
- Visualização geográfica de equipamentos
- Integração com dados de todos os apps
- Status em tempo real no mapa

## Suporte a Vendors

| Vendor | Tipos Suportados | Protocolos |
|--------|------------------|------------|
| Juniper | Switch, Router, Firewall | SNMP, SSH, NETCONF |
| Huawei | Switch, Router, OLT, ONU | SNMP, SSH, Telnet |
| FiberHome | OLT, ONU | SNMP, Telnet |
| Cisco | Switch, Router, Firewall | SNMP, SSH |
| Mikrotik | Router, Switch | SNMP, SSH, API |
| Ubiquiti | Switch, AP, Router | SNMP, SSH |
| Dell | Switch, Server | SNMP, SSH |
| HP/HPE | Switch, Server | SNMP, SSH |

## Documentação

- [Manual de Instalação Completo](./INSTALLATION.md)
- [Configuração de Integrações](./INTEGRATIONS.md)
- [API Reference](./API.md)
- [Troubleshooting](./TROUBLESHOOTING.md)

## Repositório

Este projeto será disponibilizado em repositório Git para versionamento e backup.

## Licença

Propriedade intelectual - Uso comercial planejado.

---

**Versão**: 1.0.0  
**Última Atualização**: Março 2026
