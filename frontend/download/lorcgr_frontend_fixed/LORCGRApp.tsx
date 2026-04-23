'use client';

import { useState, useEffect, useCallback } from 'react';
import Sidebar from '@/components/lor-cgr/Sidebar';
import DashboardNOC from '@/components/lor-cgr/DashboardNOC';
import Inventory from '@/components/lor-cgr/Inventory';
import Multiterminal from '@/components/lor-cgr/Multiterminal';
import TerminalModal from '@/components/lor-cgr/TerminalModal';
import NextermTerminal from '@/components/lor-cgr/NextermTerminal';
import Backups from '@/components/lor-cgr/Backups';
import AuditLogs from '@/components/lor-cgr/AuditLogs';
import Users from '@/components/lor-cgr/Users';
import SettingsComponent from '@/components/lor-cgr/Settings';
import { Device, DashboardStats, DDMStats } from '@/types/lor-cgr';
import { toast } from 'sonner';

// API Base URL - Direct to Django backend
const API_BASE_URL = 'http://45.71.242.131';

// Field mapping from Django API to frontend Device type
function mapDeviceFromApi(apiDevice: Record<string, unknown>): Device {
  return {
    id: apiDevice.id as number,
    name: (apiDevice.name as string) || (apiDevice.hostname as string) || '',
    ip: (apiDevice.primary_ip as string) || (apiDevice.ip_address as string) || '',
    port: (apiDevice.port as number) || 22,
    vendor: (apiDevice.vendor as string) || '',
    model: (apiDevice.model as string) || '',
    device_type: apiDevice.is_bras ? 'bras' : (apiDevice.device_type as Device['device_type']) || 'router',
    status: apiDevice.status === 'active' || apiDevice.is_online === true ? 'online' : 'offline',
    // SSH Credentials
    ssh_user: (apiDevice.ssh_username as string) || (apiDevice.ssh_user as string) || (apiDevice.username as string) || '',
    ssh_password: (apiDevice.ssh_password as string) || (apiDevice.password as string) || '',
    ssh_port: (apiDevice.ssh_port as number) || (apiDevice.port as number) || 22,
    ssh_version: (apiDevice.ssh_version as string) || '2',
    // Telnet
    telnet_enabled: (apiDevice.telnet_enabled as boolean) || false,
    telnet_port: (apiDevice.telnet_port as number) || 23,
    // SNMP
    snmp_community: (apiDevice.snmp_community as string) || '',
    snmp_port: (apiDevice.snmp_port as number) || 161,
    snmp_version: (apiDevice.snmp_version as string) || 'v2c',
    // Protocolo ativo
    protocol: (apiDevice.protocol as 'ssh' | 'telnet') || 'ssh',
    // Backup
    backup_enabled: apiDevice.backup_enabled as boolean,
    backup_method: apiDevice.backup_method as string,
    backup_frequency: apiDevice.backup_frequency as string,
    backup_time: apiDevice.backup_time as string,
    last_backup: apiDevice.last_backup as string,
    // Location
    location: apiDevice.location as string,
    // Integration IDs - IMPORTANT: map from both API formats
    librenms_id: (apiDevice.librenms_id as number) || undefined,
    zabbix_id: (apiDevice.zabbix_id as number) || undefined,
    web_url: apiDevice.web_url as string,
  };
}

// Field mapping from frontend Device to Django API
function mapDeviceToApi(device: Partial<Device>): Record<string, unknown> {
  const apiDevice: Record<string, unknown> = {};

  // Básico
  if (device.id) apiDevice.id = device.id;
  if (device.name) apiDevice.hostname = device.name;
  if (device.ip) apiDevice.ip_address = device.ip;
  if (device.port) apiDevice.port = device.port;
  if (device.vendor) apiDevice.vendor = device.vendor;
  if (device.model) apiDevice.model = device.model;
  if (device.device_type) apiDevice.is_bras = device.device_type === 'bras';
  if (device.location) apiDevice.location = device.location;
  if (device.web_url) apiDevice.web_url = device.web_url;
  if (device.librenms_id) apiDevice.librenms_id = device.librenms_id;

  // SSH
  if (device.ssh_user) {
    apiDevice.ssh_user = device.ssh_user;
    apiDevice.username = device.ssh_user;
  }
  if (device.ssh_password) {
    apiDevice.ssh_password = device.ssh_password;
    apiDevice.password = device.ssh_password;
  }
  if (device.ssh_port) apiDevice.ssh_port = device.ssh_port;
  if (device.ssh_version) apiDevice.ssh_version = device.ssh_version;

  // Telnet
  if (device.telnet_enabled !== undefined) apiDevice.telnet_enabled = device.telnet_enabled;
  if (device.telnet_port) apiDevice.telnet_port = device.telnet_port;

  // Protocolo ativo
  if (device.protocol) apiDevice.protocol = device.protocol;

  // SNMP
  if (device.snmp_community) apiDevice.snmp_community = device.snmp_community;
  if (device.snmp_port) apiDevice.snmp_port = device.snmp_port;
  if (device.snmp_version) apiDevice.snmp_version = device.snmp_version;

  // Backup
  if (device.backup_enabled !== undefined) apiDevice.backup_enabled = device.backup_enabled;
  if (device.backup_frequency) apiDevice.backup_frequency = device.backup_frequency;
  if (device.backup_time) apiDevice.backup_time = device.backup_time;

  return apiDevice;
}

