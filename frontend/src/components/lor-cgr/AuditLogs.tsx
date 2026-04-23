'use client';

import { useState, useEffect } from 'react';
import {
  FileText,
  RefreshCw,
  Search,
  Clock,
  User,
  Server,
  Terminal,
  HardDrive,
  Settings,
  AlertTriangle,
  CheckCircle,
  ArrowDownUp,
  Eye,
  Download,
  Trash2,
  FileDown,
  ChevronLeft,
  ChevronRight,
  Play,
  StopCircle,
  Clock3
} from 'lucide-react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
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
import { ScrollArea } from '@/components/ui/scroll-area';
import { AuditLog, Device, TerminalSession } from '@/types/lor-cgr';
import { toast } from 'sonner';

interface AuditLogsProps {
  devices: Device[];
  loading: boolean;
  onRefresh: () => void;
  isAdmin?: boolean;
}

const API_URL = 'http://45.71.242.131:8000/api/audit';

const actionCategories = [
  { value: 'all', label: 'Todas as ações' },
  { value: 'SSH_CONNECT', label: 'Conexão SSH' },
  { value: 'SSH_DISCONNECT', label: 'Desconexão SSH' },
  { value: 'COMMAND', label: 'Comandos' },
  { value: 'BACKUP', label: 'Backups' },
  { value: 'DEVICE_ADD', label: 'Adição de Dispositivo' },
  { value: 'DEVICE_UPDATE', label: 'Atualização de Dispositivo' },
  { value: 'DEVICE_DELETE', label: 'Remoção de Dispositivo' },
  { value: 'DEVICE_ONLINE', label: 'Dispositivo Online' },
  { value: 'DEVICE_OFFLINE', label: 'Dispositivo Offline' },
];

const getActionIcon = (action: string) => {
  switch (action) {
    case 'SSH_CONNECT':
      return <Terminal className="h-4 w-4 text-green-500" />;
    case 'SSH_DISCONNECT':
      return <Terminal className="h-4 w-4 text-yellow-500" />;
    case 'COMMAND':
      return <Terminal className="h-4 w-4 text-blue-500" />;
    case 'BACKUP':
      return <HardDrive className="h-4 w-4 text-purple-500" />;
    case 'DEVICE_ADD':
      return <Server className="h-4 w-4 text-green-500" />;
    case 'DEVICE_UPDATE':
      return <Settings className="h-4 w-4 text-blue-500" />;
    case 'DEVICE_DELETE':
      return <Server className="h-4 w-4 text-red-500" />;
    case 'DEVICE_ONLINE':
      return <CheckCircle className="h-4 w-4 text-green-500" />;
    case 'DEVICE_OFFLINE':
      return <AlertTriangle className="h-4 w-4 text-red-500" />;
    default:
      return <FileText className="h-4 w-4 text-gray-500" />;
  }
};

const getActionBadgeVariant = (action: string): "default" | "secondary" | "destructive" | "outline" => {
  switch (action) {
    case 'SSH_CONNECT':
    case 'DEVICE_ADD':
    case 'DEVICE_ONLINE':
      return 'default';
    case 'SSH_DISCONNECT':
    case 'DEVICE_OFFLINE':
    case 'DEVICE_DELETE':
      return 'destructive';
    case 'COMMAND':
    case 'BACKUP':
    case 'DEVICE_UPDATE':
      return 'secondary';
    default:
      return 'outline';
  }
};

const getSessionStatusIcon = (status: string) => {
  switch (status) {
    case 'active':
      return <Play className="h-4 w-4 text-green-500" />;
    case 'disconnected':
      return <StopCircle className="h-4 w-4 text-gray-500" />;
    default:
      return <Terminal className="h-4 w-4 text-yellow-500" />;
  }
};

