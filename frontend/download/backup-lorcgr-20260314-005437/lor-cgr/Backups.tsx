'use client';

import { useState, useEffect } from 'react';
import {
  HardDrive,
  RefreshCw,
  Download,
  Play,
  Clock,
  CheckCircle2,
  XCircle,
  Loader2,
  Trash2,
  Calendar,
  Server
} from 'lucide-react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
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
import { Backup, Device } from '@/types/lor-cgr';
import { toast } from 'sonner';

interface BackupsProps {
  devices: Device[];
  loading: boolean;
  onRefresh: () => void;
  onRunBackup: (deviceId: number) => Promise<void>;
  onDownloadBackup: (backupId: string) => void;
  onDeleteBackup: (backupId: string) => Promise<void>;
}

// Mock backup data - em produção viria da API
const mockBackups: Backup[] = [
  {
    id: '1',
    device_id: 2,
    device_name: 'BRAS_NE8000',
    filename: 'BRAS_NE8000_2026-02-14_03-00-01.cfg',
    created_at: '2026-02-14T03:00:01',
    size: 45678,
    status: 'success',
  },
  {
    id: '2',
    device_id: 3,
    device_name: 'PPPoE_CARDOSO_MOREIRA',
    filename: 'PPPoE_CARDOSO_MOREIRA_2026-02-14_03-00-15.cfg',
    created_at: '2026-02-14T03:00:15',
    size: 32456,
    status: 'success',
  },
  {
    id: '3',
    device_id: 2,
    device_name: 'BRAS_NE8000',
    filename: 'BRAS_NE8000_2026-02-13_03-00-01.cfg',
    created_at: '2026-02-13T03:00:01',
    size: 45000,
    status: 'success',
  },
];

