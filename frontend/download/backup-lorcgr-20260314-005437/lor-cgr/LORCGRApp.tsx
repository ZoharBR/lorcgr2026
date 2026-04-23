'use client';

import { useState, useEffect, useCallback } from 'react';
import Sidebar from '@/components/lor-cgr/Sidebar';
import DashboardNOC from '@/components/lor-cgr/DashboardNOC';
import Inventory from '@/components/lor-cgr/Inventory';
import Multiterminal from '@/components/lor-cgr/Multiterminal';
import Backups from '@/components/lor-cgr/Backups';
import AuditLogs from '@/components/lor-cgr/AuditLogs';
import { Device, DashboardStats } from '@/types/lor-cgr';
import { toast } from 'sonner';

// API Base URL - Direct to Django backend
const API_BASE_URL = 'http://45.71.242.131';

// Field mapping from Django API to frontend Device type
// Django API fields: hostname, ip_address, vendor, model, port, username, password,
// snmp_community, snmp_port, is_bras, librenms_id, etc.
function mapDeviceFromApi(apiDevice: Record<string, unknown>): Device {
  return {
    id: apiDevice.id as number,
    name: (apiDevice.hostname as string) || '',
    ip: (apiDevice.ip_address as string) || '',
    port: (apiDevice.port as number) || 22,
    vendor: (apiDevice.vendor as string) || '',
    model: (apiDevice.model as string) || '',
    device_type: apiDevice.is_bras ? 'bras' : (apiDevice.device_type as Device['device_type']) || 'router',
    status: 'online', // Will be updated by status check
    ssh_user: (apiDevice.username as string) || '',
    ssh_password: (apiDevice.password as string) || '',
    snmp_community: (apiDevice.snmp_community as string) || '',
    snmp_port: (apiDevice.snmp_port as number) || 161,
    librenms_id: apiDevice.librenms_id as number,
    web_url: apiDevice.web_url as string,
    protocol: apiDevice.protocol as string,
    backup_enabled: apiDevice.backup_enabled as boolean,
    backup_frequency: apiDevice.backup_frequency as string,
    backup_time: apiDevice.backup_time as string,
  };
}

// Field mapping from frontend Device to Django API
function mapDeviceToApi(device: Partial<Device>): Record<string, unknown> {
  const apiDevice: Record<string, unknown> = {};
  
  if (device.id) apiDevice.id = device.id;
  if (device.name) apiDevice.hostname = device.name;
  if (device.ip) apiDevice.ip_address = device.ip;
  if (device.port) apiDevice.port = device.port;
  if (device.vendor) apiDevice.vendor = device.vendor;
  if (device.model) apiDevice.model = device.model;
  if (device.device_type) apiDevice.is_bras = device.device_type === 'bras';
  if (device.ssh_user) apiDevice.username = device.ssh_user;
  if (device.ssh_password) apiDevice.password = device.ssh_password;
  if (device.snmp_community) apiDevice.snmp_community = device.snmp_community;
  if (device.snmp_port) apiDevice.snmp_port = device.snmp_port;
  if (device.librenms_id) apiDevice.librenms_id = device.librenms_id;
  if (device.web_url) apiDevice.web_url = device.web_url;
  if (device.protocol) apiDevice.protocol = device.protocol;
  if (device.backup_enabled !== undefined) apiDevice.backup_enabled = device.backup_enabled;
  if (device.backup_frequency) apiDevice.backup_frequency = device.backup_frequency;
  if (device.backup_time) apiDevice.backup_time = device.backup_time;
  
  return apiDevice;
}

