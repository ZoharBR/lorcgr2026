'use client';

import { useState } from 'react';
import {
  LayoutDashboard,
  Server,
  Terminal,
  HardDrive,
  FileText,
  Settings,
  HelpCircle,
  Menu,
  X,
  Bell,
  Sun,
  Moon,
  User,
  LogOut,
  ExternalLink,
  Activity,
  Network,
  Database,
  Key,
  Palette,
  Gauge,
  Github,
  Shield,
  ChevronDown,
  ChevronRight,
  Link2,
  Lock
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Sheet, SheetContent, SheetTrigger } from '@/components/ui/sheet';
import { cn } from '@/lib/utils';

interface SidebarProps {
  activeTab: string;
  onTabChange: (tab: string) => void;
  serverHealth?: {
    cpu: number;
    ram: number;
    disk: number;
  };
  onOpenTerminal?: () => void;
}

// Menu principal com submenus
const menuItems = [
  { id: 'dashboard', label: 'Dashboard', icon: LayoutDashboard },
  {
    id: 'equipments',
    label: 'Equipamentos',
    icon: Server,
    submenu: [
      { id: 'equipments-networks', label: 'Redes', icon: Network },
      { id: 'equipments-servers', label: 'Servidores', icon: Database },
    ]
  },
  { id: 'terminal', label: 'Terminal', icon: Terminal },
  { id: 'backups', label: 'Backups', icon: HardDrive },
  { id: 'users', label: 'Usuários', icon: User },
  { id: 'logs', label: 'Logs', icon: FileText },
  {
    id: 'settings',
    label: 'Configurações',
    icon: Settings,
    submenu: [
      { id: 'settings-apis', label: 'APIs', icon: Key },
      { id: 'settings-themes', label: 'Temas', icon: Palette },
      { id: 'settings-metrics', label: 'Métricas', icon: Gauge },
      { id: 'settings-git', label: 'Git Backup', icon: Github },
      { id: 'settings-system', label: 'Sistema', icon: Shield },
      { id: 'settings-security', label: 'Segurança', icon: Lock },
    ]
  },
];

// Links externos com URLs corretas
const externalLinks = [
  { id: 'librenms', label: 'LibreNMS', url: 'http://45.71.242.131:8080/', icon: Activity },
  { id: 'zabbix', label: 'Zabbix', url: 'http://45.71.242.131:8081/', icon: Server },
  { id: 'phpipam', label: 'phpIPAM', url: 'http://45.71.242.131/phpipam/', icon: Database },
  { id: 'grafana', label: 'Grafana', url: 'http://45.71.242.131/grafana/', icon: Gauge },
  { id: 'nexterm', label: 'Nexterm', url: 'http://45.71.242.131:6989/', icon: Terminal },
];

export default function Sidebar({ activeTab, onTabChange, serverHealth, onOpenTerminal }: SidebarProps) {
  const [collapsed, setCollapsed] = useState(false);
  const [darkMode, setDarkMode] = useState(true);

  return (
    <>
      {/* Mobile Header */}
      <div className="lg:hidden fixed top-0 left-0 right-0 z-50 bg-background border-b h-14 flex items-center justify-between px-4">
        <Sheet>
          <SheetTrigger asChild>
            <Button variant="ghost" size="icon">
              <Menu className="h-5 w-5" />
            </Button>
          </SheetTrigger>
          <SheetContent side="left" className="w-72 p-0">
            <SidebarContent
              activeTab={activeTab}
              onTabChange={onTabChange}
              collapsed={false}
              darkMode={darkMode}
              setDarkMode={setDarkMode}
              serverHealth={serverHealth}
              onOpenTerminal={onOpenTerminal}
            />
          </SheetContent>
        </Sheet>

        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-emerald-500 to-teal-600 flex items-center justify-center">
            <Activity className="h-5 w-5 text-white" />
          </div>
          <span className="font-bold text-lg">LOR-CGR</span>
        </div>

        <Button variant="ghost" size="icon">
          <Bell className="h-5 w-5" />
        </Button>
      </div>

      {/* Desktop Sidebar */}
      <div
        className={cn(
          "hidden lg:flex flex-col h-screen fixed left-0 top-0 z-40 bg-gradient-to-b from-slate-900 to-slate-950 border-r border-slate-800 transition-all duration-300",
          collapsed ? "w-16" : "w-64"
        )}
      >
        <SidebarContent
          activeTab={activeTab}
          onTabChange={onTabChange}
          collapsed={collapsed}
          darkMode={darkMode}
          setDarkMode={setDarkMode}
          serverHealth={serverHealth}
          onOpenTerminal={onOpenTerminal}
        />

        {/* Collapse Button */}
        <Button
          variant="ghost"
          size="icon"
          className="absolute -right-3 top-20 h-6 w-6 rounded-full border border-slate-700 bg-slate-800 text-slate-400 hover:text-white hover:bg-slate-700 shadow-md"
          onClick={() => setCollapsed(!collapsed)}
        >
          {collapsed ? (
            <Menu className="h-3 w-3" />
          ) : (
            <X className="h-3 w-3" />
          )}
        </Button>
      </div>

      {/* Spacer for desktop */}
      <div className={cn("hidden lg:block transition-all duration-300", collapsed ? "w-16" : "w-64")} />
    </>
  );
}

