'use client';

import { useState, useEffect, useRef, useCallback } from 'react';
import {
  Terminal as TerminalIcon,
  Plus,
  X,
  Maximize2,
  Minimize2,
  Copy,
  Download,
  RotateCcw,
  Wifi,
  WifiOff,
  AlertCircle,
  Loader2
} from 'lucide-react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { ScrollArea } from '@/components/ui/scroll-area';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Device } from '@/types/lor-cgr';
import { toast } from 'sonner';

interface TerminalTab {
  id: string;
  device: Device;
  status: 'connecting' | 'connected' | 'disconnected' | 'error';
  output: string[];
  commandHistory: string[];
  historyIndex: number;
  ws: WebSocket | null;
}

interface MultiterminalProps {
  devices: Device[];
  sessions?: { id: string; device: Device }[];
  onConnect: (deviceId: number) => void;
}

const WS_BASE_URL = 'ws://45.71.242.131';

const simulateTerminal = (command: string, device: Device): string => {
  const cmd = command.toLowerCase().trim();
  
  const responses: Record<string, string> = {
    'display version': 'Huawei Versatile Routing Platform Software\nVersion 8.180\n' + (device.vendor || 'Huawei'),
    'display cpu': 'CPU utilization: 15%',
    'display memory': 'Memory: 2949 MB used',
    'help': 'Available commands: display version, display cpu, display memory, help',
  };
  
  if (responses[cmd]) return responses[cmd];
  if (cmd === '') return '';
  return 'Unknown command. Type "help" for available commands.';
};

