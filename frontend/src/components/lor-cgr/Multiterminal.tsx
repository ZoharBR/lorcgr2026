'use client';

import { useState, useEffect, useRef, useCallback } from 'react';
import {
  Plus,
  X,
  Maximize2,
  Minimize2,
  Wifi,
  WifiOff,
  AlertCircle,
  Loader2,
  Terminal as TerminalIcon,
  Download,
  Trash2,
  Clock
} from 'lucide-react';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog';
import { Device } from '@/types/lor-cgr';
import { toast } from 'sonner';
import { Terminal } from '@xterm/xterm';
import { FitAddon } from '@xterm/addon-fit';
import '@xterm/xterm/css/xterm.css';

interface TerminalSession {
  id: string;
  device: Device;
  status: 'connecting' | 'connected' | 'disconnected' | 'error';
  ws: WebSocket | null;
  terminal: Terminal | null;
  fitAddon: FitAddon | null;
  sessionLog: string[];
  startedAt: Date;
}

interface MultiterminalProps {
  devices: Device[];
  sessions?: { id: string; device: Device }[];
  onConnect: (deviceId: number) => void;
  isOpen?: boolean;
  onClose?: () => void;
}

const WS_BASE_URL = 'ws://45.71.242.131:8001';
const API_BASE_URL = 'http://45.71.242.131:8000';

