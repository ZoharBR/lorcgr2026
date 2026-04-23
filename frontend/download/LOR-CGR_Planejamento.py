from reportlab.lib.pagesizes import A4
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_LEFT, TA_CENTER, TA_JUSTIFY
from reportlab.lib import colors
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfbase.pdfmetrics import registerFontFamily
import os

# Register fonts
pdfmetrics.registerFont(TTFont('SimHei', '/usr/share/fonts/truetype/chinese/SimHei.ttf'))
pdfmetrics.registerFont(TTFont('Times New Roman', '/usr/share/fonts/truetype/english/Times-New-Roman.ttf'))
pdfmetrics.registerFont(TTFont('DejaVuSans', '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'))
registerFontFamily('SimHei', normal='SimHei', bold='SimHei')
registerFontFamily('Times New Roman', normal='Times New Roman', bold='Times New Roman')

# Create document
doc = SimpleDocTemplate(
    "/home/z/my-project/download/LOR-CGR_Especificacao.pdf",
    pagesize=A4,
    title="LOR-CGR Especificacao",
    author='Z.ai',
    creator='Z.ai',
    subject='Especificacao completa do sistema LOR-CGR'
)

styles = getSampleStyleSheet()

# Custom styles
title_style = ParagraphStyle(
    name='TitleStyle',
    fontName='Times New Roman',
    fontSize=28,
    leading=34,
    alignment=TA_CENTER,
    spaceAfter=20
)

heading1_style = ParagraphStyle(
    name='Heading1Style',
    fontName='Times New Roman',
    fontSize=18,
    leading=22,
    alignment=TA_LEFT,
    spaceBefore=20,
    spaceAfter=12
)

heading2_style = ParagraphStyle(
    name='Heading2Style',
    fontName='Times New Roman',
    fontSize=14,
    leading=18,
    alignment=TA_LEFT,
    spaceBefore=15,
    spaceAfter=8
)

body_style = ParagraphStyle(
    name='BodyStyle',
    fontName='Times New Roman',
    fontSize=11,
    leading=16,
    alignment=TA_JUSTIFY,
    spaceAfter=8
)

table_header_style = ParagraphStyle(
    name='TableHeader',
    fontName='Times New Roman',
    fontSize=10,
    textColor=colors.white,
    alignment=TA_CENTER
)

table_cell_style = ParagraphStyle(
    name='TableCell',
    fontName='Times New Roman',
    fontSize=9,
    alignment=TA_LEFT
)

story = []

# Cover Page
story.append(Spacer(1, 100))
story.append(Paragraph("<b>LOR-CGR</b>", title_style))
story.append(Spacer(1, 20))
story.append(Paragraph("<b>Network Management System</b>", ParagraphStyle(
    name='Subtitle',
    fontName='Times New Roman',
    fontSize=18,
    alignment=TA_CENTER
)))
story.append(Spacer(1, 40))
story.append(Paragraph("Especificacao Completa do Projeto", ParagraphStyle(
    name='Subtitle2',
    fontName='Times New Roman',
    fontSize=14,
    alignment=TA_CENTER
)))
story.append(Spacer(1, 60))
story.append(Paragraph("Versao 2.0 - Reestruturacao Completa", ParagraphStyle(
    name='Version',
    fontName='Times New Roman',
    fontSize=12,
    alignment=TA_CENTER
)))
story.append(Paragraph("21 de Marco de 2026", ParagraphStyle(
    name='Date',
    fontName='Times New Roman',
    fontSize=12,
    alignment=TA_CENTER
)))
story.append(PageBreak())

# Table of Contents
story.append(Paragraph("<b>Sumario</b>", heading1_style))
story.append(Spacer(1, 12))
toc_items = [
    "1. Visao Geral do Projeto",
    "2. Estrutura do Menu",
    "3. Arquitetura do Sistema",
    "4. Banco de Dados",
    "5. Integracoes Externas",
    "6. IA Integrada",
    "7. Dashboard Customizavel",
    "8. Sistema de Mapas",
    "9. Transferencia de Arquivos",
    "10. Proximos Passos"
]
for item in toc_items:
    story.append(Paragraph(item, body_style))
story.append(PageBreak())

