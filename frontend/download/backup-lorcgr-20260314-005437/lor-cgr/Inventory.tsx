'use client';

import { useState } from 'react';
import {
  Plus,
  Search,
  Edit,
  Trash2,
  RefreshCw,
  Wifi,
  WifiOff,
  Server,
  MoreVertical,
  Save,
  X,
  Terminal,
  HardDrive,
  ExternalLink
} from 'lucide-react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Badge } from '@/components/ui/badge';
import { Switch } from '@/components/ui/switch';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Device } from '@/types/lor-cgr';
import { toast } from 'sonner';

interface InventoryProps {
  devices: Device[];
  loading: boolean;
  onRefresh: () => void;
  onAddDevice: (device: Partial<Device>) => Promise<void>;
  onUpdateDevice: (device: Partial<Device>) => Promise<void>;
  onDeleteDevice: (id: number) => Promise<void>;
  onOpenTerminal: (device: Device) => void;
  onRunBackup: (deviceId: number) => Promise<void>;
}

const deviceTypes = [
  { value: 'bras', label: 'BRAS' },
  { value: 'pppoe', label: 'PPPoE Server' },
  { value: 'olt', label: 'OLT' },
  { value: 'switch', label: 'Switch' },
  { value: 'router', label: 'Router' },
];

const vendors = [
  'Huawei',
  'Mikrotik',
  'Cisco',
  'Juniper',
  'Dell',
  'HP/Aruba',
  'Outro'
];

const backupFrequencies = [
  { value: 'hourly', label: 'A cada hora' },
  { value: 'daily', label: 'Diário' },
  { value: 'weekly', label: 'Semanal' },
  { value: 'monthly', label: 'Mensal' },
];

