'use client';

import { useState, useEffect } from 'react';
import {
  FileText,
  RefreshCw,
  Search,
  Filter,
  Clock,
  User,
  Server,
  Terminal,
  HardDrive,
  Settings,
  AlertTriangle,
  CheckCircle,
  ArrowDownUp
} from 'lucide-react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { AuditLog, Device } from '@/types/lor-cgr';

interface AuditLogsProps {
  devices: Device[];
  loading: boolean;
  onRefresh: () => void;
}

// Mock audit logs - em produção viria da API
const mockAuditLogs: AuditLog[] = [
  {
    id: '1',
    user: 'leonardo',
    action: 'SSH_CONNECT',
    device: 'BRAS_NE8000',
    details: 'Conexão SSH estabelecida',
    ip_address: '192.168.1.100',
    timestamp: '2026-02-14T20:30:00',
  },
  {
    id: '2',
    user: 'leonardo',
    action: 'COMMAND',
    device: 'BRAS_NE8000',
    details: 'display version',
    ip_address: '192.168.1.100',
    timestamp: '2026-02-14T20:31:15',
  },
  {
    id: '3',
    user: 'system',
    action: 'BACKUP',
    device: 'BRAS_NE8000',
    details: 'Backup automático concluído',
    ip_address: 'localhost',
    timestamp: '2026-02-14T03:00:01',
  },
  {
    id: '4',
    user: 'system',
    action: 'BACKUP',
    device: 'PPPoE_CARDOSO_MOREIRA',
    details: 'Backup automático concluído',
    ip_address: 'localhost',
    timestamp: '2026-02-14T03:00:15',
  },
  {
    id: '5',
    user: 'leonardo',
    action: 'DEVICE_ADD',
    device: 'BRAS_NE8000',
    details: 'Dispositivo adicionado ao inventário',
    ip_address: '192.168.1.100',
    timestamp: '2026-02-13T15:00:00',
  },
  {
    id: '6',
    user: 'leonardo',
    action: 'SSH_DISCONNECT',
    device: 'BRAS_NE8000',
    details: 'Sessão SSH encerrada - Duração: 15min',
    ip_address: '192.168.1.100',
    timestamp: '2026-02-13T14:45:00',
  },
  {
    id: '7',
    user: 'system',
    action: 'DEVICE_OFFLINE',
    device: 'PPPoE_CARDOSO_MOREIRA',
    details: 'Dispositivo está offline',
    ip_address: 'localhost',
    timestamp: '2026-02-13T10:00:00',
  },
  {
    id: '8',
    user: 'system',
    action: 'DEVICE_ONLINE',
    device: 'PPPoE_CARDOSO_MOREIRA',
    details: 'Dispositivo voltou ao normal',
    ip_address: 'localhost',
    timestamp: '2026-02-13T10:05:00',
  },
];

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

export default function AuditLogs({ devices, loading, onRefresh }: AuditLogsProps) {
  const [logs, setLogs] = useState<AuditLog[]>(mockAuditLogs);
  const [searchTerm, setSearchTerm] = useState('');
  const [actionFilter, setActionFilter] = useState('all');
  const [deviceFilter, setDeviceFilter] = useState('all');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');

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

  // Format date
  const formatDate = (dateStr: string) => {
    return new Date(dateStr).toLocaleString('pt-BR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    });
  };

  // Export to CSV
  const exportToCSV = () => {
    const headers = ['Data/Hora', 'Usuário', 'Ação', 'Dispositivo', 'Detalhes', 'IP'];
    const rows = filteredLogs.map(log => [
      formatDate(log.timestamp),
      log.user || 'system',
      log.action,
      log.device || '-',
      log.details,
      log.ip_address || '-',
    ]);
    
    const csv = [headers, ...rows].map(row => row.join(',')).join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `audit-logs-${new Date().toISOString().split('T')[0]}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row gap-4 justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Logs de Auditoria</h1>
          <p className="text-muted-foreground">
            Histórico completo de ações no sistema
          </p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" onClick={onRefresh} disabled={loading}>
            <RefreshCw className={`h-4 w-4 mr-2 ${loading ? 'animate-spin' : ''}`} />
            Atualizar
          </Button>
          <Button variant="outline" onClick={exportToCSV}>
            <FileText className="h-4 w-4 mr-2" />
            Exportar CSV
          </Button>
        </div>
      </div>

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
              {logs.filter(l => l.action.includes('OFFLINE')).length}
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
                onChange={(e) => setSearchTerm(e.target.value)}
                className="pl-9"
              />
            </div>
            <Select value={actionFilter} onValueChange={setActionFilter}>
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
            <Select value={deviceFilter} onValueChange={setDeviceFilter}>
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
          <div className="space-y-4">
            {filteredLogs.map((log) => (
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
              </div>
            ))}

            {filteredLogs.length === 0 && (
              <div className="text-center py-12 text-muted-foreground">
                <FileText className="h-12 w-12 mx-auto mb-4 opacity-50" />
                <p>Nenhum log encontrado</p>
              </div>
            )}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