export default function LORCGRApp() {
  const [activeTab, setActiveTab] = useState('dashboard');
  const [devices, setDevices] = useState<Device[]>([]);
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [terminalSessions, setTerminalSessions] = useState<{id: string; device: Device}[]>([]);

  // Fetch devices from real API
  const fetchDevices = useCallback(async () => {
    try {
      const response = await fetch(`${API_BASE_URL}/devices/api/list/`);
      if (!response.ok) throw new Error('Failed to fetch devices');
      const data = await response.json();
      const mappedDevices = data.map((d: Record<string, unknown>) => mapDeviceFromApi(d));
      setDevices(mappedDevices);
      return mappedDevices;
    } catch (error) {
      console.error('Error fetching devices:', error);
      toast.error('Erro ao carregar dispositivos');
      return [];
    }
  }, []);

  // Fetch dashboard stats
  const fetchDashboard = useCallback(async () => {
    try {
      const response = await fetch(`${API_BASE_URL}/devices/api/dashboard/`);
      if (!response.ok) throw new Error('Failed to fetch dashboard');
      const data = await response.json();
      setStats(data);
    } catch (error) {
      console.error('Error fetching dashboard:', error);
      // Set default stats if API fails
      setStats({
        devices_total: devices.length,
        bras_count: devices.filter(d => d.device_type === 'bras').length,
        pppoe_total: devices.reduce((sum, d) => sum + (d.pppoe_count || 0), 0),
        pppoe_details: devices.filter(d => d.device_type === 'bras').map(d => ({
          name: d.name,
          ip: d.ip,
          count: d.pppoe_count || 0,
        })),
        server_health: { cpu: 0, ram: 0, disk: 0 },
      });
    }
  }, [devices]);

  // Main fetch function
  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      await fetchDevices();
      await fetchDashboard();
    } finally {
      setLoading(false);
    }
  }, [fetchDevices, fetchDashboard]);

  useEffect(() => {
    fetchData();
    
    // Auto-refresh a cada 60 segundos
    const interval = setInterval(fetchData, 60000);
    return () => clearInterval(interval);
  }, [fetchData]);

  // Device CRUD operations with real API
  const handleAddDevice = async (device: Partial<Device>) => {
    try {
      const apiDevice = mapDeviceToApi(device);
      const response = await fetch(`${API_BASE_URL}/devices/api/save/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(apiDevice),
      });
      
      if (!response.ok) throw new Error('Failed to add device');
      const result = await response.json();
      
      if (result.status === 'success') {
        toast.success('Dispositivo adicionado com sucesso');
        fetchData();
      } else {
        throw new Error(result.error || 'Unknown error');
      }
    } catch (error) {
      console.error('Error adding device:', error);
      toast.error('Erro ao adicionar dispositivo');
      throw error;
    }
  };

  const handleUpdateDevice = async (device: Partial<Device>) => {
    try {
      const apiDevice = mapDeviceToApi(device);
      const response = await fetch(`${API_BASE_URL}/devices/api/save/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(apiDevice),
      });
      
      if (!response.ok) throw new Error('Failed to update device');
      const result = await response.json();
      
      if (result.status === 'success') {
        toast.success('Dispositivo atualizado com sucesso');
        fetchData();
      } else {
        throw new Error(result.error || 'Unknown error');
      }
    } catch (error) {
      console.error('Error updating device:', error);
      toast.error('Erro ao atualizar dispositivo');
      throw error;
    }
  };

  const handleDeleteDevice = async (id: number) => {
    try {
      const response = await fetch(`${API_BASE_URL}/devices/api/delete/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id }),
      });
      
      if (!response.ok) throw new Error('Failed to delete device');
      const result = await response.json();
      
      if (result.status === 'success') {
        toast.success('Dispositivo removido com sucesso');
        fetchData();
      } else {
        throw new Error(result.error || 'Unknown error');
      }
    } catch (error) {
      console.error('Error deleting device:', error);
      toast.error('Erro ao remover dispositivo');
      throw error;
    }
  };

  // Terminal operations
  const handleOpenTerminal = (device: Device) => {
    // Add to terminal sessions if not already there
    setTerminalSessions(prev => {
      const existing = prev.find(s => s.device.id === device.id);
      if (!existing) {
        return [...prev, { id: `terminal-${device.id}`, device }];
      }
      return prev;
    });
    setActiveTab('terminal');
  };

  const handleTerminalConnect = (deviceId: number) => {
    console.log('Connecting to device:', deviceId);
  };

  // Backup operations
  const handleRunBackup = async (deviceId: number) => {
    try {
      const response = await fetch(`${API_BASE_URL}/devices/api/backup/run/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ device_id: deviceId }),
      });
      
      if (!response.ok) throw new Error('Failed to run backup');
      const result = await response.json();
      
      if (result.status === 'success') {
        toast.success('Backup iniciado com sucesso');
      } else {
        throw new Error(result.error || 'Unknown error');
      }
    } catch (error) {
      console.error('Error running backup:', error);
      toast.error('Erro ao executar backup');
    }
  };

  const handleDownloadBackup = (backupId: string) => {
    window.open(`${API_BASE_URL}/devices/api/backup/download/?id=${backupId}`, '_blank');
    toast.success('Download iniciado');
  };

  const handleDeleteBackup = async (backupId: string) => {
    try {
      const response = await fetch(`${API_BASE_URL}/devices/api/backup/delete/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: backupId }),
      });
      
      if (!response.ok) throw new Error('Failed to delete backup');
      toast.success('Backup removido');
      fetchData();
    } catch (error) {
      console.error('Error deleting backup:', error);
      toast.error('Erro ao remover backup');
    }
  };

  // Render active component
  const renderContent = () => {
    switch (activeTab) {
      case 'dashboard':
        return (
          <DashboardNOC
            stats={stats}
            devices={devices}
            loading={loading}
            onRefresh={fetchData}
          />
        );
      case 'inventory':
        return (
          <Inventory
            devices={devices}
            loading={loading}
            onRefresh={fetchData}
            onAddDevice={handleAddDevice}
            onUpdateDevice={handleUpdateDevice}
            onDeleteDevice={handleDeleteDevice}
            onOpenTerminal={handleOpenTerminal}
            onRunBackup={handleRunBackup}
          />
        );
      case 'terminal':
        return (
          <Multiterminal
            devices={devices}
            sessions={terminalSessions}
            onConnect={handleTerminalConnect}
          />
        );
      case 'backups':
        return (
          <Backups
            devices={devices}
            loading={loading}
            onRefresh={fetchData}
            onRunBackup={handleRunBackup}
            onDownloadBackup={handleDownloadBackup}
            onDeleteBackup={handleDeleteBackup}
          />
        );
      case 'audit':
        return (
          <AuditLogs
            devices={devices}
            loading={loading}
            onRefresh={fetchData}
          />
        );
      default:
        return (
          <DashboardNOC
            stats={stats}
            devices={devices}
            loading={loading}
            onRefresh={fetchData}
          />
        );
    }
  };

  return (
    <div className="min-h-screen bg-background flex">
      <Sidebar
        activeTab={activeTab}
        onTabChange={setActiveTab}
        serverHealth={stats?.server_health}
      />
      
      <main className="flex-1 min-h-screen lg:pt-0 pt-14">
        <div className="container mx-auto p-6 max-w-7xl">
          {renderContent()}
        </div>
      </main>
    </div>
  );
}
