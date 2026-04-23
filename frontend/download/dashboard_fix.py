#!/usr/bin/env python3
"""Script para escrever o Dashboard.js corretamente"""

DASHBOARD_CONTENT = '''import React, { useState, useEffect } from 'react';
import { devicesApi } from '../lib/api';
import {
  PieChart, Pie, Cell, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer
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

      try {
        const ddmRes = await fetch('/api/devices/interfaces/stats/');
        const ddmData = await ddmRes.json();
        if (ddmData.status === 'success') setDdmStats(ddmData);
      } catch (e) { console.log('DDM stats not available'); }
    } catch (error) {
      console.error('Error loading data:', error);
    } finally {
      setLoading(false);
    }
  };

  // Calculate device status for pie chart
  const onlineDevices = devices.filter(d => d.status === 'active' || d.status === 'online').length;
  const offlineDevices = devices.filter(d => d.status === 'inactive' || d.status === 'offline').length;
  const unknownDevices = devices.length - onlineDevices - offlineDevices;

  const pieData = [
    { name: 'Online', value: onlineDevices, color: '#10B981' },
    { name: 'Offline', value: offlineDevices, color: '#EF4444' },
    { name: 'Unknown', value: unknownDevices, color: '#6B7280' }
  ].filter(d => d.value > 0);

  // PPPoE data for bar chart
  const barData = (stats.pppoe_details || []).slice(0, 8).map(item => ({
    name: item.name?.substring(0, 12) || 'N/A',
    total: item.count || 0,
    ip: item.ip
  }));

  // DDM Alert colors
  const getAlertColor = (type) => {
    if (type === 'critical') return 'bg-red-500';
    if (type === 'warning') return 'bg-yellow-500';
    return 'bg-green-500';
  };

  const formatTime = (date) => {
    return date.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
  };

  const formatDate = (date) => {
    return date.toLocaleDateString('pt-BR', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' });
  };

  return (
    <div className="p-6 space-y-6">
      {/* Header with Clock */}
      <div className="flex justify-between items-center mb-6">
        <div>
          <h1 className="text-3xl font-bold text-white">Dashboard - LOR CGR</h1>
          <p className="text-gray-400 mt-1">Sistema de Gestao de Rede</p>
        </div>
        <div className="text-right">
          <div className="text-4xl font-mono text-green-400 font-bold">{formatTime(time)}</div>
          <div className="text-sm text-gray-400 capitalize">{formatDate(time)}</div>
        </div>
      </div>

      {/* Alert Banner for Critical Issues */}
      {ddmStats.alerts.critical > 0 && (
        <div className="bg-red-900/50 border border-red-500 rounded-lg p-4 flex items-center">
          <span className="text-2xl mr-3">⚠️</span>
          <div>
            <h3 className="text-red-400 font-bold">Alerta Critico DDM</h3>
            <p className="text-red-300 text-sm">{ddmStats.alerts.critical} transceptore(s) com problemas criticos detectados!</p>
          </div>
        </div>
      )}

      {/* Main Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-gradient-to-br from-blue-600 to-blue-700 rounded-lg p-4 shadow-lg">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-blue-200 text-sm">Total Dispositivos</p>
              <p className="text-3xl font-bold text-white">{stats.devices_total || devices.length}</p>
            </div>
            <div className="text-4xl opacity-50">📡</div>
          </div>
        </div>

        <div className="bg-gradient-to-br from-green-600 to-green-700 rounded-lg p-4 shadow-lg">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-green-200 text-sm">Dispositivos Online</p>
              <p className="text-3xl font-bold text-white">{onlineDevices}</p>
            </div>
            <div className="text-4xl opacity-50">✅</div>
          </div>
        </div>

        <div className="bg-gradient-to-br from-red-600 to-red-700 rounded-lg p-4 shadow-lg">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-red-200 text-sm">Dispositivos Offline</p>
              <p className="text-3xl font-bold text-white">{offlineDevices}</p>
            </div>
            <div className="text-4xl opacity-50">❌</div>
          </div>
        </div>

        <div className="bg-gradient-to-br from-purple-600 to-purple-700 rounded-lg p-4 shadow-lg">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-purple-200 text-sm">Total PPPoE</p>
              <p className="text-3xl font-bold text-white">{stats.pppoe_total || 0}</p>
            </div>
            <div className="text-4xl opacity-50">👥</div>
          </div>
        </div>
      </div>

      {/* DDM Optical Health Section */}
      <div className="bg-gray-800 rounded-lg p-6 shadow-lg">
        <h2 className="text-xl font-bold text-white mb-4 flex items-center">
          <span className="mr-2">🔬</span> Saude Optica DDM
        </h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
          <div className="bg-gray-700 rounded-lg p-4 text-center">
            <p className="text-gray-400 text-sm">Transceptores</p>
            <p className="text-2xl font-bold text-white">{ddmStats.total_transceivers}</p>
          </div>
          <div className="bg-gray-700 rounded-lg p-4 text-center">
            <p className="text-gray-400 text-sm">Temp. Media</p>
            <p className="text-2xl font-bold text-cyan-400">{ddmStats.avg_temperature?.toFixed(1)}°C</p>
          </div>
          <div className="bg-gray-700 rounded-lg p-4 text-center">
            <p className="text-gray-400 text-sm">RX Power Medio</p>
            <p className="text-2xl font-bold text-green-400">{ddmStats.avg_rx_power?.toFixed(2)} dBm</p>
          </div>
          <div className="bg-gray-700 rounded-lg p-4 text-center">
            <p className="text-gray-400 text-sm">TX Power Medio</p>
            <p className="text-2xl font-bold text-yellow-400">{ddmStats.avg_tx_power?.toFixed(2)} dBm</p>
          </div>
          <div className="bg-gray-700 rounded-lg p-4 text-center">
            <p className="text-gray-400 text-sm">Alertas</p>
            <div className="flex justify-center gap-2 mt-1">
              <span className="px-2 py-1 bg-red-500 rounded text-xs text-white">{ddmStats.alerts.critical}</span>
              <span className="px-2 py-1 bg-yellow-500 rounded text-xs text-white">{ddmStats.alerts.warning}</span>
              <span className="px-2 py-1 bg-green-500 rounded text-xs text-white">{ddmStats.alerts.normal}</span>
            </div>
          </div>
        </div>

        {/* DDM Issues List */}
        {ddmStats.issues && ddmStats.issues.length > 0 && (
          <div className="mt-4 bg-gray-900 rounded-lg p-4">
            <h3 className="text-sm font-bold text-gray-400 mb-2">Problemas Detectados:</h3>
            <div className="space-y-2 max-h-32 overflow-y-auto">
              {ddmStats.issues.slice(0, 5).map((issue, idx) => (
                <div key={idx} className="flex items-center text-sm">
                  <span className={`w-2 h-2 rounded-full mr-2 ${getAlertColor(issue.level)}`}></span>
                  <span className="text-gray-300">{issue.device} - {issue.interface}</span>
                  <span className="text-gray-500 ml-2">({issue.field}: {issue.value})</span>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>

      {/* Charts Section */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Device Status Pie Chart */}
        <div className="bg-gray-800 rounded-lg p-6 shadow-lg">
          <h2 className="text-xl font-bold text-white mb-4 flex items-center">
            <span className="mr-2">📊</span> Status dos Dispositivos
          </h2>
          {pieData.length > 0 ? (
            <ResponsiveContainer width="100%" height={250}>
              <PieChart>
                <Pie
                  data={pieData}
                  cx="50%"
                  cy="50%"
                  innerRadius={60}
                  outerRadius={100}
                  paddingAngle={5}
                  dataKey="value"
                  label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
                >
                  {pieData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.color} />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          ) : (
            <div className="h-64 flex items-center justify-center text-gray-500">
              Nenhum dado disponivel
            </div>
          )}
        </div>

        {/* PPPoE Bar Chart */}
        <div className="bg-gray-800 rounded-lg p-6 shadow-lg">
          <h2 className="text-xl font-bold text-white mb-4 flex items-center">
            <span className="mr-2">📈</span> PPPoE por BRAS
          </h2>
          {barData.length > 0 ? (
            <ResponsiveContainer width="100%" height={250}>
              <BarChart data={barData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#374151" />
                <XAxis dataKey="name" stroke="#9CA3AF" fontSize={10} />
                <YAxis stroke="#9CA3AF" />
                <Tooltip 
                  contentStyle={{ backgroundColor: '#1F2937', border: 'none' }}
                  labelStyle={{ color: '#F3F4F6' }}
                />
                <Bar dataKey="total" fill="#8B5CF6" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          ) : (
            <div className="h-64 flex items-center justify-center text-gray-500">
              Nenhum dado PPPoE disponivel
            </div>
          )}
        </div>
      </div>

      {/* Server Health */}
      <div className="bg-gray-800 rounded-lg p-6 shadow-lg">
        <h2 className="text-xl font-bold text-white mb-4 flex items-center">
          <span className="mr-2">🖥️</span> Saude do Servidor
        </h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div>
            <div className="flex justify-between text-sm mb-1">
              <span className="text-gray-400">CPU</span>
              <span className="text-white">{stats.server_health?.cpu || 0}%</span>
            </div>
            <div className="w-full bg-gray-700 rounded-full h-3">
              <div 
                className={`h-3 rounded-full ${(stats.server_health?.cpu || 0) > 80 ? 'bg-red-500' : (stats.server_health?.cpu || 0) > 50 ? 'bg-yellow-500' : 'bg-green-500'}`}
                style={{ width: `${stats.server_health?.cpu || 0}%` }}
              ></div>
            </div>
          </div>
          <div>
            <div className="flex justify-between text-sm mb-1">
              <span className="text-gray-400">RAM</span>
              <span className="text-white">{stats.server_health?.ram || 0}%</span>
            </div>
            <div className="w-full bg-gray-700 rounded-full h-3">
              <div 
                className={`h-3 rounded-full ${(stats.server_health?.ram || 0) > 80 ? 'bg-red-500' : (stats.server_health?.ram || 0) > 50 ? 'bg-yellow-500' : 'bg-green-500'}`}
                style={{ width: `${stats.server_health?.ram || 0}%` }}
              ></div>
            </div>
          </div>
          <div>
            <div className="flex justify-between text-sm mb-1">
              <span className="text-gray-400">Disco</span>
              <span className="text-white">{stats.server_health?.disk || 0}%</span>
            </div>
            <div className="w-full bg-gray-700 rounded-full h-3">
              <div 
                className={`h-3 rounded-full ${(stats.server_health?.disk || 0) > 80 ? 'bg-red-500' : (stats.server_health?.disk || 0) > 50 ? 'bg-yellow-500' : 'bg-green-500'}`}
                style={{ width: `${stats.server_health?.disk || 0}%` }}
              ></div>
            </div>
          </div>
        </div>
      </div>

      {/* Loading Overlay */}
      {loading && (
        <div className="fixed top-4 right-4 bg-blue-600 text-white px-4 py-2 rounded-lg shadow-lg">
          Atualizando dados...
        </div>
      )}
    </div>
  );
};

export default Dashboard;
'''

if __name__ == '__main__':
    with open('/opt/lorcgr/frontend/src/components/Dashboard.js', 'w', encoding='utf-8') as f:
        f.write(DASHBOARD_CONTENT)
    print("✅ Dashboard.js escrito com sucesso!")
