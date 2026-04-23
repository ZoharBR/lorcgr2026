'use client';

import { useState, useEffect, useCallback } from 'react';
import Sidebar from '@/components/lor-cgr/Sidebar';
import DashboardNOC from '@/components/lor-cgr/DashboardNOC';
import Inventory from '@/components/lor-cgr/Inventory';
import Multiterminal from '@/components/lor-cgr/Multiterminal';
import Backups from '@/components/lor-cgr/Backups';
import AuditLogs from '@/components/lor-cgr/AuditLogs';
import Users from '@/components/lor-cgr/Users';
import SettingsComponent from '@/components/lor-cgr/Settings';
import NextermTerminal from '@/components/lor-cgr/NextermTerminal';
import TerminalModal from '@/components/lor-cgr/TerminalModal';
import { Device } from '@/types/lor-cgr';
import { toast } from 'sonner';

// Função helper para fetch com autenticação (cookies + CSRF)
const authFetch = async (url: string, options: RequestInit = {}) => {
  // Obter CSRF token do cookie
  const getCsrfToken = (): string => {
    if (typeof document === 'undefined') return '';
    const match = document.cookie.match(/csrftoken=([^;]+)/);
    return match ? match[1] : '';
  };
  
  const csrfToken = getCsrfToken();
  
  return fetch(url, {
    ...options,
    credentials: 'include', // Envia cookies de sessão!
    headers: {
      ...(options.headers || {}),
      'Content-Type': 'application/json',
      ...(csrfToken ? { 'X-CSRFToken': csrfToken } : {}),
    },
  });
};

const API_URL = '/api/equipments';

export default function LORCGRApp() {
  const [activeTab, setActiveTab] = useState('dashboard');
  const [devices, setDevices] = useState<Device[]>([]);
  const [loading, setLoading] = useState(true);
  const [terminalModalOpen, setTerminalModalOpen] = useState(false);

  const fetchDevices = useCallback(async () => {
    try {
      const res = await authFetch(API_URL + '/');
      if (res.ok) {
        const data = await res.json();
        const deviceList = Array.isArray(data) ? data : [];
        const mapped = deviceList.map((d: any) => ({
          id: d.id,
          name: d.name || d.hostname || '',
          ip: d.primary_ip || '',
          port: d.ssh_port || 22,
          vendor: d.vendor || '',
          model: d.model || '',
          device_type: d.device_type || 'router',
          status: d.status === 'active' ? 'online' : 'offline',
          ssh_user: d.ssh_username || '',
          ssh_password: d.ssh_password || '',
          ssh_port: d.ssh_port || 22,
          snmp_community: d.snmp_community || '',
          location: d.location || '',
          librenms_id: d.librenms_id,
          zabbix_id: d.zabbix_id,
        }));
        setDevices(mapped);
      }
    } catch (err) {
      console.error('Erro ao buscar:', err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchDevices();
  }, [fetchDevices]);

  const handleAddDevice = async (device: Partial<Device>) => {
    try {
      const res = await authFetch(API_URL + '/', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: device.name,
          hostname: device.name?.toLowerCase().replace(/\s+/g, '_'),
          primary_ip: device.ip,
          device_type: device.device_type || 'router',
          vendor: device.vendor || 'huawei',
          model: device.model || '',
          ssh_username: device.ssh_user || '',
          ssh_password: device.ssh_password || '',
          ssh_port: device.ssh_port || 22,
          snmp_community: device.snmp_community || '',
          location: device.location || '',
          status: 'active',
        }),
      });
      if (!res.ok) throw new Error('Erro ao criar');
      toast.success('Dispositivo criado!');
      fetchDevices();
    } catch (err: any) {
      toast.error('Erro: ' + err.message);
      throw err;
    }
  };

  const handleUpdateDevice = async (device: Partial<Device>) => {
    try {
      if (!device.id) throw new Error('ID nao informado');
      const res = await authFetch(API_URL + '/' + device.id + '/', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: device.name,
          hostname: device.name?.toLowerCase().replace(/\s+/g, '_'),
          primary_ip: device.ip,
          device_type: device.device_type,
          vendor: device.vendor,
          model: device.model,
          ssh_username: device.ssh_user,
          ssh_password: device.ssh_password,
          ssh_port: device.ssh_port || 22,
          snmp_community: device.snmp_community,
          location: device.location,
        }),
      });
      if (!res.ok) throw new Error('Erro ao atualizar');
      toast.success('Dispositivo atualizado!');
      fetchDevices();
    } catch (err: any) {
      toast.error('Erro: ' + err.message);
      throw err;
    }
  };

  const handleDeleteDevice = async (id: number) => {
    try {
      const res = await authFetch(API_URL + '/' + id + '/', { method: 'DELETE' });
      if (!res.ok) throw new Error('Erro ao excluir');
      toast.success('Dispositivo excluido!');
      fetchDevices();
    } catch (err: any) {
      toast.error('Erro: ' + err.message);
      throw err;
    }
  };

  const handleOpenTerminal = (device: Device) => setTerminalModalOpen(true);
  const handleRunBackup = async (id: number) => toast.info('Backup iniciado...');

  const renderContent = () => {
    switch (activeTab) {
      case 'dashboard': return <DashboardNOC />;
      case 'inventory':
      case 'equipments':
      case 'equipments-networks':
      case 'equipments-servers':
        return <Inventory devices={devices} loading={loading} onRefresh={fetchDevices} onAddDevice={handleAddDevice} onUpdateDevice={handleUpdateDevice} onDeleteDevice={handleDeleteDevice} onOpenTerminal={handleOpenTerminal} onRunBackup={handleRunBackup} />;
      case 'terminal': return <NextermTerminal />;
      case 'backups': return <Backups devices={devices} loading={loading} onRefresh={fetchDevices} />;
      case 'users': return <Users loading={loading} onRefresh={fetchDevices} isAdmin={true} />;
      case 'logs':
      case 'audit': return <AuditLogs devices={devices} loading={loading} onRefresh={fetchDevices} isAdmin={true} />;
      case 'settings-security':
        return <SettingsComponent loading={loading} onRefresh={fetchDevices} isAdmin={true} defaultTab="security" />;
      default: return <SettingsComponent loading={loading} onRefresh={fetchDevices} isAdmin={true} />;
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-900 to-slate-950 flex">
      <Sidebar activeTab={activeTab} onTabChange={setActiveTab} onOpenTerminal={() => setTerminalModalOpen(true)} />
      <main className="flex-1 min-h-screen lg:pt-0 pt-14">{renderContent()}</main>
      <TerminalModal open={terminalModalOpen} onOpenChange={setTerminalModalOpen} devices={devices} sessions={[]} onConnect={() => {}} />
    </div>
  );
}
