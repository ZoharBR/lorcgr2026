// LOR CGR API Client
// Backend Django: http://45.71.242.131 (porta 80 para frontend, 9000 interno para API)

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://45.71.242.131';
const WS_BASE_URL = process.env.NEXT_PUBLIC_WS_URL || 'ws://45.71.242.131';

// Para desenvolvimento local, usar proxy
const getApiUrl = (endpoint: string) => {
  if (typeof window !== 'undefined' && window.location.hostname === 'localhost') {
    return `/api${endpoint}`;
  }
  return `${API_BASE_URL}${endpoint}`;
};

const getWsUrl = (path: string) => {
  return `${WS_BASE_URL}${path}`;
};

// Generic fetch wrapper
async function fetchApi<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
  const url = getApiUrl(endpoint);
  
  const defaultHeaders: HeadersInit = {
    'Content-Type': 'application/json',
  };

  const response = await fetch(url, {
    ...options,
    headers: {
      ...defaultHeaders,
      ...options.headers,
    },
  });

  if (!response.ok) {
    const error = await response.json().catch(() => ({ error: 'Network error' }));
    throw new Error(error.error || `HTTP ${response.status}`);
  }

  return response.json();
}

// Devices API
export const devicesApi = {
  list: () => fetchApi<{ devices: import('@/types/lor-cgr').Device[] }>('/devices/api/list/'),
  
  dashboard: () => fetchApi<import('@/types/lor-cgr').DashboardStats>('/devices/api/dashboard/'),
  
  get: (id: number) => fetchApi<{ device: import('@/types/lor-cgr').Device }>(`/devices/api/${id}/`),
  
  save: (device: Partial<import('@/types/lor-cgr').Device>) => 
    fetchApi<{ success: boolean; device: import('@/types/lor-cgr').Device }>('/devices/api/save/', {
      method: 'POST',
      body: JSON.stringify(device),
    }),
  
  delete: (id: number) => 
    fetchApi<{ success: boolean }>(`/devices/api/${id}/`, {
      method: 'DELETE',
    }),
  
  discovery: (ipRange: string) => 
    fetchApi<{ discovered: number; devices: import('@/types/lor-cgr').Device[] }>('/devices/api/discovery/', {
      method: 'POST',
      body: JSON.stringify({ ip_range: ipRange }),
    }),
};

// Backups API
export const backupsApi = {
  list: (deviceId?: number) => {
    const params = deviceId ? `?device_id=${deviceId}` : '';
    return fetchApi<{ backups: import('@/types/lor-cgr').Backup[] }>(`/devices/api/backup/list/${params}`);
  },
  
  run: (deviceId: number) => 
    fetchApi<{ success: boolean; backup: import('@/types/lor-cgr').Backup }>('/devices/api/backup/run/', {
      method: 'POST',
      body: JSON.stringify({ device_id: deviceId }),
    }),
  
  download: (backupId: string) => 
    `${getApiUrl('/devices/api/backup/download/')}?id=${backupId}`,
};

// Audit Logs API
export const auditApi = {
  list: (filters?: { device_id?: number; action?: string; limit?: number }) => {
    const params = new URLSearchParams();
    if (filters?.device_id) params.append('device_id', filters.device_id.toString());
    if (filters?.action) params.append('action', filters.action);
    if (filters?.limit) params.append('limit', filters.limit.toString());
    const queryString = params.toString();
    return fetchApi<{ logs: import('@/types/lor-cgr').AuditLog[] }>(
      `/devices/api/audit-logs/${queryString ? `?${queryString}` : ''}`
    );
  },
};

// Terminal Sessions API
export const terminalApi = {
  list: () => 
    fetchApi<{ sessions: import('@/types/lor-cgr').TerminalSession[] }>('/devices/api/terminal-sessions/'),
};

// Manual API
export const manualApi = {
  get: () => 
    fetchApi<{ manual: import('@/types/lor-cgr').ManualEntry[] }>('/devices/api/manual/'),
  
  save: (entry: Partial<import('@/types/lor-cgr').ManualEntry>) => 
    fetchApi<{ success: boolean; entry: import('@/types/lor-cgr').ManualEntry }>('/devices/api/manual/save/', {
      method: 'POST',
      body: JSON.stringify(entry),
    }),
};

// WebSocket connection for SSH terminal
export class TerminalWebSocket {
  private ws: WebSocket | null = null;
  private deviceId: number;
  private onMessage: (msg: import('@/types/lor-cgr').WSMessage) => void;
  private onConnect: () => void;
  private onDisconnect: () => void;

  constructor(
    deviceId: number,
    onMessage: (msg: import('@/types/lor-cgr').WSMessage) => void,
    onConnect: () => void,
    onDisconnect: () => void
  ) {
    this.deviceId = deviceId;
    this.onMessage = onMessage;
    this.onConnect = onConnect;
    this.onDisconnect = onDisconnect;
  }

  connect() {
    const wsUrl = getWsUrl(`/ws/terminal/${this.deviceId}/`);
    this.ws = new WebSocket(wsUrl);

    this.ws.onopen = () => {
      console.log('WebSocket connected');
      this.onConnect();
    };

    this.ws.onmessage = (event) => {
      try {
        const msg = JSON.parse(event.data) as import('@/types/lor-cgr').WSMessage;
        this.onMessage(msg);
      } catch {
        this.onMessage({ type: 'output', data: event.data });
      }
    };

    this.ws.onclose = () => {
      console.log('WebSocket disconnected');
      this.onDisconnect();
    };

    this.ws.onerror = (error) => {
      console.error('WebSocket error:', error);
      this.onMessage({ type: 'error', data: 'Connection error' });
    };
  }

  send(data: string) {
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify({ type: 'input', data }));
    }
  }

  resize(cols: number, rows: number) {
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify({ type: 'resize', cols, rows }));
    }
  }

  disconnect() {
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }

  isConnected() {
    return this.ws?.readyState === WebSocket.OPEN;
  }
}

const apiClient = {
  devices: devicesApi,
  backups: backupsApi,
  audit: auditApi,
  terminal: terminalApi,
  manual: manualApi,
  TerminalWebSocket,
};

export default apiClient;