export default function Multiterminal({ devices, sessions = [], onConnect, isOpen = true, onClose }: MultiterminalProps) {
  const [tabs, setTabs] = useState<TerminalSession[]>([]);
  const [activeTabId, setActiveTabId] = useState<string | null>(null);
  const [selectDeviceOpen, setSelectDeviceOpen] = useState(false);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [deleteLogOpen, setDeleteLogOpen] = useState(false);
  const [sessionToDelete, setSessionToDelete] = useState<string | null>(null);

  const containerRefs = useRef<Record<string, HTMLDivElement>>({});
  const initialized = useRef<Record<string, boolean>>({});

  const activeSession = tabs.find(t => t.id === activeTabId);

  // Inicializar terminal quando a aba ativa muda
  useEffect(() => {
    if (!activeTabId || !containerRefs.current[activeTabId]) return;
    if (initialized.current[activeTabId]) return;

    const session = tabs.find(t => t.id === activeTabId);
    if (!session) return;

    // Criar terminal xterm.js
    const terminal = new Terminal({
      theme: {
        background: '#0d1117',
        foreground: '#c9d1d9',
        cursor: '#58a6ff',
        cursorAccent: '#0d1117',
        black: '#484f58',
        red: '#ff7b72',
        green: '#3fb950',
        yellow: '#d29922',
        blue: '#58a6ff',
        magenta: '#bc8cff',
        cyan: '#39c5cf',
        white: '#b1bac4',
        brightBlack: '#6e7681',
        brightRed: '#ffa198',
        brightGreen: '#56d364',
        brightYellow: '#e3b341',
        brightBlue: '#79c0ff',
        brightMagenta: '#d2a8ff',
        brightCyan: '#56d4dd',
        brightWhite: '#f0f6fc',
      },
      fontFamily: '"JetBrains Mono", "Fira Code", "Cascadia Code", Consolas, monospace',
      fontSize: 14,
      lineHeight: 1.2,
      cursorBlink: true,
      cursorStyle: 'block',
      scrollback: 10000,
      allowProposedApi: true,
    });

    const fitAddon = new FitAddon();
    terminal.loadAddon(fitAddon);

    // Abrir terminal no container
    const container = containerRefs.current[activeTabId];
    terminal.open(container);

    // Ajustar tamanho
    setTimeout(() => {
      fitAddon.fit();
    }, 100);

    // Escrever mensagem inicial
    terminal.writeln('\x1b[1;36m╔═══════════════════════════════════════════════════════════════╗\x1b[0m');
    terminal.writeln('\x1b[1;36m║\x1b[0m  \x1b[1;37mLOR-CGR Terminal SSH\x1b[0m - Sessão sendo gravada para auditoria  \x1b[1;36m║\x1b[0m');
    terminal.writeln('\x1b[1;36m╚═══════════════════════════════════════════════════════════════╝\x1b[0m');
    terminal.writeln('');

    if (session.status === 'connected' && session.ws) {
      terminal.writeln(`\x1b[1;32m✓ Conectado a ${session.device.name}\x1b[0m`);
      terminal.writeln(`\x1b[90m  IP: ${session.device.ip}:${session.device.ssh_port || 22}\x1b[0m`);
      terminal.writeln(`\x1b[90m  Usuário: ${session.device.ssh_user || 'N/A'}\x1b[0m`);
      terminal.writeln(`\x1b[90m  Sessão ID: ${session.id}\x1b[0m`);
      terminal.writeln('');
    }

    // Configurar input do terminal - CORRIGIDO para tratar teclas especiais
    terminal.onData((data) => {
      if (session.ws && session.ws.readyState === WebSocket.OPEN) {
        // Enviar dados brutos para o WebSocket
        session.ws.send(JSON.stringify({
          type: 'input',
          data: data
        }));

        // Registrar no log da sessão
        setTabs(prev => prev.map(t => {
          if (t.id === activeTabId) {
            return { ...t, sessionLog: [...t.sessionLog, `[INPUT]: ${JSON.stringify(data)}`] };
          }
          return t;
        }));
      }
    });

    // Configurar resize
    terminal.onResize(({ cols, rows }) => {
      if (session.ws && session.ws.readyState === WebSocket.OPEN) {
        session.ws.send(JSON.stringify({
          type: 'resize',
          cols,
          rows
        }));
      }
    });

    // Salvar referências
    setTabs(prev => prev.map(t =>
      t.id === activeTabId ? { ...t, terminal, fitAddon } : t
    ));

    initialized.current[activeTabId] = true;
  }, [activeTabId, tabs]);

  // Re-ajustar terminal quando muda o tamanho
  useEffect(() => {
    const handleResize = () => {
      const session = tabs.find(t => t.id === activeTabId);
      if (session?.fitAddon) {
        try {
          session.fitAddon.fit();
        } catch {
          // Ignorar erros de fit
        }
      }
    };

    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, [activeTabId, tabs]);

  // Criar nova sessão
  const createSession = useCallback((device: Device) => {
    const tabId = `${device.id}-${Date.now()}`;

    const newSession: TerminalSession = {
      id: tabId,
      device,
      status: 'connecting',
      ws: null,
      terminal: null,
      fitAddon: null,
      sessionLog: [],
      startedAt: new Date(),
    };

    setTabs(prev => [...prev, newSession]);
    setActiveTabId(tabId);
    setSelectDeviceOpen(false);
    initialized.current[tabId] = false;

    // Conectar WebSocket
    try {
      const wsUrl = `${WS_BASE_URL}/ws/terminal/${device.id}/`;
      console.log('Conectando a:', wsUrl);
      const ws = new WebSocket(wsUrl);

      ws.onopen = () => {
        console.log('WebSocket conectado');
        setTabs(prev => prev.map(t =>
          t.id === tabId ? { ...t, status: 'connected', ws } : t
        ));
      };

      ws.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);

          setTabs(prev => {
            const currentSession = prev.find(t => t.id === tabId);
            if (!currentSession) return prev;

            // Registrar output no log
            const logEntry = `[OUTPUT]: ${data.data || data.message || ''}`;

            if (data.type === 'output' && currentSession.terminal) {
              currentSession.terminal.write(data.data);
            } else if (data.type === 'connected' && currentSession.terminal) {
              currentSession.terminal.writeln(`\x1b[1;32m${data.message || data.data}\x1b[0m`);
            } else if (data.type === 'error' && currentSession.terminal) {
              currentSession.terminal.writeln(`\x1b[1;31m${data.message || data.data}\x1b[0m`);
            }

            return prev.map(t =>
              t.id === tabId ? { ...t, sessionLog: [...t.sessionLog, logEntry] } : t
            );
          });
        } catch {
          // Output raw se não for JSON
          setTabs(prev => {
            const session = prev.find(t => t.id === tabId);
            if (session?.terminal) {
              session.terminal.write(event.data);
            }
            return prev.map(t =>
              t.id === tabId ? { ...t, sessionLog: [...t.sessionLog, `[RAW]: ${event.data}`] } : t
            );
          });
        }
      };

      ws.onclose = (event) => {
        console.log('WebSocket fechado:', event.code);
        setTabs(prev => prev.map(t => {
          if (t.id !== tabId) return t;
          if (t.terminal) {
            t.terminal.writeln('');
            t.terminal.writeln(`\x1b[33m⏏ Conexão encerrada (código: ${event.code})\x1b[0m`);
          }
          return { ...t, status: 'disconnected', ws: null };
        }));
      };

      ws.onerror = (err) => {
        console.error('WebSocket erro:', err);
        setTabs(prev => prev.map(t => {
          if (t.id !== tabId) return t;
          if (t.terminal) {
            t.terminal.writeln('\x1b[1;31m✗ Erro na conexão WebSocket\x1b[0m');
            t.terminal.writeln('\x1b[90m  Verifique se o serviço está rodando na porta 8001\x1b[0m');
          }
          return { ...t, status: 'error', ws: null };
        }));
      };

      setTabs(prev => prev.map(t =>
        t.id === tabId ? { ...t, ws } : t
      ));

    } catch (error) {
      console.error('Erro ao criar sessão:', error);
      setTabs(prev => prev.map(t => {
        if (t.id !== tabId) return t;
        return { ...t, status: 'error' };
      }));
    }

    onConnect(device.id);
  }, [onConnect]);

  // Fechar aba
  const closeTab = (tabId: string, e?: React.MouseEvent) => {
    e?.stopPropagation();

    const session = tabs.find(t => t.id === tabId);

    // Salvar log da sessão antes de fechar
    if (session && session.sessionLog.length > 0) {
      saveSessionLog(session);
    }

    // Fechar WebSocket
    if (session?.ws) {
      session.ws.close();
    }

    // Destruir terminal
    if (session?.terminal) {
      session.terminal.dispose();
    }

    // Remover referências
    delete containerRefs.current[tabId];
    delete initialized.current[tabId];

    // Atualizar estado
    setTabs(prev => prev.filter(t => t.id !== tabId));

    if (activeTabId === tabId) {
      const remaining = tabs.filter(t => t.id !== tabId);
      setActiveTabId(remaining.length > 0 ? remaining[0].id : null);
    }
  };

  // Salvar log da sessão no servidor
  const saveSessionLog = async (session: TerminalSession) => {
    try {
      const logData = {
        session_id: session.id,
        device_id: session.device.id,
        device_name: session.device.name,
        started_at: session.startedAt.toISOString(),
        ended_at: new Date().toISOString(),
        log: session.sessionLog.join('\n'),
      };

      await fetch(`${API_BASE_URL}/api/terminal/sessions/save/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(logData),
      });

      console.log('Log da sessão salvo');
    } catch (error) {
      console.error('Erro ao salvar log:', error);
    }
  };

  // Reconectar
  const reconnect = (tabId: string) => {
    const session = tabs.find(t => t.id === tabId);
    if (!session) return;

    // Destruir terminal antigo
    if (session.terminal) {
      session.terminal.dispose();
    }

    initialized.current[tabId] = false;
    createSession(session.device);
  };

  // Download do log da sessão atual
  const downloadSessionLog = () => {
    if (!activeSession) return;

    const logContent = `
========================================
LOR-CGR - Log de Sessão Terminal
========================================
Dispositivo: ${activeSession.device.name}
IP: ${activeSession.device.ip}:${activeSession.device.ssh_port || 22}
Início: ${activeSession.startedAt.toLocaleString()}
Fim: ${new Date().toLocaleString()}
Session ID: ${activeSession.id}
========================================

${activeSession.sessionLog.join('\n')}
`;

    const blob = new Blob([logContent], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `terminal_${activeSession.device.name}_${activeSession.id}.log`;
    a.click();
    URL.revokeObjectURL(url);
    toast.success('Log baixado com sucesso');
  };

  // Deletar log da sessão (apenas admin)
  const deleteSessionLog = async () => {
    if (!sessionToDelete) return;

    try {
      await fetch(`${API_BASE_URL}/api/terminal/sessions/delete/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ session_id: sessionToDelete }),
      });
      toast.success('Log removido');
    } catch (error) {
      toast.error('Erro ao remover log');
    }

    setDeleteLogOpen(false);
    setSessionToDelete(null);
  };

  // Se não está aberto, não renderizar nada
  if (!isOpen) return null;

  return (
    <div className={isFullscreen ? 'fixed inset-0 z-50 bg-background' : ''}>
      <div className={isFullscreen ? 'h-full flex flex-col' : 'space-y-4'}>
        {/* Header */}
        <div className="flex items-center justify-between px-2">
          <div className="flex items-center gap-2">
            <TerminalIcon className="h-6 w-6 text-primary" />
            <h1 className="text-xl font-semibold">Terminal SSH</h1>
            {activeSession && (
              <Badge variant="outline" className="ml-2">
                <Clock className="h-3 w-3 mr-1" />
                {Math.floor((Date.now() - activeSession.startedAt.getTime()) / 60000)} min
              </Badge>
            )}
          </div>
          <div className="flex gap-1">
            {activeSession && (
              <>
                <Button variant="ghost" size="sm" onClick={downloadSessionLog} title="Baixar log">
                  <Download className="h-4 w-4" />
                </Button>
              </>
            )}
            <Button variant="ghost" size="icon" onClick={() => setIsFullscreen(!isFullscreen)}>
              {isFullscreen ? <Minimize2 className="h-4 w-4" /> : <Maximize2 className="h-4 w-4" />}
            </Button>
            {onClose && (
              <Button variant="ghost" size="icon" onClick={onClose}>
                <X className="h-4 w-4" />
              </Button>
            )}
            <Button size="sm" onClick={() => setSelectDeviceOpen(true)}>
              <Plus className="h-4 w-4 mr-1" />
              Nova Conexão
            </Button>
          </div>
        </div>

        {/* Main Terminal Container */}
        <Card className="overflow-hidden flex-1">
          {/* Tab Bar */}
          <div className="flex items-center bg-muted/30 border-b overflow-x-auto">
            {tabs.map(tab => (
              <div
                key={tab.id}
                onClick={() => setActiveTabId(tab.id)}
                className={`flex items-center gap-2 px-4 py-2 cursor-pointer border-r min-w-fit transition-colors ${
                  activeTabId === tab.id
                    ? 'bg-background border-b-2 border-b-primary'
                    : 'hover:bg-muted/50'
                }`}
              >
                {tab.status === 'connected' ? (
                  <Wifi className="h-3.5 w-3.5 text-green-500" />
                ) : tab.status === 'connecting' ? (
                  <Loader2 className="h-3.5 w-3.5 text-yellow-500 animate-spin" />
                ) : tab.status === 'error' ? (
                  <AlertCircle className="h-3.5 w-3.5 text-red-500" />
                ) : (
                  <WifiOff className="h-3.5 w-3.5 text-gray-500" />
                )}
                <span className="text-sm font-medium whitespace-nowrap">{tab.device.name}</span>
                {tab.status === 'disconnected' && (
                  <Button
                    variant="ghost"
                    size="sm"
                    className="h-5 px-1 text-xs"
                    onClick={(e) => { e.stopPropagation(); reconnect(tab.id); }}
                  >
                    Reconectar
                  </Button>
                )}
                <Button
                  variant="ghost"
                  size="icon"
                  className="h-5 w-5"
                  onClick={(e) => closeTab(tab.id, e)}
                >
                  <X className="h-3 w-3" />
                </Button>
              </div>
            ))}
            {tabs.length === 0 && (
              <div className="px-4 py-2 text-muted-foreground text-sm">
                Nenhuma conexão ativa - Clique em "Nova Conexão"
              </div>
            )}
          </div>

          {/* Terminal Area */}
          <div className="relative" style={{ height: isFullscreen ? 'calc(100% - 100px)' : '500px' }}>
            {tabs.map(tab => (
              <div
                key={tab.id}
                ref={el => { if (el) containerRefs.current[tab.id] = el; }}
                className={`absolute inset-0 ${activeTabId === tab.id ? 'visible' : 'hidden'}`}
                style={{ background: '#0d1117' }}
              />
            ))}

            {/* Empty State */}
            {tabs.length === 0 && (
              <div className="absolute inset-0 flex items-center justify-center bg-[#0d1117]">
                <div className="text-center">
                  <TerminalIcon className="h-20 w-20 mx-auto mb-4 text-muted-foreground opacity-30" />
                  <h3 className="text-lg font-medium text-muted-foreground mb-2">
                    Nenhuma conexão ativa
                  </h3>
                  <p className="text-sm text-muted-foreground mb-4">
                    Clique em "Nova Conexão" para iniciar uma sessão SSH
                  </p>
                  <Button onClick={() => setSelectDeviceOpen(true)}>
                    <Plus className="h-4 w-4 mr-2" />
                    Nova Conexão
                  </Button>
                </div>
              </div>
            )}
          </div>

          {/* Status Bar */}
          {activeSession && (
            <div className="flex items-center justify-between px-4 py-1 bg-muted/30 border-t text-xs">
              <div className="flex items-center gap-4">
                <span className="text-muted-foreground">
                  {activeSession.device.ip}:{activeSession.device.ssh_port || 22}
                </span>
                <span className="text-muted-foreground">
                  {activeSession.device.vendor}
                </span>
                {activeSession.device.ssh_user && (
                  <span className="text-muted-foreground">
                    {activeSession.device.ssh_user}
                  </span>
                )}
                <span className="text-muted-foreground">
                  Log: {activeSession.sessionLog.length} entradas
                </span>
              </div>
              <div className="flex items-center gap-2">
                {activeSession.status === 'connected' && (
                  <Badge variant="outline" className="bg-green-500/10 text-green-500 border-green-500/20 text-xs">
                    Conectado
                  </Badge>
                )}
                {activeSession.status === 'connecting' && (
                  <Badge variant="outline" className="bg-yellow-500/10 text-yellow-500 text-xs">
                    Conectando...
                  </Badge>
                )}
                {activeSession.status === 'error' && (
                  <Badge variant="outline" className="bg-red-500/10 text-red-500 text-xs">
                    Erro
                  </Badge>
                )}
                {activeSession.status === 'disconnected' && (
                  <Badge variant="outline" className="bg-gray-500/10 text-gray-500 text-xs">
                    Desconectado
                  </Badge>
                )}
              </div>
            </div>
          )}
        </Card>
      </div>

      {/* Device Selection Dialog */}
      <Dialog open={selectDeviceOpen} onOpenChange={setSelectDeviceOpen}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>Selecionar Dispositivo</DialogTitle>
          </DialogHeader>
          <div className="space-y-2 max-h-[400px] overflow-y-auto">
            {devices.filter(d => d.ssh_user).map(device => (
              <div
                key={device.id}
                onClick={() => createSession(device)}
                className="flex items-center justify-between p-3 border rounded-lg hover:bg-muted/50 cursor-pointer transition-colors"
              >
                <div className="flex items-center gap-3">
                  <Wifi className="h-5 w-5 text-green-500" />
                  <div>
                    <div className="font-medium">{device.name}</div>
                    <div className="text-sm text-muted-foreground">
                      {device.ip}:{device.ssh_port || device.port || 22}
                    </div>
                  </div>
                </div>
                <div className="text-right">
                  <Badge variant="outline" className="capitalize">
                    {device.device_type}
                  </Badge>
                </div>
              </div>
            ))}
            {devices.filter(d => d.ssh_user).length === 0 && (
              <div className="text-center py-8 text-muted-foreground">
                Nenhum dispositivo com credenciais SSH configurado
              </div>
            )}
          </div>
        </DialogContent>
      </Dialog>

      {/* Delete Log Confirmation */}
      <AlertDialog open={deleteLogOpen} onOpenChange={setDeleteLogOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Confirmar Exclusão</AlertDialogTitle>
            <AlertDialogDescription>
              Tem certeza que deseja excluir o log desta sessão? Esta ação não pode ser desfeita.
              Apenas administradores podem excluir logs de sessão.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction onClick={deleteSessionLog} className="bg-destructive text-destructive-foreground">
              Excluir
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