export default function Multiterminal({ devices, sessions = [], onConnect }: MultiterminalProps) {
  const [tabs, setTabs] = useState<TerminalTab[]>([]);
  const [activeTab, setActiveTab] = useState<string | null>(null);
  const [commandInput, setCommandInput] = useState('');
  const [selectDeviceOpen, setSelectDeviceOpen] = useState(false);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [useSimulation, setUseSimulation] = useState<Record<string, boolean>>({});
  
  const terminalRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    sessions.forEach(session => {
      const existingTab = tabs.find(t => t.device.id === session.device.id);
      if (!existingTab) {
        createTab(session.device);
      }
    });
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sessions]);

  useEffect(() => {
    if (terminalRef.current) {
      terminalRef.current.scrollTop = terminalRef.current.scrollHeight;
    }
  }, [tabs, activeTab]);

  useEffect(() => {
    return () => {
      tabs.forEach(tab => {
        if (tab.ws) tab.ws.close();
      });
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const createTab = useCallback((device: Device) => {
    const tabId = device.id + '-' + Date.now();
    
    const newTab: TerminalTab = {
      id: tabId,
      device,
      status: 'connecting',
      output: ['[CONNECTING] Connecting to ' + device.name + '...'],
      commandHistory: [],
      historyIndex: -1,
      ws: null,
    };
    
    setTabs(prev => [...prev, newTab]);
    setActiveTab(tabId);
    setSelectDeviceOpen(false);

    try {
      const wsUrl = WS_BASE_URL + '/ws/terminal/' + device.id + '/';
      const ws = new WebSocket(wsUrl);
      
      ws.onopen = () => {
        setTabs(prev => prev.map(tab => {
          if (tab.id !== tabId) return tab;
          return { ...tab, ws, status: 'connected', output: [...tab.output, '[OK] Connected!'] };
        }));
        setUseSimulation(prev => ({ ...prev, [tabId]: false }));
      };
      
      ws.onmessage = (event) => {
        setTabs(prev => prev.map(tab => {
          if (tab.id !== tabId) return tab;
          return { ...tab, output: [...tab.output, event.data] };
        }));
      };
      
      ws.onclose = (event) => {
        setTabs(prev => prev.map(tab => {
          if (tab.id !== tabId) return tab;
          return { ...tab, status: 'disconnected', ws: null, output: [...tab.output, '[DISCONNECTED] Code: ' + event.code] };
        }));
      };
      
      ws.onerror = () => {
        setUseSimulation(prev => ({ ...prev, [tabId]: true }));
        setTabs(prev => prev.map(tab => {
          if (tab.id !== tabId) return tab;
          return { ...tab, status: 'connected', output: [...tab.output, '[SIM] Simulation mode'] };
        }));
      };
      
      setTabs(prev => prev.map(tab => {
        if (tab.id !== tabId) return tab;
        return { ...tab, ws };
      }));
      
    } catch {
      setUseSimulation(prev => ({ ...prev, [tabId]: true }));
      setTabs(prev => prev.map(tab => {
        if (tab.id !== tabId) return tab;
        return { ...tab, status: 'connected', output: [...tab.output, '[SIM] Simulation mode'] };
      }));
    }
    
    onConnect(device.id);
  }, [onConnect]);

  const closeTab = (tabId: string) => {
    setTabs(prev => {
      const tab = prev.find(t => t.id === tabId);
      if (tab && tab.ws) tab.ws.close();
      return prev.filter(t => t.id !== tabId);
    });
    if (activeTab === tabId) {
      const remaining = tabs.filter(tab => tab.id !== tabId);
      setActiveTab(remaining.length > 0 ? remaining[0].id : null);
    }
  };

  const executeCommand = (command: string) => {
    if (!activeTab) return;
    const activeTerminal = tabs.find(t => t.id === activeTab);
    if (!activeTerminal) return;

    if (useSimulation[activeTab] || !activeTerminal.ws || activeTerminal.ws.readyState !== WebSocket.OPEN) {
      const output = simulateTerminal(command, activeTerminal.device);
      setTabs(prev => prev.map(tab => {
        if (tab.id !== activeTab) return tab;
        return { ...tab, output: [...tab.output, '>' + command, output], commandHistory: [command, ...tab.commandHistory] };
      }));
    } else {
      activeTerminal.ws.send(JSON.stringify({ type: 'input', data: command + '\n' }));
      setTabs(prev => prev.map(tab => {
        if (tab.id !== activeTab) return tab;
        return { ...tab, output: [...tab.output, '>' + command], commandHistory: [command, ...tab.commandHistory] };
      }));
    }
    setCommandInput('');
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (!activeTab) return;
    if (e.key === 'Enter') executeCommand(commandInput);
  };

  const copyOutput = () => {
    if (!activeTab) return;
    const activeTerminal = tabs.find(t => t.id === activeTab);
    if (!activeTerminal) return;
    navigator.clipboard.writeText(activeTerminal.output.join('\n'));
    toast.success('Output copied');
  };

  const clearTerminal = () => {
    if (!activeTab) return;
    setTabs(prev => prev.map(tab => tab.id === activeTab ? { ...tab, output: ['>'] } : tab));
  };

  const downloadOutput = () => {
    if (!activeTab) return;
    const activeTerminal = tabs.find(t => t.id === activeTab);
    if (!activeTerminal) return;
    const blob = new Blob([activeTerminal.output.join('\n')], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'terminal-' + activeTerminal.device.name + '.txt';
    a.click();
    URL.revokeObjectURL(url);
  };

  const activeTerminal = tabs.find(t => t.id === activeTab);

  return (
    <div className={'space-y-4' + (isFullscreen ? ' fixed inset-0 z-50 bg-background p-4' : '')}>
      <div className="flex flex-col sm:flex-row gap-4 justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Multi-Terminal SSH</h1>
          <p className="text-muted-foreground">Terminal with command auditing</p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" size="icon" onClick={() => setIsFullscreen(!isFullscreen)}>
            {isFullscreen ? <Minimize2 className="h-4 w-4" /> : <Maximize2 className="h-4 w-4" />}
          </Button>
          <Button onClick={() => setSelectDeviceOpen(true)}>
            <Plus className="h-4 w-4 mr-2" />New Connection
          </Button>
        </div>
      </div>

      <Card>
        <CardHeader className="pb-2">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2 overflow-x-auto">
              {tabs.map(tab => (
                <div
                  key={tab.id}
                  className={'flex items-center gap-2 px-3 py-1.5 rounded-md cursor-pointer ' + (activeTab === tab.id ? 'bg-primary text-primary-foreground' : 'bg-muted hover:bg-muted/80')}
                  onClick={() => setActiveTab(tab.id)}
                >
                  {tab.status === 'connected' ? (
                    useSimulation[tab.id] ? <AlertCircle className="h-3 w-3 text-yellow-500" /> : <Wifi className="h-3 w-3 text-green-500" />
                  ) : tab.status === 'connecting' ? (
                    <Loader2 className="h-3 w-3 text-yellow-500 animate-spin" />
                  ) : (
                    <WifiOff className="h-3 w-3 text-red-500" />
                  )}
                  <span className="text-sm whitespace-nowrap">{tab.device.name}</span>
                  <Button variant="ghost" size="icon" className="h-4 w-4 p-0" onClick={e => { e.stopPropagation(); closeTab(tab.id); }}>
                    <X className="h-3 w-3" />
                  </Button>
                </div>
              ))}
              {tabs.length === 0 && <span className="text-muted-foreground text-sm">No active connections</span>}
            </div>
            {activeTab && (
              <div className="flex gap-1">
                <Button variant="ghost" size="icon" onClick={copyOutput}><Copy className="h-4 w-4" /></Button>
                <Button variant="ghost" size="icon" onClick={downloadOutput}><Download className="h-4 w-4" /></Button>
                <Button variant="ghost" size="icon" onClick={clearTerminal}><RotateCcw className="h-4 w-4" /></Button>
              </div>
            )}
          </div>
        </CardHeader>
        <CardContent className="p-0">
          {activeTerminal ? (
            <div className="bg-black rounded-b-lg overflow-hidden h-[500px]" onClick={() => inputRef.current && inputRef.current.focus()}>
              <ScrollArea className="h-full">
                <div ref={terminalRef} className="p-4 font-mono text-sm text-green-400 whitespace-pre-wrap">
                  {activeTerminal.output.map((line, i) => <div key={i}>{line}</div>)}
                </div>
              </ScrollArea>
              <div className="flex items-center p-2 border-t border-gray-800 bg-black">
                <span className="text-green-400 font-mono mr-2">{activeTerminal.device.name}&gt;</span>
                <input
                  ref={inputRef}
                  type="text"
                  value={commandInput}
                  onChange={e => setCommandInput(e.target.value)}
                  onKeyDown={handleKeyDown}
                  className="flex-1 bg-transparent border-none outline-none text-green-400 font-mono text-sm"
                  placeholder="Enter command..."
                  autoFocus
                />
                {useSimulation[activeTab] && <Badge variant="outline" className="ml-2 text-yellow-500 border-yellow-500/50">SIM</Badge>}
              </div>
            </div>
          ) : (
            <div className="h-[500px] flex items-center justify-center bg-black/5 rounded-b-lg">
              <div className="text-center text-muted-foreground">
                <TerminalIcon className="h-16 w-16 mx-auto mb-4 opacity-50" />
                <p className="text-lg">No active connections</p>
                <p className="text-sm">Click &quot;New Connection&quot; to start</p>
              </div>
            </div>
          )}
        </CardContent>
      </Card>

      {activeTerminal && (
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm">Quick Commands</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex flex-wrap gap-2">
              {['display version', 'display cpu', 'display memory'].map(cmd => (
                <Button key={cmd} variant="outline" size="sm" className="font-mono text-xs" onClick={() => executeCommand(cmd)}>{cmd}</Button>
              ))}
            </div>
          </CardContent>
        </Card>
      )}

      <Dialog open={selectDeviceOpen} onOpenChange={setSelectDeviceOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Select Device</DialogTitle>
            <DialogDescription>Choose a device to connect via SSH</DialogDescription>
          </DialogHeader>
          <div className="space-y-2 max-h-[400px] overflow-y-auto">
            {devices.map(device => (
              <div
                key={device.id}
                className="flex items-center justify-between p-3 border rounded-lg hover:bg-muted/50 cursor-pointer"
                onClick={() => createTab(device)}
              >
                <div className="flex items-center gap-3">
                  <Wifi className="h-5 w-5 text-green-500" />
                  <div>
                    <div className="font-medium">{device.name}</div>
                    <div className="text-sm text-muted-foreground">{device.ip}:{device.port || 22}</div>
                  </div>
                </div>
                <Badge variant="outline">{device.device_type}</Badge>
              </div>
            ))}
            {devices.length === 0 && <div className="text-center py-8 text-muted-foreground">No devices available</div>}
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}
