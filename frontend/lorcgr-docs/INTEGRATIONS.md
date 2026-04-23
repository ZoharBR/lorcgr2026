# Configuração de Integrações - LOR-CGR

## Visão Geral de Integrações

O LOR-CGR integra múltiplas aplicações através de APIs REST. Este documento detalha como cada integração funciona e como configurá-las.

---

## 1. LibreNMS Integration

### 1.1 Obter API Token

1. Acessar LibreNMS como admin
2. Ir em **Settings > API > Create API Token**
3. Definir descrição: "LOR-CGR Integration"
4. Copiar o token gerado

### 1.2 Endpoints Utilizados

```python
# Buscar todos os dispositivos
GET /api/v0/devices

# Buscar dispositivo específico
GET /api/v0/devices/{hostname}

# Buscar portas do dispositivo
GET /api/v0/devices/{hostname}/ports

# Buscar alerts
GET /api/v0/alerts

# Buscar health/bgp/ospf
GET /api/v0/devices/{hostname}/health
GET /api/v0/bgp
GET /api/v0/ospf
```

### 1.3 Configuração no Django

```python
# settings.py
LIBRENMS_URL = 'http://localhost/librenms/api/v0'
LIBRENMS_TOKEN = 'SEU_TOKEN_AQUI'

# integrations/librenms.py
import requests
from django.conf import settings

class LibreNMSClient:
    def __init__(self):
        self.base_url = settings.LIBRENMS_URL
        self.headers = {'X-Auth-Token': settings.LIBRENMS_TOKEN}
    
    def get_devices(self):
        response = requests.get(f'{self.base_url}/devices', headers=self.headers)
        return response.json().get('devices', [])
    
    def get_device(self, hostname):
        response = requests.get(f'{self.base_url}/devices/{hostname}', headers=self.headers)
        return response.json().get('devices', [{}])[0]
    
    def get_device_ports(self, hostname):
        response = requests.get(f'{self.base_url}/devices/{hostname}/ports', headers=self.headers)
        return response.json().get('ports', [])
```

---

## 2. Zabbix Integration

### 2.1 API JSON-RPC

Zabbix utiliza API JSON-RPC para todas as integrações.

### 2.2 Autenticação

```python
import requests
import json

class ZabbixClient:
    def __init__(self):
        self.url = settings.ZABBIX_URL
        self.user = settings.ZABBIX_USER
        self.password = settings.ZABBIX_PASSWORD
        self.auth_token = None
        self.login()
    
    def login(self):
        payload = {
            "jsonrpc": "2.0",
            "method": "user.login",
            "params": {
                "user": self.user,
                "password": self.password
            },
            "id": 1
        }
        response = requests.post(self.url, json=payload)
        self.auth_token = response.json().get('result')
    
    def get_hosts(self):
        payload = {
            "jsonrpc": "2.0",
            "method": "host.get",
            "params": {
                "output": ["hostid", "host", "name", "status"],
                "selectInterfaces": ["ip", "dns", "port"]
            },
            "auth": self.auth_token,
            "id": 2
        }
        response = requests.post(self.url, json=payload)
        return response.json().get('result', [])
    
    def get_items(self, hostid):
        payload = {
            "jsonrpc": "2.0",
            "method": "item.get",
            "params": {
                "output": ["itemid", "name", "key_", "lastvalue"],
                "hostids": hostid
            },
            "auth": self.auth_token,
            "id": 3
        }
        response = requests.post(self.url, json=payload)
        return response.json().get('result', [])
    
    def get_alerts(self):
        payload = {
            "jsonrpc": "2.0",
            "method": "alert.get",
            "params": {
                "output": "extend",
                "selectHosts": ["host", "name"]
            },
            "auth": self.auth_token,
            "id": 4
        }
        response = requests.post(self.url, json=payload)
        return response.json().get('result', [])
```

---

## 3. phpIPAM Integration

### 3.1 Criar API App

1. Acessar phpIPAM como admin
2. Ir em **Administration > API**
3. Criar novo App:
   - App ID: `lorcgr`
   - App Code: (gerar automaticamente)
   - Permissions: Read/Write

### 3.2 Endpoints

```python
class phpIPAMClient:
    def __init__(self):
        self.base_url = f'{settings.PHPIPAM_URL}/{settings.PHPIPAM_APP_ID}'
        self.app_code = settings.PHPIPAM_KEY
        self.token = None
        self.get_token()
    
    def get_token(self):
        response = requests.post(
            f'{self.base_url}/user/',
            headers={'phpipam-app-code': self.app_code}
        )
        self.token = response.json().get('data', {}).get('token')
    
    def get_sections(self):
        response = requests.get(
            f'{self.base_url}/sections/',
            headers={'phpipam-token': self.token}
        )
        return response.json().get('data', [])
    
    def get_subnets(self, section_id):
        response = requests.get(
            f'{self.base_url}/sections/{section_id}/subnets/',
            headers={'phpipam-token': self.token}
        )
        return response.json().get('data', [])
    
    def get_addresses(self, subnet_id):
        response = requests.get(
            f'{self.base_url}/subnets/{subnet_id}/addresses/',
            headers={'phpipam-token': self.token}
        )
        return response.json().get('data', [])
    
    def get_devices(self):
        response = requests.get(
            f'{self.base_url}/devices/',
            headers={'phpipam-token': self.token}
        )
        return response.json().get('data', [])
```