# Section 1: Visao Geral
story.append(Paragraph("<b>1. Visao Geral do Projeto</b>", heading1_style))
story.append(Paragraph("""
O LOR-CGR e um sistema completo de gerenciamento de rede que integra multiplas ferramentas 
de monitoramento e gestao em uma unica interface. O sistema sera reconstruido do zero com 
uma arquitetura limpa e modular, permitindo facil manutencao e expansao futura.
""", body_style))
story.append(Spacer(1, 12))

story.append(Paragraph("<b>1.1 Objetivos Principais</b>", heading2_style))
objectives = [
    "- Interface unificada para todas as ferramentas de rede",
    "- Integracao total entre LibreNMS, phpIPAM, Zabbix, Grafana e Nexterm",
    "- Sistema de IA para analise e sugestoes automaticas",
    "- Dashboard customizavel com widgets",
    "- Mapas interativos com geolocalizacao",
    "- Backups automatizados e agendados",
    "- Sistema de usuarios com permissoes granulares",
    "- Logs completos de todas as acoes"
]
for obj in objectives:
    story.append(Paragraph(obj, body_style))
story.append(Spacer(1, 12))

story.append(Paragraph("<b>1.2 Tecnologias Escolhidas</b>", heading2_style))

tech_data = [
    [Paragraph('<b>Categoria</b>', table_header_style), Paragraph('<b>Tecnologia</b>', table_header_style), Paragraph('<b>Motivo</b>', table_header_style)],
    [Paragraph('Frontend', table_cell_style), Paragraph('Next.js 16 + React 19', table_cell_style), Paragraph('SSR, App Router, performance', table_cell_style)],
    [Paragraph('Backend', table_cell_style), Paragraph('Django REST Framework', table_cell_style), Paragraph('API robusta, ORM maduro', table_cell_style)],
    [Paragraph('Database', table_cell_style), Paragraph('PostgreSQL', table_cell_style), Paragraph('Multi-tenant, performance', table_cell_style)],
    [Paragraph('Terminal', table_cell_style), Paragraph('Nexterm (Docker)', table_cell_style), Paragraph('SSH/VNC/RDP pronto', table_cell_style)],
    [Paragraph('IA', table_cell_style), Paragraph('Groq API (Llama 3.1)', table_cell_style), Paragraph('Gratuito, rapido, 128K ctx', table_cell_style)],
    [Paragraph('Mapas', table_cell_style), Paragraph('OpenStreetMap + Leaflet', table_cell_style), Paragraph('100% gratuito, ilimitado', table_cell_style)],
    [Paragraph('Web Server', table_cell_style), Paragraph('Nginx', table_cell_style), Paragraph('Proxy reverso, SSL', table_cell_style)],
]

tech_table = Table(tech_data, colWidths=[100, 150, 180])
tech_table.setStyle(TableStyle([
    ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#1F4E79')),
    ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
    ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
    ('FONTNAME', (0, 0), (-1, -1), 'Times New Roman'),
    ('FONTSIZE', (0, 0), (-1, -1), 9),
    ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
    ('TOPPADDING', (0, 0), (-1, -1), 8),
    ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
    ('BACKGROUND', (0, 1), (-1, -1), colors.HexColor('#F5F5F5')),
    ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#F5F5F5')]),
]))
story.append(tech_table)
story.append(PageBreak())

# Section 2: Menu Structure
story.append(Paragraph("<b>2. Estrutura do Menu</b>", heading1_style))
story.append(Paragraph("""
O menu lateral tera navegacao clara e intuitiva, com todos os modulos principais 
disponiveis em um clique. Abaixo esta a estrutura completa definida pelo usuario:
""", body_style))
story.append(Spacer(1, 12))

