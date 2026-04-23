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
  WifiOff
} from 'lucide-react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Progress } from '@/components/ui/progress';
import {
  ChartConfig,
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
} from '@/components/ui/chart';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, ResponsiveContainer, PieChart, Pie, Cell, LineChart, Line, Area, AreaChart } from 'recharts';
import { DashboardStats, Device } from '@/types/lor-cgr';

interface DashboardNOCProps {
  stats: DashboardStats | null;
  devices: Device[];
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
} satisfies ChartConfig;

const COLORS = ['#0088FE', '#00C49F', '#FFBB28', '#FF8042', '#8884d8'];

export default function DashboardNOC({ stats, devices, loading, onRefresh }: DashboardNOCProps) {
  const [time, setTime] = useState(new Date());

  useEffect(() => {
    const timer = setInterval(() => setTime(new Date()), 1000);
    return () => clearInterval(timer);
  }, []);

  // Calcular dispositivos online/offline
  const onlineDevices = devices.filter(d => d.status === 'online').length;
  const offlineDevices = devices.filter(d => d.status === 'offline').length;

  // Dados para gráfico de pizza
  const deviceStatusData = [
    { name: 'Online', value: onlineDevices, color: '#22c55e' },
    { name: 'Offline', value: offlineDevices, color: '#ef4444' },
  ];

  // Dados para gráfico de PPPoE
  const pppoeData = stats?.pppoe_details?.map((item, index) => ({
    name: item.name.replace('_', ' ').substring(0, 15),
    pppoe: item.count > 0 ? item.count : 0,
    fill: COLORS[index % COLORS.length],
  })) || [];

  // Dados para gráfico de saúde do servidor
  const serverHealthData = stats?.server_health ? [
    { name: 'CPU', value: stats.server_health.cpu, fill: '#3b82f6' },
    { name: 'RAM', value: stats.server_health.ram, fill: '#8b5cf6' },
    { name: 'Disco', value: stats.server_health.disk, fill: '#f59e0b' },
  ] : [];

  // Dados simulados para gráfico de tráfego (últimas 24h)
  const trafficData = Array.from({ length: 24 }, (_, i) => ({
    hour: `${i.toString().padStart(2, '0')}:00`,
    download: Math.floor(Math.random() * 500) + 100,
    upload: Math.floor(Math.random() * 300) + 50,
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
        <div className="text-right">
          <div className="text-2xl font-mono font-bold">
            {time.toLocaleTimeString('pt-BR')}
          </div>
          <div className="text-sm text-muted-foreground">
            {time.toLocaleDateString('pt-BR', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}
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
              {onlineDevices} online, {offlineDevices} offline
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
              <TrendingUp className="inline h-3 w-3 text-green-500" /> +2.5% vs ontem
            </p>
          </CardContent>
        </Card>

        {/* Alertas */}
        <Card className="border-l-4 border-l-yellow-500">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Alertas Ativos</CardTitle>
            <AlertCircle className="h-4 w-4 text-yellow-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{offlineDevices}</div>
            <p className="text-xs text-muted-foreground">
              {offlineDevices > 0 ? 'Dispositivos offline' : 'Nenhum alerta'}
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Cards de Saúde do Servidor */}
      <div className="grid gap-4 md:grid-cols-3">
        {/* CPU */}
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">CPU</CardTitle>
            <Cpu className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats?.server_health?.cpu?.toFixed(1) || 0}%</div>
            <Progress value={stats?.server_health?.cpu || 0} className="mt-2" />
          </CardContent>
        </Card>

        {/* RAM */}
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Memória RAM</CardTitle>
            <MemoryStick className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats?.server_health?.ram?.toFixed(1) || 0}%</div>
            <Progress value={stats?.server_health?.ram || 0} className="mt-2" />
          </CardContent>
        </Card>

        {/* Disco */}
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Disco</CardTitle>
            <HardDrive className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{stats?.server_health?.disk?.toFixed(1) || 0}%</div>
            <Progress value={stats?.server_health?.disk || 0} className="mt-2" />
          </CardContent>
        </Card>
      </div>

      {/* Gráficos */}
      <div className="grid gap-4 md:grid-cols-2">
        {/* Gráfico de PPPoE por BRAS */}
        <Card>
          <CardHeader>
            <CardTitle>PPPoE por BRAS</CardTitle>
            <CardDescription>Distribuição de conexões PPPoE</CardDescription>
          </CardHeader>
          <CardContent>
            <ChartContainer config={chartConfig} className="h-[250px]">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={pppoeData}>
                  <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
                  <XAxis dataKey="name" className="text-xs" />
                  <YAxis className="text-xs" />
                  <ChartTooltip content={<ChartTooltipContent />} />
                  <Bar dataKey="pppoe" fill="var(--color-pppoe)" radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </ChartContainer>
          </CardContent>
        </Card>

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
                    outerRadius={80}
                    paddingAngle={5}
                    dataKey="value"
                    label={({ name, value }) => `${name}: ${value}`}
                  >
                    {deviceStatusData.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={entry.color} />
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
      </div>

      {/* Gráfico de Tráfego */}
      <Card>
        <CardHeader>
          <CardTitle>Tráfego de Rede (24h)</CardTitle>
          <CardDescription>Download e Upload em Mbps</CardDescription>
        </CardHeader>
        <CardContent>
          <ChartContainer config={chartConfig} className="h-[300px]">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={trafficData}>
                <defs>
                  <linearGradient id="colorDownload" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.8}/>
                    <stop offset="95%" stopColor="#3b82f6" stopOpacity={0}/>
                  </linearGradient>
                  <linearGradient id="colorUpload" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#22c55e" stopOpacity={0.8}/>
                    <stop offset="95%" stopColor="#22c55e" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
                <XAxis dataKey="hour" className="text-xs" />
                <YAxis className="text-xs" />
                <ChartTooltip content={<ChartTooltipContent />} />
                <Area type="monotone" dataKey="download" stroke="#3b82f6" fillOpacity={1} fill="url(#colorDownload)" />
                <Area type="monotone" dataKey="upload" stroke="#22c55e" fillOpacity={1} fill="url(#colorUpload)" />
              </AreaChart>
            </ResponsiveContainer>
          </ChartContainer>
        </CardContent>
      </Card>

      {/* Lista de Equipamentos */}
      <Card>
        <CardHeader>
          <CardTitle>Equipamentos Monitorados</CardTitle>
          <CardDescription>Lista de todos os dispositivos cadastrados</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {devices.map((device) => (
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
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
