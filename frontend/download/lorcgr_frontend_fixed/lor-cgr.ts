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
  // Ping monitoring
  ping_ms?: number;
  ping_status?: 'excellent' | 'good' | 'warning' | 'critical' | 'offline';
  // SSH Credentials
  ssh_user?: string;
  ssh_password?: string;
  ssh_port?: number;
  ssh_version?: string;
  // Telnet
  telnet_enabled?: boolean;
  telnet_port?: number;
  // SNMP Credentials
  snmp_community?: string;
  snmp_port?: number;
  snmp_version?: string;
  // Protocolo ativo (ssh ou telnet)
  protocol?: 'ssh' | 'telnet';
  // Backup
  backup_enabled?: boolean;
  backup_method?: string;
  backup_frequency?: string;
  backup_time?: string;
  last_backup?: string;
  // Location
  location?: string;
  // LibreNMS
  librenms_id?: number;
  // Zabbix
  zabbix_id?: number;
  // Web Interface
  web_url?: string;
  // PPPoE
  pppoe_count?: number;
  // Timestamps
  created_at?: string;
  updated_at?: string;
}

// User Types
export type UserRole = 'ADMIN' | 'NOC' | 'VIEW' | 'PERSONALIZADO';

export interface User {
  id: number;
  name: string;
  login: string;
  email?: string;
  phone?: string;
  role: UserRole;
  is_active: boolean;
  last_login?: string;
  created_at?: string;
  // Permissões personalizadas
  permissions?: UserPermissions;
}

export interface UserPermissions {
  dashboard?: boolean;
  equipment_view?: boolean;
  equipment_edit?: boolean;
  terminal?: boolean;
  backups_view?: boolean;
  backups_run?: boolean;
  users_view?: boolean;
  users_edit?: boolean;
  logs_view?: boolean;
  logs_delete?: boolean;
  settings_view?: boolean;
  settings_edit?: boolean;
}

// Settings Types
export interface Settings {
  // LibreNMS
  librenms_url?: string;
  librenms_api_token?: string;
  librenms_enabled?: boolean;
  // phpIPAM
  phpipam_url?: string;
  phpipam_app_id?: string;
  phpipam_api_key?: string;
  phpipam_enabled?: boolean;
  // Zabbix
  zabbix_url?: string;
  zabbix_user?: string;
  zabbix_password?: string;
  zabbix_enabled?: boolean;
  // Groq AI
  groq_api_key?: string;
  groq_model?: string;
  groq_enabled?: boolean;
  // IXC Provedor
  ixc_url?: string;
  ixc_token?: string;
  ixc_enabled?: boolean;
  // GitHub Backup
  github_token?: string;
  github_repo?: string;
  github_branch?: string;
  auto_backup_enabled?: boolean;
  backup_frequency?: string;
  // FTP
  ftp_host?: string;
  ftp_port?: number;
  ftp_user?: string;
  ftp_password?: string;
  ftp_enabled?: boolean;
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

// DDM (Digital Diagnostics Monitoring) Stats
export interface DDMStats {
  status: string;
  total_transceivers: number;
  avg_temperature: number;
  avg_rx_power: number;
  avg_tx_power: number;
  alerts: {
    critical: number;
    warning: number;
    normal: number;
  };
  issues?: DDMIssue[];
}

export interface DDMIssue {
  device_name: string;
  interface_name: string;
  status: 'critical' | 'warning' | 'normal';
  message: string;
}

// Device Interface with DDM data
export interface DeviceInterface {
  id: number;
  device: number;
  device_name?: string;
  if_name: string;
  if_alias?: string;
  if_oper_status: string;
  has_gbic: boolean;
  gbic_type?: string;
  gbic_vendor?: string;
  gbic_serial?: string;
  gbic_temperature?: number;
  rx_power?: number;
  tx_power?: number;
  gbic_bias_current?: number;
}

// Device Uptime
export interface DeviceUptime {
  device_id: number;
  device_name: string;
  uptime_seconds: number;
  uptime_formatted: string;
  last_boot?: string;
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
  id: number;
  user?: string;
  action: string;
  device?: string;
  details: string;
  ip_address?: string;
  timestamp: string;
  session_id?: string;
}

export interface TerminalSession {
  id: number;
  session_id: string;
  device_id: number;
  device_name: string;
  user?: string;
  ip_address?: string;
  start_time: string;
  end_time?: string;
  duration_seconds?: number;
  status: string;
  session_content?: string;
  commands_executed?: string;
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
