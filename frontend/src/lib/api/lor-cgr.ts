// LOR CGR API Client
const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000';

async function fetchApi(endpoint: string, options: RequestInit = {}): Promise<any> {
    const url = `${API_BASE_URL}${endpoint}`;

    const getCsrfToken = (): string => {
        if (typeof document === 'undefined') return '';
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
        credentials: 'include',
        headers: {
            ...defaultHeaders,
            ...options.headers,
        },
    });

    if (!response.ok) {
        let errorMessage = `HTTP ${response.status}`;
        try {
            const errorData = await response.json();
            errorMessage = errorData.detail || errorData.error || errorData.message || errorMessage;
        } catch (e) {
            errorMessage = response.statusText || errorMessage;
        }
        throw new Error(errorMessage);
    }

    return response.json();
}

export const api = {
    get: (url: string) => fetchApi(url),
    post: (url: string, data?: any) => fetchApi(url, {
        method: 'POST',
        body: data ? JSON.stringify(data) : undefined,
    }),
    put: (url: string, data: any) => fetchApi(url, {
        method: 'PUT',
        body: JSON.stringify(data),
    }),
    patch: (url: string, data: any) => fetchApi(url, {
        method: 'PATCH',
        body: JSON.stringify(data),
    }),
    delete: (url: string) => fetchApi(url, {
        method: 'DELETE',
    }),
};

export const devicesApi = {
    list: () => api.get('/api/equipments/'),
    dashboard: () => api.get('/api/devices/dashboard/'),
    get: (id: number) => api.get(`/api/equipments/${id}/`),
    create: (data: any) => api.post('/api/equipments/', data),
    update: (id: number, data: any) => api.patch(`/api/equipments/${id}/`, data),
    delete: (id: number) => api.delete(`/api/equipments/${id}/`),
    ping: (id: number) => api.post(`/api/devices/${id}/ping/`),
};

export const monitoringApi = {
    allStatus: () => api.get('/api/monitoring/all-status/'),
    summary: () => api.get('/api/monitoring/summary/'),
    history: (id: number) => api.get(`/api/monitoring/${id}/history/`),
};

export default { fetchApi, api };
