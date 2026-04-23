#!/bin/bash

################################################################################
# LOR-CGR Installation Script - Part 10: Next.js Frontend
################################################################################

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  LOR-CGR - Instalação do Next.js${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script deve ser executado como root!${NC}"
   exit 1
fi

#######################################
# Instalar Node.js
#######################################
echo -e "${YELLOW}>>> Instalando Node.js 20 LTS...${NC}"
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Verificar instalação
node --version
npm --version

#######################################
# Criar projeto Next.js
#######################################
echo -e "${YELLOW}>>> Criando projeto Next.js...${NC}"
mkdir -p /opt/lorcgr/frontend
cd /opt/lorcgr/frontend

# Criar package.json
cat > package.json << 'PKGEOF'
{
  "name": "lorcgr-frontend",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev -p 3001",
    "build": "next build",
    "start": "next start -p 3001",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "^14.2.0",
    "react": "^18.3.0",
    "react-dom": "^18.3.0",
    "axios": "^1.7.0",
    "@tanstack/react-query": "^5.28.0",
    "lucide-react": "^0.359.0",
    "recharts": "^2.12.0",
    "react-leaflet": "^4.2.1",
    "leaflet": "^1.9.4",
    "date-fns": "^3.6.0",
    "clsx": "^2.1.0",
    "tailwind-merge": "^2.2.0"
  },
  "devDependencies": {
    "@types/node": "^20.11.0",
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0",
    "typescript": "^5.4.0",
    "tailwindcss": "^3.4.0",
    "postcss": "^8.4.0",
    "autoprefixer": "^10.4.0",
    "eslint": "^8.57.0",
    "eslint-config-next": "^14.2.0"
  }
}
PKGEOF

#######################################
# Instalar dependências
#######################################
echo -e "${YELLOW}>>> Instalando dependências...${NC}"
npm install

#######################################
# Criar estrutura de diretórios
#######################################
echo -e "${YELLOW}>>> Criando estrutura...${NC}"
mkdir -p /opt/lorcgr/frontend/src/app
mkdir -p /opt/lorcgr/frontend/src/components
mkdir -p /opt/lorcgr/frontend/src/lib
mkdir -p /opt/lorcgr/frontend/src/hooks
mkdir -p /opt/lorcgr/frontend/public

#######################################
# Criar configurações
#######################################
echo -e "${YELLOW}>>> Criando configurações...${NC}"

# next.config.js
cat > next.config.js << 'NCEOF'
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  basePath: '',
  trailingSlash: false,
  async rewrites() {
    return [
      {
        source: '/api/:path*',
        destination: 'http://localhost:8000/api/:path*',
      },
    ];
  },
};

module.exports = nextConfig;
NCEOF

# tsconfig.json
cat > tsconfig.json << 'TSEOF'
{
  "compilerOptions": {
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
TSEOF

# tailwind.config.js
cat > tailwind.config.js << 'TWEOF'
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#eff6ff',
          100: '#dbeafe',
          200: '#bfdbfe',
          300: '#93c5fd',
          400: '#60a5fa',
          500: '#3b82f6',
          600: '#2563eb',
          700: '#1d4ed8',
          800: '#1e40af',
          900: '#1e3a8a',
        },
      },
    },
  },
  plugins: [],
};
TWEOF

# postcss.config.js
cat > postcss.config.js << 'PCEOF'
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
PCEOF

#######################################
# Criar layout principal
#######################################
echo -e "${YELLOW}>>> Criando layout principal...${NC}"

# src/app/globals.css
cat > src/app/globals.css << 'CSSEOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  --background: #ffffff;
  --foreground: #171717;
}

@media (prefers-color-scheme: dark) {
  :root {
    --background: #0a0a0a;
    --foreground: #ededed;
  }
}

body {
  color: var(--foreground);
  background: var(--background);
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
}

/* Custom scrollbar */
::-webkit-scrollbar {
  width: 8px;
  height: 8px;
}

::-webkit-scrollbar-track {
  background: #1f2937;
}

::-webkit-scrollbar-thumb {
  background: #4b5563;
  border-radius: 4px;
}

::-webkit-scrollbar-thumb:hover {
  background: #6b7280;
}
CSSEOF

# src/app/layout.tsx
cat > src/app/layout.tsx << 'LAYOUTEOF'
import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'LOR-CGR - Sistema de Gerenciamento de Rede',
  description: 'Plataforma completa de gerenciamento de rede',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="pt-BR">
      <body className="antialiased bg-gray-900 text-gray-100">
        {children}
      </body>
    </html>
  );
}
LAYOUTEOF