menu_data = [
    [Paragraph('<b>Menu</b>', table_header_style), Paragraph('<b>Submenu</b>', table_header_style), Paragraph('<b>Funcionalidades</b>', table_header_style)],
    [Paragraph('Dashboard', table_cell_style), Paragraph('-', table_cell_style), Paragraph('Visao geral, graficos, status customizavel', table_cell_style)],
    [Paragraph('Equipamentos', table_cell_style), Paragraph('Redes, Servidores', table_cell_style), Paragraph('Lista com ping/cores, SSH/Telnet/SNMP, sync LibreNMS/Zabbix', table_cell_style)],
    [Paragraph('Terminal', table_cell_style), Paragraph('-', table_cell_style), Paragraph('Nexterm integrado (SSH/VNC/RDP)', table_cell_style)],
    [Paragraph('Backups', table_cell_style), Paragraph('-', table_cell_style), Paragraph('Automaticos, em grupos, manuais por equipamento', table_cell_style)],
    [Paragraph('Usuarios', table_cell_style), Paragraph('-', table_cell_style), Paragraph('ADMIN, NOC, VIEW com permissoes', table_cell_style)],
    [Paragraph('Logs', table_cell_style), Paragraph('-', table_cell_style), Paragraph('Logs de terminal, acoes do sistema', table_cell_style)],
    [Paragraph('Configuracoes', table_cell_style), Paragraph('APIs, Temas, Metricas', table_cell_style), Paragraph('LibreNMS, phpIPAM, Zabbix, IXC, Groq', table_cell_style)],
    [Paragraph('Configuracoes', table_cell_style), Paragraph('Git Backup', table_cell_style), Paragraph('Backup do codigo no GitHub', table_cell_style)],
    [Paragraph('Configuracoes', table_cell_style), Paragraph('Sistema', table_cell_style), Paragraph('Backup/Restore completo', table_cell_style)],
    [Paragraph('Links Externos', table_cell_style), Paragraph('-', table_cell_style), Paragraph('LibreNMS, Zabbix, phpIPAM, Grafana, Nexterm', table_cell_style)],
]

menu_table = Table(menu_data, colWidths=[100, 100, 230])
menu_table.setStyle(TableStyle([
    ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#1F4E79')),
    ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
    ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
    ('FONTNAME', (0, 0), (-1, -1), 'Times New Roman'),
    ('FONTSIZE', (0, 0), (-1, -1), 9),
    ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
    ('TOPPADDING', (0, 0), (-1, -1), 8),
    ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
    ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#F5F5F5')]),
]))
story.append(menu_table)
story.append(Spacer(1, 12))

story.append(Paragraph("<b>2.1 Cores de Status Ping</b>", heading2_style))
ping_data = [
    [Paragraph('<b>Latencia</b>', table_header_style), Paragraph('<b>Cor</b>', table_header_style), Paragraph('<b>Descricao</b>', table_header_style)],
    [Paragraph('< 10ms', table_cell_style), Paragraph('Verde (#22C55E)', table_cell_style), Paragraph('Excelente conectividade', table_cell_style)],
    [Paragraph('11-30ms', table_cell_style), Paragraph('Amarelo (#EAB308)', table_cell_style), Paragraph('Conectividade boa', table_cell_style)],
    [Paragraph('> 30ms', table_cell_style), Paragraph('Laranja (#F97316)', table_cell_style), Paragraph('Latencia elevada', table_cell_style)],
    [Paragraph('Offline', table_cell_style), Paragraph('Vermelho (#EF4444) piscando', table_cell_style), Paragraph('Dispositivo indisponivel', table_cell_style)],
]

ping_table = Table(ping_data, colWidths=[100, 150, 180])
ping_table.setStyle(TableStyle([
    ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#1F4E79')),
    ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
    ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
    ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#F5F5F5')]),
    ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
    ('TOPPADDING', (0, 0), (-1, -1), 8),
]))
story.append(ping_table)
story.append(PageBreak())

# Section 3: Architecture
story.append(Paragraph("<b>3. Arquitetura do Sistema</b>", heading1_style))
story.append(Paragraph("""
A arquitetura foi projetada para ser modular e escalavel. Cada componente tem 
responsabilidade unica e pode ser desenvolvido/testado independentemente.
""", body_style))
story.append(Spacer(1, 12))

