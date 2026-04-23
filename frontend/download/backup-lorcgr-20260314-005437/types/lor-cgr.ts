// LOR CGR Types

export interface Device {
  id: number;
  name: string;
  ip: string;
  port?: number;
  vendor: string;
  model?: string;
  os_version?: string;
  serial_number?: string;
  device_type: 'bras' | 'pppoe' | 'olt' | 'switch' | 'router';
  status: 'online' | 'offline' | 'unknown';
  ssh_user?: string;
  ssh_password?: string;
  snmp_community?: string;
  snmp_port?: number;
  snmp_version?: string;
  librenms_id?: number;
  web_url?: string;
  protocol?: string;
  pppoe_count?: number;
  backup_enabled?: boolean;
  backup_frequency?: string;
  backup_time?: string;
  last_backup?: string;
  created_at?: string;
  updated_at?: string;
}

export interface DashboardStats {
  devices_total: number;
  bras_count: number;
  pppoe_total: number;
  pppoe_details: PPPoEDetail[];
  server_health: ServerHealth;
}

export interface PPPoEDetail {
  name: string;
  ip: string;
  count: number;
}

export interface ServerHealth {
  cpu: number;
  ram: number;
  disk: number;
}

export interface Backup {
  id: string;
  device_id: number;
  device_name: string;
  filename: string;
  created_at: string;
  size: number;
  status: 'success' | 'failed' | 'running';
}

export interface AuditLog {
  id: string;
  user?: string;
  action: string;
  device?: string;
  details: string;
  ip_address?: string;
  timestamp: string;
}

export interface TerminalSession {
  id: string;
  device_id: number;
  device_name: string;
  user?: string;
  started_at: string;
  ended_at?: string;
  commands_count: number;
  status: 'active' | 'closed';
}

export interface ManualEntry {
  id: string;
  title: string;
  category: string;
  content: string;
  created_at: string;
  updated_at: string;
}

// API Response types
export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}

// WebSocket message types
export interface WSMessage {
  type: 'output' | 'status' | 'error' | 'connected' | 'disconnected';
  data: string;
  timestamp?: string;
}

export interface SSHCommand {
  command: string;
  timestamp: string;
}
