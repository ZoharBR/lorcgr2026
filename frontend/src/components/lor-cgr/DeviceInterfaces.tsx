'use client';

import { useEffect, useState } from 'react';
import {
  Network,
  Activity,
  Thermometer,
  Zap,
  ArrowDownCircle,
  ArrowUpCircle,
  RefreshCw,
  AlertTriangle,
  CheckCircle,
  XCircle,
  Cpu,
  Clock,
  Info
} from 'lucide-react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import {
  ChartConfig,
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
} from '@/components/ui/chart';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, ResponsiveContainer, LineChart, Line, Area, AreaChart } from 'recharts';
import { DeviceInterface, DDMData, InterfaceStats, InterfaceTraffic } from '@/types/lor-cgr';
import apiClient from '@/lib/api/lor-cgr';

interface DeviceInterfacesProps {
  deviceId: number;
  deviceName: string;
}

// DDM Status helper
const getDDMStatus = (value: number | undefined, lowWarn: number, highWarn: number, lowAlarm: number, highAlarm: number): 'normal' | 'warning' | 'critical' => {
  if (value === undefined) return 'normal';
  if (value <= lowAlarm || value >= highAlarm) return 'critical';
  if (value <= lowWarn || value >= highWarn) return 'warning';
  return 'normal';
};

// Format power in dBm
const formatPower = (power: number | undefined): string => {
  if (power === undefined || power === null) return '-';
  return `${power.toFixed(2)} dBm`;
};

// Format temperature
const formatTemperature = (temp: number | undefined): string => {
  if (temp === undefined || temp === null) return '-';
  return `${temp.toFixed(1)}°C`;
};

// Format bias current
const formatBiasCurrent = (bias: number | undefined): string => {
  if (bias === undefined || bias === null) return '-';
  return `${(bias * 1000).toFixed(1)} mA`;
};

// Format speed
const formatSpeed = (speed: number | undefined): string => {
  if (!speed) return '-';
  if (speed >= 1000000000) return `${(speed / 1000000000).toFixed(0)}G`;
  if (speed >= 1000000) return `${(speed / 1000000).toFixed(0)}M`;
  return `${speed}`;
};

// Status badge component
const StatusBadge = ({ status }: { status: string }) => {
  const config: Record<string, { color: string; icon: React.ReactNode }> = {
    up: { color: 'bg-green-500/10 text-green-500 border-green-500/20', icon: <CheckCircle className="h-3 w-3" /> },
    down: { color: 'bg-red-500/10 text-red-500 border-red-500/20', icon: <XCircle className="h-3 w-3" /> },
    testing: { color: 'bg-yellow-500/10 text-yellow-500 border-yellow-500/20', icon: <Activity className="h-3 w-3" /> },
    dormant: { color: 'bg-gray-500/10 text-gray-500 border-gray-500/20', icon: <Network className="h-3 w-3" /> },
  };
  const { color, icon } = config[status] || config.dormant;
  return (
    <Badge variant="outline" className={`${color} flex items-center gap-1`}>
      {icon}
      {status}
    </Badge>
  );
};

// DDM Status badge
const DDMStatusBadge = ({ status }: { status: 'normal' | 'warning' | 'critical' }) => {
  const config = {
    normal: { color: 'bg-green-500/10 text-green-500 border-green-500/20', icon: <CheckCircle className="h-3 w-3" /> },
    warning: { color: 'bg-yellow-500/10 text-yellow-500 border-yellow-500/20', icon: <AlertTriangle className="h-3 w-3" /> },
    critical: { color: 'bg-red-500/10 text-red-500 border-red-500/20', icon: <XCircle className="h-3 w-3" /> },
  };
  const { color, icon } = config[status];
  return (
    <Badge variant="outline" className={`${color} flex items-center gap-1`}>
      {icon}
      {status.toUpperCase()}
    </Badge>
  );
};