story.append(Paragraph("<b>3.1 Estrutura de Diretorios</b>", heading2_style))
story.append(Paragraph("""
/opt/lorcgr/<br/>
├── backend/           # Django REST API<br/>
│   ├── api/           # Endpoints REST<br/>
│   ├── integrations/  # LibreNMS, phpIPAM, Zabbix, Grafana<br/>
│   ├── ai/            # Modulo de IA com Groq<br/>
│   └── models/        # Models Django<br/>
├── frontend/          # Next.js 16 App Router<br/>
│   ├── app/           # Pginas (App Router)<br/>
│   ├── components/    # Componentes React organizados<br/>
│   ├── lib/           # API clients e utilidades<br/>
│   └── hooks/         # React hooks customizados<br/>
├── nginx/             # Configuracoes nginx<br/>
├── docker/            # Docker compose files<br/>
└── scripts/           # Scripts de deploy e backup<br/>
""", ParagraphStyle(name='Code', fontName='DejaVuSans', fontSize=9, leading=12)))
story.append(Spacer(1, 12))

story.append(Paragraph("<b>3.2 Fluxo de Dados</b>", heading2_style))
story.append(Paragraph("""
1. Usuario acessa interface Next.js (porta 80)<br/>
2. Next.js chama API Django (porta 8000)<br/>
3. Django consulta PostgreSQL e APIs externas<br/>
4. Integracoes buscam dados de LibreNMS, phpIPAM, Zabbix<br/>
5. IA analisa configuracoes e sugere acoes<br/>
6. Nexterm fornece acesso terminal (porta 6989)<br/>
7. Grafana embeda dashboards externos<br/>
""", body_style))
story.append(PageBreak())

# Section 4: Database
story.append(Paragraph("<b>4. Banco de Dados</b>", heading1_style))
story.append(Paragraph("""
Cada sistema precisa de seu proprio banco de dados devido a conflitos de schema 
e isolamento de dados. O PostgreSQL sera o banco principal para todos os sistemas.
""", body_style))
story.append(Spacer(1, 12))

db_data = [
    [Paragraph('<b>Sistema</b>', table_header_style), Paragraph('<b>Database</b>', table_header_style), Paragraph('<b>Tipo</b>', table_header_style)],
    [Paragraph('LOR-CGR (Django)', table_cell_style), Paragraph('lorcgr_db', table_cell_style), Paragraph('PostgreSQL', table_cell_style)],
    [Paragraph('LibreNMS', table_cell_style), Paragraph('librenms_db', table_cell_style), Paragraph('MySQL/PostgreSQL', table_cell_style)],
    [Paragraph('phpIPAM', table_cell_style), Paragraph('phpipam_db', table_cell_style), Paragraph('MySQL/PostgreSQL', table_cell_style)],
    [Paragraph('Zabbix', table_cell_style), Paragraph('zabbix_db', table_cell_style), Paragraph('PostgreSQL', table_cell_style)],
    [Paragraph('Grafana', table_cell_style), Paragraph('grafana_db', table_cell_style), Paragraph('PostgreSQL', table_cell_style)],
    [Paragraph('Nexterm', table_cell_style), Paragraph('SQLite (container)', table_cell_style), Paragraph('SQLite', table_cell_style)],
]

db_table = Table(db_data, colWidths=[150, 150, 130])
db_table.setStyle(TableStyle([
    ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#1F4E79')),
    ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
    ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
    ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#F5F5F5')]),
    ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
    ('TOPPADDING', (0, 0), (-1, -1), 8),
]))
story.append(db_table)
story.append(Spacer(1, 12))

story.append(Paragraph("<b>4.1 Modelo de Dados Principal (LOR-CGR)</b>", heading2_style))
models_text = """
- <b>devices_device</b>: Equipamentos de rede (hostname, ip, vendor, modelo, SSH/SNMP configs)<br/>
- <b>devices_backup</b>: Backups dos equipamentos (arquivo, data, metodo)<br/>
- <b>users_user</b>: Usuarios com permissoes (ADMIN, NOC, VIEW)<br/>
- <b>audit_log</b>: Logs de todas as acoes (usuario, acao, data, dispositivo)<br/>
- <b>terminal_session</b>: Sessoes de terminal (inicio, fim, comandos)<br/>
- <b>settings_setting</b>: Configuracoes do sistema (chave, valor)<br/>
- <b>maps_map</b>: Mapas personalizados (nome, configuracao, widgets)<br/>
"""
story.append(Paragraph(models_text, body_style))
story.append(PageBreak())

