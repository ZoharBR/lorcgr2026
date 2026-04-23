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
  Terminal,
  HardDrive,
  ExternalLink,
  Activity,
  RefreshCcw,
  CheckCircle2,
  XCircle,
  Link2
} from 'lucide-react';
import { useEquipmentMonitoring } from '@/hooks/useEquipmentMonitoring';
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
  { value: 'huawei', label: 'Huawei' },
  { value: 'mikrotik', label: 'Mikrotik' },
  { value: 'cisco', label: 'Cisco' },
  { value: 'juniper', label: 'Juniper' },
  { value: 'dell', label: 'Dell' },
  { value: 'hp', label: 'HP/Aruba' },
  { value: 'aruba', label: 'Aruba' },
  { value: 'outro', label: 'Outro' }
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
    protocol: 'ssh',
    ssh_user: '',
    ssh_password: '',
    ssh_port: 22,
    ssh_version: '2',
    telnet_enabled: false,
    telnet_port: 23,
    snmp_community: '',
    snmp_port: 161,
    snmp_version: 'v2c',
    web_url: '',
    librenms_id: undefined,
    backup_enabled: true,
    backup_frequency: 'daily',
    backup_time: '01:00',
    location: '',
  });
  const [saving, setSaving] = useState(false);
  const [syncingLibreNMS, setSyncingLibreNMS] = useState(false);
  const [syncingZabbix, setSyncingZabbix] = useState(false);
  const [syncingDevice, setSyncingDevice] = useState<number | null>(null);
  const [pingingDevices, setPingingDevices] = useState<Set<number>>(new Set());
  const [discovering, setDiscovering] = useState(false);

  // Monitoramento Real-time via ICMP
  const {
    data: monitoringData,
    loading: monitoringLoading,
    getStatusColor,
    getStatusAnimation,
    formatLatency,
  } = useEquipmentMonitoring(60000); // Atualiza a cada 60s


  // Discover device info from LibreNMS by IP
  const handleDiscoverFromIP = async () => {
    if (!formData.ip) {
      toast.error('Digite um IP primeiro');
      return;
    }
    
    setDiscovering(true);
    try {
      const response = await fetch(`http://45.71.242.131/api/equipments/discover_from_ip/?ip=${formData.ip}`);
      const data = await response.json();
      
      if (data.found) {
        setFormData(prev => ({
          ...prev,
          name: data.name || prev.name,
          ip: data.ip || prev.ip,
          vendor: data.vendor || prev.vendor,
          model: data.model || prev.model,
          librenms_id: data.librenms_id || prev.librenms_id,
          snmp_community: data.snmp_community || prev.snmp_community,
        }));
        toast.success(`Encontrado: ${data.name} (${data.vendor} ${data.model})`);
      } else {
        toast.warning('Dispositivo não encontrado no LibreNMS');
      }
    } catch (error) {
      toast.error('Erro ao buscar informações do LibreNMS');
    }
    setDiscovering(false);
  };

  // Helper function to get ping color from REAL-TIME ICMP monitoring
  const getPingStatus = (device: Device) => {
    // Buscar status real do monitoring data
    const realStatus = monitoringData.find(m => m.id === device.id);
    
    if (realStatus) {
      // Usar dados REAIS do ICMP
      if (realStatus.status === 'offline') {
        return { color: 'red', label: 'OFFLINE', animate: true };
      } else if (realStatus.status === 'degraded') {
        return { color: 'orange', label: `${formatLatency(realStatus.latency_ms)}`, animate: false };
      } else {
        // Online - verificar latência para cor
        const ms = realStatus.latency_ms || 0;
        if (ms > 20) {
          return { color: 'yellow', label: `${formatLatency(ms)} (lento)`, animate: false };
        }
        return { color: 'green', label: `${formatLatency(ms)}`, animate: false };
      }
    }
    
    // Fallback para dados estáticos se não tiver monitoring ainda
    if (device.status === 'offline' || device.ping_ms === undefined) {
      return { color: 'red', label: 'Offline', animate: device.status === 'offline' };
    }
    const ms = device.ping_ms;
    if (ms < 10) {
      return { color: 'green', label: `${ms}ms`, animate: false };
    } else if (ms <= 30) {
      return { color: 'yellow', label: `${ms}ms`, animate: false };
    } else {
      return { color: 'orange', label: `${ms}ms`, animate: false };
    }
  };

  // Sync single device with all systems
  const handleSyncDevice = async (deviceId: number) => {
    setSyncingDevice(deviceId);
    try {
      // Sync to LibreNMS
      const librenmsRes = await fetch(`http://45.71.242.131/api/equipments/${deviceId}/sync_to_librenms/`, {
        method: 'POST',
      });
      // Sync to Zabbix  
      const zabbixRes = await fetch(`http://45.71.242.131/api/equipments/${deviceId}/sync_to_zabbix/`, {
        method: 'POST',
      });
      
      if (librenmsRes.ok && zabbixRes.ok) {
        toast.success('Sincronização concluída!');
      } else {
        toast.warning('Sincronização parcial - verifique os sistemas');
      }
      onRefresh();
    } catch (error) {
      toast.error('Erro ao sincronizar dispositivo');
    }
    setSyncingDevice(null);
  };

  // Sync all devices with LibreNMS
  const handleSyncLibreNMS = async () => {
    setSyncingLibreNMS(true);
    try {
      const response = await fetch('http://45.71.242.131/api/equipments/sync_all/', {
        method: 'POST',
      });
      if (response.ok) {
        toast.success('Sincronização com LibreNMS concluída!');
        onRefresh();
      } else {
        toast.error('Erro ao sincronizar com LibreNMS');
      }
    } catch (error) {
      toast.error('Erro de conexão');
    }
    setSyncingLibreNMS(false);
  };

  // Sync all with Zabbix
  const handleSyncZabbix = async () => {
    setSyncingZabbix(true);
    try {
      // Sync each device
      for (const device of devices) {
        await fetch(`http://45.71.242.131/api/equipments/${device.id}/sync_to_zabbix/`, {
          method: 'POST',
        });
      }
      toast.success('Sincronização com Zabbix concluída!');
      onRefresh();
    } catch (error) {
      toast.error('Erro ao sincronizar com Zabbix');
    }
    setSyncingZabbix(false);
  };

  // Test ping for a single device
  const handleTestPing = async (deviceId: number) => {
    setPingingDevices(prev => new Set([...prev, deviceId]));
    try {
      const response = await fetch(`http://45.71.242.131:8000/api/devices/${deviceId}/ping/`, {
        method: 'POST',
      });
      if (response.ok) {
        toast.success('Ping realizado com sucesso');
        onRefresh();
      }
    } catch (error) {
      toast.error('Erro ao executar ping');
    }
    setTimeout(() => {
      setPingingDevices(prev => {
        const newSet = new Set(prev);
        newSet.delete(deviceId);
        return newSet;
      });
    }, 5000);
  };

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
      protocol: 'ssh',
      ssh_user: '',
      ssh_password: '',
      ssh_port: 22,
      ssh_version: '2',
      telnet_enabled: false,
      telnet_port: 23,
      snmp_community: '',
      snmp_port: 161,
      snmp_version: 'v2c',
      web_url: '',
      librenms_id: undefined,
      backup_enabled: true,
      backup_frequency: 'daily',
      backup_time: '01:00',
      location: '',
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
      protocol: device.protocol || 'ssh',
      ssh_user: device.ssh_user || '',
      ssh_password: device.ssh_password || '',
      ssh_port: device.ssh_port || 22,
      ssh_version: device.ssh_version || '2',
      telnet_enabled: device.telnet_enabled || false,
      telnet_port: device.telnet_port || 23,
      snmp_community: device.snmp_community || '',
      snmp_port: device.snmp_port || 161,
      snmp_version: device.snmp_version || 'v2c',
      web_url: device.web_url,
      librenms_id: device.librenms_id,
      backup_enabled: device.backup_enabled ?? true,
      backup_frequency: device.backup_frequency || 'daily',
      backup_time: device.backup_time || '01:00',
      location: device.location || '',
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
          <h1 className="text-3xl font-bold tracking-tight">Equipamentos</h1>
          <p className="text-muted-foreground">
            Gerenciamento de equipamentos de rede
          </p>
        </div>
        <div className="flex gap-2 flex-wrap">
          <Button variant="outline" onClick={onRefresh} disabled={loading}>
            <RefreshCw className={`h-4 w-4 mr-2 ${loading ? 'animate-spin' : ''}`} />
            Atualizar
          </Button>
          <Button variant="outline" onClick={handleSyncLibreNMS} disabled={syncingLibreNMS}>
            <RefreshCcw className={`h-4 w-4 mr-2 ${syncingLibreNMS ? 'animate-spin' : ''}`} />
            Sync LibreNMS
          </Button>
          <Button variant="outline" onClick={handleSyncZabbix} disabled={syncingZabbix}>
            <RefreshCcw className={`h-4 w-4 mr-2 ${syncingZabbix ? 'animate-spin' : ''}`} />
            Sync Zabbix
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
            {filteredDevices.map((device) => {
              const pingStatus = getPingStatus(device);
              return (
              <div
                key={device.id}
                className="flex items-center justify-between p-4 border rounded-lg hover:bg-muted/50 transition-colors"
              >
                <div className="flex items-center gap-4">
                  <div className={`p-3 rounded-lg relative ${
                    pingStatus.color === 'green' ? 'bg-green-500/10 text-green-500' :
                    pingStatus.color === 'yellow' ? 'bg-yellow-500/10 text-yellow-500' :
                    pingStatus.color === 'orange' ? 'bg-orange-500/10 text-orange-500' :
                    'bg-red-500/10 text-red-500'
                  }`}>
                    {device.status === 'online' ? (
                      <Wifi className="h-6 w-6" />
                    ) : (
                      <WifiOff className={`h-6 w-6 ${pingStatus.animate ? 'animate-pulse' : ''}`} />
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
                      {/* Ping status indicator */}
                      <Badge className={`ml-2 ${
                        pingStatus.color === 'green' ? 'bg-green-500/10 text-green-500 border-green-500/20' :
                        pingStatus.color === 'yellow' ? 'bg-yellow-500/10 text-yellow-500 border-yellow-500/20' :
                        pingStatus.color === 'orange' ? 'bg-orange-500/10 text-orange-500 border-orange-500/20' :
                        'bg-red-500/10 text-red-500 border-red-500/20'
                      } ${pingStatus.animate ? 'animate-pulse' : ''}`}>
                        <Activity className="h-3 w-3 mr-1" />
                        {pingStatus.label}
                      </Badge>
                    </div>
                    <div className="text-sm text-muted-foreground flex items-center gap-2">
                      <span>{device.ip}</span>
                      <span>•</span>
                      <span>{device.vendor}</span>
                      {device.model && (
                        <>
                          <span>•</span>
                          <span>{device.model}</span>
                        </>
                      )}
                      <span>•</span>
                      <span className="capitalize">{device.protocol || 'ssh'}</span>
                    </div>
                  </div>
                </div>

                <div className="flex items-center gap-3">
                  {/* Status de Sincronização */}
                  <div className="flex items-center gap-2">
                    {/* LibreNMS Status */}
                    <div className="flex items-center gap-1" title={device.librenms_id ? `LibreNMS ID: ${device.librenms_id}` : 'Não sincronizado com LibreNMS'}>
                      {device.librenms_id ? (
                        <a 
                          href={`http://45.71.242.131:8080/device/device=${device.librenms_id}/`}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="flex items-center gap-1"
                        >
                          <CheckCircle2 className="h-4 w-4 text-green-500" />
                          <Badge className="bg-blue-500/10 text-blue-500 border-blue-500/20 text-xs cursor-pointer hover:bg-blue-500/20">
                            LibreNMS
                          </Badge>
                        </a>
                      ) : (
                        <XCircle className="h-4 w-4 text-red-500" title="Não sincronizado" />
                      )}
                    </div>
                    
                    {/* Zabbix Status */}
                    <div className="flex items-center gap-1" title={device.zabbix_id ? `Zabbix ID: ${device.zabbix_id}` : 'Não sincronizado com Zabbix'}>
                      {device.zabbix_id ? (
                        <a 
                          href={`http://45.71.242.131:8081/hosts.php?hostid=${device.zabbix_id}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="flex items-center gap-1"
                        >
                          <CheckCircle2 className="h-4 w-4 text-green-500" />
                          <Badge className="bg-red-500/10 text-red-500 border-red-500/20 text-xs cursor-pointer hover:bg-red-500/20">
                            Zabbix
                          </Badge>
                        </a>
                      ) : (
                        <XCircle className="h-4 w-4 text-red-500" title="Não sincronizado" />
                      )}
                    </div>
                    
                    {/* Sync Button */}
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => handleSyncDevice(device.id)}
                      disabled={syncingDevice === device.id}
                      title="Sincronizar com todos os sistemas"
                    >
                      <RefreshCw className={`h-4 w-4 ${syncingDevice === device.id ? 'animate-spin' : ''}`} />
                    </Button>
                  </div>
                  
                  <Badge variant="outline" className="capitalize">
                    {deviceTypes.find(t => t.value === device.device_type)?.label || device.device_type}
                  </Badge>
                  
                  {device.ssh_user && (
                    <Badge className="bg-blue-500/10 text-blue-500 border-blue-500/20">
                      SSH: {device.ssh_user}
                    </Badge>
                  )}

                  {device.telnet_enabled && (
                    <Badge className="bg-yellow-500/10 text-yellow-500 border-yellow-500/20">
                      Telnet:{device.telnet_port}
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
                        Terminal
                      </DropdownMenuItem>
                      <DropdownMenuItem onClick={() => onRunBackup(device.id)}>
                        <HardDrive className="h-4 w-4 mr-2" />
                        Executar Backup
                      </DropdownMenuItem>
                      {device.librenms_id && (
                        <DropdownMenuItem asChild>
                          <a 
                            href={`http://45.71.242.131:8080/device/device=${device.librenms_id}/`}
                            target="_blank"
                            rel="noopener noreferrer"
                          >
                            <ExternalLink className="h-4 w-4 mr-2" />
                            Abrir no LibreNMS
                          </a>
                        </DropdownMenuItem>
                      )}
                      {device.zabbix_id && (
                        <DropdownMenuItem asChild>
                          <a 
                            href={`http://45.71.242.131:8081/hosts.php?hostid=${device.zabbix_id}`}
                            target="_blank"
                            rel="noopener noreferrer"
                          >
                            <ExternalLink className="h-4 w-4 mr-2" />
                            Abrir no Zabbix
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
              );
            })}

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
            <TabsList className="grid w-full grid-cols-5">
              <TabsTrigger value="basic">Básico</TabsTrigger>
              <TabsTrigger value="ssh">SSH</TabsTrigger>
              <TabsTrigger value="telnet">Telnet</TabsTrigger>
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
                  <div className="flex gap-2">
                    <Input
                      id="ip"
                      value={formData.ip || ''}
                      onChange={(e) => setFormData({ ...formData, ip: e.target.value })}
                      placeholder="192.168.1.1"
                      className="flex-1"
                    />
                    <Button 
                      type="button" 
                      variant="outline" 
                      onClick={handleDiscoverFromIP}
                      disabled={discovering}
                      title="Buscar informações no LibreNMS"
                    >
                      <Search className={`h-4 w-4 ${discovering ? 'animate-pulse' : ''}`} />
                    </Button>
                  </div>
                  <p className="text-xs text-muted-foreground">Clique na lupa para buscar dados no LibreNMS</p>
                </div>
                <div className="space-y-2">
                  <Label htmlFor="vendor">Vendor/Fabricante</Label>
                  <Select
                    value={formData.vendor?.toLowerCase() || ''}
                    onValueChange={(value) => setFormData({ ...formData, vendor: value })}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Selecione" />
                    </SelectTrigger>
                    <SelectContent>
                      {vendors.map((v) => (
                        <SelectItem key={v.value} value={v.value}>{v.label}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="model">Modelo</Label>
                  <Input
                    id="model"
                    value={formData.model || ''}
                    onChange={(e) => setFormData({ ...formData, model: e.target.value })}
                    placeholder="NetEngine 8000"
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="location">Localização</Label>
                  <Input
                    id="location"
                    value={formData.location || ''}
                    onChange={(e) => setFormData({ ...formData, location: e.target.value })}
                    placeholder="Data Center Principal"
                  />
                </div>
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
              <div className="p-4 border rounded-lg bg-blue-500/5 border-blue-500/20">
                <div className="flex items-center gap-2 mb-2">
                  <Badge className="bg-blue-500">SSH</Badge>
                  <span className="text-sm text-muted-foreground">Secure Shell</span>
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4">
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
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="ssh_port">Porta SSH</Label>
                  <Input
                    id="ssh_port"
                    type="number"
                    value={formData.ssh_port || 22}
                    onChange={(e) => setFormData({ ...formData, ssh_port: parseInt(e.target.value) })}
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="ssh_version">Versão SSH</Label>
                  <Select
                    value={formData.ssh_version || '2'}
                    onValueChange={(value) => setFormData({ ...formData, ssh_version: value })}
                  >
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="2">SSH-2</SelectItem>
                      <SelectItem value="1">SSH-1</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>
              <div className="flex items-center justify-between p-4 border rounded-lg">
                <div className="space-y-0.5">
                  <Label>Usar SSH como protocolo padrão</Label>
                  <p className="text-sm text-muted-foreground">
                    Terminal e backup usarão SSH por padrão
                  </p>
                </div>
                <Switch
                  checked={formData.protocol === 'ssh'}
                  onCheckedChange={(checked) => setFormData({ ...formData, protocol: checked ? 'ssh' : 'telnet' })}
                />
              </div>
            </TabsContent>

            <TabsContent value="telnet" className="space-y-4 mt-4">
              <div className="flex items-center justify-between p-4 border rounded-lg bg-yellow-500/5 border-yellow-500/20">
                <div className="flex items-center gap-2">
                  <Badge className="bg-yellow-500">Telnet</Badge>
                  <span className="text-sm text-muted-foreground">Protocolo inseguro - use apenas quando necessário</span>
                </div>
                <Switch
                  checked={formData.telnet_enabled || false}
                  onCheckedChange={(checked) => setFormData({ 
                    ...formData, 
                    telnet_enabled: checked,
                    protocol: checked ? 'telnet' : 'ssh'
                  })}
                />
              </div>
              
              {formData.telnet_enabled && (
                <>
                  <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <Label htmlFor="telnet_user">Usuário Telnet</Label>
                      <Input
                        id="telnet_user"
                        value={formData.ssh_user || ''}
                        onChange={(e) => setFormData({ ...formData, ssh_user: e.target.value })}
                        placeholder="admin"
                      />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="telnet_password">Senha Telnet</Label>
                      <Input
                        id="telnet_password"
                        type="password"
                        value={formData.ssh_password || ''}
                        onChange={(e) => setFormData({ ...formData, ssh_password: e.target.value })}
                        placeholder="••••••••"
                      />
                    </div>
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="telnet_port">Porta Telnet</Label>
                    <Input
                      id="telnet_port"
                      type="number"
                      value={formData.telnet_port || 23}
                      onChange={(e) => setFormData({ ...formData, telnet_port: parseInt(e.target.value) })}
                    />
                  </div>
                  <div className="p-3 bg-yellow-500/10 rounded-lg text-sm text-yellow-600">
                    ⚠️ Telnet transmite dados sem criptografia. Use SSH sempre que possível.
                  </div>
                </>
              )}
            </TabsContent>

            <TabsContent value="snmp" className="space-y-4 mt-4">
              <div className="p-4 border rounded-lg bg-purple-500/5 border-purple-500/20">
                <div className="flex items-center gap-2">
                  <Badge className="bg-purple-500">SNMP</Badge>
                  <span className="text-sm text-muted-foreground">Simple Network Management Protocol</span>
                </div>
              </div>
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
                      <SelectItem value="v1">v1</SelectItem>
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
                  <div className="space-y-2">
                    <Label>Método de Backup</Label>
                    <Select
                      value={formData.protocol || 'ssh'}
                      onValueChange={(value) => setFormData({ ...formData, protocol: value as 'ssh' | 'telnet' })}
                    >
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="ssh">SSH (Recomendado)</SelectItem>
                        <SelectItem value="telnet">Telnet</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
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
