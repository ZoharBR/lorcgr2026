'use client';

import { useEffect, useState } from 'react';
import { 
  Activity, 
  Server, 
  Users, 
  HardDrive, 
  Cpu, 
  MemoryStick,
  TrendingUp,
  TrendingDown,
  AlertCircle,
  CheckCircle2,
  Wifi,
  WifiOff,
  Thermometer,
  ArrowUpCircle,
  ArrowDownCircle,
  RefreshCw,
  Zap,
  XCircle,
  ExternalLink
} from 'lucide-react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Progress } from '@/components/ui/progress';
import { Button } from '@/components/ui/button';
import {
  ChartConfig,
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
} from '@/components/ui/chart';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, ResponsiveContainer, PieChart, Pie, Cell, LineChart, Line, Area, AreaChart, RadialBarChart, RadialBar } from 'recharts';
import { DashboardStats, Device, DDMStats } from '@/types/lor-cgr';

interface DashboardNOCProps {
  stats: DashboardStats | null;
  devices: Device[];
  ddmStats: DDMStats | null;
  loading: boolean;
  onRefresh: () => void;
}

const chartConfig = {
  pppoe: {
    label: 'PPPoE',
    color: 'hsl(var(--chart-1))',
  },
  cpu: {
    label: 'CPU',
    color: 'hsl(var(--chart-2))',
  },
  ram: {
    label: 'RAM',
    color: 'hsl(var(--chart-3))',
  },
  disk: {
    label: 'Disco',
    color: 'hsl(var(--chart-4))',
  },
  temperature: {
    label: 'Temperatura',
    color: 'hsl(25, 95%, 53%)',
  },
  rxPower: {
    label: 'RX Power',
    color: 'hsl(217, 91%, 60%)',
  },
  txPower: {
    label: 'TX Power',
    color: 'hsl(142, 71%, 45%)',
  },
} satisfies ChartConfig;

const COLORS = ['#8b5cf6', '#3b82f6', '#22c55e', '#f59e0b', '#ef4444', '#06b6d4', '#ec4899', '#84cc16'];