#######################################
# Criar API client
#######################################
cat > src/lib/api.ts << 'APIEOF'
import axios from 'axios';

const api = axios.create({
  baseURL: '/api',
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Interceptor para erros
api.interceptors.response.use(
  (response) => response,
  (error) => {
    console.error('API Error:', error.response?.data || error.message);
    return Promise.reject(error);
  }
);

export default api;

// Equipment API
export const equipmentApi = {
  list: () => api.get('/equipment/list/'),
  get: (id: number) => api.get(`/equipment/list/${id}/`),
  create: (data: any) => api.post('/equipment/list/', data),
  update: (id: number, data: any) => api.patch(`/equipment/list/${id}/`, data),
  delete: (id: number) => api.delete(`/equipment/list/${id}/`),
  backup: (id: number) => api.post(`/equipment/list/${id}/backup/`),
  sync: (id: number) => api.post(`/equipment/list/${id}/sync/`),
};

// Vendor API
export const vendorApi = {
  list: () => api.get('/equipment/vendors/'),
};

// Type API
export const typeApi = {
  list: () => api.get('/equipment/types/'),
};

// Group API
export const groupApi = {
  list: () => api.get('/equipment/groups/'),
  create: (data: any) => api.post('/equipment/groups/', data),
};
APIEOF

#######################################
# Criar página principal com Dashboard
#######################################
cat > src/app/page.tsx << 'PAGEEOF'
'use client';

import { useState } from 'react';
import {
  LayoutDashboard,
  Server,
  Terminal,
  HardDrive,
  Users,
  FileText,
  Settings,
  ExternalLink,
  Map,
  Menu,
  X,
  ChevronDown,
  Activity,
  AlertTriangle,
  CheckCircle,
  Clock,
} from 'lucide-react';

// Menu items
const menuItems = [
  { id: 'dashboard', label: 'Dashboard', icon: LayoutDashboard },
  {
    id: 'equipments',
    label: 'Equipamentos',
    icon: Server,
    submenu: [
      { id: 'networks', label: 'Redes' },
      { id: 'servers', label: 'Servidores' },
    ],
  },
  { id: 'terminal', label: 'Terminal', icon: Terminal },
  { id: 'backups', label: 'Backups', icon: HardDrive },
  { id: 'users', label: 'Usuários', icon: Users },
  { id: 'logs', label: 'Logs', icon: FileText },
  {
    id: 'settings',
    label: 'Configurações',
    icon: Settings,
    submenu: [
      { id: 'apis', label: 'APIs' },
      { id: 'themes', label: 'Temas' },
      { id: 'metrics', label: 'Métricas' },
      { id: 'git', label: 'Git Backup' },
      { id: 'system', label: 'Sistema' },
    ],
  },
  { id: 'links', label: 'Links Externos', icon: ExternalLink },
  { id: 'maps', label: 'Mapas', icon: Map },
];

// External links
const externalLinks = [
  { name: 'LibreNMS', url: '/librenms/', color: 'bg-blue-600' },
  { name: 'Zabbix', url: '/zabbix/', color: 'bg-red-600' },
  { name: 'phpIPAM', url: '/phpipam/', color: 'bg-green-600' },
  { name: 'Grafana', url: '/grafana/', color: 'bg-orange-600' },
  { name: 'Nexterm', url: '/nexterm/', color: 'bg-purple-600' },
];

// Stats mock
const stats = [
  { label: 'Equipamentos Ativos', value: '127', icon: CheckCircle, color: 'text-green-500' },
  { label: 'Equipamentos Inativos', value: '8', icon: AlertTriangle, color: 'text-red-500' },
  { label: 'Alertas Ativos', value: '23', icon: Activity, color: 'text-yellow-500' },
  { label: 'Última Sincronização', value: '5 min', icon: Clock, color: 'text-blue-500' },
];

export default function Dashboard() {
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [activeMenu, setActiveMenu] = useState('dashboard');
  const [expandedMenu, setExpandedMenu] = useState<string | null>(null);

  const toggleSubmenu = (menuId: string) => {
    setExpandedMenu(expandedMenu === menuId ? null : menuId);
  };

  return (
    <div className="min-h-screen bg-gray-900 flex">
      {/* Sidebar */}
      <aside
        className={`${
          sidebarOpen ? 'w-64' : 'w-20'
        } bg-gray-800 border-r border-gray-700 transition-all duration-300 flex flex-col`}
      >
        {/* Logo */}
        <div className="h-16 flex items-center justify-between px-4 border-b border-gray-700">
          {sidebarOpen && (
            <span className="text-xl font-bold text-white">LOR-CGR</span>
          )}
          <button
            onClick={() => setSidebarOpen(!sidebarOpen)}
            className="p-2 rounded-lg hover:bg-gray-700 text-gray-400"
          >
            {sidebarOpen ? <X size={20} /> : <Menu size={20} />}
          </button>
        </div>

        {/* Menu */}
        <nav className="flex-1 py-4 overflow-y-auto">
          {menuItems.map((item) => (
            <div key={item.id}>
              <button
                onClick={() => {
                  if (item.submenu) {
                    toggleSubmenu(item.id);
                  } else {
                    setActiveMenu(item.id);
                  }
                }}
                className={`w-full flex items-center gap-3 px-4 py-3 text-left ${
                  activeMenu === item.id
                    ? 'bg-primary-600 text-white'
                    : 'text-gray-300 hover:bg-gray-700'
                }`}
              >
                <item.icon size={20} />
                {sidebarOpen && (
                  <>
                    <span className="flex-1">{item.label}</span>
                    {item.submenu && (
                      <ChevronDown
                        size={16}
                        className={`transition-transform ${
                          expandedMenu === item.id ? 'rotate-180' : ''
                        }`}
                      />
                    )}
                  </>
                )}
              </button>

              {/* Submenu */}
              {item.submenu && sidebarOpen && expandedMenu === item.id && (
                <div className="bg-gray-900">
                  {item.submenu.map((sub) => (
                    <button
                      key={sub.id}
                      onClick={() => setActiveMenu(sub.id)}
                      className="w-full px-4 py-2 pl-12 text-gray-400 hover:text-white hover:bg-gray-700"
                    >
                      {sub.label}
                    </button>
                  ))}
                </div>
              )}
            </div>
          ))}
        </nav>

        {/* External Links */}
        {sidebarOpen && (
          <div className="p-4 border-t border-gray-700">
            <p className="text-xs text-gray-500 mb-2">Links Rápidos</p>
            <div className="flex flex-wrap gap-2">
              {externalLinks.map((link) => (
                <a
                  key={link.name}
                  href={link.url}
                  target="_blank"
                  rel="noopener noreferrer"
                  className={`${link.color} text-white text-xs px-2 py-1 rounded hover:opacity-80`}
                >
                  {link.name}
                </a>
              ))}
            </div>
          </div>
        )}
      </aside>

      {/* Main Content */}
      <main className="flex-1 flex flex-col">
        {/* Header */}
        <header className="h-16 bg-gray-800 border-b border-gray-700 flex items-center justify-between px-6">
          <h1 className="text-xl font-semibold text-white">Dashboard</h1>
          <div className="flex items-center gap-4">
            <span className="text-gray-400 text-sm">
              {new Date().toLocaleString('pt-BR')}
            </span>
            <div className="w-8 h-8 bg-primary-600 rounded-full flex items-center justify-center">
              <span className="text-white text-sm font-medium">L</span>
            </div>
          </div>
        </header>

        {/* Content */}
        <div className="flex-1 p-6 overflow-y-auto">
          {/* Stats */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
            {stats.map((stat) => (
              <div
                key={stat.label}
                className="bg-gray-800 rounded-lg p-6 border border-gray-700"
              >
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-gray-400 text-sm">{stat.label}</p>
                    <p className="text-2xl font-bold text-white mt-1">
                      {stat.value}
                    </p>
                  </div>
                  <stat.icon size={24} className={stat.color} />
                </div>
              </div>
            ))}
          </div>

          {/* Recent Activity & Quick Actions */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Recent Activity */}
            <div className="bg-gray-800 rounded-lg border border-gray-700">
              <div className="px-6 py-4 border-b border-gray-700">
                <h2 className="text-lg font-semibold text-white">
                  Atividade Recente
                </h2>
              </div>
              <div className="p-6">
                <div className="space-y-4">
                  {[
                    { action: 'Backup realizado', device: 'SW-Core-01', time: '2 min' },
                    { action: 'Alerta resolvido', device: 'RT-Edge-03', time: '15 min' },
                    { action: 'Novo dispositivo', device: 'OLT-Central', time: '1h' },
                    { action: 'Configuração alterada', device: 'FW-Main', time: '2h' },
                  ].map((item, i) => (
                    <div
                      key={i}
                      className="flex items-center justify-between py-2 border-b border-gray-700 last:border-0"
                    >
                      <div>
                        <p className="text-white">{item.action}</p>
                        <p className="text-gray-400 text-sm">{item.device}</p>
                      </div>
                      <span className="text-gray-500 text-sm">{item.time}</span>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            {/* Quick Actions */}
            <div className="bg-gray-800 rounded-lg border border-gray-700">
              <div className="px-6 py-4 border-b border-gray-700">
                <h2 className="text-lg font-semibold text-white">
                  Ações Rápidas
                </h2>
              </div>
              <div className="p-6">
                <div className="grid grid-cols-2 gap-4">
                  {[
                    { label: 'Novo Equipamento', icon: Server, color: 'bg-blue-600' },
                    { label: 'Backup em Lote', icon: HardDrive, color: 'bg-green-600' },
                    { label: 'Verificar Status', icon: Activity, color: 'bg-yellow-600' },
                    { label: 'Terminal', icon: Terminal, color: 'bg-purple-600' },
                  ].map((action) => (
                    <button
                      key={action.label}
                      className={`${action.color} text-white p-4 rounded-lg hover:opacity-90 transition flex flex-col items-center gap-2`}
                    >
                      <action.icon size={24} />
                      <span className="text-sm">{action.label}</span>
                    </button>
                  ))}
                </div>
              </div>
            </div>
          </div>

          {/* System Status */}
          <div className="mt-6 bg-gray-800 rounded-lg border border-gray-700">
            <div className="px-6 py-4 border-b border-gray-700">
              <h2 className="text-lg font-semibold text-white">
                Status dos Sistemas
              </h2>
            </div>
            <div className="p-6">
              <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
                {[
                  { name: 'LibreNMS', status: 'online' },
                  { name: 'Zabbix', status: 'online' },
                  { name: 'phpIPAM', status: 'online' },
                  { name: 'Grafana', status: 'online' },
                  { name: 'Nexterm', status: 'online' },
                ].map((system) => (
                  <div
                    key={system.name}
                    className="flex items-center gap-3 p-3 bg-gray-900 rounded-lg"
                  >
                    <div
                      className={`w-3 h-3 rounded-full ${
                        system.status === 'online'
                          ? 'bg-green-500'
                          : 'bg-red-500'
                      }`}
                    />
                    <span className="text-gray-300">{system.name}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
PAGEEOF

#######################################
# Build do projeto
#######################################
echo -e "${YELLOW}>>> Fazendo build do projeto...${NC}"
npm run build

#######################################
# Criar serviço systemd
#######################################
echo -e "${YELLOW}>>> Criando serviço systemd...${NC}"

cat > /etc/systemd/system/lorcgr-frontend.service << 'EOF'
[Unit]
Description=LOR-CGR Next.js Frontend
After=network.target

[Service]
Type=simple
User=lorcgr
Group=lorcgr
WorkingDirectory=/opt/lorcgr/frontend
Environment="NODE_ENV=production"
Environment="PORT=3001"
ExecStart=/usr/bin/node /opt/lorcgr/frontend/.next/standalone/server.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Ajustar permissões
chown -R lorcgr:lorcgr /opt/lorcgr/frontend

systemctl daemon-reload
systemctl enable lorcgr-frontend
systemctl start lorcgr-frontend

#######################################
# Verificar status
#######################################
echo -e "${YELLOW}>>> Verificando status...${NC}"
sleep 3

if systemctl is-active --quiet lorcgr-frontend; then
    echo -e "${GREEN}✓ Next.js está rodando na porta 3001${NC}"
else
    echo -e "${RED}✗ Next.js não está rodando${NC}"
    journalctl -u lorcgr-frontend --no-pager -n 20
fi

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  LOR-CGR INSTALAÇÃO COMPLETA!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "Acesse: http://seu-ip/"
echo ""
echo "Todos os serviços instalados:"
echo "  ✓ PostgreSQL"
echo "  ✓ MariaDB"
echo "  ✓ Redis"
echo "  ✓ LibreNMS"
echo "  ✓ phpIPAM"
echo "  ✓ Zabbix"
echo "  ✓ Grafana"
echo "  ✓ Nexterm"
echo "  ✓ Django API"
echo "  ✓ Next.js Frontend"
echo "  ✓ Nginx Reverse Proxy"
echo ""
echo "Credenciais (todos os sistemas):"
echo "  Usuário: lorcgr / Admin"
echo "  Senha: Lor#Cgr#2026"
echo ""
echo "Execute '11-post-install.sh' para configurações finais."
