'use client';

import { useEquipmentMonitoring } from '@/hooks/useEquipmentMonitoring';
import { Badge } from '@/components/ui/badge';
import { Wifi, WifiOff, AlertTriangle, Activity } from 'lucide-react';

interface EquipmentStatusBadgeProps {
  equipmentId?: number;
  equipmentName?: string;
  showLatency?: boolean;
  showIcon?: boolean;
  size?: 'sm' | 'md' | 'lg';
  refreshInterval?: number; // em ms (padrão: 60000 = 1 min)
}

export function EquipmentStatusBadge({
  equipmentId,
  equipmentName,
  showLatency = true,
  showIcon = true,
  size = 'md',
  refreshInterval = 60000,
}: EquipmentStatusBadgeProps) {
  const {
    data,
    loading,
    getStatusColor,
    getStatusAnimation,
    formatLatency,
  } = useEquipmentMonitoring(refreshInterval);

  // Se foi passado equipmentId, filtrar só esse equipamento
  const equipment = equipmentId 
    ? data.find(e => e.id === equipmentId)
    : equipmentName 
      ? data.find(e => e.name === equipmentName)
      : null;

  // Se não encontrou ou não passou filtro, mostrar resumo
  if (!equipment) {
    return (
      <div className={`flex items-center gap-2 ${loading ? 'opacity-50' : ''}`}>
        <Activity className={`h-${size === 'sm' ? '3' : size === 'lg' ? '6' : '4'} w-${size === 'sm' ? '3' : size === 'lg' ? '6' : '4'} text-muted-foreground animate-spin`} />
        <span className="text-xs text-muted-foreground">
          {loading ? 'Verificando...' : 'N/A'}
        </span>
      </div>
    );
  }

  const colorClasses = getStatusColor(equipment.status, equipment.latency_ms);
  const animationClass = getStatusAnimation(equipment.is_flashing, equipment.status);

  // Ícone baseado no status
  const StatusIcon = () => {
    if (equipment.status === 'offline') return <WifiOff className="h-3 w-3" />;
    if (equipment.status === 'degraded') return <AlertTriangle className="h-3 w-3" />;
    return <Wifi className="h-3 w-3" />;
  };

  // Texto do status
  const statusText = () => {
    if (equipment.status === 'offline') return 'OFFLINE';
    if (equipment.status === 'degraded') return `DEGRADED (${formatLatency(equipment.latency_ms)})`;
    return `ONLINE (${formatLatency(equipment.latency_ms)})`;
  };

  const sizeClasses = {
    sm: 'text-[10px] px-1.5 py-0.5',
    md: 'text-xs px-2 py-1',
    lg: 'text-sm px-3 py-1.5',
  };

  return (
    <Badge
      variant="outline"
      className={`${colorClasses} ${animationClass} ${sizeClasses[size]} font-mono transition-all duration-300`}
    >
      {showIcon && <StatusIcon />}
      <span className="ml-1">{statusText()}</span>
    </Badge>
  );
}

// Componente para lista de equipamentos (tabela/grid)
export function EquipmentStatusList({ refreshInterval = 60000 }: { refreshInterval?: number }) {
  const { data, summary, loading, lastUpdate, refetch, getStatusColor, getStatusAnimation, formatLatency } = useEquipmentMonitoring(refreshInterval);

  if (loading && data.length === 0) {
    return (
      <div className="flex items-center justify-center p-8">
        <Activity className="h-8 w-8 text-muted-foreground animate-spin mr-3" />
        <span className="text-muted-foreground">Carregando status dos equipamentos...</span>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {/* Cabeçalho com resumo */}
      {summary && (
        <div className="flex items-center justify-between p-4 bg-card rounded-lg border">
          <div className="flex items-center gap-4">
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 rounded-full bg-emerald-500" />
              <span className="text-sm">{summary.online} Online</span>
            </div>
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 rounded-full bg-orange-500" />
              <span className="text-sm">{summary.degraded} Degraded</span>
            </div>
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 rounded-full bg-red-500 animate-pulse" />
              <span className="text-sm">{summary.offline} Offline</span>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <span className="text-xs text-muted-foreground">
              Uptime: {summary.uptime_percentage.toFixed(1)}%
            </span>
            {lastUpdate && (
              <span className="text-xs text-muted-foreground">
                Última: {lastUpdate.toLocaleTimeString('pt-BR')}
              </span>
            )}
            <button
              onClick={() => refetch()}
              className="text-xs bg-primary text-primary-foreground px-2 py-1 rounded hover:bg-primary/90 transition-colors"
            >
              Atualizar
            </button>
          </div>
        </div>
      )}

      {/* Lista de equipamentos */}
      <div className="grid gap-2">
        {data.map((eq) => {
          const colorClasses = getStatusColor(eq.status, eq.latency_ms);
          const animationClass = getStatusAnimation(eq.is_flashing, eq.status);

          return (
            <div
              key={eq.id}
              className={`flex items-center justify-between p-3 rounded-lg border ${colorClasses.replace('text-', 'bg-opacity-10 bg-').replace('border-', 'border-')} transition-all duration-300 ${animationClass}`}
            >
              <div className="flex items-center gap-3">
                {/* Indicador de cor */}
                <div className={`w-3 h-3 rounded-full ${
                  eq.status === 'offline' ? 'bg-red-500 animate-pulse' :
                  eq.status === 'degraded' ? 'bg-orange-500' :
                  'bg-emerald-500'
                }`} />

                {/* Informações do equipamento */}
                <div>
                  <p className="font-medium text-sm">{eq.name}</p>
                  <p className="text-xs opacity-70">{eq.primary_ip} | {eq.vendor} {eq.device_type}</p>
                </div>
              </div>

              {/* Status e latência */}
              <div className="text-right">
                <p className={`font-mono text-sm font-bold ${
                  eq.status === 'offline' ? 'text-red-400' :
                  eq.status === 'degraded' ? 'text-orange-400' :
                  'text-emerald-400'
                }`}>
                  {eq.status.toUpperCase()}
                </p>
                <p className="text-xs opacity-70">
                  {formatLatency(eq.latency_ms)} | {eq.packet_loss}% loss
                </p>
              </div>
            </div>
          );
        })}
      </div>

      {data.length === 0 && !loading && (
        <div className="text-center p-8 text-muted-foreground">
          Nenhum equipamento encontrado
        </div>
      )}
    </div>
  );
}
