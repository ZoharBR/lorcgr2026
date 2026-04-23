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
  Activity
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
}

const menuItems = [
  { id: 'dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { id: 'inventory', label: 'Inventário', icon: Server },
  { id: 'terminal', label: 'Terminal SSH', icon: Terminal },
  { id: 'backups', label: 'Backups', icon: HardDrive },
  { id: 'audit', label: 'Auditoria', icon: FileText },
];

const externalLinks = [
  { id: 'librenms', label: 'LibreNMS', url: 'http://45.71.242.131:8081/', icon: Activity },
  { id: 'phpipam', label: 'PHPIPAM', url: 'http://45.71.242.131:9100/', icon: Server },
];

export default function Sidebar({ activeTab, onTabChange, serverHealth }: SidebarProps) {
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
          <SheetContent side="left" className="w-64 p-0">
            <SidebarContent
              activeTab={activeTab}
              onTabChange={onTabChange}
              collapsed={false}
              darkMode={darkMode}
              setDarkMode={setDarkMode}
              serverHealth={serverHealth}
            />
          </SheetContent>
        </Sheet>
        
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-primary flex items-center justify-center">
            <Activity className="h-5 w-5 text-primary-foreground" />
          </div>
          <span className="font-bold">LOR CGR</span>
        </div>

        <Button variant="ghost" size="icon">
          <Bell className="h-5 w-5" />
        </Button>
      </div>

      {/* Desktop Sidebar */}
      <div
        className={cn(
          "hidden lg:flex flex-col h-screen fixed left-0 top-0 z-40 bg-background border-r transition-all duration-300",
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
        />
        
        {/* Collapse Button */}
        <Button
          variant="ghost"
          size="icon"
          className="absolute -right-3 top-20 h-6 w-6 rounded-full border bg-background shadow-md"
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
}

function SidebarContent({
  activeTab,
  onTabChange,
  collapsed,
  darkMode,
  setDarkMode,
  serverHealth,
}: SidebarContentProps) {
  return (
    <div className="flex flex-col h-full">
      {/* Logo */}
      <div className="h-14 flex items-center justify-between px-4 border-b">
        {!collapsed && (
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-primary flex items-center justify-center">
              <Activity className="h-5 w-5 text-primary-foreground" />
            </div>
            <div>
              <div className="font-bold">LOR CGR</div>
              <div className="text-xs text-muted-foreground">v1.0.0</div>
            </div>
          </div>
        )}
        {collapsed && (
          <div className="w-8 h-8 rounded-lg bg-primary flex items-center justify-center mx-auto">
            <Activity className="h-5 w-5 text-primary-foreground" />
          </div>
        )}
      </div>

      {/* Navigation */}
      <nav className="flex-1 py-4 px-2 space-y-1 overflow-y-auto">
        {menuItems.map((item) => (
          <button
            key={item.id}
            onClick={() => onTabChange(item.id)}
            className={cn(
              "w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition-colors",
              activeTab === item.id
                ? "bg-primary text-primary-foreground"
                : "hover:bg-muted text-muted-foreground hover:text-foreground"
            )}
          >
            <item.icon className="h-5 w-5 flex-shrink-0" />
            {!collapsed && <span>{item.label}</span>}
          </button>
        ))}

        {!collapsed && (
          <div className="pt-4 pb-2">
            <div className="px-3 text-xs font-semibold text-muted-foreground uppercase tracking-wider">
              Integrações
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
              "w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition-colors hover:bg-muted text-muted-foreground hover:text-foreground",
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
        <div className="px-3 py-2 border-t">
          <div className="text-xs font-semibold text-muted-foreground mb-2">
            Saúde do Servidor
          </div>
          <div className="space-y-1">
            <div className="flex items-center justify-between text-xs">
              <span>CPU</span>
              <span className={serverHealth.cpu > 80 ? 'text-red-500' : 'text-green-500'}>
                {serverHealth.cpu.toFixed(1)}%
              </span>
            </div>
            <div className="flex items-center justify-between text-xs">
              <span>RAM</span>
              <span className={serverHealth.ram > 80 ? 'text-red-500' : 'text-green-500'}>
                {serverHealth.ram.toFixed(1)}%
              </span>
            </div>
            <div className="flex items-center justify-between text-xs">
              <span>Disco</span>
              <span className={serverHealth.disk > 80 ? 'text-red-500' : 'text-green-500'}>
                {serverHealth.disk.toFixed(1)}%
              </span>
            </div>
          </div>
        </div>
      )}

      {/* User Menu */}
      <div className="p-2 border-t">
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <button
              className={cn(
                "w-full flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-muted transition-colors",
                collapsed && "justify-center"
              )}
            >
              <Avatar className="h-8 w-8">
                <AvatarImage src="/avatar.png" />
                <AvatarFallback className="bg-primary text-primary-foreground text-xs">
                  LE
                </AvatarFallback>
              </Avatar>
              {!collapsed && (
                <div className="text-left">
                  <div className="text-sm font-medium">Leonardo</div>
                  <div className="text-xs text-muted-foreground">Admin</div>
                </div>
              )}
            </button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="w-56">
            <DropdownMenuLabel>Minha Conta</DropdownMenuLabel>
            <DropdownMenuSeparator />
            <DropdownMenuItem onClick={() => setDarkMode(!darkMode)}>
              {darkMode ? (
                <Sun className="h-4 w-4 mr-2" />
              ) : (
                <Moon className="h-4 w-4 mr-2" />
              )}
              {darkMode ? 'Modo Claro' : 'Modo Escuro'}
            </DropdownMenuItem>
            <DropdownMenuItem>
              <Settings className="h-4 w-4 mr-2" />
              Configurações
            </DropdownMenuItem>
            <DropdownMenuItem>
              <HelpCircle className="h-4 w-4 mr-2" />
              Ajuda
            </DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem className="text-red-500">
              <LogOut className="h-4 w-4 mr-2" />
              Sair
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
    </div>
  );
}
