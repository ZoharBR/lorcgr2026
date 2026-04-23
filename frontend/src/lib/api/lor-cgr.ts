// LOR CGR API Client
// Backend Django: http://45.71.242.131 (porta 80)

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || '';

// Generic fetch wrapper with Auth & CSRF support
async function fetchApi<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
  const url = `${API_BASE_URL}${endpoint}`;
  
  // Obter CSRF token do cookie
  const getCsrfToken = (): string => {
    if (typeof document === 'undefined') return '';
    
    // Tentar pegar do cookie
    const match = document.cookie.match(/csrftoken=([^;]+)/);
    return match ? match[1] : '';
  };

  const csrfToken = getCsrfToken();
  
  const defaultHeaders: HeadersInit = {
    'Content-Type': 'application/json',
    ...(csrfToken ? { 'X-CSRFToken': csrfToken } : {}),
  };

  const response = await fetch(url, {
    ...options,
    credentials: 'include', // IMPORTANTE: Envia cookies de sessão!
    headers: {
      ...defaultHeaders,
      ...options.headers,
    },
  });

  if (!response.ok) {
    // Tentar parsear erro como JSON
    let errorMessage = `HTTP ${response.status}`;
    try {
      const errorData = await response.json();
      errorMessage = errorData.detail || errorData.error || errorData.message || errorMessage;
    } catch (e) {
      // Se não for JSON, usar status text
      errorMessage = response.statusText || errorMessage;
    }
    throw new Error(errorMessage);
  }

  return response.json();
}

// Métodos HTTP convenientes
export const api = {
  get: <T>(url: string) => fetchApi<T>(url),
  
  post: <T>(url: string, data?: any) => fetchApi<T>(url, {
    method: 'POST',
    body: data ? JSON.stringify(data) : undefined,
  }),
  
  put: <T>(url: string, data: any) => fetchApi<T>(url, {
    method: 'PUT',
    body: JSON.stringify(data),
  }),
  
  patch: <T>(url: string, data: any) => fetchApi<T>(url, {
    method: 'PATCH',
    body: JSON.stringify(data),
  }),
  
  delete: <T>(url: string) => fetchApi<T>(url, {
    method: 'DELETE',
  }),
};

// Devices API
export const devicesApi = {
  list: () => api.get<any[]>('/api/equipments/'),
  
  dashboard: () => api.get<any>('/api/devices/dashboard'),
  
  get: (id: number) => api.get<{ device: any }>(`/api/equipments/${id}/`),
  
  create: (data: any) => api.post('/api/equipments/', data),
  
  update: (id: number, data: any) => api.patch(`/api/equipments/${id}/`, data),
  
  delete: (id: number) => api.delete(`/api/equipments/${id}/`),
  
  ping: (id: number) => api.post(`/api/devices/${id}/ping/`),
  
  discoverFromIP: (ip: string) => api.get(`/api/equipments/discover_from_ip/?ip=${ip}`),
  
  syncToLibreNMS: (id: number) => api.post(`/api/equipments/${id}/sync_to_librenms/`),
  
  syncToZabbix: (id: number) => api.post(`/api/equipments/${id}/sync_to_zabbix/`),
  
  syncAllLibreNMS: () => api.post('/api/equipments/sync_all/'),
};

// Health API
export const healthApi = {
  server: () => api.get<any>('/api/equipments/server_health/'),
};

// Monitoring API
export const monitoringApi = {
  allStatus: () => api.get<any>('/api/monitoring/all-status/'),
  summary: () => api.get<any>('/api/monitoring/summary/'),
  history: (id: number) => api.get<any>(`/api/monitoring/${id}/history/`),
};

export default { fetchApi, api };
