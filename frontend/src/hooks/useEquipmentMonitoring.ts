'use client';

import { useState, useEffect, useCallback } from 'react';

export interface EquipmentStatus {
  id: number;
  name: string;
  primary_ip: string;
  device_type: string;
  vendor: string;
  status: 'online' | 'degraded' | 'offline';
  latency_ms: number | null;
  packet_loss: number;
  last_check: string;
  last_success: string | null;
  is_flashing: boolean;
  color_class: string;
}

interface MonitoringData {
  success: boolean;
  count: number;
  data: EquipmentStatus[];
  timestamp: string;
}

interface MonitoringSummary {
  success: boolean;
  summary: {
    total: number;
    online: number;
    degraded: number;
    offline: number;
    uptime_percentage: number;
  };
}

export function useEquipmentMonitoring(refreshInterval = 60000) {
  const [data, setData] = useState<EquipmentStatus[]>([]);
  const [summary, setSummary] = useState<MonitoringSummary['summary'] | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [lastUpdate, setLastUpdate] = useState<Date | null>(null);

  const fetchStatus = useCallback(async () => {
    try {
      setLoading(true);
      
      const statusRes = await fetch('/api/monitoring/all-status/');
      const statusData: MonitoringData = await statusRes.json();
      
      if (statusData.success) {
        setData(statusData.data);
        setLastUpdate(new Date());
      }
      
      const summaryRes = await fetch('/api/monitoring/summary/');
      const summaryData: MonitoringSummary = await summaryRes.json();
      
      if (summaryData.success) {
        setSummary(summaryData.summary);
      }
      
      setError(null);
    } catch (err) {
      console.error('Erro ao buscar status:', err);
      setError('Falha ao carregar status dos equipamentos');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchStatus();
    
    if (refreshInterval > 0) {
      const interval = setInterval(fetchStatus, refreshInterval);
      return () => clearInterval(interval);
    }
  }, [fetchStatus, refreshInterval]);

  const getStatusColor = (status: string, latency?: number | null): string => {
    if (status === 'offline') return 'bg-red-500 text-red-400 border-red-500/30';
    if (status === 'degraded' || (latency && latency > 20)) return 'bg-orange-500 text-orange-400 border-orange-500/30';
    return 'bg-emerald-500 text-emerald-400 border-emerald-500/30';
  };

  const getStatusAnimation = (isFlashing: boolean, status: string): string => {
    if (isFlashing || status === 'offline') return 'animate-pulse';
    return '';
  };

  // Sempre mostrar em ms com até 2 casas decimais
  const formatLatency = (ms: number | null): string => {
    if (ms === null || ms === undefined) return '-- ms';
    return `${ms.toFixed(2)} ms`;
  };

  return {
    data,
    summary,
    loading,
    error,
    lastUpdate,
    refetch: fetchStatus,
    getStatusColor,
    getStatusAnimation,
    formatLatency,
  };
}