export default function AuditLogs({ devices, loading, onRefresh, isAdmin = false }: AuditLogsProps) {
  const [logs, setLogs] = useState<AuditLog[]>([]);
  const [sessions, setSessions] = useState<TerminalSession[]>([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [actionFilter, setActionFilter] = useState('all');
  const [deviceFilter, setDeviceFilter] = useState('all');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');
  const [isLoading, setIsLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('logs');
  
  // Dialogs
  const [viewDialogOpen, setViewDialogOpen] = useState(false);
  const [sessionDialogOpen, setSessionDialogOpen] = useState(false);
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [selectedLog, setSelectedLog] = useState<AuditLog | null>(null);
  const [selectedSession, setSelectedSession] = useState<TerminalSession | null>(null);
  const [sessionContent, setSessionContent] = useState<string>('');
  const [isLoadingSession, setIsLoadingSession] = useState(false);
  
  // Pagination
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 20;

  // Fetch audit logs from API
  const fetchAuditLogs = async () => {
    setIsLoading(true);
    try {
      const [logsRes, sessionsRes] = await Promise.all([
        fetch(`${API_URL}/logs/`),
        fetch(`${API_URL}/sessions/`)
      ]);
      
      if (logsRes.ok) {
        const data = await logsRes.json();
        setLogs(data.logs || []);
      }
      
      if (sessionsRes.ok) {
        const data = await sessionsRes.json();
        setSessions(data.sessions || []);
      }
    } catch (error) {
      console.error('Error fetching data:', error);
      toast.error('Erro ao carregar dados');
    }
    setIsLoading(false);
  };

  useEffect(() => {
    fetchAuditLogs();
  }, []);

  // Fetch session content
  const fetchSessionContent = async (sessionId: string) => {
    setIsLoadingSession(true);
    try {
      const response = await fetch(`${API_URL}/sessions/${sessionId}/`);
      if (response.ok) {
        const data = await response.json();
        setSessionContent(data.content || '(sem conteúdo)');
        setSelectedSession(data);
      } else {
        toast.error('Erro ao carregar conteúdo da sessão');
      }
    } catch (error) {
      toast.error('Erro de conexão');
    }
    setIsLoadingSession(false);
  };

  // Filter logs
  const filteredLogs = logs
    .filter(log => {
      const matchesSearch = 
        log.details.toLowerCase().includes(searchTerm.toLowerCase()) ||
        log.user?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        log.device?.toLowerCase().includes(searchTerm.toLowerCase());
      
      const matchesAction = actionFilter === 'all' || log.action === actionFilter;
      const matchesDevice = deviceFilter === 'all' || log.device === deviceFilter;
      
      return matchesSearch && matchesAction && matchesDevice;
    })
    .sort((a, b) => {
      const dateA = new Date(a.timestamp).getTime();
      const dateB = new Date(b.timestamp).getTime();
      return sortOrder === 'desc' ? dateB - dateA : dateA - dateB;
    });

  // Pagination
  const totalPages = Math.ceil(filteredLogs.length / itemsPerPage);
  const paginatedLogs = filteredLogs.slice(
    (currentPage - 1) * itemsPerPage,
    currentPage * itemsPerPage
  );

  // Format date
  const formatDate = (dateStr: string) => {
    if (!dateStr) return '-';
    return new Date(dateStr).toLocaleString('pt-BR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    });
  };

  // Format duration
  const formatDuration = (seconds: number) => {
    if (!seconds) return '-';
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return mins > 0 ? `${mins}m ${secs}s` : `${secs}s`;
  };

  // View log details
  const handleView = (log: AuditLog) => {
    setSelectedLog(log);
    setViewDialogOpen(true);
  };

  // View session content
  const handleViewSession = (session: TerminalSession) => {
    setSelectedSession(session);
    setSessionDialogOpen(true);
    fetchSessionContent(session.session_id);
  };

  // Download log
  const handleDownload = (log: AuditLog) => {
    const logData = {
      id: log.id,
      timestamp: formatDate(log.timestamp),
      user: log.user,
      action: log.action,
      device: log.device,
      details: log.details,
      ip_address: log.ip_address,
      session_id: log.session_id,
    };
    
    const content = JSON.stringify(logData, null, 2);
    const blob = new Blob([content], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `audit-log-${log.id}-${new Date().toISOString().split('T')[0]}.json`;
    a.click();
    URL.revokeObjectURL(url);
    
    toast.success('Log baixado com sucesso!');
  };

  // Download session content as TXT
  const handleDownloadSession = async (session: TerminalSession) => {
    try {
      const response = await fetch(`${API_URL}/sessions/${session.session_id}/download/`);
      if (response.ok) {
        const blob = await response.blob();
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `session-${session.session_id}.txt`;
        a.click();
        URL.revokeObjectURL(url);
        toast.success('Sessão baixada com sucesso!');
      } else {
        // Fallback: criar TXT manualmente
        const content = `SESSÃO DE TERMINAL - LOR-CGR
============================================================
Sessão ID: ${session.session_id}
Dispositivo: ${session.device_name}
Usuário: ${session.user || 'admin'}
Início: ${formatDate(session.start_time)}
Fim: ${formatDate(session.end_time || '')}
Duração: ${formatDuration(session.duration_seconds || 0)}
Status: ${session.status}
============================================================

CONTEÚDO DA SESSÃO:
------------------------------------------------------------
${sessionContent}

------------------------------------------------------------
COMANDOS EXECUTADOS:
------------------------------------------------------------
${session.commands_executed || '(nenhum comando registrado)'}
`;
        const blob = new Blob([content], { type: 'text/plain;charset=utf-8' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `session-${session.session_id}.txt`;
        a.click();
        URL.revokeObjectURL(url);
        toast.success('Sessão baixada com sucesso!');
      }
    } catch (error) {
      toast.error('Erro ao baixar sessão');
    }
  };

  // Delete log (admin only)
  const handleDelete = (log: AuditLog) => {
    setSelectedLog(log);
    setDeleteDialogOpen(true);
  };

  const confirmDelete = async () => {
    if (!selectedLog) return;
    
    try {
      const response = await fetch(`${API_URL}/logs/${selectedLog.id}/delete/`, {
        method: 'DELETE',
      });
      
      if (response.ok) {
        setLogs(prev => prev.filter(l => l.id !== selectedLog.id));
        toast.success('Log excluído com sucesso!');
      } else {
        const data = await response.json();
        toast.error(data.error || 'Erro ao excluir log');
      }
    } catch (error) {
      toast.error('Erro de conexão');
    }
    
    setDeleteDialogOpen(false);
    setSelectedLog(null);
  };

  // Export all to CSV
  const exportToCSV = () => {
    const headers = ['ID', 'Data/Hora', 'Usuário', 'Ação', 'Dispositivo', 'Detalhes', 'IP', 'Sessão'];
    const rows = filteredLogs.map(log => [
      log.id,
      formatDate(log.timestamp),
      log.user || 'system',
      log.action,
      log.device || '-',
      `"${log.details.replace(/"/g, '""')}"`,
      log.ip_address || '-',
      log.session_id || '-',
    ]);
    
    const csv = [headers.join(','), ...rows.map(r => r.join(','))].join('\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `audit-logs-${new Date().toISOString().split('T')[0]}.csv`;
    a.click();
    URL.revokeObjectURL(url);
    
    toast.success('CSV exportado com sucesso!');
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row gap-4 justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">LOG</h1>
          <p className="text-muted-foreground">
            Logs de atividades e sessões de terminal
          </p>
        </div>
        <div className="flex gap-2 flex-wrap">
          <Button variant="outline" onClick={() => { fetchAuditLogs(); onRefresh(); }} disabled={isLoading}>
            <RefreshCw className={`h-4 w-4 mr-2 ${isLoading ? 'animate-spin' : ''}`} />
            Atualizar
          </Button>
          <Button variant="outline" onClick={exportToCSV}>
            <FileDown className="h-4 w-4 mr-2" />
            Exportar CSV
          </Button>
        </div>
      </div>

      {/* Tabs */}
      <Tabs value={activeTab} onValueChange={setActiveTab}>
        <TabsList>
          <TabsTrigger value="logs" className="gap-2">
            <FileText className="h-4 w-4" />
            Logs ({logs.length})
          </TabsTrigger>
          <TabsTrigger value="sessions" className="gap-2">
            <Terminal className="h-4 w-4" />
            Sessões ({sessions.length})
          </TabsTrigger>
        </TabsList>

        {/* Logs Tab */}
        <TabsContent value="logs" className="space-y-4">
          {/* Stats */}
          <div className="grid gap-4 md:grid-cols-4">
            <Card>
              <CardContent className="pt-6">
                <div className="text-2xl font-bold">{logs.length}</div>
                <p className="text-xs text-muted-foreground">Total de Logs</p>
              </CardContent>
            </Card>
            <Card>
              <CardContent className="pt-6">
                <div className="text-2xl font-bold text-blue-500">
                  {logs.filter(l => l.action.includes('SSH')).length}
                </div>
                <p className="text-xs text-muted-foreground">Sessões SSH</p>
              </CardContent>
            </Card>
            <Card>
              <CardContent className="pt-6">
                <div className="text-2xl font-bold text-purple-500">
                  {logs.filter(l => l.action === 'BACKUP').length}
                </div>
                <p className="text-xs text-muted-foreground">Backups</p>
              </CardContent>
            </Card>
            <Card>
              <CardContent className="pt-6">
                <div className="text-2xl font-bold text-red-500">
                  {logs.filter(l => l.action.includes('OFFLINE') || l.action.includes('DELETE')).length}
                </div>
                <p className="text-xs text-muted-foreground">Alertas</p>
              </CardContent>
            </Card>
          </div>

          {/* Filters */}
          <Card>
            <CardContent className="pt-6">
              <div className="grid gap-4 md:grid-cols-4">
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                  <Input
                    placeholder="Buscar nos logs..."
                    value={searchTerm}
                    onChange={(e) => { setSearchTerm(e.target.value); setCurrentPage(1); }}
                    className="pl-9"
                  />
                </div>
                <Select value={actionFilter} onValueChange={(v) => { setActionFilter(v); setCurrentPage(1); }}>
                  <SelectTrigger>
                    <SelectValue placeholder="Filtrar por ação" />
                  </SelectTrigger>
                  <SelectContent>
                    {actionCategories.map((cat) => (
                      <SelectItem key={cat.value} value={cat.value}>
                        {cat.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                <Select value={deviceFilter} onValueChange={(v) => { setDeviceFilter(v); setCurrentPage(1); }}>
                  <SelectTrigger>
                    <SelectValue placeholder="Filtrar por dispositivo" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">Todos os dispositivos</SelectItem>
                    {devices.map((device) => (
                      <SelectItem key={device.id} value={device.name}>
                        {device.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                <Button
                  variant="outline"
                  onClick={() => setSortOrder(prev => prev === 'desc' ? 'asc' : 'desc')}
                >
                  <ArrowDownUp className="h-4 w-4 mr-2" />
                  {sortOrder === 'desc' ? 'Mais recentes' : 'Mais antigos'}
                </Button>
              </div>
            </CardContent>
          </Card>

          {/* Logs List */}
          <Card>
            <CardHeader>
              <CardTitle>Registros de Atividade</CardTitle>
              <CardDescription>
                {filteredLogs.length} de {logs.length} registros
              </CardDescription>
            </CardHeader>
            <CardContent>
              {isLoading ? (
                <div className="text-center py-12">
                  <RefreshCw className="h-8 w-8 mx-auto animate-spin text-muted-foreground" />
                  <p className="mt-2 text-muted-foreground">Carregando logs...</p>
                </div>
              ) : (
                <div className="space-y-4">
                  {paginatedLogs.map((log) => (
                    <div
                      key={log.id}
                      className="flex items-start gap-4 p-4 border rounded-lg hover:bg-muted/50 transition-colors"
                    >
                      <div className="mt-1">
                        {getActionIcon(log.action)}
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 flex-wrap">
                          <Badge variant={getActionBadgeVariant(log.action)}>
                            {log.action}
                          </Badge>
                          {log.device && (
                            <Badge variant="outline" className="text-xs">
                              <Server className="h-3 w-3 mr-1" />
                              {log.device}
                            </Badge>
                          )}
                          {log.session_id && (
                            <Badge variant="outline" className="text-xs bg-blue-500/10">
                              <Terminal className="h-3 w-3 mr-1" />
                              Sessão
                            </Badge>
                          )}
                        </div>
                        <div className="mt-1 font-medium">{log.details}</div>
                        <div className="mt-1 text-sm text-muted-foreground flex items-center gap-4 flex-wrap">
                          <span className="flex items-center gap-1">
                            <User className="h-3 w-3" />
                            {log.user || 'system'}
                          </span>
                          <span className="flex items-center gap-1">
                            <Clock className="h-3 w-3" />
                            {formatDate(log.timestamp)}
                          </span>
                          {log.ip_address && (
                            <span>IP: {log.ip_address}</span>
                          )}
                        </div>
                      </div>
                      {/* Action Buttons */}
                      <div className="flex items-center gap-1">
                        <Button
                          variant="ghost"
                          size="icon"
                          onClick={() => handleView(log)}
                          title="Visualizar"
                        >
                          <Eye className="h-4 w-4 text-blue-500" />
                        </Button>
                        <Button
                          variant="ghost"
                          size="icon"
                          onClick={() => handleDownload(log)}
                          title="Baixar"
                        >
                          <Download className="h-4 w-4 text-green-500" />
                        </Button>
                        {isAdmin && (
                          <Button
                            variant="ghost"
                            size="icon"
                            onClick={() => handleDelete(log)}
                            title="Excluir (Admin)"
                          >
                            <Trash2 className="h-4 w-4 text-red-500" />
                          </Button>
                        )}
                      </div>
                    </div>
                  ))}

                  {paginatedLogs.length === 0 && (
                    <div className="text-center py-12 text-muted-foreground">
                      <FileText className="h-12 w-12 mx-auto mb-4 opacity-50" />
                      <p>Nenhum log encontrado</p>
                    </div>
                  )}
                </div>
              )}

              {/* Pagination */}
              {totalPages > 1 && (
                <div className="flex items-center justify-between mt-6 pt-4 border-t">
                  <p className="text-sm text-muted-foreground">
                    Página {currentPage} de {totalPages}
                  </p>
                  <div className="flex gap-2">
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => setCurrentPage(prev => Math.max(1, prev - 1))}
                      disabled={currentPage === 1}
                    >
                      <ChevronLeft className="h-4 w-4" />
                      Anterior
                    </Button>
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => setCurrentPage(prev => Math.min(totalPages, prev + 1))}
                      disabled={currentPage === totalPages}
                    >
                      Próxima
                      <ChevronRight className="h-4 w-4" />
                    </Button>
                  </div>
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        {/* Sessions Tab */}
        <TabsContent value="sessions" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Sessões de Terminal</CardTitle>
              <CardDescription>
                Histórico de sessões SSH com gravação completa
              </CardDescription>
            </CardHeader>
            <CardContent>
              {isLoading ? (
                <div className="text-center py-12">
                  <RefreshCw className="h-8 w-8 mx-auto animate-spin text-muted-foreground" />
                  <p className="mt-2 text-muted-foreground">Carregando sessões...</p>
                </div>
              ) : (
                <div className="space-y-4">
                  {sessions.map((session) => (
                    <div
                      key={session.id}
                      className="flex items-start gap-4 p-4 border rounded-lg hover:bg-muted/50 transition-colors"
                    >
                      <div className="mt-1">
                        {getSessionStatusIcon(session.status)}
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 flex-wrap">
                          <Badge variant={session.status === 'active' ? 'default' : 'secondary'}>
                            {session.status}
                          </Badge>
                          <Badge variant="outline" className="text-xs">
                            <Server className="h-3 w-3 mr-1" />
                            {session.device_name}
                          </Badge>
                        </div>
                        <div className="mt-1 font-medium">
                          Sessão #{session.session_id.split('-')[1]}
                        </div>
                        <div className="mt-1 text-sm text-muted-foreground flex items-center gap-4 flex-wrap">
                          <span className="flex items-center gap-1">
                            <User className="h-3 w-3" />
                            {session.user || 'admin'}
                          </span>
                          <span className="flex items-center gap-1">
                            <Play className="h-3 w-3" />
                            {formatDate(session.start_time)}
                          </span>
                          {session.duration_seconds && (
                            <span className="flex items-center gap-1">
                              <Clock3 className="h-3 w-3" />
                              {formatDuration(session.duration_seconds)}
                            </span>
                          )}
                        </div>
                      </div>
                      {/* Action Buttons */}
                      <div className="flex items-center gap-1">
                        <Button
                          variant="ghost"
                          size="icon"
                          onClick={() => handleViewSession(session)}
                          title="Ver Conteúdo"
                        >
                          <Eye className="h-4 w-4 text-blue-500" />
                        </Button>
                        <Button
                          variant="ghost"
                          size="icon"
                          onClick={() => handleDownloadSession(session)}
                          title="Baixar TXT"
                        >
                          <Download className="h-4 w-4 text-green-500" />
                        </Button>
                      </div>
                    </div>
                  ))}

                  {sessions.length === 0 && (
                    <div className="text-center py-12 text-muted-foreground">
                      <Terminal className="h-12 w-12 mx-auto mb-4 opacity-50" />
                      <p>Nenhuma sessão registrada</p>
                    </div>
                  )}
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>

      {/* View Log Dialog */}
      <Dialog open={viewDialogOpen} onOpenChange={setViewDialogOpen}>
        <DialogContent className="max-w-lg">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              {selectedLog && getActionIcon(selectedLog.action)}
              Detalhes do Log
            </DialogTitle>
            <DialogDescription>
              Informações completas do registro
            </DialogDescription>
          </DialogHeader>
          
          {selectedLog && (
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="text-sm font-medium text-muted-foreground">ID</label>
                  <p className="font-mono">{selectedLog.id}</p>
                </div>
                <div>
                  <label className="text-sm font-medium text-muted-foreground">Ação</label>
                  <p><Badge variant={getActionBadgeVariant(selectedLog.action)}>{selectedLog.action}</Badge></p>
                </div>
                <div>
                  <label className="text-sm font-medium text-muted-foreground">Usuário</label>
                  <p className="flex items-center gap-1"><User className="h-4 w-4" />{selectedLog.user || 'system'}</p>
                </div>
                <div>
                  <label className="text-sm font-medium text-muted-foreground">Dispositivo</label>
                  <p className="flex items-center gap-1"><Server className="h-4 w-4" />{selectedLog.device || '-'}</p>
                </div>
                <div>
                  <label className="text-sm font-medium text-muted-foreground">Data/Hora</label>
                  <p className="flex items-center gap-1"><Clock className="h-4 w-4" />{formatDate(selectedLog.timestamp)}</p>
                </div>
                <div>
                  <label className="text-sm font-medium text-muted-foreground">Endereço IP</label>
                  <p>{selectedLog.ip_address || '-'}</p>
                </div>
                {selectedLog.session_id && (
                  <div className="col-span-2">
                    <label className="text-sm font-medium text-muted-foreground">Sessão ID</label>
                    <p className="font-mono text-xs">{selectedLog.session_id}</p>
                  </div>
                )}
              </div>
              
              <div>
                <label className="text-sm font-medium text-muted-foreground">Detalhes</label>
                <div className="mt-1 p-3 bg-muted rounded-lg font-mono text-sm">
                  {selectedLog.details}
                </div>
              </div>
            </div>
          )}
          
          <DialogFooter>
            <Button variant="outline" onClick={() => setViewDialogOpen(false)}>
              Fechar
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* View Session Dialog */}
      <Dialog open={sessionDialogOpen} onOpenChange={setSessionDialogOpen}>
        <DialogContent className="max-w-4xl max-h-[80vh]">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <Terminal className="h-5 w-5" />
              Conteúdo da Sessão
            </DialogTitle>
            <DialogDescription>
              {selectedSession?.device_name} - {selectedSession && formatDate(selectedSession.start_time)}
            </DialogDescription>
          </DialogHeader>
          
          {selectedSession && (
            <div className="space-y-4">
              <div className="grid grid-cols-4 gap-4 text-sm">
                <div>
                  <label className="text-xs font-medium text-muted-foreground">Dispositivo</label>
                  <p className="font-medium">{selectedSession.device_name}</p>
                </div>
                <div>
                  <label className="text-xs font-medium text-muted-foreground">Usuário</label>
                  <p>{selectedSession.user || 'admin'}</p>
                </div>
                <div>
                  <label className="text-xs font-medium text-muted-foreground">Duração</label>
                  <p>{formatDuration(selectedSession.duration_seconds || 0)}</p>
                </div>
                <div>
                  <label className="text-xs font-medium text-muted-foreground">Status</label>
                  <Badge variant={selectedSession.status === 'active' ? 'default' : 'secondary'}>
                    {selectedSession.status}
                  </Badge>
                </div>
              </div>
              
              <div>
                <label className="text-sm font-medium text-muted-foreground mb-2 block">
                  Conteúdo do Terminal
                </label>
                <ScrollArea className="h-[400px] w-full rounded-lg border bg-[#1a1a2e]">
                  <pre className="p-4 text-sm font-mono text-green-400 whitespace-pre-wrap">
                    {isLoadingSession ? (
                      <span className="text-yellow-400">Carregando...</span>
                    ) : (
                      sessionContent || '(sem conteúdo registrado)'
                    )}
                  </pre>
                </ScrollArea>
              </div>

              {selectedSession.commands_executed && (
                <div>
                  <label className="text-sm font-medium text-muted-foreground mb-2 block">
                    Comandos Executados
                  </label>
                  <div className="p-3 bg-muted rounded-lg font-mono text-sm">
                    {selectedSession.commands_executed}
                  </div>
                </div>
              )}
            </div>
          )}
          
          <DialogFooter className="flex justify-between">
            <Button variant="outline" onClick={() => setSessionDialogOpen(false)}>
              Fechar
            </Button>
            {selectedSession && (
              <Button onClick={() => handleDownloadSession(selectedSession)}>
                <Download className="h-4 w-4 mr-2" />
                Baixar TXT
              </Button>
            )}
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete Confirmation Dialog */}
      <AlertDialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle className="flex items-center gap-2">
              <AlertTriangle className="h-5 w-5 text-red-500" />
              Confirmar Exclusão
            </AlertDialogTitle>
            <AlertDialogDescription>
              Tem certeza que deseja excluir este log? Esta ação não pode ser desfeita.
              {selectedLog && (
                <div className="mt-2 p-2 bg-muted rounded text-sm">
                  <strong>ID:</strong> {selectedLog.id}<br/>
                  <strong>Ação:</strong> {selectedLog.action}<br/>
                  <strong>Detalhes:</strong> {selectedLog.details}
                </div>
              )}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancelar</AlertDialogCancel>
            <AlertDialogAction
              onClick={confirmDelete}
              className="bg-red-500 hover:bg-red-600"
            >
              Excluir
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