# Section 5: Integrations
story.append(Paragraph("<b>5. Integracoes Externas</b>", heading1_style))
story.append(Paragraph("""
O LOR-CGR integra com todas as ferramentas existentes via API, permitindo 
visualizar e gerenciar tudo em um unico lugar.
""", body_style))
story.append(Spacer(1, 12))

int_data = [
    [Paragraph('<b>Sistema</b>', table_header_style), Paragraph('<b>Integracao</b>', table_header_style), Paragraph('<b>Dados Sincronizados</b>', table_header_style)],
    [Paragraph('LibreNMS', table_cell_style), Paragraph('API REST', table_cell_style), Paragraph('Dispositivos, status, alertas, portas, trafego', table_cell_style)],
    [Paragraph('phpIPAM', table_cell_style), Paragraph('API REST', table_cell_style), Paragraph('Subnets, IPs, VLANs, dispositivos', table_cell_style)],
    [Paragraph('Zabbix', table_cell_style), Paragraph('API JSON-RPC', table_cell_style), Paragraph('Alertas, metricas, triggers, graficos', table_cell_style)],
    [Paragraph('Grafana', table_cell_style), Paragraph('Embed + API', table_cell_style), Paragraph('Dashboards, paineis, graficos', table_cell_style)],
    [Paragraph('Nexterm', table_cell_style), Paragraph('Iframe + API', table_cell_style), Paragraph('Sessoes SSH/VNC/RDP, credenciais', table_cell_style)],
]

int_table = Table(int_data, colWidths=[100, 100, 230])
int_table.setStyle(TableStyle([
    ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#1F4E79')),
    ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
    ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
    ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#F5F5F5')]),
    ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
    ('TOPPADDING', (0, 0), (-1, -1), 8),
]))
story.append(int_table)
story.append(Spacer(1, 12))

story.append(Paragraph("<b>5.1 Fluxo de Sincronizacao</b>", heading2_style))
story.append(Paragraph("""
1. A cada 5 minutos, Django consulta APIs externas<br/>
2. Novos dispositivos sao adicionados automaticamente<br/>
3. Status sao atualizados em tempo real<br/>
4. Alertas sao agregados e exibidos no dashboard<br/>
5. Dados de IPAM enriquecem informacoes de equipamentos<br/>
""", body_style))
story.append(PageBreak())

# Section 6: AI Integration
story.append(Paragraph("<b>6. IA Integrada</b>", heading1_style))
story.append(Paragraph("""
O sistema contara com IA para analise de rede, sugestoes de configuracao 
e assistencia ao operador. Groq foi escolhido como provedor principal.
""", body_style))
story.append(Spacer(1, 12))

story.append(Paragraph("<b>6.1 Provedores de IA</b>", heading2_style))
ai_data = [
    [Paragraph('<b>Provedor</b>', table_header_style), Paragraph('<b>Modelo</b>', table_header_style), Paragraph('<b>Limite Gratis</b>', table_header_style), Paragraph('<b>Uso</b>', table_header_style)],
    [Paragraph('Groq (Principal)', table_cell_style), Paragraph('Llama 3.1 70B', table_cell_style), Paragraph('14K tokens/min', table_cell_style), Paragraph('Alertas, comandos', table_cell_style)],
    [Paragraph('Google Gemini', table_cell_style), Paragraph('Gemini Flash', table_cell_style), Paragraph('60 req/min', table_cell_style), Paragraph('Analise de logs', table_cell_style)],
    [Paragraph('Together AI', table_cell_style), Paragraph('Llama 3.1', table_cell_style), Paragraph('$1/mes credito', table_cell_style), Paragraph('Backup', table_cell_style)],
]

ai_table = Table(ai_data, colWidths=[110, 110, 100, 110])
ai_table.setStyle(TableStyle([
    ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#1F4E79')),
    ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
    ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
    ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#F5F5F5')]),
    ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
    ('TOPPADDING', (0, 0), (-1, -1), 8),
]))
story.append(ai_table)
story.append(Spacer(1, 12))

story.append(Paragraph("<b>6.2 Funcionalidades da IA</b>", heading2_style))
ai_features = [
    "- Analise de configuracoes de equipamentos e sugestoes de otimizacao",
    "- Deteccao automatica de problemas e anomalias na rede",
    "- Geracao de comandos para troubleshooting",
    "- Resumo de logs e alertas",
    "- Chat para consultas sobre a rede",
    "- Sugestoes de backup e manutencao preventiva"
]
for feat in ai_features:
    story.append(Paragraph(feat, body_style))