export default function DashboardNOC({ stats, devices, ddmStats, loading, onRefresh }: DashboardNOCProps) {
  const [time, setTime] = useState(new Date());
  const [refreshing, setRefreshing] = useState(false);

  useEffect(() => {
    const timer = setInterval(() => setTime(new Date()), 1000);
    return () => clearInterval(timer);
  }, []);

  const handleRefresh = async () => {
    setRefreshing(true);
    await onRefresh();
    setTimeout(() => setRefreshing(false), 500);
  };

  // Calcular dispositivos online/offline
  const onlineDevices = devices.filter(d => d.status === 'online').length;
  const offlineDevices = devices.filter(d => d.status === 'offline').length;

  // Dados para gráfico de pizza - Status dos Dispositivos
  const deviceStatusData = [
    { name: 'Online', value: onlineDevices, fill: '#22c55e' },
    { name: 'Offline', value: offlineDevices, fill: '#ef4444' },
  ].filter(d => d.value > 0);

  // Dados para gráfico de PPPoE por BRAS
  const pppoeData = stats?.pppoe_details?.map((item, index) => ({
    name: item.name?.replace(/[-_]/g, ' ').substring(0, 12) || `BRAS ${index + 1}`,
    pppoe: item.count || 0,
    fill: COLORS[index % COLORS.length],
  }))?.filter(p => p.pppoe > 0) || [];

  // Dados para gráfico de saúde do servidor
  const serverHealthData = stats?.server_health ? [
    { name: 'CPU', value: stats.server_health.cpu, fill: '#3b82f6' },
    { name: 'RAM', value: stats.server_health.ram, fill: '#8b5cf6' },
    { name: 'Disco', value: stats.server_health.disk, fill: '#f59e0b' },
  ] : [];

  // Dados DDM para gráficos
  const ddmChartData = ddmStats ? [
    { 
      name: 'Temperatura', 
      value: ddmStats.avg_temperature, 
      unit: '°C',
      fill: '#f59e0b',
      min: 0, 
      max: 80,
      status: ddmStats.avg_temperature > 60 ? 'critical' : ddmStats.avg_temperature > 45 ? 'warning' : 'normal'
    },
    { 
      name: 'RX Power', 
      value: Math.abs(ddmStats.avg_rx_power), 
      unit: 'dBm',
      fill: '#3b82f6',
      min: 0, 
      max: 30,
      status: ddmStats.avg_rx_power < -25 ? 'critical' : ddmStats.avg_rx_power < -20 ? 'warning' : 'normal'
    },
    { 
      name: 'TX Power', 
      value: Math.abs(ddmStats.avg_tx_power), 
      unit: 'dBm',
      fill: '#22c55e',
      min: 0, 
      max: 10,
      status: ddmStats.avg_tx_power < -5 ? 'critical' : ddmStats.avg_tx_power < 0 ? 'warning' : 'normal'
    },
  ] : [];

  // DDM Status para gráfico radial
  const ddmStatusData = ddmStats?.alerts ? [
    { name: 'Normal', value: ddmStats.alerts.normal, fill: '#22c55e' },
    { name: 'Warning', value: ddmStats.alerts.warning, fill: '#f59e0b' },
    { name: 'Critical', value: ddmStats.alerts.critical, fill: '#ef4444' },
  ].filter(d => d.value > 0) : [];

  // Tipos de dispositivos
  const deviceTypes = devices.reduce((acc, d) => {
    const type = d.device_type || 'outro';
    acc[type] = (acc[type] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);
  
  const deviceTypeData = Object.entries(deviceTypes).map(([name, value], index) => ({
    name: name.charAt(0).toUpperCase() + name.slice(1),
    value,
    fill: COLORS[index % COLORS.length],
  }));

  // Dados simulados para histórico (em produção viria de uma API)
  const trafficHistory = Array.from({ length: 24 }, (_, i) => ({
    hour: `${i.toString().padStart(2, '0')}:00`,
    rx: ddmStats ? Math.abs(ddmStats.avg_rx_power) + (Math.random() * 4 - 2) : Math.random() * 20,
    tx: ddmStats ? Math.abs(ddmStats.avg_tx_power) + (Math.random() * 2 - 1) : Math.random() * 5,
    temp: ddmStats ? ddmStats.avg_temperature + (Math.random() * 6 - 3) : 30 + Math.random() * 10,
  }));

  if (loading) {
    return (
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        {[...Array(8)].map((_, i) => (
          <Card key={i} className="animate-pulse">
            <CardHeader className="pb-2">
              <div className="h-4 bg-muted rounded w-1/2"></div>
            </CardHeader>
            <CardContent>
              <div className="h-8 bg-muted rounded w-3/4"></div>
            </CardContent>
          </Card>
        ))}
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header com relógio */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Dashboard NOC</h1>
          <p className="text-muted-foreground">LOR CGR - Centralized Network Management</p>
        </div>
        <div className="text-right flex items-center gap-4">
          <Button 
            variant="outline" 
            size="sm" 
            onClick={handleRefresh}
            disabled={refreshing}
          >
            <RefreshCw className={`h-4 w-4 mr-2 ${refreshing ? 'animate-spin' : ''}`} />
            Atualizar
          </Button>
          <div>
            <div className="text-2xl font-mono font-bold">
              {time.toLocaleTimeString('pt-BR')}
            </div>
            <div className="text-sm text-muted-foreground">
              {time.toLocaleDateString('pt-BR', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}
            </div>
          </div>
        </div>
      </div>

      {/* Cards de Status Principal */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        {/* Total Dispositivos */}
        <Card className="border-l-4 border-l-blue-500">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Dispositivos</CardTitle>
            <Server className="h-4 w-4 text-blue-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats?.devices_total || devices.length}</div>
            <p className="text-xs text-muted-foreground">
              <span className="text-green-500">{onlineDevices} online</span>
              {offlineDevices > 0 && <span className="text-red-500 ml-2">{offlineDevices} offline</span>}
            </p>
          </CardContent>
        </Card>

        {/* BRAS Count */}
        <Card className="border-l-4 border-l-purple-500">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">BRAS Ativos</CardTitle>
            <Activity className="h-4 w-4 text-purple-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats?.bras_count || 0}</div>
            <p className="text-xs text-muted-foreground">
              {stats?.bras_count && stats.bras_count > 0 ? (
                <span className="text-green-500 flex items-center gap-1">
                  <CheckCircle2 className="h-3 w-3" /> Todos operacionais
                </span>
              ) : (
                <span className="text-yellow-500">Verificar status</span>
              )}
            </p>
          </CardContent>
        </Card>

        {/* PPPoE Total */}
        <Card className="border-l-4 border-l-green-500">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">PPPoE Total</CardTitle>
            <Users className="h-4 w-4 text-green-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats?.pppoe_total?.toLocaleString() || 0}</div>
            <p className="text-xs text-muted-foreground">
              <TrendingUp className="inline h-3 w-3 text-green-500" /> Conexões ativas
            </p>
          </CardContent>
        </Card>

        {/* DDM Alertas */}
        <Card className="border-l-4 border-l-orange-500">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Transceivers (DDM)</CardTitle>
            <Zap className="h-4 w-4 text-orange-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{ddmStats?.total_transceivers || 0}</div>
            <p className="text-xs text-muted-foreground">
              {(ddmStats?.alerts?.critical || 0) + (ddmStats?.alerts?.warning || 0) > 0 ? (
                <span className="text-orange-500">
                  {(ddmStats?.alerts?.critical || 0) + (ddmStats?.alerts?.warning || 0)} alertas
                </span>
              ) : (
                <span className="text-green-500">Todos normais</span>
              )}
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Cards de Saúde do Servidor */}
      <div className="grid gap-4 md:grid-cols-3">
        {serverHealthData.map((item, index) => (
          <Card key={index}>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">{item.name}</CardTitle>
              {item.name === 'CPU' && <Cpu className="h-4 w-4 text-muted-foreground" />}
              {item.name === 'RAM' && <MemoryStick className="h-4 w-4 text-muted-foreground" />}
              {item.name === 'Disco' && <HardDrive className="h-4 w-4 text-muted-foreground" />}
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{item.value.toFixed(1)}%</div>
              <Progress 
                value={item.value} 
                className="mt-2"
              />
            </CardContent>
          </Card>
        ))}
      </div>

      {/* Seção DDM - TX, RX, TEMP */}
      <div className="space-y-4">
        <h2 className="text-xl font-semibold flex items-center gap-2">
          <Zap className="h-5 w-5 text-orange-500" />
          Saúde Óptica (DDM) - GBICs/Transceivers
        </h2>
        
        {/* DDM Stats Cards */}
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
          {/* Temperatura Média */}
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Temp. Média</CardTitle>
              <Thermometer className="h-4 w-4 text-orange-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">
                {ddmStats?.avg_temperature?.toFixed(1) || '-'}°C
              </div>
              <Progress 
                value={ddmStats?.avg_temperature ? (ddmStats.avg_temperature / 80) * 100 : 0} 
                className="mt-2"
              />
              <p className="text-xs text-muted-foreground mt-1">
                {ddmStats?.avg_temperature && ddmStats.avg_temperature > 60 ? (
                  <span className="text-red-500">Crítico</span>
                ) : ddmStats?.avg_temperature && ddmStats.avg_temperature > 45 ? (
                  <span className="text-yellow-500">Atenção</span>
                ) : (
                  <span className="text-green-500">Normal</span>
                )}
              </p>
            </CardContent>
          </Card>

          {/* RX Power */}
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">RX Power Médio</CardTitle>
              <ArrowDownCircle className="h-4 w-4 text-blue-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">
                {ddmStats?.avg_rx_power?.toFixed(2) || '-'} dBm
              </div>
              <Progress 
                value={ddmStats?.avg_rx_power ? ((Math.abs(ddmStats.avg_rx_power) / 30) * 100) : 0} 
                className="mt-2"
              />
              <p className="text-xs text-muted-foreground mt-1">
                {ddmStats?.avg_rx_power && ddmStats.avg_rx_power < -25 ? (
                  <span className="text-red-500">Sinal fraco</span>
                ) : ddmStats?.avg_rx_power && ddmStats.avg_rx_power < -20 ? (
                  <span className="text-yellow-500">Atenção</span>
                ) : (
                  <span className="text-green-500">Normal</span>
                )}
              </p>
            </CardContent>
          </Card>

          {/* TX Power */}
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">TX Power Médio</CardTitle>
              <ArrowUpCircle className="h-4 w-4 text-green-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">
                {ddmStats?.avg_tx_power?.toFixed(2) || '-'} dBm
              </div>
              <Progress 
                value={ddmStats?.avg_tx_power ? ((Math.abs(ddmStats.avg_tx_power) / 10) * 100) : 0} 
                className="mt-2"
              />
              <p className="text-xs text-muted-foreground mt-1">
                {ddmStats?.avg_tx_power && ddmStats.avg_tx_power < -5 ? (
                  <span className="text-red-500">Baixa potência</span>
                ) : ddmStats?.avg_tx_power && ddmStats.avg_tx_power < 0 ? (
                  <span className="text-yellow-500">Atenção</span>
                ) : (
                  <span className="text-green-500">Normal</span>
                )}
              </p>
            </CardContent>
          </Card>

          {/* Status DDM */}
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Status DDM</CardTitle>
              <AlertCircle className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="flex flex-wrap gap-2">
                <Badge variant="outline" className="bg-green-500/10 text-green-500 border-green-500/20">
                  {ddmStats?.alerts?.normal || 0} OK
                </Badge>
                <Badge variant="outline" className="bg-yellow-500/10 text-yellow-500 border-yellow-500/20">
                  {ddmStats?.alerts?.warning || 0} Warn
                </Badge>
                <Badge variant="outline" className="bg-red-500/10 text-red-500 border-red-500/20">
                  {ddmStats?.alerts?.critical || 0} Crit
                </Badge>
              </div>
              <div className="mt-4">
                <div className="text-sm text-muted-foreground">Total transceivers</div>
                <div className="text-lg font-semibold">{ddmStats?.total_transceivers || 0}</div>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Gráfico de Histórico DDM */}
        <Card>
          <CardHeader>
            <CardTitle>Histórico DDM (24h)</CardTitle>
            <CardDescription>Temperatura, RX e TX Power ao longo do tempo</CardDescription>
          </CardHeader>
          <CardContent>
            <ChartContainer config={chartConfig} className="h-[300px]">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={trafficHistory}>
                  <defs>
                    <linearGradient id="colorTemp" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#f59e0b" stopOpacity={0.8}/>
                      <stop offset="95%" stopColor="#f59e0b" stopOpacity={0}/>
                    </linearGradient>
                    <linearGradient id="colorRx" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.8}/>
                      <stop offset="95%" stopColor="#3b82f6" stopOpacity={0}/>
                    </linearGradient>
                    <linearGradient id="colorTx" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#22c55e" stopOpacity={0.8}/>
                      <stop offset="95%" stopColor="#22c55e" stopOpacity={0}/>
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
                  <XAxis dataKey="hour" className="text-xs" />
                  <YAxis className="text-xs" />
                  <ChartTooltip content={<ChartTooltipContent />} />
                  <Area type="monotone" dataKey="temp" name="Temperatura (°C)" stroke="#f59e0b" fillOpacity={1} fill="url(#colorTemp)" />
                  <Area type="monotone" dataKey="rx" name="RX Power (dBm)" stroke="#3b82f6" fillOpacity={1} fill="url(#colorRx)" />
                  <Area type="monotone" dataKey="tx" name="TX Power (dBm)" stroke="#22c55e" fillOpacity={1} fill="url(#colorTx)" />
                </AreaChart>
              </ResponsiveContainer>
            </ChartContainer>
            <div className="flex justify-center gap-6 mt-4">
              <div className="flex items-center gap-2">
                <div className="w-3 h-3 rounded-full bg-orange-500"></div>
                <span className="text-sm text-muted-foreground">Temperatura</span>
              </div>
              <div className="flex items-center gap-2">
                <div className="w-3 h-3 rounded-full bg-blue-500"></div>
                <span className="text-sm text-muted-foreground">RX Power</span>
              </div>
              <div className="flex items-center gap-2">
                <div className="w-3 h-3 rounded-full bg-green-500"></div>
                <span className="text-sm text-muted-foreground">TX Power</span>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Gráficos de Status */}
      <div className="grid gap-4 md:grid-cols-2">
        {/* Gráfico de Status dos Dispositivos */}
        <Card>
          <CardHeader>
            <CardTitle>Status dos Dispositivos</CardTitle>
            <CardDescription>Visão geral da rede</CardDescription>
          </CardHeader>
          <CardContent>
            <ChartContainer config={chartConfig} className="h-[250px]">
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={deviceStatusData}
                    cx="50%"
                    cy="50%"
                    innerRadius={60}
                    outerRadius={90}
                    paddingAngle={5}
                    dataKey="value"
                    label={({ name, value }) => `${name}: ${value}`}
                  >
                    {deviceStatusData.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={entry.fill} />
                    ))}
                  </Pie>
                  <ChartTooltip content={<ChartTooltipContent />} />
                </PieChart>
              </ResponsiveContainer>
            </ChartContainer>
            <div className="flex justify-center gap-4 mt-4">
              <Badge variant="outline" className="bg-green-500/10 text-green-500 border-green-500/20">
                <Wifi className="h-3 w-3 mr-1" /> Online: {onlineDevices}
              </Badge>
              <Badge variant="outline" className="bg-red-500/10 text-red-500 border-red-500/20">
                <WifiOff className="h-3 w-3 mr-1" /> Offline: {offlineDevices}
              </Badge>
            </div>
          </CardContent>
        </Card>

        {/* Gráfico de PPPoE por BRAS */}
        <Card>
          <CardHeader>
            <CardTitle>PPPoE por BRAS</CardTitle>
            <CardDescription>Distribuição de conexões PPPoE</CardDescription>
          </CardHeader>
          <CardContent>
            {pppoeData.length > 0 ? (
              <ChartContainer config={chartConfig} className="h-[250px]">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={pppoeData}>
                    <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
                    <XAxis dataKey="name" className="text-xs" angle={-45} textAnchor="end" height={60} />
                    <YAxis className="text-xs" />
                    <ChartTooltip content={<ChartTooltipContent />} />
                    <Bar dataKey="pppoe" name="PPPoE" fill="var(--color-pppoe)" radius={[4, 4, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </ChartContainer>
            ) : (
              <div className="flex items-center justify-center h-[250px] text-muted-foreground">
                Nenhum dado PPPoE disponível
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Dispositivos por Tipo */}
      <div className="grid gap-4 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Dispositivos por Tipo</CardTitle>
            <CardDescription>Distribuição por categoria</CardDescription>
          </CardHeader>
          <CardContent>
            <ChartContainer config={chartConfig} className="h-[250px]">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={deviceTypeData} layout="vertical">
                  <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
                  <XAxis type="number" className="text-xs" />
                  <YAxis dataKey="name" type="category" className="text-xs" width={80} />
                  <ChartTooltip content={<ChartTooltipContent />} />
                  <Bar dataKey="value" name="Quantidade" radius={[0, 4, 4, 0]}>
                    {deviceTypeData.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={entry.fill} />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </ChartContainer>
          </CardContent>
        </Card>

        {/* DDM Status Radial */}
        <Card>
          <CardHeader>
            <CardTitle>Status dos Transceivers</CardTitle>
            <CardDescription>Alertas DDM</CardDescription>
          </CardHeader>
          <CardContent>
            {ddmStatusData.length > 0 ? (
              <ChartContainer config={chartConfig} className="h-[250px]">
                <ResponsiveContainer width="100%" height="100%">
                  <RadialBarChart 
                    cx="50%" 
                    cy="50%" 
                    innerRadius="30%" 
                    outerRadius="90%" 
                    data={ddmStatusData} 
                    startAngle={180} 
                    endAngle={0}
                  >
                    <RadialBar
                      minAngle={15}
                      background
                      clockWise
                      dataKey="value"
                    />
                    <ChartTooltip content={<ChartTooltipContent />} />
                  </RadialBarChart>
                </ResponsiveContainer>
              </ChartContainer>
            ) : (
              <div className="flex items-center justify-center h-[250px] text-muted-foreground">
                Nenhum dado DDM disponível
              </div>
            )}
            <div className="flex justify-center gap-4 mt-4">
              {ddmStatusData.map((item, index) => (
                <Badge key={index} variant="outline" style={{ 
                  backgroundColor: `${item.fill}20`, 
                  color: item.fill,
                  borderColor: `${item.fill}40`
                }}>
                  {item.name}: {item.value}
                </Badge>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Lista de Equipamentos Recentes */}
      <Card>
        <CardHeader>
          <CardTitle>Equipamentos Monitorados</CardTitle>
          <CardDescription>Lista de todos os dispositivos cadastrados e status de sincronização</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {devices.slice(0, 10).map((device) => (
              <div
                key={device.id}
                className="flex items-center justify-between p-4 border rounded-lg hover:bg-muted/50 transition-colors"
              >
                <div className="flex items-center gap-4">
                  <div className={`p-2 rounded-full ${
                    device.status === 'online' ? 'bg-green-500/10' : 'bg-red-500/10'
                  }`}>
                    {device.status === 'online' ? (
                      <Wifi className="h-5 w-5 text-green-500" />
                    ) : (
                      <WifiOff className="h-5 w-5 text-red-500" />
                    )}
                  </div>
                  <div>
                    <div className="font-medium">{device.name}</div>
                    <div className="text-sm text-muted-foreground">
                      {device.ip}:{device.port || 22}
                    </div>
                  </div>
                </div>
                <div className="flex items-center gap-4">
                  {/* Status de Sincronização */}
                  <div className="flex items-center gap-2">
                    {/* LibreNMS */}
                    {device.librenms_id ? (
                      <a 
                        href={`http://45.71.242.131:8080/device/device=${device.librenms_id}/`}
                        target="_blank"
                        rel="noopener noreferrer"
                        title="Abrir no LibreNMS"
                      >
                        <Badge className="bg-blue-500/10 text-blue-500 border-blue-500/20 cursor-pointer hover:bg-blue-500/20">
                          <CheckCircle2 className="h-3 w-3 mr-1" />
                          LibreNMS
                        </Badge>
                      </a>
                    ) : (
                      <Badge className="bg-gray-500/10 text-gray-500 border-gray-500/20">
                        <XCircle className="h-3 w-3 mr-1" />
                        LibreNMS
                      </Badge>
                    )}
                    
                    {/* Zabbix */}
                    {device.zabbix_id ? (
                      <a 
                        href={`http://45.71.242.131/zabbix/hosts.php?hostid=${device.zabbix_id}`}
                        target="_blank"
                        rel="noopener noreferrer"
                        title="Abrir no Zabbix"
                      >
                        <Badge className="bg-red-500/10 text-red-500 border-red-500/20 cursor-pointer hover:bg-red-500/20">
                          <CheckCircle2 className="h-3 w-3 mr-1" />
                          Zabbix
                        </Badge>
                      </a>
                    ) : (
                      <Badge className="bg-gray-500/10 text-gray-500 border-gray-500/20">
                        <XCircle className="h-3 w-3 mr-1" />
                        Zabbix
                      </Badge>
                    )}
                  </div>
                  
                  <div className="text-right">
                    <Badge variant="outline" className="capitalize">
                      {device.device_type}
                    </Badge>
                    <div className="text-xs text-muted-foreground mt-1">
                      {device.vendor}
                    </div>
                  </div>
                  {device.pppoe_count !== undefined && device.pppoe_count > 0 && (
                    <Badge className="bg-blue-500/10 text-blue-500 border-blue-500/20">
                      {device.pppoe_count} PPPoE
                    </Badge>
                  )}
                </div>
              </div>
            ))}
            {devices.length === 0 && (
              <div className="text-center py-8 text-muted-foreground">
                Nenhum dispositivo cadastrado
              </div>
            )}
            {devices.length > 10 && (
              <div className="text-center py-2 text-sm text-muted-foreground">
                Mostrando 10 de {devices.length} dispositivos
              </div>
            )}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
