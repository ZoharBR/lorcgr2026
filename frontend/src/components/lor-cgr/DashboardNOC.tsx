'use client';

import { useEffect, useState } from 'react';
import { Activity, Server, Cpu, HardDrive, Clock, Wifi, WifiOff, AlertTriangle, RefreshCw } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Progress } from '@/components/ui/progress';
import { Badge } from '@/components/ui/badge';
import { useEquipmentMonitoring } from '@/hooks/useEquipmentMonitoring';

export default function DashboardNOC() {
  const [health, setHealth] = useState({cpu: 0, ram: 0, disk: 0, uptime: ''});
  const [loading, setLoading] = useState(true);
  
  // Usar hook de monitoramento real-time (atualiza a cada 60 segundos)
  const {
    data: monitoringData,
    summary: monitoringSummary,
    loading: monitoringLoading,
    lastUpdate,
    refetch: refetchMonitoring,
    getStatusColor,
    getStatusAnimation,
    formatLatency,
  } = useEquipmentMonitoring(60000); // 60 segundos

  useEffect(() => {
    let mounted = true;
    
    async function loadHealth() {
      try {
        const healthRes = await fetch('/api/equipments/server_health/');
        if (healthRes.ok) {
          const h = await healthRes.json();
          if (mounted) {
            setHealth({
              cpu: h.cpu?.percent || 0,
              ram: h.memory?.percent || 0,
              disk: h.disk?.percent || 0,
              uptime: h.uptime?.formatted || '',
            });
          }
        }
      } catch (err) {
        console.error('Erro ao carregar health:', err);
      } finally {
        if (mounted) setLoading(false);
      }
    }

    loadHealth();
    const interval = setInterval(loadHealth, 30000);
    return () => { mounted = false; clearInterval(interval); };
  }, []);

  if (loading && monitoringData.length === 0) {
    return (
      <div className="min-h-screen bg-gradient-to-b from-slate-900 to-slate-950 p-8 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin inline-block w-10 h-10 border-4 border-emerald-500 border-t-transparent rounded-full"></div>
          <p className="mt-4 text-slate-400">Carregando Dashboard...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-900 to-slate-950">
      <div className="space-y-6 p-6">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold text-white">Dashboard NOC</h1>
            <p className="text-slate-400">LOR CGR - Centralized Network Management (Monitoramento Real-Time)</p>
          </div>
          <div className="flex items-center gap-4">
            {/* Botão de refresh manual */}
            <button
              onClick={() => refetchMonitoring()}
              className="flex items-center gap-2 px-3 py-1.5 bg-slate-700 hover:bg-slate-600 rounded-lg text-sm text-slate-300 transition-colors"
            >
              <RefreshCw className={`h-4 w-4 ${monitoringLoading ? 'animate-spin' : ''}`} />
              Atualizar
            </button>
            
            <div className="text-right">
              <div className="text-xl font-bold text-emerald-400">{health.uptime}</div>
              <div className="text-sm text-slate-400">Uptime do Servidor</div>
            </div>
          </div>
        </div>
        
        {/* Cards principais */}
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-5">
          {/* Dispositivos - com monitoramento real */}
          <Card className="bg-slate-800/50 border-slate-700">
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium text-slate-300">Dispositivos</CardTitle>
              <Server className="h-4 w-4 text-emerald-500" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-white">{monitoringSummary?.total || 0}</div>
              <p className="text-xs text-slate-400 space-y-1">
                <div className="flex justify-between">
                  <span className="text-emerald-400">✓ {monitoringSummary?.online || 0} Online</span>
                </div>
                {(monitoringSummary?.degraded > 0) && (
                  <div className="flex justify-between">
                    <span className="text-orange-400">⚠ {monitoringSummary.degraded} Degraded</span>
                  </div>
                )}
                {(monitoringSummary?.offline > 0) && (
                  <div className="flex justify-between">
                    <span className="text-red-400 animate-pulse">✕ {monitoringSummary.offline} Offline</span>
                  </div>
                )}
              </p>
            </CardContent>
          </Card>

          {/* Uptime % */}
          <Card className="bg-slate-800/50 border-slate-700">
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium text-slate-300">Uptime Rede</CardTitle>
              <Activity className="h-4 w-4 text-blue-400" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-white">{monitoringSummary?.uptime_percentage.toFixed(1) || 0}%</div>
              <Progress value={monitoringSummary?.uptime_percentage || 0} className="mt-2 h-2" />
              {lastUpdate && (
                <p className="text-[10px] text-slate-500 mt-1">
                  Último check: {lastUpdate.toLocaleTimeString('pt-BR')}
                </p>
              )}
            </CardContent>
          </Card>

          {/* CPU */}
          <Card className="bg-slate-800/50 border-slate-700">
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium text-slate-300">CPU</CardTitle>
              <Cpu className="h-4 w-4 text-blue-400" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-white">{health.cpu.toFixed(1)}%</div>
              <Progress value={health.cpu} className="mt-2 h-2" />
            </CardContent>
          </Card>

          {/* Memoria */}
          <Card className="bg-slate-800/50 border-slate-700">
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium text-slate-300">Memoria</CardTitle>
              <Activity className="h-4 w-4 text-purple-400" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-white">{health.ram.toFixed(1)}%</div>
              <Progress value={health.ram} className="mt-2 h-2" />
            </CardContent>
          </Card>

          {/* Disco */}
          <Card className="bg-slate-800/50 border-slate-700">
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <CardTitle className="text-sm font-medium text-slate-300">Disco</CardTitle>
              <HardDrive className="h-4 w-4 text-orange-400" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-white">{health.disk.toFixed(1)}%</div>
              <Progress value={health.disk} className="mt-2 h-2" />
            </CardContent>
          </Card>
        </div>

        {/* Legenda de Cores */}
        <div className="flex items-center gap-6 p-3 bg-slate-800/30 rounded-lg border border-slate-700/50">
          <span className="text-xs text-slate-400 font-medium">LEGENDA DE STATUS (ICMP):</span>
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-emerald-500" />
            <span className="text-xs text-slate-300">Online (0-20ms)</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-orange-500" />
            <span className="text-xs text-slate-300">Degraded (21-100ms)</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-red-500 animate-pulse" />
            <span className="text-xs text-slate-300">Offline (Sem resposta)</span>
          </div>
          <div className="ml-auto text-xs text-slate-500">
            Atualização automática a cada 60 segundos
          </div>
        </div>

        {/* Lista de Equipamentos - COM MONITORAMENTO REAL */}
        <Card className="bg-slate-800/50 border-slate-700">
          <CardHeader>
            <CardTitle className="text-white flex items-center gap-2">
              <Server className="h-5 w-5 text-emerald-500" />
              Equipamentos ({monitoringData.length})
              {monitoringLoading && (
                <RefreshCw className="h-4 w-4 text-slate-400 animate-spin ml-2" />
              )}
            </CardTitle>
          </CardHeader>
          <CardContent>
            {monitoringData.length === 0 ? (
              <div className="text-center py-8">
                {monitoringLoading ? (
                  <>
                    <Activity className="h-8 w-8 text-muted-foreground animate-spin mx-auto mb-3" />
                    <p className="text-slate-400">Verificando status dos equipamentos via ICMP...</p>
                  </>
                ) : (
                  <>
                    <WifiOff className="h-8 w-8 text-slate-500 mx-auto mb-3" />
                    <p className="text-slate-400">Nenhum equipamento cadastrado ou sem IP configurado</p>
                  </>
                )}
              </div>
            ) : (
              <div className="space-y-3">
                {monitoringData.map((device) => {
                  const colorClasses = getStatusColor(device.status, device.latency_ms);
                  const animationClass = getStatusAnimation(device.is_flashing, device.status);
                  
                  return (
                    <div 
                      key={device.id} 
                      className={`flex items-center justify-between p-4 rounded-lg border transition-all duration-300 ${animationClass} ${
                        device.status === 'offline' 
                          ? 'bg-red-950/20 border-red-900/30' 
                          : device.status === 'degraded' 
                            ? 'bg-orange-950/20 border-orange-900/30'
                            : 'bg-slate-700/50 border-slate-600 hover:bg-slate-700'
                      }`}
                    >
                      <div className="flex items-center gap-4">
                        {/* Indicador de Status com cor baseada no ping */}
                        <div className={`p-2 rounded-full transition-colors duration-300 ${
                          device.status === 'offline' 
                            ? 'bg-red-500/20' 
                            : device.status === 'degraded'
                              ? 'bg-orange-500/20'
                              : 'bg-emerald-500/20'
                        }`}>
                          {device.status === 'offline' ? (
                            <WifiOff className={`h-5 w-5 text-red-400 ${device.is_flashing ? 'animate-pulse' : ''}`} />
                          ) : device.status === 'degraded' ? (
                            <AlertTriangle className="h-5 w-5 text-orange-400" />
                          ) : (
                            <Wifi className="h-5 w-5 text-emerald-400" />
                          )}
                        </div>
                        
                        <div>
                          <div className="font-medium text-white">{device.name}</div>
                          <div className="text-sm text-slate-400">{device.primary_ip || 'N/A'}</div>
                        </div>
                      </div>
                      
                      <div className="flex items-center gap-4">
                        {/* Info do dispositivo */}
                        <div className="text-right hidden sm:block">
                          <div className="text-sm text-slate-300">{device.vendor} {device.device_type}</div>
                          <div className="text-xs text-slate-500">
                            Último check: {new Date(device.last_check).toLocaleTimeString('pt-BR')}
                          </div>
                        </div>
                        
                        {/* Badge de Latência e Status */}
                        <Badge 
                          variant="outline" 
                          className={`${colorClasses} font-mono text-xs px-3 py-1.5 transition-all duration-300`}
                        >
                          {device.status === 'offline' ? (
                            <span className="flex items-center gap-1">
                              <WifiOff className="h-3 w-3" /> OFFLINE
                            </span>
                          ) : device.status === 'degraded' ? (
                            <span className="flex items-center gap-1">
                              <AlertTriangle className="h-3 w-3" /> {formatLatency(device.latency_ms)}
                            </span>
                          ) : (
                            <span className="flex items-center gap-1">
                              <Wifi className="h-3 w-3" /> {formatLatency(device.latency_ms)}
                            </span>
                          )}
                        </Badge>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