story.append(Spacer(1, 12))

story.append(Paragraph("<b>6.3 Acesso da IA aos Dados</b>", heading2_style))
story.append(Paragraph("""
A IA tera acesso de leitura (VIEW) a todas as configuracoes de equipamentos, 
permitindo analise completa da rede. O acesso sera feito via API interna do Django, 
com logs de todas as consultas realizadas.
""", body_style))
story.append(PageBreak())

# Section 7: Dashboard
story.append(Paragraph("<b>7. Dashboard Customizavel</b>", heading1_style))
story.append(Paragraph("""
O dashboard sera totalmente customizavel, permitindo ao usuario escolher 
quais widgets exibir, seu tamanho e posicao.
""", body_style))
story.append(Spacer(1, 12))

story.append(Paragraph("<b>7.1 Widgets Disponiveis</b>", heading2_style))
widgets_data = [
    [Paragraph('<b>Widget</b>', table_header_style), Paragraph('<b>Descricao</b>', table_header_style)],
    [Paragraph('Status de Rede', table_cell_style), Paragraph('Grafico de dispositivos online/offline', table_cell_style)],
    [Paragraph('Alertas Ativos', table_cell_style), Paragraph('Lista de alertas do LibreNMS/Zabbix', table_cell_style)],
    [Paragraph('Trafego de Rede', table_cell_style), Paragraph('Grafico de banda passante', table_cell_style)],
    [Paragraph('Backups Recentes', table_cell_style), Paragraph('Status dos ultimos backups', table_cell_style)],
    [Paragraph('Sessoes Ativas', table_cell_style), Paragraph('Usuarios conectados no terminal', table_cell_style)],
    [Paragraph('Mapa de Rede', table_cell_style), Paragraph('Mapa geografico com dispositivos', table_cell_style)],
    [Paragraph('Metricas de CPU/RAM', table_cell_style), Paragraph('Uso de recursos dos servidores', table_cell_style)],
    [Paragraph('Log de Acoes', table_cell_style), Paragraph('Ultimas acoes dos usuarios', table_cell_style)],
]

widgets_table = Table(widgets_data, colWidths=[150, 280])
widgets_table.setStyle(TableStyle([
    ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#1F4E79')),
    ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
    ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
    ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#F5F5F5')]),
    ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
    ('TOPPADDING', (0, 0), (-1, -1), 8),
]))
story.append(widgets_table)
story.append(PageBreak())

# Section 8: Maps
story.append(Paragraph("<b>8. Sistema de Mapas</b>", heading1_style))
story.append(Paragraph("""
O modulo de mapas permitira criar visualizacoes geograficas da rede, 
integrando dados de todas as fontes externas.
""", body_style))
story.append(Spacer(1, 12))

story.append(Paragraph("<b>8.1 Tipos de Fundo</b>", heading2_style))
story.append(Paragraph("""
- <b>Estatico</b>: Imagem personalizada carregada pelo usuario<br/>
- <b>Foto</b>: Foto de satelite ou mapa estatico<br/>
- <b>Geo Localizacao</b>: Mapa real estilo Google Maps usando OpenStreetMap (gratuito)<br/>
""", body_style))
story.append(Spacer(1, 12))

story.append(Paragraph("<b>8.2 Fontes de Dados para Mapas</b>", heading2_style))
map_sources = [
    "- LibreNMS: Localizacao de dispositivos, status, portas",
    "- phpIPAM: Subnets, ranges de IP, localizacoes",
    "- Zabbix: Alertas ativos, metricas",
    "- Grafana: Painel de metricas embedados",
    "- Manual: Dispositivos adicionados pelo usuario"
]
for src in map_sources:
    story.append(Paragraph(src, body_style))
story.append(Spacer(1, 12))

story.append(Paragraph("<b>8.3 Recursos do Mapa</b>", heading2_style))
story.append(Paragraph("""
- Adicionar dispositivos arrastando e soltando<br/>
- Conectar dispositivos com linhas de link<br/>
- Cores baseadas em status (online/offline/alerta)<br/>
- Popup com detalhes ao clicar<br/>
- Zoom e pan<br/>
- Exportar mapa como imagem<br/>
- Compartilhar mapa com outros usuarios<br/>
""", body_style))
story.append(PageBreak())

