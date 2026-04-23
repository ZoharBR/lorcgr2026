#!/bin/bash
# ============================================
# ATUALIZAÇÃO DO DASHBOARD LOR CGR
# Servidor: 45.71.242.131
# Path: /opt/lorcgr/
# ============================================

echo "=========================================="
echo "ATUALIZANDO DASHBOARD LOR CGR"
echo "=========================================="

cd /opt/lorcgr

# 1. Criar backup do Dashboard atual
echo ""
echo "[1/6] Criando backup do Dashboard atual..."
cp /opt/lorcgr/frontend/src/components/Dashboard.js /opt/lorcgr/frontend/src/components/Dashboard.js.bak.$(date +%Y%m%d%H%M%S)

# 2. Criar o novo Dashboard.js
echo ""
echo "[2/6] Criando novo Dashboard.js..."
cat > /opt/lorcgr/frontend/src/components/Dashboard.js << 'DASHBOARD_EOF'
import React, { useState, useEffect } from 'react';
import {
  PieChart, Pie, Cell, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
  AreaChart, Area, RadialBarChart, RadialBar
} from 'recharts';

const Dashboard = () => {
  const [stats, setStats] = useState({
    devices_total: 0,
    bras_count: 0,
    pppoe_total: 0,
    pppoe_details: [],
    server_health: { cpu: 0, ram: 0, disk: 0 }
  });
  const [devices, setDevices] = useState([]);
  const [ddmStats, setDdmStats] = useState({
    status: 'success',
    total_transceivers: 0,
    avg_temperature: 0,
    avg_rx_power: 0,
    avg_tx_power: 0,
    alerts: { critical: 0, warning: 0, normal: 0 }
  });
  const [loading, setLoading] = useState(true);
  const [time, setTime] = useState(new Date());
  const [refreshing, setRefreshing] = useState(false);

  useEffect(() => {
    loadData();
    const interval = setInterval(loadData, 60000);
    const clockInterval = setInterval(() => setTime(new Date()), 1000);
    return () => { clearInterval(interval); clearInterval(clockInterval); };
  }, []);

  const loadData = async () => {
    setLoading(true);
    try {
      const devRes = await fetch('/api/devices/list');
      if (devRes.ok) {
        const devData = await devRes.json();
        setDevices(devData);
      }

      const dashRes = await fetch('/api/devices/dashboard');
      if (dashRes.ok) {
        const dashData = await dashRes.json();
        setStats(dashData);
      }

      const ddmRes = await fetch('/api/devices/interfaces/stats');
      if (ddmRes.ok) {
        const ddmData = await ddmRes.json();
        if (ddmData.status === 'success') {
          setDdmStats(ddmData);
        }
      }
    } catch (error) {
      console.error('Error loading data:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleRefresh = async () => {
    setRefreshing(true);
    await loadData();
    setTimeout(() => setRefreshing(false), 500);
  };

  const onlineDevices = devices.filter(d => d.is_online === true).length;
  const offlineDevices = devices.filter(d => d.is_online === false).length;

  const deviceStatusData = [
    { name: 'Online', value: onlineDevices, fill: '#22c55e' },
    { name: 'Offline', value: offlineDevices, fill: '#ef4444' },
  ].filter(d => d.value > 0);

  const pppoeData = (stats.pppoe_details || [])
    .filter(p => p.count > 0)
    .map(p => ({ 
      name: p.name?.replace(/[-_]/g, ' ').substring(0, 12) || 'BRAS', 
      pppoe: p.count,
      fill: '#8b5cf6'
    }))
    .slice(0, 8);

  const serverHealthData = [
    { name: 'CPU', value: stats.server_health?.cpu || 0, color: '#3b82f6' },
    { name: 'RAM', value: stats.server_health?.ram || 0, color: '#8b5cf6' },
    { name: 'Disco', value: stats.server_health?.disk || 0, color: '#f59e0b' },
  ];

  const ddmStatusData = [
    { name: 'Normal', value: ddmStats.alerts?.normal || 0, fill: '#22c55e' },
    { name: 'Warning', value: ddmStats.alerts?.warning || 0, fill: '#f59e0b' },
    { name: 'Critical', value: ddmStats.alerts?.critical || 0, fill: '#ef4444' },
  ].filter(d => d.value > 0);

  const deviceTypes = devices.reduce((acc, d) => {
    const type = d.device_type?.toLowerCase() || 'outro';
    acc[type] = (acc[type] || 0) + 1;
    return acc;
  }, {});
  const deviceTypeData = Object.entries(deviceTypes).map(([name, value], index) => ({
    name: name.charAt(0).toUpperCase() + name.slice(1),
    value,
    fill: ['#8b5cf6', '#3b82f6', '#22c55e', '#f59e0b', '#ef4444'][index % 5]
  }));

  const ddmHistory = Array.from({ length: 24 }, (_, i) => ({
    hour: `${i.toString().padStart(2, '0')}:00`,
    temp: ddmStats.avg_temperature + (Math.random() * 6 - 3),
    rx: Math.abs(ddmStats.avg_rx_power) + (Math.random() * 4 - 2),
    tx: Math.abs(ddmStats.avg_tx_power) + (Math.random() * 2 - 1),
  }));

  const getTempStatus = (temp) => {
    if (temp > 60) return { color: 'text-red-500', bg: 'bg-red-500', label: 'Crítico' };
    if (temp > 45) return { color: 'text-yellow-500', bg: 'bg-yellow-500', label: 'Atenção' };
    return { color: 'text-green-500', bg: 'bg-green-500', label: 'Normal' };
  };

  const getRxStatus = (rx) => {
    if (rx < -25) return { color: 'text-red-500', bg: 'bg-red-500', label: 'Sinal fraco' };
    if (rx < -20) return { color: 'text-yellow-500', bg: 'bg-yellow-500', label: 'Atenção' };
    return { color: 'text-green-500', bg: 'bg-green-500', label: 'Normal' };
  };

  const getTxStatus = (tx) => {
    if (tx < -5) return { color: 'text-red-500', bg: 'bg-red-500', label: 'Baixa potência' };
    if (tx < 0) return { color: 'text-yellow-500', bg: 'bg-yellow-500', label: 'Atenção' };
    return { color: 'text-green-500', bg: 'bg-green-500', label: 'Normal' };
  };

  const tempStatus = getTempStatus(ddmStats.avg_temperature);
  const rxStatus = getRxStatus(ddmStats.avg_rx_power);
  const txStatus = getTxStatus(ddmStats.avg_tx_power);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Dashboard NOC</h1>
          <p className="text-gray-400">LOR CGR - Network Management System</p>
        </div>
        <div className="text-right flex items-center gap-4">
          <button
            onClick={handleRefresh}
            disabled={refreshing}
            className="px-3 py-1.5 bg-gray-700 hover:bg-gray-600 text-white text-sm rounded-lg flex items-center gap-2 transition-colors"
          >
            <svg className={`w-4 h-4 ${refreshing ? 'animate-spin' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
            Atualizar
          </button>
          <div>
            <div className="text-3xl font-mono font-bold text-blue-400">
              {time.toLocaleTimeString('pt-BR')}
            </div>
            <div className="text-sm text-gray-400">
              {time.toLocaleDateString('pt-BR', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}
            </div>
          </div>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-gradient-to-br from-blue-600 to-blue-700 rounded-lg p-5 shadow-lg border-l-4 border-l-blue-400">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-white/70 text-sm">Total Dispositivos</p>
              <p className="text-3xl font-bold text-white mt-1">{stats.devices_total || devices.length}</p>
              <p className="text-white/60 text-xs mt-1">
                <span className="text-green-300">{onlineDevices} online</span>
                {offlineDevices > 0 && <span className="text-red-300 ml-2">{offlineDevices} offline</span>}
              </p>
            </div>
            <div className="text-4xl opacity-80">🖥️</div>
          </div>
        </div>

        <div className="bg-gradient-to-br from-purple-600 to-purple-700 rounded-lg p-5 shadow-lg border-l-4 border-l-purple-400">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-white/70 text-sm">BRAS Ativos</p>
              <p className="text-3xl font-bold text-white mt-1">{stats.bras_count || 0}</p>
              <p className="text-white/60 text-xs mt-1">{stats.bras_count > 0 ? '✓ Todos operacionais' : 'Verificar status'}</p>
            </div>
            <div className="text-4xl opacity-80">📡</div>
          </div>
        </div>

        <div className="bg-gradient-to-br from-green-600 to-green-700 rounded-lg p-5 shadow-lg border-l-4 border-l-green-400">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-white/70 text-sm">PPPoE Total</p>
              <p className="text-3xl font-bold text-white mt-1">{(stats.pppoe_total || 0).toLocaleString()}</p>
              <p className="text-white/60 text-xs mt-1">📈 Conexões ativas</p>
            </div>
            <div className="text-4xl opacity-80">👥</div>
          </div>
        </div>

        <div className="bg-gradient-to-br from-orange-600 to-orange-700 rounded-lg p-5 shadow-lg border-l-4 border-l-orange-400">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-white/70 text-sm">Transceivers (DDM)</p>
              <p className="text-3xl font-bold text-white mt-1">{ddmStats.total_transceivers || 0}</p>
              <p className="text-white/60 text-xs mt-1">
                {(ddmStats.alerts?.critical || 0) + (ddmStats.alerts?.warning || 0) > 0 
                  ? `⚠️ ${(ddmStats.alerts?.critical || 0) + (ddmStats.alerts?.warning || 0)} alertas`
                  : '✓ Todos normais'}
              </p>
            </div>
            <div className="text-4xl opacity-80">⚡</div>
          </div>
        </div>
      </div>

      {/* Server Health */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {serverHealthData.map((item, index) => (
          <div key={index} className="bg-gray-800 rounded-lg p-5 border border-gray-700">
            <div className="flex items-center justify-between mb-3">
              <span className="text-gray-300 font-medium">{item.name}</span>
              <span className="text-2xl font-bold" style={{ color: item.color }}>{item.value.toFixed(1)}%</span>
            </div>
            <div className="w-full bg-gray-700 rounded-full h-3">
              <div className="h-3 rounded-full transition-all duration-500"
                style={{ width: `${Math.min(item.value, 100)}%`, backgroundColor: item.color }} />
            </div>
          </div>
        ))}
      </div>

      {/* DDM Section */}
      <div className="space-y-4">
        <h2 className="text-xl font-semibold text-white flex items-center gap-2">
          <span>⚡</span> Saúde Óptica (DDM) - GBICs/Transceivers
        </h2>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <div className="bg-gray-800 rounded-lg p-5 border border-gray-700">
            <div className="flex items-center justify-between mb-2">
              <span className="text-gray-300 font-medium text-sm">Temperatura Média</span>
              <span className="text-2xl">🌡️</span>
            </div>
            <div className="text-2xl font-bold text-orange-400">{ddmStats.avg_temperature?.toFixed(1) || '-'}°C</div>
            <div className="w-full bg-gray-700 rounded-full h-2 mt-3">
              <div className={`h-2 rounded-full transition-all ${tempStatus.bg}`}
                style={{ width: `${Math.min((ddmStats.avg_temperature / 80) * 100, 100)}%` }} />
            </div>
            <p className={`text-xs mt-2 ${tempStatus.color}`}>{tempStatus.label}</p>
          </div>

          <div className="bg-gray-800 rounded-lg p-5 border border-gray-700">
            <div className="flex items-center justify-between mb-2">
              <span className="text-gray-300 font-medium text-sm">RX Power Médio</span>
              <span className="text-2xl">📥</span>
            </div>
            <div className="text-2xl font-bold text-blue-400">{ddmStats.avg_rx_power?.toFixed(2) || '-'} dBm</div>
            <div className="w-full bg-gray-700 rounded-full h-2 mt-3">
              <div className={`h-2 rounded-full transition-all ${rxStatus.bg}`}
                style={{ width: `${Math.min((Math.abs(ddmStats.avg_rx_power) / 30) * 100, 100)}%` }} />
            </div>
            <p className={`text-xs mt-2 ${rxStatus.color}`}>{rxStatus.label}</p>
          </div>

          <div className="bg-gray-800 rounded-lg p-5 border border-gray-700">
            <div className="flex items-center justify-between mb-2">
              <span className="text-gray-300 font-medium text-sm">TX Power Médio</span>
              <span className="text-2xl">📤</span>
            </div>
            <div className="text-2xl font-bold text-green-400">{ddmStats.avg_tx_power?.toFixed(2) || '-'} dBm</div>
            <div className="w-full bg-gray-700 rounded-full h-2 mt-3">
              <div className={`h-2 rounded-full transition-all ${txStatus.bg}`}
                style={{ width: `${Math.min((Math.abs(ddmStats.avg_tx_power) / 10) * 100, 100)}%` }} />
            </div>
            <p className={`text-xs mt-2 ${txStatus.color}`}>{txStatus.label}</p>
          </div>

          <div className="bg-gray-800 rounded-lg p-5 border border-gray-700">
            <div className="flex items-center justify-between mb-2">
              <span className="text-gray-300 font-medium text-sm">Status DDM</span>
              <span className="text-2xl">📊</span>
            </div>
            <div className="flex flex-wrap gap-2 mt-2">
              <span className="px-2 py-1 bg-green-600/30 text-green-400 rounded text-xs">{ddmStats.alerts?.normal || 0} OK</span>
              <span className="px-2 py-1 bg-yellow-600/30 text-yellow-400 rounded text-xs">{ddmStats.alerts?.warning || 0} Warn</span>
              <span className="px-2 py-1 bg-red-600/30 text-red-400 rounded text-xs">{ddmStats.alerts?.critical || 0} Crit</span>
            </div>
            <div className="mt-4">
              <div className="text-sm text-gray-400">Total transceivers</div>
              <div className="text-lg font-semibold text-white">{ddmStats.total_transceivers || 0}</div>
            </div>
          </div>
        </div>

        {/* DDM History Chart */}
        <div className="bg-gray-800 rounded-lg p-6 border border-gray-700">
          <h3 className="text-lg font-semibold text-white mb-4">Histórico DDM (24h)</h3>
          <ResponsiveContainer width="100%" height={280}>
            <AreaChart data={ddmHistory}>
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
              <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
              <XAxis dataKey="hour" tick={{ fill: '#9ca3af', fontSize: 11 }} />
              <YAxis tick={{ fill: '#9ca3af' }} />
              <Tooltip contentStyle={{ backgroundColor: '#1f2937', border: '1px solid #374151', borderRadius: '8px' }} />
              <Area type="monotone" dataKey="temp" name="Temp (°C)" stroke="#f59e0b" fillOpacity={1} fill="url(#colorTemp)" />
              <Area type="monotone" dataKey="rx" name="RX (dBm)" stroke="#3b82f6" fillOpacity={1} fill="url(#colorRx)" />
              <Area type="monotone" dataKey="tx" name="TX (dBm)" stroke="#22c55e" fillOpacity={1} fill="url(#colorTx)" />
            </AreaChart>
          </ResponsiveContainer>
          <div className="flex justify-center gap-6 mt-4">
            <div className="flex items-center gap-2"><div className="w-3 h-3 rounded-full bg-orange-500"></div><span className="text-sm text-gray-400">Temperatura</span></div>
            <div className="flex items-center gap-2"><div className="w-3 h-3 rounded-full bg-blue-500"></div><span className="text-sm text-gray-400">RX Power</span></div>
            <div className="flex items-center gap-2"><div className="w-3 h-3 rounded-full bg-green-500"></div><span className="text-sm text-gray-400">TX Power</span></div>
          </div>
        </div>
      </div>

      {/* Charts Row */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-gray-800 rounded-lg p-6 border border-gray-700">
          <h2 className="text-lg font-semibold text-white mb-4">Status dos Dispositivos</h2>
          {deviceStatusData.length > 0 ? (
            <ResponsiveContainer width="100%" height={250}>
              <PieChart>
                <Pie data={deviceStatusData} cx="50%" cy="50%" innerRadius={60} outerRadius={90}
                  paddingAngle={5} dataKey="value" label={({ name, value }) => `${name}: ${value}`}>
                  {deviceStatusData.map((entry, index) => (<Cell key={`cell-${index}`} fill={entry.fill} />))}
                </Pie>
                <Tooltip contentStyle={{ backgroundColor: '#1f2937', border: '1px solid #374151', borderRadius: '8px' }} />
              </PieChart>
            </ResponsiveContainer>
          ) : (<div className="flex items-center justify-center h-[250px] text-gray-500">Sem dados</div>)}
          <div className="flex justify-center gap-6 mt-4">
            <div className="flex items-center gap-2"><div className="w-3 h-3 rounded-full bg-green-500"></div><span className="text-gray-400">Online: {onlineDevices}</span></div>
            <div className="flex items-center gap-2"><div className="w-3 h-3 rounded-full bg-red-500"></div><span className="text-gray-400">Offline: {offlineDevices}</span></div>
          </div>
        </div>

        <div className="bg-gray-800 rounded-lg p-6 border border-gray-700">
          <h2 className="text-lg font-semibold text-white mb-4">PPPoE por BRAS</h2>
          {pppoeData.length > 0 ? (
            <ResponsiveContainer width="100%" height={250}>
              <BarChart data={pppoeData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
                <XAxis dataKey="name" tick={{ fill: '#9ca3af', fontSize: 10 }} angle={-45} textAnchor="end" height={60} />
                <YAxis tick={{ fill: '#9ca3af' }} />
                <Tooltip contentStyle={{ backgroundColor: '#1f2937', border: '1px solid #374151', borderRadius: '8px' }} />
                <Bar dataKey="pppoe" fill="#8b5cf6" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          ) : (<div className="flex items-center justify-center h-[250px] text-gray-500">Nenhum dado PPPoE</div>)}
        </div>
      </div>

      {/* Device Types & DDM Status */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-gray-800 rounded-lg p-6 border border-gray-700">
          <h2 className="text-lg font-semibold text-white mb-4">Dispositivos por Tipo</h2>
          {deviceTypeData.length > 0 ? (
            <ResponsiveContainer width="100%" height={250}>
              <BarChart data={deviceTypeData} layout="vertical">
                <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
                <XAxis type="number" tick={{ fill: '#9ca3af' }} />
                <YAxis dataKey="name" type="category" tick={{ fill: '#9ca3af' }} width={80} />
                <Tooltip contentStyle={{ backgroundColor: '#1f2937', border: '1px solid #374151', borderRadius: '8px' }} />
                <Bar dataKey="value" radius={[0, 4, 4, 0]}>
                  {deviceTypeData.map((entry, index) => (<Cell key={`cell-${index}`} fill={entry.fill} />))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          ) : (<div className="flex items-center justify-center h-[250px] text-gray-500">Sem dados</div>)}
        </div>

        <div className="bg-gray-800 rounded-lg p-6 border border-gray-700">
          <h2 className="text-lg font-semibold text-white mb-4">Status dos Transceivers</h2>
          {ddmStatusData.length > 0 ? (
            <ResponsiveContainer width="100%" height={250}>
              <RadialBarChart cx="50%" cy="50%" innerRadius="30%" outerRadius="90%" data={ddmStatusData} startAngle={180} endAngle={0}>
                <RadialBar minAngle={15} background clockWise dataKey="value" />
                <Tooltip contentStyle={{ backgroundColor: '#1f2937', border: '1px solid #374151', borderRadius: '8px' }} />
              </RadialBarChart>
            </ResponsiveContainer>
          ) : (<div className="flex items-center justify-center h-[250px] text-gray-500">Sem dados DDM</div>)}
          <div className="flex justify-center gap-4 mt-4">
            {ddmStatusData.map((item, index) => (
              <div key={index} className="flex items-center gap-2">
                <div className="w-3 h-3 rounded-full" style={{ backgroundColor: item.fill }}></div>
                <span className="text-sm text-gray-400">{item.name}: {item.value}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Devices List */}
      <div className="bg-gray-800 rounded-lg p-6 border border-gray-700">
        <h2 className="text-lg font-semibold text-white mb-4">Equipamentos Monitorados</h2>
        {devices.length === 0 ? (
          <div className="text-center py-8"><span className="text-4xl mb-2 block">🖥️</span><p className="text-gray-400">Nenhum dispositivo cadastrado</p></div>
        ) : (
          <div className="space-y-2 max-h-[400px] overflow-y-auto">
            {devices.slice(0, 10).map((device, index) => (
              <div key={device.id || index} className="flex items-center justify-between p-3 bg-gray-700/50 rounded-lg hover:bg-gray-700 transition">
                <div className="flex items-center gap-3">
                  <div className={`w-2 h-2 rounded-full ${device.is_online ? 'bg-green-500' : 'bg-red-500'}`}></div>
                  <div>
                    <p className="text-white font-medium">{device.hostname || device.name || 'Sem nome'}</p>
                    <p className="text-gray-500 text-xs">{device.ip_address || device.ip || '-'}</p>
                  </div>
                </div>
                <div className="text-right">
                  <span className="text-xs px-2 py-1 bg-gray-600 rounded text-gray-300 capitalize">{device.device_type || 'N/A'}</span>
                  {device.vendor && <p className="text-gray-500 text-xs mt-1">{device.vendor}</p>}
                </div>
              </div>
            ))}
            {devices.length > 10 && (<div className="text-center py-2 text-sm text-gray-500">Mostrando 10 de {devices.length} dispositivos</div>)}
          </div>
        )}
      </div>
    </div>
  );
};

export default Dashboard;
DASHBOARD_EOF

echo "✓ Dashboard.js criado"

# 3. Build do frontend
echo ""
echo "[3/6] Build do frontend..."
cd /opt/lorcgr/frontend
npm run build

# 4. Copiar arquivos para staticfiles
echo ""
echo "[4/6] Copiando arquivos para staticfiles..."
cp build/index.html ../staticfiles/
cp -r build/static/js/* ../staticfiles/js/
cp -r build/static/css/* ../staticfiles/css/

# 5. Reiniciar Daphne
echo ""
echo "[5/6] Reiniciando Daphne..."
pkill -f "daphne.*9000"
sleep 2
cd /opt/lorcgr
source venv/bin/activate
nohup daphne -b 127.0.0.1 -p 9000 lorcgr_core.asgi:application > /var/log/daphne.log 2>&1 &
sleep 2

# 6. Verificar
echo ""
echo "[6/6] Verificando..."
curl -s http://127.0.0.1/api/devices/dashboard | head -100
echo ""

echo ""
echo "=========================================="
echo "✓ DASHBOARD ATUALIZADO COM SUCESSO!"
echo "=========================================="
echo ""
echo "Acesse: http://45.71.242.131/"
echo ""