export default function Backups({
  devices,
  loading,
  onRefresh,
  onRunBackup,
  onDownloadBackup,
  onDeleteBackup,
}: BackupsProps) {
  const [backups, setBackups] = useState<Backup[]>(mockBackups);
  const [selectedDevice, setSelectedDevice] = useState<string>('all');
  const [runningBackup, setRunningBackup] = useState<number | null>(null);
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [selectedBackup, setSelectedBackup] = useState<Backup | null>(null);

  // Filter backups by device
  const filteredBackups = selectedDevice === 'all'
    ? backups
    : backups.filter(b => b.device_id === parseInt(selectedDevice));

  // Format file size
  const formatSize = (bytes: number) => {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
  };

  // Format date
  const formatDate = (dateStr: string) => {
    return new Date(dateStr).toLocaleString('pt-BR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  // Run backup for a device
  const handleRunBackup = async (deviceId: number) => {
    setRunningBackup(deviceId);
    try {
      await onRunBackup(deviceId);
      
      // Add new backup to list (simulated)
      const device = devices.find(d => d.id === deviceId);
      const newBackup: Backup = {
        id: `${Date.now()}`,
        device_id: deviceId,
        device_name: device?.name || 'Unknown',
        filename: `${device?.name}_${new Date().toISOString().replace(/[:.]/g, '-')}.cfg`,
        created_at: new Date().toISOString(),
        size: Math.floor(Math.random() * 50000) + 30000,
        status: 'success',
      };
      
      setBackups(prev => [newBackup, ...prev]);
      toast.success(`Backup de ${device?.name} concluído com sucesso`);
    } catch (error) {
      toast.error('Erro ao executar backup');
    } finally {
      setRunningBackup(null);
    }
  };

  // Handle delete backup
  const handleDeleteBackup = async () => {
    if (!selectedBackup) return;
    
    try {
      await onDeleteBackup(selectedBackup.id);
      setBackups(prev => prev.filter(b => b.id !== selectedBackup.id));
      toast.success('Backup removido com sucesso');
      setDeleteDialogOpen(false);
    } catch (error) {
      toast.error('Erro ao remover backup');
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row gap-4 justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Backups</h1>
          <p className="text-muted-foreground">
            Gerenciamento de configurações de equipamentos
          </p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" onClick={onRefresh} disabled={loading}>
            <RefreshCw className={`h-4 w-4 mr-2 ${loading ? 'animate-spin' : ''}`} />
            Atualizar
          </Button>
        </div>
      </div>

      {/* Quick Backup Actions */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Play className="h-5 w-5" />
            Backup Rápido
          </CardTitle>
          <CardDescription>
            Execute backup manual de qualquer dispositivo
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
            {devices.map((device) => (
              <div
                key={device.id}
                className="flex items-center justify-between p-4 border rounded-lg"
              >
                <div className="flex items-center gap-3">
                  <Server className={`h-5 w-5 ${
                    device.status === 'online' ? 'text-green-500' : 'text-red-500'
                  }`} />
                  <div>
                    <div className="font-medium">{device.name}</div>
                    <div className="text-xs text-muted-foreground">{device.ip}</div>
                  </div>
                </div>
                <Button
                  size="sm"
                  onClick={() => handleRunBackup(device.id)}
                  disabled={runningBackup === device.id || device.status !== 'online'}
                >
                  {runningBackup === device.id ? (
                    <Loader2 className="h-4 w-4 animate-spin" />
                  ) : (
                    <HardDrive className="h-4 w-4" />
                  )}
                </Button>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Stats */}
      <div className="grid gap-4 md:grid-cols-4">
        <Card>
          <CardContent className="pt-6">
            <div className="text-2xl font-bold">{backups.length}</div>
            <p className="text-xs text-muted-foreground">Total de Backups</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-6">
            <div className="text-2xl font-bold text-green-500">
              {backups.filter(b => b.status === 'success').length}
            </div>
            <p className="text-xs text-muted-foreground">Sucesso</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-6">
            <div className="text-2xl font-bold text-red-500">
              {backups.filter(b => b.status === 'failed').length}
            </div>
            <p className="text-xs text-muted-foreground">Falhou</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-6">
            <div className="text-2xl font-bold text-blue-500">
              {formatSize(backups.reduce((acc, b) => acc + b.size, 0))}
            </div>
            <p className="text-xs text-muted-foreground">Tamanho Total</p>
          </CardContent>
        </Card>
      </div>

      {/* Filter and List */}
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <div>
              <CardTitle>Histórico de Backups</CardTitle>
              <CardDescription>
                Todos os backups realizados automaticamente e manualmente
              </CardDescription>
            </div>
            <Select value={selectedDevice} onValueChange={setSelectedDevice}>
              <SelectTrigger className="w-[200px]">
                <SelectValue placeholder="Filtrar por dispositivo" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">Todos os dispositivos</SelectItem>
                {devices.map((device) => (
                  <SelectItem key={device.id} value={device.id.toString()}>
                    {device.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {filteredBackups.map((backup) => (
              <div
                key={backup.id}
                className="flex items-center justify-between p-4 border rounded-lg hover:bg-muted/50 transition-colors"
              >
                <div className="flex items-center gap-4">
                  <div className={`p-2 rounded-full ${
                    backup.status === 'success' 
                      ? 'bg-green-500/10 text-green-500' 
                      : backup.status === 'failed'
                      ? 'bg-red-500/10 text-red-500'
                      : 'bg-yellow-500/10 text-yellow-500'
                  }`}>
                    {backup.status === 'success' ? (
                      <CheckCircle2 className="h-5 w-5" />
                    ) : backup.status === 'failed' ? (
                      <XCircle className="h-5 w-5" />
                    ) : (
                      <Loader2 className="h-5 w-5 animate-spin" />
                    )}
                  </div>
                  <div>
                    <div className="font-medium">{backup.filename}</div>
                    <div className="text-sm text-muted-foreground flex items-center gap-2">
                      <span>{backup.device_name}</span>
                      <span>•</span>
                      <Clock className="h-3 w-3" />
                      <span>{formatDate(backup.created_at)}</span>
                      <span>•</span>
                      <span>{formatSize(backup.size)}</span>
                    </div>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <Badge variant="outline" className={
                    backup.status === 'success' 
                      ? 'text-green-500 border-green-500/20' 
                      : backup.status === 'failed'
                      ? 'text-red-500 border-red-500/20'
                      : 'text-yellow-500 border-yellow-500/20'
                  }>
                    {backup.status === 'success' ? 'Sucesso' : backup.status === 'failed' ? 'Falhou' : 'Executando'}
                  </Badge>
                  <Button
                    variant="ghost"
                    size="icon"
                    onClick={() => onDownloadBackup(backup.id)}
                    disabled={backup.status !== 'success'}
                  >
                    <Download className="h-4 w-4" />
                  </Button>
                  <Button
                    variant="ghost"
                    size="icon"
                    className="text-red-500 hover:text-red-600"
                    onClick={() => {
                      setSelectedBackup(backup);
                      setDeleteDialogOpen(true);
                    }}
                  >
                    <Trash2 className="h-4 w-4" />
                  </Button>
                </div>
              </div>
            ))}

            {filteredBackups.length === 0 && (
              <div className="text-center py-12 text-muted-foreground">
                <HardDrive className="h-12 w-12 mx-auto mb-4 opacity-50" />
                <p>Nenhum backup encontrado</p>
              </div>
            )}
          </div>
        </CardContent>
      </Card>

      {/* Schedule Info */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Calendar className="h-5 w-5" />
            Agendamento Automático
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex items-center gap-4 p-4 bg-muted/50 rounded-lg">
            <Clock className="h-8 w-8 text-blue-500" />
            <div>
              <div className="font-medium">Backup Diário Automático</div>
              <div className="text-sm text-muted-foreground">
                Todos os dias às 03:00 - Backup de todos os equipamentos online
              </div>
            </div>
            <Badge className="ml-auto">Ativo</Badge>
          </div>
        </CardContent>
      </Card>

      {/* Delete Confirmation Dialog */}
      <Dialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Confirmar Exclusão</DialogTitle>
            <DialogDescription>
              Tem certeza que deseja excluir o backup <strong>{selectedBackup?.filename}</strong>?
              Esta ação não pode ser desfeita.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeleteDialogOpen(false)}>
              Cancelar
            </Button>
            <Button variant="destructive" onClick={handleDeleteBackup}>
              Excluir
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