---

## 4. Grafana Integration

### 4.1 API Endpoints

```python
class GrafanaClient:
    def __init__(self):
        self.base_url = settings.GRAFANA_URL
        self.auth = (settings.GRAFANA_USER, settings.GRAFANA_PASSWORD)
    
    def get_dashboards(self):
        response = requests.get(
            f'{self.base_url}/api/search',
            auth=self.auth
        )
        return response.json()
    
    def get_dashboard(self, uid):
        response = requests.get(
            f'{self.base_url}/api/dashboards/uid/{uid}',
            auth=self.auth
        )
        return response.json()
    
    def create_dashboard(self, dashboard_json):
        response = requests.post(
            f'{self.base_url}/api/dashboards/db',
            auth=self.auth,
            json=dashboard_json
        )
        return response.json()
    
    def get_datasources(self):
        response = requests.get(
            f'{self.base_url}/api/datasources',
            auth=self.auth
        )
        return response.json()
```

---

## 5. Nexterm Integration

### 5.1 Terminal Integration

Nexterm é integrado via iframe no LOR-CGR para acesso SSH/RDP/VNC.

```typescript
// Frontend - Terminal Component
export function TerminalEmbed({ serverId }: { serverId: string }) {
  const nextermUrl = process.env.NEXT_PUBLIC_NEXTERM_URL;
  
  return (
    <iframe
      src={`${nextermUrl}/terminal/${serverId}`}
      className="w-full h-full border-0"
      allow="clipboard-read; clipboard-write"
    />
  );
}
```

### 5.2 API Nexterm (se disponível)

```python
class NextermClient:
    def __init__(self):
        self.base_url = settings.NEXTERM_URL
    
    def get_servers(self):
        # Nexterm pode ter API própria
        pass
    
    def create_server(self, server_data):
        # Criar configuração de servidor
        pass
```

---

## 6. GROQ AI Integration

### 6.1 Configuração

```python
# settings.py
GROQ_API_KEY = 'SUA_KEY_AQUI'
GROQ_MODEL = 'llama3-70b-8192'  # ou mixtral-8x7b-32768
```

### 6.2 Cliente GROQ

```python
import groq
from django.conf import settings

class GroqClient:
    def __init__(self):
        self.client = groq.Groq(api_key=settings.GROQ_API_KEY)
        self.model = settings.GROQ_MODEL
    
    def analyze_config(self, config_text, vendor, device_type):
        """Analisa configuração de equipamento"""
        prompt = f"""
        Você é um especialista em redes {vendor} para {device_type}.
        Analise a seguinte configuração e forneça:
        1. Resumo da configuração
        2. Problemas potenciais
        3. Recomendações de segurança
        4. Sugestões de otimização
        
        Configuração:
        ```
        {config_text}
        ```
        """
        
        response = self.client.chat.completions.create(
            model=self.model,
            messages=[{"role": "user", "content": prompt}],
            temperature=0.7,
            max_tokens=2000
        )
        
        return response.choices[0].message.content
    
    def suggest_fix(self, error_message, device_info):
        """Sugere correção baseada em erro"""
        prompt = f"""
        Um equipamento {device_info['vendor']} {device_info['type']} 
        apresentou o seguinte erro:
        
        {error_message}
        
        Sugira possíveis correções e comandos de diagnóstico.
        """
        
        response = self.client.chat.completions.create(
            model=self.model,
            messages=[{"role": "user", "content": prompt}],
            temperature=0.7
        )
        
        return response.choices[0].message.content
    
    def generate_backup_script(self, device_info):
        """Gera script de backup personalizado"""
        prompt = f"""
        Gere um script de backup para:
        - Vendor: {device_info['vendor']}
        - Tipo: {device_info['type']}
        - Modelo: {device_info['model']}
        - IP: {device_info['ip']}
        - Protocolo preferido: {device_info['protocol']}
        
        O script deve salvar configuração completa.
        """
        
        response = self.client.chat.completions.create(
            model=self.model,
            messages=[{"role": "user", "content": prompt}],
            temperature=0.7
        )
        
        return response.choices[0].message.content
```

---

## 7. Sincronização de Usuários

### 7.1 Criar Usuário em Todos os Apps