export default function LORCGRApp() {
  const [activeTab, setActiveTab] = useState('dashboard');
  const [devices, setDevices] = useState<Device[]>([]);
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [ddmStats, setDdmStats] = useState<DDMStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [terminalSessions, setTerminalSessions] = useState<{id: string; device: Device}[]>([]);
  const [terminalModalOpen, setTerminalModalOpen] = useState(false);
  const [initialDevice, setInitialDevice] = useState<Device | null>(null);

  // Fetch devices from real API
  const fetchDevices = useCallback(async () => {
    try {
      // Try equipments endpoint first (Django)
      const response = await fetch(`${API_BASE_URL}/api/equipments/`);
      if (!response.ok) throw new Error('Failed to fetch devices');
      const data = await response.json();
      // Handle both array and paginated responses
      const devices = Array.isArray(data) ? data : (data.results || []);
      const mappedDevices = devices.map((d: Record<string, unknown>) => mapDeviceFromApi(d));
      setDevices(mappedDevices);
      return mappedDevices;
    } catch (error) {
      console.error('Error fetching devices:', error);
      toast.error('Erro ao carregar dispositivos');
      return [];
    }
  }, []);

  // Fetch dashboard stats
  // NOTA: Não depender de 'devices' para evitar loop infinito
  const fetchDashboard = useCallback(async () => {
    try {
      const response = await fetch(`${API_BASE_URL}/api/devices/dashboard/`);
      if (!response.ok) throw new Error('Failed to fetch dashboard');
      const data = await response.json();
      setStats(data);
    } catch (error) {
      console.error('Error fetching dashboard:', error);
      // Set default stats if API fails - não usar 'devices' aqui
      setStats({
        devices_total: 0,
        bras_count: 0,
        pppoe_total: 0,
        pppoe_details: [],
        server_health: { cpu: 0, ram: 0, disk: 0 },
      });
    }
  }, []);  // Dependência vazia para evitar loop infinito

  // Fetch DDM stats
  const fetchDDMStats = useCallback(async () => {
    try {
      const response = await fetch(`${API_BASE_URL}/api/devices/interfaces/stats/`);
      if (!response.ok) throw new Error('Failed to fetch DDM stats');
      const data = await response.json();
      if (data.status === 'success') {
        setDdmStats(data);
      }
    } catch (error) {
      console.error('Error fetching DDM stats:', error);
      // Set default DDM stats if API fails
      setDdmStats({
        status: 'success',
        total_transceivers: 0,
        avg_temperature: 0,
        avg_rx_power: 0,
        avg_tx_power: 0,
        alerts: { critical: 0, warning: 0, normal: 0 },
      });
    }
  }, []);

  // Main fetch function
  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      await Promise.all([
        fetchDevices(),
        fetchDashboard(),
        fetchDDMStats(),
      ]);
    } finally {
      setLoading(false);
    }
  }, [fetchDevices, fetchDashboard, fetchDDMStats]);

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
      const response = await fetch(`${API_BASE_URL}/api/devices/save/`, {
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
      const response = await fetch(`${API_BASE_URL}/api/devices/save/`, {
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
      const response = await fetch(`${API_BASE_URL}/api/devices/delete/`, {
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
    setInitialDevice(device);
    setTerminalModalOpen(true);
  };

  const handleTerminalConnect = (deviceId: number) => {
    console.log('Connecting to device:', deviceId);
  };

  // Backup operations
  const handleRunBackup = async (deviceId: number) => {
    try {
      const response = await fetch(`${API_BASE_URL}/api/devices/backup/run/`, {
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
    window.open(`${API_BASE_URL}:8000/api/backups/download/?id=${backupId}`, '_blank');
    toast.success('Download iniciado');
  };

  const handleDeleteBackup = async (backupId: string) => {
    try {
      const response = await fetch(`${API_BASE_URL}:8000/api/backups/delete/`, {
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
            ddmStats={ddmStats}
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
        return <NextermTerminal />;
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
      case 'users':
        return (
          <Users
            loading={loading}
            onRefresh={fetchData}
            isAdmin={true}
          />
        );
      case 'audit':
        return (
          <AuditLogs
            devices={devices}
            loading={loading}
            onRefresh={fetchData}
            isAdmin={true}
          />
        );
      case 'settings':
        return (
          <SettingsComponent
            loading={loading}
            onRefresh={fetchData}
            isAdmin={true}
          />
        );
      default:
        return (
          <DashboardNOC
            stats={stats}
            devices={devices}
            ddmStats={ddmStats}
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
        onOpenTerminal={() => setTerminalModalOpen(true)}
      />

      <main className="flex-1 min-h-screen lg:pt-0 pt-14">
        <div className="container mx-auto p-6 max-w-7xl">
          {renderContent()}
        </div>
      </main>

      {/* Terminal Modal */}
      <TerminalModal
        open={terminalModalOpen}
        onOpenChange={setTerminalModalOpen}
        devices={devices}
        sessions={terminalSessions}
        onConnect={handleTerminalConnect}
        initialDevice={initialDevice}
      />
    </div>
  );
}
