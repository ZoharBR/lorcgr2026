import React, { useState, useEffect } from 'react';
import { devicesApi } from '../lib/api';
import {
  PieChart, Pie, Cell, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer
} from 'recharts';

const Dashboard = () => {
  const [stats, setStats] = useState({
    total_devices: 0,
    active_devices: 0,
    inactive_devices: 0,
    total_backups: 0,
    pppoe_total: 0,
    pppoe_details: [],
    server_health: { cpu: 0, ram: 0, disk: 0 }
  });
  const [devices, setDevices] = useState([]);
  const [ddmStats, setDdmStats] = useState({
    total_transceivers: 0,
    avg_temperature: 0,
    avg_rx_power: 0,
    avg_tx_power: 0,
    alerts: { critical: 0, warning: 0, normal: 0 },
    issues: []
  });
  const [loading, setLoading] = useState(true);
  const [time, setTime] = useState(new Date());

  useEffect(() => {
    loadData();
    const interval = setInterval(loadData, 60000);
    const clockInterval = setInterval(() => setTime(new Date()), 1000);
    return () => { clearInterval(interval); clearInterval(clockInterval); };
  }, []);

  const loadData = async () => {
    setLoading(true);
    try {
      const dashRes = await devicesApi.dashboard();
      setStats(dashRes || {});

      const devRes = await devicesApi.list();
      setDevices(devRes.devices || devRes || []);

      // Load DDM stats
      try {
        const ddmRes = await fetch('/api/devices/interfaces/stats/');
        const ddmData = await ddmRes.json();
        if (ddmData.status === 'success') {
          setDdmStats(ddmData);
        }
      } catch (e) {
        console.log('DDM stats not available');
      }
    } catch (error) {
      console.error('Error loading data:', error);
    } finally {
      setLoading(false);
    }
  };

  // Calculate device status
  const onlineDevices = devices.filter(d => d.is_active !== false && d.status !== 'offline').length;
  const offlineDevices = devices.filter(d => d.is_active === false || d.status === 'offline').length;

  // Pie chart data - Device Status
  const deviceStatusData = [
    { name: 'Online', value: onlineDevices, color: '#22c55e' },
    { name: 'Offline', value: offlineDevices, color: '#ef4444' },
  ].filter(d => d.value > 0);

  // Bar chart data - PPPoE by BRAS
  const pppoeData = (stats.pppoe_details || [])
    .filter(p => p.count > 0)
    .map(p => ({ name: p.name?.substring(0, 12) || 'BRAS', pppoe: p.count }))
    .slice(0, 8);

  // Server health data
  const serverHealthData = [
    { name: 'CPU', value: stats.server_health?.cpu || 0, color: '#3b82f6' },
    { name: 'RAM', value: stats.server_health?.ram || 0, color: '#8b5cf6' },
    { name: 'Disco', value: stats.server_health?.disk || 0, color: '#f59e0b' },
  ];

  // DDM Status pie data
  const ddmStatusData = [
    { name: 'Normal', value: ddmStats.alerts?.normal || 0, color: '#22c55e' },
    { name: 'Warning', value: ddmStats.alerts?.warning || 0, color: '#f59e0b' },
    { name: 'Critical', value: ddmStats.alerts?.critical || 0, color: '#ef4444' },
  ].filter(d => d.value > 0);

  // Device type distribution
  const deviceTypes = devices.reduce((acc, d) => {
    const type = d.device_type || d.type || 'outro';
    acc[type] = (acc[type] || 0) + 1;
    return acc;
  }, {});
  const deviceTypeData = Object.entries(deviceTypes).map(([name, value]) => ({
    name: name.charAt(0).toUpperCase() + name.slice(1),
    value,
    color: name === 'bras' ? '#8b5cf6' : name === 'router' ? '#3b82f6' : name === 'switch' ? '#22c55e' : '#f59e0b'
  }));

  const statCards = [
    { label: 'Total Dispositivos', value: stats.total_devices || devices.length, sub: `${onlineDevices} online`, icon: '🖥️', color: 'from-blue-600 to-blue-700' },
    { label: 'BRAS Ativos', value: stats.bras_count || 0, sub: 'Operacionais', icon: '📡', color: 'from-purple-600 to-purple-700' },
    { label: 'PPPoE Total', value: (stats.pppoe_total || 0).toLocaleString(), sub: 'Conexões ativas', icon: '👥', color: 'from-green-600 to-green-700' },
    { label: 'Alertas DDM', value: (ddmStats.alerts?.critical || 0) + (ddmStats.alerts?.warning || 0), sub: `${ddmStats.alerts?.critical || 0} críticos`, icon: '⚠️', color: 'from-orange-600 to-orange-700' },
  ];

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header with Clock */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Dashboard NOC</h1>
          <p className="text-gray-400">LOR CGR - Network Management System</p>
        </div>
        <div className="text-right">
          <div className="text-3xl font-mono font-bold text-blue-400">
            {time.toLocaleTimeString('pt-BR')}
          </div>
          <div className="text-sm text-gray-400">
            {time.toLocaleDateString('pt-BR', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}
          </div>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {statCards.map((stat, index) => (
          <div key={index} className={`bg-gradient-to-br ${stat.color} rounded-lg p-5 shadow-lg`}>
            <div className="flex items-center justify-between">
              <div>
                <p className="text-white/70 text-sm">{stat.label}</p>
                <p className="text-3xl font-bold text-white mt-1">{stat.value}</p>
                <p className="text-white/60 text-xs mt-1">{stat.sub}</p>
              </div>
              <div className="text-4xl opacity-80">{stat.icon}</div>
            </div>
          </div>
        ))}
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

      {/* Charts Row 1 */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Device Status Pie Chart */}
        <div className="bg-gray-800 rounded-lg p-6 border border-gray-700">
          <h2 className="text-lg font-semibold text-white mb-4">Status dos Dispositivos</h2>
          {deviceStatusData.length > 0 ? (
            <ResponsiveContainer width="100%" height={250}>
              <PieChart>
                <Pie data={deviceStatusData} cx="50%" cy="50%" innerRadius={60} outerRadius={90}
                  paddingAngle={5} dataKey="value" label={({ name, value }) => `${name}: ${value}`}>
                  {deviceStatusData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.color} />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          ) : (
            <div className="flex items-center justify-center h-[250px] text-gray-500">Sem dados</div>
          )}
          <div className="flex justify-center gap-6 mt-4">
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 rounded-full bg-green-500"></div>
              <span className="text-gray-400">Online: {onlineDevices}</span>
            </div>
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 rounded-full bg-red-500"></div>
              <span className="text-gray-400">Offline: {offlineDevices}</span>
            </div>
          </div>
        </div>

        {/* PPPoE by BRAS Bar Chart */}
        <div className="bg-gray-800 rounded-lg p-6 border border-gray-700">
          <h2 className="text-lg font-semibold text-white mb-4">PPPoE por BRAS</h2>
          {pppoeData.length > 0 ? (
            <ResponsiveContainer width="100%" height={250}>
              <BarChart data={pppoeData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
                <XAxis dataKey="name" tick={{ fill: '#9ca3af', fontSize: 11 }} />
                <YAxis tick={{ fill: '#9ca3af' }} />
                <Tooltip contentStyle={{ backgroundColor: '#1f2937', border: '1px solid #374151', borderRadius: '8px' }} />
                <Bar dataKey="pppoe" fill="#8b5cf6" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          ) : (
            <div className="flex items-center justify-center h-[250px] text-gray-500">Nenhum dado PPPoE</div>
          )}
        </div>
      </div>

      {/* DDM / Optical Health Section */}
      <div className="bg-gray-800 rounded-lg p-6 border border-gray-700">
        <h2 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
          <span>🔬</span> Saúde Óptica (DDM)
        </h2>
        
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4 mb-6">
          <div className="bg-gray-700/50 rounded-lg p-4 text-center">
            <p className="text-gray-400 text-sm">Transceivers</p>
            <p className="text-2xl font-bold text-indigo-400">{ddmStats.total_transceivers || 0}</p>
          </div>
          <div className="bg-gray-700/50 rounded-lg p-4 text-center">
            <p className="text-gray-400 text-sm">Temp. Média</p>
            <p className="text-2xl font-bold text-orange-400">{ddmStats.avg_temperature?.toFixed(1) || '-'}°C</p>
          </div>
          <div className="bg-gray-700/50 rounded-lg p-4 text-center">
            <p className="text-gray-400 text-sm">Rx Power Médio</p>
            <p className="text-2xl font-bold text-blue-400">{ddmStats.avg_rx_power?.toFixed(2) || '-'} dBm</p>
          </div>
          <div className="bg-gray-700/50 rounded-lg p-4 text-center">
            <p className="text-gray-400 text-sm">Tx Power Médio</p>
            <p className="text-2xl font-bold text-green-400">{ddmStats.avg_tx_power?.toFixed(2) || '-'} dBm</p>
          </div>
          <div className="bg-gray-700/50 rounded-lg p-4">
            <p className="text-gray-400 text-sm text-center mb-2">Status DDM</p>
            <div className="flex justify-center gap-2 flex-wrap">
              <span className="px-2 py-1 bg-green-600/30 text-green-400 rounded text-xs">{ddmStats.alerts?.normal || 0} OK</span>
              <span className="px-2 py-1 bg-yellow-600/30 text-yellow-400 rounded text-xs">{ddmStats.alerts?.warning || 0} Warn</span>
              <span className="px-2 py-1 bg-red-600/30 text-red-400 rounded text-xs">{ddmStats.alerts?.critical || 0} Crit</span>
            </div>
          </div>
        </div>

        {/* DDM Issues List */}
        {ddmStats.issues && ddmStats.issues.length > 0 && (
          <div className="mt-4">
            <h3 className="text-sm font-medium text-gray-300 mb-2">Alertas Recentes</h3>
            <div className="space-y-2">
              {ddmStats.issues.slice(0, 5).map((issue, idx) => (
                <div key={idx} className="flex items-center justify-between p-3 bg-gray-700/30 rounded-lg">
                  <div className="flex items-center gap-3">
                    <span className={`w-2 h-2 rounded-full ${issue.status === 'critical' ? 'bg-red-500' : 'bg-yellow-500'}`}></span>
                    <div>
                      <span className="text-white font-medium">{issue.device_name}</span>
                      <span className="text-gray-500 mx-2">/</span>
                      <span className="text-gray-400 text-sm">{issue.interface_name}</span>
                    </div>
                  </div>
                  <span className="text-sm text-gray-400">{issue.message}</span>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>

      {/* Device Type & Recent Devices */}
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
                  {deviceTypeData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.color} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          ) : (
            <div className="flex items-center justify-center h-[250px] text-gray-500">Sem dados</div>
          )}
        </div>

        {/* Recent Devices List */}
        <div className="bg-gray-800 rounded-lg p-6 border border-gray-700">
          <h2 className="text-lg font-semibold text-white mb-4">Dispositivos Recentes</h2>
          {devices.length === 0 ? (
            <div className="text-center py-8">
              <span className="text-4xl mb-2 block">🖥️</span>
              <p className="text-gray-400">Nenhum dispositivo cadastrado</p>
            </div>
          ) : (
            <div className="space-y-2 max-h-[250px] overflow-y-auto">
              {devices.slice(0, 8).map((device, index) => (
                <div key={device.id || index} className="flex items-center justify-between p-3 bg-gray-700/50 rounded-lg hover:bg-gray-700 transition">
                  <div className="flex items-center gap-3">
                    <div className={`w-2 h-2 rounded-full ${device.is_active !== false ? 'bg-green-500' : 'bg-red-500'}`}></div>
                    <div>
                      <p className="text-white font-medium">{device.name || device.hostname || 'Sem nome'}</p>
                      <p className="text-gray-500 text-xs">{device.ip_address || device.ip || '-'}</p>
                    </div>
                  </div>
                  <div className="text-right">
                    <span className="text-xs px-2 py-1 bg-gray-600 rounded text-gray-300 capitalize">
                      {device.device_type || device.type || 'N/A'}
                    </span>
                    {device.vendor && <p className="text-gray-500 text-xs mt-1">{device.vendor}</p>}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