# Section 9: File Transfer
story.append(Paragraph("<b>9. Transferencia de Arquivos</b>", heading1_style))
story.append(Paragraph("""
Para resolver problemas de codificacao ao copiar codigo pelo terminal, 
serao implementados multiplos metodos de transferencia.
""", body_style))
story.append(Spacer(1, 12))

story.append(Paragraph("<b>9.1 Metodos Disponiveis</b>", heading2_style))
transfer_methods = [
    "- <b>Git Clone</b>: Repositorio GitHub com o codigo atualizado",
    "- <b>Download ZIP</b>: Arquivo ZIP com todo o projeto",
    "- <b>SCP/SFTP</b>: Transferencia direta de arquivos",
    "- <b>Painel Web</b>: Interface para upload de arquivos",
    "- <b>API de Deploy</b>: Endpoint para atualizar arquivos remotamente"
]
for method in transfer_methods:
    story.append(Paragraph(method, body_style))
story.append(Spacer(1, 12))

story.append(Paragraph("<b>9.2 Acesso Remoto do Desenvolvedor</b>", heading2_style))
story.append(Paragraph("""
Para que o desenvolvedor possa ver e analisar o servidor em producao:
<br/><br/>
- <b>SSH Access</b>: Acesso terminal ao servidor<br/>
- <b>Port Forwarding</b>: Tnel para visualizar localhost<br/>
- <b>Logs em Tempo Real</b>: API para leitura de logs<br/>
- <b>Status API</b>: Endpoint com estado de todos os servicos<br/>
""", body_style))
story.append(PageBreak())

# Section 10: Next Steps
story.append(Paragraph("<b>10. Proximos Passos</b>", heading1_style))
story.append(Paragraph("""
Apos aprovacao desta especificacao, o desenvolvimento seguira as seguintes etapas:
""", body_style))
story.append(Spacer(1, 12))

steps_data = [
    [Paragraph('<b>Etapa</b>', table_header_style), Paragraph('<b>Tarefa</b>', table_header_style), Paragraph('<b>Tempo Est.</b>', table_header_style)],
    [Paragraph('1', table_cell_style), Paragraph('Limpar servidor e preparar ambiente', table_cell_style), Paragraph('1 hora', table_cell_style)],
    [Paragraph('2', table_cell_style), Paragraph('Configurar PostgreSQL e bancos', table_cell_style), Paragraph('2 horas', table_cell_style)],
    [Paragraph('3', table_cell_style), Paragraph('Desenvolver backend Django', table_cell_style), Paragraph('8 horas', table_cell_style)],
    [Paragraph('4', table_cell_style), Paragraph('Desenvolver frontend Next.js', table_cell_style), Paragraph('10 horas', table_cell_style)],
    [Paragraph('5', table_cell_style), Paragraph('Integrar LibreNMS/phpIPAM/Zabbix', table_cell_style), Paragraph('4 horas', table_cell_style)],
    [Paragraph('6', table_cell_style), Paragraph('Implementar IA com Groq', table_cell_style), Paragraph('3 horas', table_cell_style)],
    [Paragraph('7', table_cell_style), Paragraph('Desenvolver sistema de mapas', table_cell_style), Paragraph('4 horas', table_cell_style)],
    [Paragraph('8', table_cell_style), Paragraph('Testes e ajustes finais', table_cell_style), Paragraph('4 horas', table_cell_style)],
]

steps_table = Table(steps_data, colWidths=[60, 270, 100])
steps_table.setStyle(TableStyle([
    ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#1F4E79')),
    ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
    ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
    ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#F5F5F5')]),
    ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
    ('TOPPADDING', (0, 0), (-1, -1), 8),
]))
story.append(steps_table)
story.append(Spacer(1, 20))

story.append(Paragraph("<b>Tempo Total Estimado: 36 horas</b>", ParagraphStyle(
    name='Total',
    fontName='Times New Roman',
    fontSize=14,
    alignment=TA_CENTER
)))

# Build PDF
doc.build(story)
print("PDF criado com sucesso!")