interface SidebarContentProps {
  activeTab: string;
  onTabChange: (tab: string) => void;
  collapsed: boolean;
  darkMode: boolean;
  setDarkMode: (value: boolean) => void;
  serverHealth?: {
    cpu: number;
    ram: number;
    disk: number;
  };
  onOpenTerminal?: () => void;
}

function SidebarContent({
  activeTab,
  onTabChange,
  collapsed,
  darkMode,
  setDarkMode,
  serverHealth,
  onOpenTerminal,
}: SidebarContentProps) {
  const [expandedMenus, setExpandedMenus] = useState<string[]>(['equipments', 'settings']);

  const toggleSubmenu = (menuId: string) => {
    setExpandedMenus(prev =>
      prev.includes(menuId)
        ? prev.filter(id => id !== menuId)
        : [...prev, menuId]
    );
  };

  const handleMenuClick = (item: typeof menuItems[0]) => {
    if (item.submenu) {
      if (!collapsed) {
        toggleSubmenu(item.id);
      }
    } else {
      onTabChange(item.id);
    }
  };

  const isItemActive = (itemId: string) => {
    return activeTab === itemId || activeTab.startsWith(itemId + '-');
  };

  return (
    <div className="flex flex-col h-full bg-gradient-to-b from-slate-900 to-slate-950">
      {/* Logo */}
      <div className="h-16 flex items-center justify-between px-4 border-b border-slate-800">
        {!collapsed && (
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-emerald-500 to-teal-600 flex items-center justify-center shadow-lg shadow-emerald-500/20">
              <Activity className="h-6 w-6 text-white" />
            </div>
            <div>
              <div className="font-bold text-white text-lg">LOR-CGR</div>
              <div className="text-xs text-slate-400">Sistema de Gestão de Rede</div>
            </div>
          </div>
        )}
        {collapsed && (
          <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-emerald-500 to-teal-600 flex items-center justify-center mx-auto shadow-lg shadow-emerald-500/20">
            <Activity className="h-6 w-6 text-white" />
          </div>
        )}
      </div>

      {/* Navigation */}
      <nav className="flex-1 py-4 px-2 space-y-1 overflow-y-auto">
        {menuItems.map((item) => (
          <div key={item.id}>
            <button
              onClick={() => handleMenuClick(item)}
              className={cn(
                "w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition-all duration-200",
                isItemActive(item.id)
                  ? "bg-gradient-to-r from-emerald-600 to-teal-600 text-white shadow-lg shadow-emerald-500/20"
                  : "hover:bg-slate-800 text-slate-400 hover:text-white",
                collapsed && "justify-center"
              )}
            >
              <item.icon className="h-5 w-5 flex-shrink-0" />
              {!collapsed && (
                <>
                  <span className="flex-1 text-left">{item.label}</span>
                  {item.submenu && (
                    expandedMenus.includes(item.id)
                      ? <ChevronDown className="h-4 w-4" />
                      : <ChevronRight className="h-4 w-4" />
                  )}
                </>
              )}
            </button>

            {/* Submenu */}
            {item.submenu && expandedMenus.includes(item.id) && !collapsed && (
              <div className="ml-4 mt-1 space-y-1 border-l border-slate-700 pl-2">
                {item.submenu.map((subitem) => (
                  <button
                    key={subitem.id}
                    onClick={() => onTabChange(subitem.id)}
                    className={cn(
                      "w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm transition-all duration-200",
                      activeTab === subitem.id
                        ? "bg-emerald-600/20 text-emerald-400 border border-emerald-500/30"
                        : "hover:bg-slate-800 text-slate-500 hover:text-slate-300"
                    )}
                  >
                    <subitem.icon className="h-4 w-4 flex-shrink-0" />
                    <span>{subitem.label}</span>
                  </button>
                ))}
              </div>
            )}
          </div>
        ))}

        {/* Separador */}
        {!collapsed && (
          <div className="pt-4 pb-2">
            <div className="px-3 text-xs font-semibold text-slate-500 uppercase tracking-wider flex items-center gap-2">
              <Link2 className="h-3 w-3" />
              Links Externos
            </div>
          </div>
        )}

        {externalLinks.map((link) => (
          <a
            key={link.id}
            href={link.url}
            target="_blank"
            rel="noopener noreferrer"
            className={cn(
              "w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition-all duration-200 hover:bg-slate-800 text-slate-400 hover:text-white",
              collapsed && "justify-center"
            )}
          >
            <link.icon className="h-5 w-5 flex-shrink-0" />
            {!collapsed && (
              <>
                <span className="flex-1 text-left">{link.label}</span>
                <ExternalLink className="h-4 w-4" />
              </>
            )}
          </a>
        ))}
      </nav>

      {/* Server Health */}
      {!collapsed && serverHealth && (
        <div className="px-4 py-3 border-t border-slate-800 bg-slate-900/50">
          <div className="text-xs font-semibold text-slate-400 mb-3 flex items-center gap-2">
            <Activity className="h-3 w-3" />
            Saúde do Servidor
          </div>
          <div className="space-y-2">
            <div className="flex items-center justify-between text-xs">
              <span className="text-slate-500">CPU</span>
              <div className="flex items-center gap-2">
                <div className="w-16 h-1.5 bg-slate-700 rounded-full overflow-hidden">
                  <div
                    className={cn(
                      "h-full rounded-full transition-all",
                      serverHealth.cpu > 80 ? "bg-red-500" : "bg-emerald-500"
                    )}
                    style={{ width: `${serverHealth.cpu}%` }}
                  />
                </div>
                <span className={serverHealth.cpu > 80 ? 'text-red-400' : 'text-emerald-400'}>
                  {serverHealth.cpu.toFixed(0)}%
                </span>
              </div>
            </div>
            <div className="flex items-center justify-between text-xs">
              <span className="text-slate-500">RAM</span>
              <div className="flex items-center gap-2">
                <div className="w-16 h-1.5 bg-slate-700 rounded-full overflow-hidden">
                  <div
                    className={cn(
                      "h-full rounded-full transition-all",
                      serverHealth.ram > 80 ? "bg-red-500" : "bg-emerald-500"
                    )}
                    style={{ width: `${serverHealth.ram}%` }}
                  />
                </div>
                <span className={serverHealth.ram > 80 ? 'text-red-400' : 'text-emerald-400'}>
                  {serverHealth.ram.toFixed(0)}%
                </span>
              </div>
            </div>
            <div className="flex items-center justify-between text-xs">
              <span className="text-slate-500">Disco</span>
              <div className="flex items-center gap-2">
                <div className="w-16 h-1.5 bg-slate-700 rounded-full overflow-hidden">
                  <div
                    className={cn(
                      "h-full rounded-full transition-all",
                      serverHealth.disk > 80 ? "bg-red-500" : "bg-emerald-500"
                    )}
                    style={{ width: `${serverHealth.disk}%` }}
                  />
                </div>
                <span className={serverHealth.disk > 80 ? 'text-red-400' : 'text-emerald-400'}>
                  {serverHealth.disk.toFixed(0)}%
                </span>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* User Menu */}
      <div className="p-3 border-t border-slate-800">
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <button
              className={cn(
                "w-full flex items-center gap-3 px-3 py-2.5 rounded-lg hover:bg-slate-800 transition-colors",
                collapsed && "justify-center"
              )}
            >
              <Avatar className="h-9 w-9 border-2 border-emerald-500/50">
                <AvatarImage src="/avatar.png" />
                <AvatarFallback className="bg-gradient-to-br from-emerald-500 to-teal-600 text-white text-sm font-medium">
                  LE
                </AvatarFallback>
              </Avatar>
              {!collapsed && (
                <div className="text-left">
                  <div className="text-sm font-medium text-white">Leonardo</div>
                  <div className="text-xs text-slate-400">Administrador</div>
                </div>
              )}
            </button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="w-56 bg-slate-900 border-slate-700">
            <DropdownMenuLabel className="text-white">Minha Conta</DropdownMenuLabel>
            <DropdownMenuSeparator className="bg-slate-700" />
            <DropdownMenuItem onClick={() => setDarkMode(!darkMode)} className="text-slate-300 hover:text-white hover:bg-slate-800">
              {darkMode ? (
                <Sun className="h-4 w-4 mr-2" />
              ) : (
                <Moon className="h-4 w-4 mr-2" />
              )}
              {darkMode ? 'Modo Claro' : 'Modo Escuro'}
            </DropdownMenuItem>
            <DropdownMenuItem className="text-slate-300 hover:text-white hover:bg-slate-800">
              <Settings className="h-4 w-4 mr-2" />
              Configurações
            </DropdownMenuItem>
            <DropdownMenuItem className="text-slate-300 hover:text-white hover:bg-slate-800">
              <HelpCircle className="h-4 w-4 mr-2" />
              Ajuda
            </DropdownMenuItem>
            <DropdownMenuSeparator className="bg-slate-700" />
            <DropdownMenuItem className="text-red-400 hover:text-red-300 hover:bg-slate-800">
              <LogOut className="h-4 w-4 mr-2" />
              Sair
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
    </div>
  );
}