const chartConfig = {
  rxPower: {
    label: 'Rx Power',
    color: 'hsl(var(--chart-1))',
  },
  txPower: {
    label: 'Tx Power',
    color: 'hsl(var(--chart-2))',
  },
  temperature: {
    label: 'Temperature',
    color: 'hsl(var(--chart-3))',
  },
} satisfies ChartConfig;

export default function DeviceInterfaces({ deviceId, deviceName }: DeviceInterfacesProps) {
  const [interfaces, setInterfaces] = useState<DeviceInterface[]>([]);
  const [stats, setStats] = useState<InterfaceStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [syncing, setSyncing] = useState(false);
  const [selectedInterface, setSelectedInterface] = useState<DeviceInterface | null>(null);
  const [showDetails, setShowDetails] = useState(false);

  useEffect(() => {
    loadInterfaces();
  }, [deviceId]);

  const loadInterfaces = async () => {
    setLoading(true);
    try {
      const [interfacesRes, statsRes] = await Promise.all([
        apiClient.interfaces.list(deviceId),
        apiClient.interfaces.stats(deviceId).catch(() => null),
      ]);
      setInterfaces(interfacesRes.interfaces || []);
      setStats(statsRes);
    } catch (error) {
      console.error('Error loading interfaces:', error);
    } finally {
      setLoading(false);
    }
  };

  const syncFromLibreNMS = async () => {
    setSyncing(true);
    try {
      await apiClient.interfaces.syncFromLibreNMS(deviceId);
      await loadInterfaces();
    } catch (error) {
      console.error('Error syncing:', error);
    } finally {
      setSyncing(false);
    }
  };

  const syncDDMFromLibreNMS = async () => {
    setSyncing(true);
    try {
      await apiClient.interfaces.syncDDMFromLibreNMS(deviceId);
      await loadInterfaces();
    } catch (error) {
      console.error('Error syncing DDM:', error);
    } finally {
      setSyncing(false);
    }
  };

  // Calculate DDM status for an interface
  const getInterfaceDDMStatus = (iface: DeviceInterface): 'normal' | 'warning' | 'critical' => {
    // Temperature thresholds (typical SFP/SFP+/QSFP)
    const tempStatus = getDDMStatus(iface.gbic_temperature, 0, 70, -10, 80);
    // Rx power thresholds (dBm)
    const rxStatus = getDDMStatus(iface.gbic_rx_power, -20, -2, -30, 2);
    // Tx power thresholds (dBm)
    const txStatus = getDDMStatus(iface.gbic_tx_power, -10, 2, -20, 5);

    if (tempStatus === 'critical' || rxStatus === 'critical' || txStatus === 'critical') {
      return 'critical';
    }
    if (tempStatus === 'warning' || rxStatus === 'warning' || txStatus === 'warning') {
      return 'warning';
    }
    return 'normal';
  };

  // Interfaces with transceivers
  const transceiverInterfaces = interfaces.filter(i => i.has_transceiver);

  // DDM chart data
  const ddmChartData = transceiverInterfaces.map(iface => ({
    name: iface.name.replace(/^.+\//, '').substring(0, 10),
    rxPower: iface.gbic_rx_power || 0,
    txPower: iface.gbic_tx_power || 0,
    temperature: iface.gbic_temperature || 0,
    status: getInterfaceDDMStatus(iface),
  }));

  if (loading) {
    return (
      <div className="space-y-4">
        {[...Array(3)].map((_, i) => (
          <Card key={i} className="animate-pulse">
            <CardHeader>
              <div className="h-4 bg-muted rounded w-1/3"></div>
            </CardHeader>
            <CardContent>
              <div className="h-20 bg-muted rounded"></div>
            </CardContent>
          </Card>
        ))}
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header with actions */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">Interfaces & Transceivers</h2>
          <p className="text-muted-foreground">{deviceName}</p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" onClick={syncFromLibreNMS} disabled={syncing}>
            <RefreshCw className={`h-4 w-4 mr-2 ${syncing ? 'animate-spin' : ''}`} />
            Sync Interfaces
          </Button>
          <Button variant="outline" onClick={syncDDMFromLibreNMS} disabled={syncing}>
            <Activity className="h-4 w-4 mr-2" />
            Sync DDM
          </Button>
        </div>
      </div>

      {/* Stats Cards */}
      {stats && (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
          <Card className="border-l-4 border-l-blue-500">
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Total Interfaces</CardTitle>
              <Network className="h-4 w-4 text-blue-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{stats.total_interfaces}</div>
              <p className="text-xs text-muted-foreground">
                {stats.interfaces_up} up, {stats.interfaces_down} down
              </p>
            </CardContent>
          </Card>

          <Card className="border-l-4 border-l-purple-500">
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Transceivers</CardTitle>
              <Cpu className="h-4 w-4 text-purple-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{stats.interfaces_with_transceiver}</div>
              <p className="text-xs text-muted-foreground">GBICs/Transceivers detectados</p>
            </CardContent>
          </Card>

          <Card className="border-l-4 border-l-yellow-500">
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Alertas DDM</CardTitle>
              <AlertTriangle className="h-4 w-4 text-yellow-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">
                {stats.ddm_alerts.critical + stats.ddm_alerts.warning}
              </div>
              <p className="text-xs text-muted-foreground">
                {stats.ddm_alerts.critical} críticos, {stats.ddm_alerts.warning} avisos
              </p>
            </CardContent>
          </Card>

          <Card className="border-l-4 border-l-green-500">
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Saúde Óptica</CardTitle>
              <Activity className="h-4 w-4 text-green-500" />
            </CardHeader>
            <CardContent>
              <div className="text-lg font-bold">
                Rx: {stats.optical_health.avg_rx_power?.toFixed(1) || '-'} dBm
              </div>
              <p className="text-xs text-muted-foreground">
                Temp: {stats.optical_health.avg_temperature?.toFixed(1) || '-'}°C
              </p>
            </CardContent>
          </Card>
        </div>
      )}

      {/* Tabs for different views */}
      <Tabs defaultValue="all" className="space-y-4">
        <TabsList>
          <TabsTrigger value="all">Todas ({interfaces.length})</TabsTrigger>
          <TabsTrigger value="transceivers">Transceivers ({transceiverInterfaces.length})</TabsTrigger>
          <TabsTrigger value="charts">Gráficos DDM</TabsTrigger>
        </TabsList>

        {/* All Interfaces Tab */}
        <TabsContent value="all">
          <Card>
            <CardHeader>
              <CardTitle>Interfaces</CardTitle>
              <CardDescription>Todas as interfaces do dispositivo</CardDescription>
            </CardHeader>
            <CardContent>
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Interface</TableHead>
                    <TableHead>Alias</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead>Speed</TableHead>
                    <TableHead>Transceiver</TableHead>
                    <TableHead>DDM</TableHead>
                    <TableHead></TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {interfaces.map((iface) => (
                    <TableRow key={iface.id} className="cursor-pointer hover:bg-muted/50"
                      onClick={() => { setSelectedInterface(iface); setShowDetails(true); }}>
                      <TableCell className="font-medium">{iface.name}</TableCell>
                      <TableCell className="max-w-[200px] truncate">{iface.if_alias || '-'}</TableCell>
                      <TableCell>
                        <StatusBadge status={iface.if_oper_status || 'dormant'} />
                      </TableCell>
                      <TableCell>{formatSpeed(iface.if_speed)}</TableCell>
                      <TableCell>
                        {iface.has_transceiver ? (
                          <Badge variant="outline" className="bg-purple-500/10 text-purple-500">
                            {iface.transceiver_type?.substring(0, 15) || 'SFP'}
                          </Badge>
                        ) : '-'}
                      </TableCell>
                      <TableCell>
                        {iface.has_transceiver ? (
                          <DDMStatusBadge status={getInterfaceDDMStatus(iface)} />
                        ) : '-'}
                      </TableCell>
                      <TableCell>
                        <Button variant="ghost" size="sm">
                          <Info className="h-4 w-4" />
                        </Button>
                      </TableCell>
                    </TableRow>
                  ))}
                  {interfaces.length === 0 && (
                    <TableRow>
                      <TableCell colSpan={7} className="text-center text-muted-foreground">
                        Nenhuma interface encontrada
                      </TableCell>
                    </TableRow>
                  )}
                </TableBody>
              </Table>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Transceivers Tab with DDM */}
        <TabsContent value="transceivers">
          <Card>
            <CardHeader>
              <CardTitle>Transceivers & DDM</CardTitle>
              <CardDescription>Digital Diagnostic Monitoring - Monitoramento óptico</CardDescription>
            </CardHeader>
            <CardContent>
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Interface</TableHead>
                    <TableHead>Tipo</TableHead>
                    <TableHead>
                      <div className="flex items-center gap-1">
                        <Thermometer className="h-4 w-4" /> Temp
                      </div>
                    </TableHead>
                    <TableHead>
                      <div className="flex items-center gap-1">
                        <ArrowDownCircle className="h-4 w-4" /> Rx Power
                      </div>
                    </TableHead>
                    <TableHead>
                      <div className="flex items-center gap-1">
                        <ArrowUpCircle className="h-4 w-4" /> Tx Power
                      </div>
                    </TableHead>
                    <TableHead>
                      <div className="flex items-center gap-1">
                        <Zap className="h-4 w-4" /> Bias
                      </div>
                    </TableHead>
                    <TableHead>Status</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {transceiverInterfaces.map((iface) => {
                    const ddmStatus = getInterfaceDDMStatus(iface);
                    return (
                      <TableRow key={iface.id} className="cursor-pointer hover:bg-muted/50"
                        onClick={() => { setSelectedInterface(iface); setShowDetails(true); }}>
                        <TableCell className="font-medium">{iface.name}</TableCell>
                        <TableCell>
                          <Badge variant="outline" className="bg-purple-500/10 text-purple-500">
                            {iface.transceiver_type?.substring(0, 20) || 'Unknown'}
                          </Badge>
                        </TableCell>
                        <TableCell>
                          <span className={ddmStatus === 'critical' ? 'text-red-500 font-bold' : 
                            ddmStatus === 'warning' ? 'text-yellow-500' : ''}>
                            {formatTemperature(iface.gbic_temperature)}
                          </span>
                        </TableCell>
                        <TableCell>
                          <span className={ddmStatus === 'critical' ? 'text-red-500 font-bold' : 
                            ddmStatus === 'warning' ? 'text-yellow-500' : ''}>
                            {formatPower(iface.gbic_rx_power)}
                          </span>
                        </TableCell>
                        <TableCell>
                          <span className={ddmStatus === 'critical' ? 'text-red-500 font-bold' : 
                            ddmStatus === 'warning' ? 'text-yellow-500' : ''}>
                            {formatPower(iface.gbic_tx_power)}
                          </span>
                        </TableCell>
                        <TableCell>{formatBiasCurrent(iface.gbic_bias_current)}</TableCell>
                        <TableCell>
                          <DDMStatusBadge status={ddmStatus} />
                        </TableCell>
                      </TableRow>
                    );
                  })}
                  {transceiverInterfaces.length === 0 && (
                    <TableRow>
                      <TableCell colSpan={7} className="text-center text-muted-foreground">
                        Nenhum transceiver detectado
                      </TableCell>
                    </TableRow>
                  )}
                </TableBody>
              </Table>
            </CardContent>
          </Card>
        </TabsContent>

        {/* DDM Charts Tab */}
        <TabsContent value="charts" className="space-y-4">
          <div className="grid gap-4 md:grid-cols-2">
            {/* Rx/Tx Power Chart */}
            <Card>
              <CardHeader>
                <CardTitle>Potência Óptica (dBm)</CardTitle>
                <CardDescription>Rx e Tx Power por interface</CardDescription>
              </CardHeader>
              <CardContent>
                <ChartContainer config={chartConfig} className="h-[300px]">
                  <ResponsiveContainer width="100%" height="100%">
                    <BarChart data={ddmChartData}>
                      <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
                      <XAxis dataKey="name" className="text-xs" />
                      <YAxis className="text-xs" domain={[-30, 10]} />
                      <ChartTooltip content={<ChartTooltipContent />} />
                      <Bar dataKey="rxPower" name="Rx Power" fill="var(--color-rxPower)" radius={[4, 4, 0, 0]} />
                      <Bar dataKey="txPower" name="Tx Power" fill="var(--color-txPower)" radius={[4, 4, 0, 0]} />
                    </BarChart>
                  </ResponsiveContainer>
                </ChartContainer>
              </CardContent>
            </Card>

            {/* Temperature Chart */}
            <Card>
              <CardHeader>
                <CardTitle>Temperatura (°C)</CardTitle>
                <CardDescription>Temperatura dos transceivers</CardDescription>
              </CardHeader>
              <CardContent>
                <ChartContainer config={chartConfig} className="h-[300px]">
                  <ResponsiveContainer width="100%" height="100%">
                    <BarChart data={ddmChartData}>
                      <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
                      <XAxis dataKey="name" className="text-xs" />
                      <YAxis className="text-xs" domain={[0, 80]} />
                      <ChartTooltip content={<ChartTooltipContent />} />
                      <Bar dataKey="temperature" name="Temperature" fill="var(--color-temperature)" radius={[4, 4, 0, 0]} />
                    </BarChart>
                  </ResponsiveContainer>
                </ChartContainer>
              </CardContent>
            </Card>
          </div>
        </TabsContent>
      </Tabs>

      {/* Interface Details Dialog */}
      <Dialog open={showDetails} onOpenChange={setShowDetails}>
        <DialogContent className="max-w-3xl max-h-[80vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>{selectedInterface?.name}</DialogTitle>
            <DialogDescription>
              {selectedInterface?.if_alias || 'Sem descrição'}
            </DialogDescription>
          </DialogHeader>
          
          {selectedInterface && (
            <div className="space-y-4">
              {/* Interface Info */}
              <div className="grid grid-cols-2 gap-4">
                <Card>
                  <CardHeader className="pb-2">
                    <CardTitle className="text-sm">Informações</CardTitle>
                  </CardHeader>
                  <CardContent className="space-y-2 text-sm">
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">Tipo:</span>
                      <span>{selectedInterface.if_type || '-'}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">Speed:</span>
                      <span>{formatSpeed(selectedInterface.if_speed)}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">MTU:</span>
                      <span>{selectedInterface.if_mtu || '-'}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">MAC:</span>
                      <span className="font-mono text-xs">{selectedInterface.if_phys_address || '-'}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">Admin Status:</span>
                      <StatusBadge status={selectedInterface.if_admin_status || 'dormant'} />
                    </div>
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">Oper Status:</span>
                      <StatusBadge status={selectedInterface.if_oper_status || 'dormant'} />
                    </div>
                  </CardContent>
                </Card>

                {/* Transceiver Info */}
                {selectedInterface.has_transceiver && (
                  <Card>
                    <CardHeader className="pb-2">
                      <CardTitle className="text-sm">Transceiver</CardTitle>
                    </CardHeader>
                    <CardContent className="space-y-2 text-sm">
                      <div className="flex justify-between">
                        <span className="text-muted-foreground">Tipo:</span>
                        <span>{selectedInterface.transceiver_type || '-'}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-muted-foreground">Vendor:</span>
                        <span>{selectedInterface.transceiver_vendor || '-'}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-muted-foreground">Serial:</span>
                        <span className="font-mono text-xs">{selectedInterface.transceiver_serial || '-'}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-muted-foreground">Part Number:</span>
                        <span className="font-mono text-xs">{selectedInterface.transceiver_part || '-'}</span>
                      </div>
                      {selectedInterface.gbic_distance && (
                        <div className="flex justify-between">
                          <span className="text-muted-foreground">Distância:</span>
                          <span>{selectedInterface.gbic_distance} km</span>
                        </div>
                      )}
                      {selectedInterface.gbic_wavelength && (
                        <div className="flex justify-between">
                          <span className="text-muted-foreground">Wavelength:</span>
                          <span>{selectedInterface.gbic_wavelength} nm</span>
                        </div>
                      )}
                    </CardContent>
                  </Card>
                )}
              </div>

              {/* DDM Data */}
              {selectedInterface.has_transceiver && (
                <Card>
                  <CardHeader className="pb-2">
                    <CardTitle className="text-sm flex items-center gap-2">
                      <Activity className="h-4 w-4" />
                      DDM - Digital Diagnostic Monitoring
                    </CardTitle>
                  </CardHeader>
                  <CardContent>
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                      <div className="text-center p-3 rounded-lg bg-muted">
                        <Thermometer className="h-5 w-5 mx-auto mb-1 text-orange-500" />
                        <div className="text-lg font-bold">
                          {formatTemperature(selectedInterface.gbic_temperature)}
                        </div>
                        <div className="text-xs text-muted-foreground">Temperatura</div>
                      </div>
                      <div className="text-center p-3 rounded-lg bg-muted">
                        <ArrowDownCircle className="h-5 w-5 mx-auto mb-1 text-blue-500" />
                        <div className="text-lg font-bold">
                          {formatPower(selectedInterface.gbic_rx_power)}
                        </div>
                        <div className="text-xs text-muted-foreground">Rx Power</div>
                      </div>
                      <div className="text-center p-3 rounded-lg bg-muted">
                        <ArrowUpCircle className="h-5 w-5 mx-auto mb-1 text-green-500" />
                        <div className="text-lg font-bold">
                          {formatPower(selectedInterface.gbic_tx_power)}
                        </div>
                        <div className="text-xs text-muted-foreground">Tx Power</div>
                      </div>
                      <div className="text-center p-3 rounded-lg bg-muted">
                        <Zap className="h-5 w-5 mx-auto mb-1 text-yellow-500" />
                        <div className="text-lg font-bold">
                          {formatBiasCurrent(selectedInterface.gbic_bias_current)}
                        </div>
                        <div className="text-xs text-muted-foreground">Bias Current</div>
                      </div>
                    </div>
                    {selectedInterface.ddm_last_update && (
                      <div className="flex items-center gap-1 mt-2 text-xs text-muted-foreground">
                        <Clock className="h-3 w-3" />
                        Última atualização: {new Date(selectedInterface.ddm_last_update).toLocaleString('pt-BR')}
                      </div>
                    )}
                  </CardContent>
                </Card>
              )}

              {/* Traffic Stats */}
              <Card>
                <CardHeader className="pb-2">
                  <CardTitle className="text-sm">Estatísticas de Tráfego</CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                    <div>
                      <div className="text-muted-foreground">In Octets</div>
                      <div className="font-mono">{selectedInterface.if_in_octets?.toLocaleString() || '-'}</div>
                    </div>
                    <div>
                      <div className="text-muted-foreground">Out Octets</div>
                      <div className="font-mono">{selectedInterface.if_out_octets?.toLocaleString() || '-'}</div>
                    </div>
                    <div>
                      <div className="text-muted-foreground">In Errors</div>
                      <div className="font-mono text-red-500">{selectedInterface.if_in_errors || 0}</div>
                    </div>
                    <div>
                      <div className="text-muted-foreground">Out Errors</div>
                      <div className="font-mono text-red-500">{selectedInterface.if_out_errors || 0}</div>
                    </div>
                  </div>
                </CardContent>
              </Card>
            </div>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}