```python
class UserSyncService:
    """Sincroniza criação de usuários em todas as plataformas"""
    
    def create_user_all_platforms(self, username, password, email, role='VIEW'):
        results = {}
        
        # 1. Criar no Django (LOR-CGR)
        try:
            from django.contrib.auth.models import User
            user = User.objects.create_user(username, email, password)
            # Adicionar ao grupo correspondente
            results['lorcgr'] = {'success': True, 'id': user.id}
        except Exception as e:
            results['lorcgr'] = {'success': False, 'error': str(e)}
        
        # 2. Criar no LibreNMS
        try:
            # LibreNMS usa MySQL diretamente ou API
            results['librenms'] = self.create_librenms_user(username, password, email, role)
        except Exception as e:
            results['librenms'] = {'success': False, 'error': str(e)}
        
        # 3. Criar no Zabbix
        try:
            zabbix = ZabbixClient()
            # Criar usuário via API Zabbix
            results['zabbix'] = self.create_zabbix_user(zabbix, username, password)
        except Exception as e:
            results['zabbix'] = {'success': False, 'error': str(e)}
        
        # 4. Criar no phpIPAM
        try:
            # phpIPAM usa banco MySQL
            results['phpipam'] = self.create_phpipam_user(username, password, email)
        except Exception as e:
            results['phpipam'] = {'success': False, 'error': str(e)}
        
        # 5. Criar no Grafana
        try:
            grafana = GrafanaClient()
            results['grafana'] = self.create_grafana_user(grafana, username, password, email)
        except Exception as e:
            results['grafana'] = {'success': False, 'error': str(e)}
        
        return results
    
    def create_zabbix_user(self, zabbix_client, username, password):
        payload = {
            "jsonrpc": "2.0",
            "method": "user.create",
            "params": {
                "alias": username,
                "passwd": password,
                "usrgrps": [{"usrgrpid": "7"}],  # Zabbix users group
                "type": "1"  # Zabbix user type
            },
            "auth": zabbix_client.auth_token,
            "id": 1
        }
        response = requests.post(zabbix_client.url, json=payload)
        return {'success': True, 'response': response.json()}
    
    def create_grafana_user(self, grafana_client, username, password, email):
        response = requests.post(
            f'{grafana_client.base_url}/api/admin/users',
            auth=grafana_client.auth,
            json={
                "name": username,
                "email": email,
                "login": username,
                "password": password
            }
        )
        return {'success': response.status_code == 200}
```

---

## 8. Integração com Servidores Remotos

### 8.1 Configuração de Servidor Remoto

```python
# models.py
class RemoteServer(models.Model):
    name = models.CharField(max_length=100)
    server_type = models.CharField(choices=[
        ('librenms', 'LibreNMS'),
        ('zabbix', 'Zabbix'),
        ('phpipam', 'phpIPAM'),
        ('grafana', 'Grafana'),
        ('nexterm', 'Nexterm'),
    ])
    url = models.URLField()
    api_key = models.CharField(max_length=255, blank=True)
    username = models.CharField(max_length=100, blank=True)
    password = models.CharField(max_length=255, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    def get_client(self):
        """Retorna cliente apropriado para o tipo de servidor"""
        if self.server_type == 'librenms':
            return LibreNMSClient(self.url, self.api_key)
        elif self.server_type == 'zabbix':
            return ZabbixClient(self.url, self.username, self.password)
        elif self.server_type == 'phpipam':
            return phpIPAMClient(self.url, self.api_key)
        elif self.server_type == 'grafana':
            return GrafanaClient(self.url, self.username, self.password)
        return None
```

---

## 9. Mapas - Integração

### 9.1 Coleta de Localização

```python
class MapDataService:
    def get_all_device_locations(self):
        """Coleta localização de todos os equipamentos"""
        locations = []
        
        # De LibreNMS
        librenms = LibreNMSClient()
        devices = librenms.get_devices()
        for device in devices:
            if device.get('lat') and device.get('lng'):
                locations.append({
                    'source': 'librenms',
                    'name': device['hostname'],
                    'ip': device['ip'],
                    'lat': device['lat'],
                    'lng': device['lng'],
                    'status': device['status']
                })
        
        # De Zabbix
        zabbix = ZabbixClient()
        hosts = zabbix.get_hosts()
        for host in hosts:
            # Zabbix pode ter inventário com localização
            inventory = zabbix.get_host_inventory(host['hostid'])
            if inventory.get('location_lat') and inventory.get('location_lon'):
                locations.append({
                    'source': 'zabbix',
                    'name': host['name'],
                    'lat': inventory['location_lat'],
                    'lng': inventory['location_lon'],
                    'status': 'up' if host['status'] == '0' else 'down'
                })
        
        # De phpIPAM
        phpipam = phpIPAMClient()
        devices = phpipam.get_devices()
        for device in devices:
            if device.get('lat') and device.get('long'):
                locations.append({
                    'source': 'phpipam',
                    'name': device['hostname'],
                    'ip': device['ip'],
                    'lat': device['lat'],
                    'lng': device['long']
                })
        
        return locations
```

### 9.2 Frontend Map (Leaflet - Gratuito)

```typescript
// components/MapWidget.tsx
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';

export function MapWidget({ devices }: { devices: Device[] }) {
  return (
    <MapContainer
      center={[-15.7801, -47.9292]} // Brasil
      zoom={4}
      className="h-full w-full"
    >
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      {devices.map((device) => (
        <Marker
          key={device.id}
          position={[device.lat, device.lng]}
        >
          <Popup>
            <div>
              <strong>{device.name}</strong>
              <br />
              IP: {device.ip}
              <br />
              Status: {device.status}
            </div>
          </Popup>
        </Marker>
      ))}
    </MapContainer>
  );
}
```

---

**Documento em construção - Atualizado conforme desenvolvimento**