export default function Inventory({
  devices,
  loading,
  onRefresh,
  onAddDevice,
  onUpdateDevice,
  onDeleteDevice,
  onOpenTerminal,
  onRunBackup
}: InventoryProps) {
  const [searchTerm, setSearchTerm] = useState('');
  const [dialogOpen, setDialogOpen] = useState(false);
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [selectedDevice, setSelectedDevice] = useState<Device | null>(null);
  const [formData, setFormData] = useState<Partial<Device>>({
    name: '',
    ip: '',
    port: 22,
    vendor: '',
    device_type: 'router',
    ssh_user: '',
    ssh_password: '',
    snmp_community: '',
    snmp_port: 161,
    web_url: '',
    librenms_id: undefined,
    backup_enabled: true,
    backup_frequency: 'daily',
    backup_time: '01:00',
  });
  const [saving, setSaving] = useState(false);

  // Filtrar dispositivos
  const filteredDevices = devices.filter(device =>
    device.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    device.ip.includes(searchTerm) ||
    device.vendor?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const handleOpenAdd = () => {
    setSelectedDevice(null);
    setFormData({
      name: '',
      ip: '',
      port: 22,
      vendor: '',
      device_type: 'router',
      ssh_user: '',
      ssh_password: '',
      snmp_community: '',
      snmp_port: 161,
      web_url: '',
      librenms_id: undefined,
      backup_enabled: true,
      backup_frequency: 'daily',
      backup_time: '01:00',
    });
    setDialogOpen(true);
  };

  const handleOpenEdit = (device: Device) => {
    setSelectedDevice(device);
    setFormData({
      id: device.id,
      name: device.name,
      ip: device.ip,
      port: device.port || 22,
      vendor: device.vendor,
      device_type: device.device_type,
      ssh_user: device.ssh_user,
      ssh_password: device.ssh_password,
      snmp_community: device.snmp_community,
      snmp_port: device.snmp_port || 161,
      web_url: device.web_url,
      librenms_id: device.librenms_id,
      backup_enabled: device.backup_enabled ?? true,
      backup_frequency: device.backup_frequency || 'daily',
      backup_time: device.backup_time || '01:00',
    });
    setDialogOpen(true);
  };

  const handleOpenDelete = (device: Device) => {
    setSelectedDevice(device);
    setDeleteDialogOpen(true);
  };

  const handleSave = async () => {
    if (!formData.name || !formData.ip) {
      toast.error('Nome e IP são obrigatórios');
      return;
    }

    setSaving(true);
    try {
      if (selectedDevice) {
        await onUpdateDevice(formData);
      } else {
        await onAddDevice(formData);
      }
      setDialogOpen(false);
    } catch (error) {
      console.error('Error saving device:', error);
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async () => {
    if (!selectedDevice) return;

    setSaving(true);
    try {
      await onDeleteDevice(selectedDevice.id);
      setDeleteDialogOpen(false);
    } catch (error) {
      console.error('Error deleting device:', error);
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row gap-4 justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Inventário</h1>
          <p className="text-muted-foreground">
            Gerenciamento de equipamentos de rede
          </p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" onClick={onRefresh} disabled={loading}>
            <RefreshCw className={`h-4 w-4 mr-2 ${loading ? 'animate-spin' : ''}`} />
            Atualizar
          </Button>
          <Button onClick={handleOpenAdd}>
            <Plus className="h-4 w-4 mr-2" />
            Novo Dispositivo
          </Button>
        </div>
      </div>

      {/* Search */}
      <Card>
        <CardContent className="pt-6">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <Input
              placeholder="Buscar por nome, IP ou vendor..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="pl-9"
            />
          </div>
        </CardContent>
      </Card>

      {/* Stats */}
      <div className="grid gap-4 md:grid-cols-4">
        <Card>
          <CardContent className="pt-6">
            <div className="text-2xl font-bold">{devices.length}</div>
            <p className="text-xs text-muted-foreground">Total de Dispositivos</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-6">
            <div className="text-2xl font-bold text-green-500">
              {devices.filter(d => d.status === 'online').length}
            </div>
            <p className="text-xs text-muted-foreground">Online</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-6">
            <div className="text-2xl font-bold text-red-500">
              {devices.filter(d => d.status === 'offline').length}
            </div>
            <p className="text-xs text-muted-foreground">Offline</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-6">
            <div className="text-2xl font-bold text-blue-500">
              {devices.filter(d => d.device_type === 'bras').length}
            </div>
            <p className="text-xs text-muted-foreground">BRAS</p>
          </CardContent>
        </Card>
      </div>

      {/* Device List */}
      <Card>
        <CardHeader>
          <CardTitle>Dispositivos</CardTitle>
          <CardDescription>
            {filteredDevices.length} de {devices.length} dispositivos
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {filteredDevices.map((device) => (
              <div
                key={device.id}
                className="flex items-center justify-between p-4 border rounded-lg hover:bg-muted/50 transition-colors"
              >
                <div className="flex items-center gap-4">
                  <div className={`p-3 rounded-lg ${
                    device.status === 'online' 
                      ? 'bg-green-500/10 text-green-500' 
                      : 'bg-red-500/10 text-red-500'
                  }`}>
                    {device.status === 'online' ? (
                      <Wifi className="h-6 w-6" />
                    ) : (
                      <WifiOff className="h-6 w-6" />
                    )}
                  </div>
                  <div>
                    <div className="font-medium text-lg flex items-center gap-2">
                      {device.name}
                      {device.web_url && (
                        <a 
                          href={device.web_url} 
                          target="_blank" 
                          rel="noopener noreferrer"
                          className="text-muted-foreground hover:text-primary"
                        >
                          <ExternalLink className="h-4 w-4" />
                        </a>
                      )}
                    </div>
                    <div className="text-sm text-muted-foreground flex items-center gap-2">
                      <span>{device.ip}:{device.port || 22}</span>
                      <span>•</span>
                      <span>{device.vendor}</span>
                      {device.model && (
                        <>
                          <span>•</span>
                          <span>{device.model}</span>
                        </>
                      )}
                    </div>
                  </div>
                </div>

                <div className="flex items-center gap-3">
                  <Badge variant="outline" className="capitalize">
                    {deviceTypes.find(t => t.value === device.device_type)?.label || device.device_type}
                  </Badge>
                  
                  {device.pppoe_count !== undefined && device.pppoe_count > 0 && (
                    <Badge className="bg-blue-500/10 text-blue-500 border-blue-500/20">
                      {device.pppoe_count} PPPoE
                    </Badge>
                  )}

                  {device.backup_enabled && (
                    <Badge className="bg-green-500/10 text-green-500 border-green-500/20">
                      Backup ON
                    </Badge>
                  )}

                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <Button variant="ghost" size="icon">
                        <MoreVertical className="h-4 w-4" />
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end">
                      <DropdownMenuItem onClick={() => handleOpenEdit(device)}>
                        <Edit className="h-4 w-4 mr-2" />
                        Editar
                      </DropdownMenuItem>
                      <DropdownMenuItem onClick={() => onOpenTerminal(device)}>
                        <Terminal className="h-4 w-4 mr-2" />
                        Terminal SSH
                      </DropdownMenuItem>
                      <DropdownMenuItem onClick={() => onRunBackup(device.id)}>
                        <HardDrive className="h-4 w-4 mr-2" />
                        Executar Backup
                      </DropdownMenuItem>
                      {device.librenms_id && (
                        <DropdownMenuItem asChild>
                          <a 
                            href={`http://45.71.242.131/librenms/device/device=${device.librenms_id}/`}
                            target="_blank"
                            rel="noopener noreferrer"
                          >
                            <ExternalLink className="h-4 w-4 mr-2" />
                            Ver no LibreNMS
                          </a>
                        </DropdownMenuItem>
                      )}
                      <DropdownMenuSeparator />
                      <DropdownMenuItem 
                        className="text-red-500"
                        onClick={() => handleOpenDelete(device)}
                      >
                        <Trash2 className="h-4 w-4 mr-2" />
                        Remover
                      </DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>
                </div>
              </div>
            ))}

            {filteredDevices.length === 0 && (
              <div className="text-center py-12 text-muted-foreground">
                <Server className="h-12 w-12 mx-auto mb-4 opacity-50" />
                <p>Nenhum dispositivo encontrado</p>
              </div>
            )}
          </div>
        </CardContent>
      </Card>

      {/* Add/Edit Dialog */}
      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>
              {selectedDevice ? 'Editar Dispositivo' : 'Novo Dispositivo'}
            </DialogTitle>
            <DialogDescription>
              Preencha os dados do equipamento de rede
            </DialogDescription>
          </DialogHeader>

          <Tabs defaultValue="basic" className="w-full">
            <TabsList className="grid w-full grid-cols-4">
              <TabsTrigger value="basic">Básico</TabsTrigger>
              <TabsTrigger value="ssh">SSH</TabsTrigger>
              <TabsTrigger value="snmp">SNMP</TabsTrigger>
              <TabsTrigger value="backup">Backup</TabsTrigger>
            </TabsList>

            <TabsContent value="basic" className="space-y-4 mt-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="name">Nome/Hostname *</Label>
                  <Input
                    id="name"
                    value={formData.name || ''}
                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                    placeholder="BRAS_NE8000"
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="device_type">Tipo</Label>
                  <Select
                    value={formData.device_type || 'router'}
                    onValueChange={(value) => setFormData({ ...formData, device_type: value as Device['device_type'] })}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Selecione" />
                    </SelectTrigger>
                    <SelectContent>
                      {deviceTypes.map((type) => (
                        <SelectItem key={type.value} value={type.value}>
                          {type.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="ip">Endereço IP *</Label>
                  <Input
                    id="ip"
                    value={formData.ip || ''}
                    onChange={(e) => setFormData({ ...formData, ip: e.target.value })}
                    placeholder="192.168.1.1"
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="port">Porta SSH</Label>
                  <Input
                    id="port"
                    type="number"
                    value={formData.port || 22}
                    onChange={(e) => setFormData({ ...formData, port: parseInt(e.target.value) })}
                  />
                </div>
              </div>
              <div className="space-y-2">
                <Label htmlFor="vendor">Vendor/Fabricante</Label>
                <Select
                  value={formData.vendor || ''}
                  onValueChange={(value) => setFormData({ ...formData, vendor: value })}
                >
                  <SelectTrigger>
                    <SelectValue placeholder="Selecione o fabricante" />
                  </SelectTrigger>
                  <SelectContent>
                    {vendors.map((v) => (
                      <SelectItem key={v} value={v}>{v}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label htmlFor="model">Modelo</Label>
                <Input
                  id="model"
                  value={formData.model || ''}
                  onChange={(e) => setFormData({ ...formData, model: e.target.value })}
                  placeholder="NetEngine 8000"
                />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="web_url">URL Web Interface</Label>
                  <Input
                    id="web_url"
                    value={formData.web_url || ''}
                    onChange={(e) => setFormData({ ...formData, web_url: e.target.value })}
                    placeholder="https://192.168.1.1/"
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="librenms_id">LibreNMS ID</Label>
                  <Input
                    id="librenms_id"
                    type="number"
                    value={formData.librenms_id || ''}
                    onChange={(e) => setFormData({ ...formData, librenms_id: parseInt(e.target.value) || undefined })}
                    placeholder="1"
                  />
                </div>
              </div>
            </TabsContent>

            <TabsContent value="ssh" className="space-y-4 mt-4">
              <div className="space-y-2">
                <Label htmlFor="ssh_user">Usuário SSH</Label>
                <Input
                  id="ssh_user"
                  value={formData.ssh_user || ''}
                  onChange={(e) => setFormData({ ...formData, ssh_user: e.target.value })}
                  placeholder="admin"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="ssh_password">Senha SSH</Label>
                <Input
                  id="ssh_password"
                  type="password"
                  value={formData.ssh_password || ''}
                  onChange={(e) => setFormData({ ...formData, ssh_password: e.target.value })}
                  placeholder="••••••••"
                />
              </div>
              <div className="p-4 bg-muted rounded-lg text-sm text-muted-foreground">
                <p><strong>Nota:</strong> As credenciais SSH são usadas para:</p>
                <ul className="list-disc list-inside mt-2 space-y-1">
                  <li>Terminal SSH interativo</li>
                  <li>Backup automático de configurações</li>
                  <li>Coleta de informações do equipamento</li>
                </ul>
              </div>
            </TabsContent>

            <TabsContent value="snmp" className="space-y-4 mt-4">
              <div className="space-y-2">
                <Label htmlFor="snmp_community">SNMP Community</Label>
                <Input
                  id="snmp_community"
                  value={formData.snmp_community || ''}
                  onChange={(e) => setFormData({ ...formData, snmp_community: e.target.value })}
                  placeholder="public"
                />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="snmp_port">Porta SNMP</Label>
                  <Input
                    id="snmp_port"
                    type="number"
                    value={formData.snmp_port || 161}
                    onChange={(e) => setFormData({ ...formData, snmp_port: parseInt(e.target.value) })}
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="snmp_version">Versão SNMP</Label>
                  <Select
                    value={formData.snmp_version || 'v2c'}
                    onValueChange={(value) => setFormData({ ...formData, snmp_version: value })}
                  >
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="v2c">v2c</SelectItem>
                      <SelectItem value="v3">v3</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>
            </TabsContent>

            <TabsContent value="backup" className="space-y-4 mt-4">
              <div className="flex items-center justify-between p-4 border rounded-lg">
                <div className="space-y-0.5">
                  <Label>Backup Automático</Label>
                  <p className="text-sm text-muted-foreground">
                    Ativar backup automático das configurações
                  </p>
                </div>
                <Switch
                  checked={formData.backup_enabled ?? true}
                  onCheckedChange={(checked) => setFormData({ ...formData, backup_enabled: checked })}
                />
              </div>
              
              {formData.backup_enabled && (
                <>
                  <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <Label>Frequência</Label>
                      <Select
                        value={formData.backup_frequency || 'daily'}
                        onValueChange={(value) => setFormData({ ...formData, backup_frequency: value })}
                      >
                        <SelectTrigger>
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          {backupFrequencies.map((f) => (
                            <SelectItem key={f.value} value={f.value}>{f.label}</SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="backup_time">Horário</Label>
                      <Input
                        id="backup_time"
                        type="time"
                        value={formData.backup_time || '01:00'}
                        onChange={(e) => setFormData({ ...formData, backup_time: e.target.value })}
                      />
                    </div>
                  </div>
                </>
              )}
            </TabsContent>
          </Tabs>

          <DialogFooter>
            <Button variant="outline" onClick={() => setDialogOpen(false)}>
              Cancelar
            </Button>
            <Button onClick={handleSave} disabled={saving}>
              {saving ? (
                <RefreshCw className="h-4 w-4 mr-2 animate-spin" />
              ) : (
                <Save className="h-4 w-4 mr-2" />
              )}
              Salvar
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete Confirmation Dialog */}
      <Dialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Confirmar Remoção</DialogTitle>
            <DialogDescription>
              Tem certeza que deseja remover o dispositivo <strong>{selectedDevice?.name}</strong>?
              Esta ação não pode ser desfeita.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeleteDialogOpen(false)}>
              Cancelar
            </Button>
            <Button variant="destructive" onClick={handleDelete} disabled={saving}>
              {saving && <RefreshCw className="h-4 w-4 mr-2 animate-spin" />}
              Remover
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
