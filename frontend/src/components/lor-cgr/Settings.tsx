'use client';

import { useState, useEffect } from 'react';
import {
  Save,
  RefreshCw,
  TestTube,
  CheckCircle,
  XCircle,
  Loader2,
  Settings as SettingsIcon,
  GitBranch,
  Upload,
  Download,
  Server,
  Key,
  Globe,
  Database,
  HardDrive,
  Clock,
  AlertTriangle,
  FileText,
  Cloud,
  Shield,
} from 'lucide-react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Badge } from '@/components/ui/badge';
import { Switch } from '@/components/ui/switch';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import SecuritySettings from './SecuritySettings';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Settings } from '@/types/lor-cgr';
import { toast } from 'sonner';

interface SettingsProps {
  loading: boolean;
  onRefresh: () => void;
  isAdmin?: boolean;
  defaultTab?: string;
}

const API_URL = 'http://45.71.242.131:8000/api/settings';

const backupFrequencies = [
  { value: 'hourly', label: 'A cada hora' },
  { value: 'daily', label: 'Diário' },
  { value: 'weekly', label: 'Semanal' },
  { value: 'monthly', label: 'Mensal' },
];

export default function SettingsComponent({ loading, onRefresh, isAdmin = true, defaultTab = 'apis' }: SettingsProps) {
  const [settings, setSettings] = useState<Settings>({});
  const [saving, setSaving] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [testingConnection, setTestingConnection] = useState<string | null>(null);

  // GitHub status
  const [gitStatus, setGitStatus] = useState<{
    branch?: string;
    remote?: string;
    ahead?: number;
    behind?: number;
    staged?: number;
    unstaged?: number;
  }>({});

  // Load settings
  const fetchSettings = async () => {
    setIsLoading(true);
    try {
      const response = await fetch(`${API_URL}/get/`);
      if (response.ok) {
        const data = await response.json();
        setSettings(data.settings || {});
      }
    } catch (error) {
      console.error('Error fetching settings:', error);
    }
    setIsLoading(false);
  };

  // Load git status
  const fetchGitStatus = async () => {
    try {
      const response = await fetch(`${API_URL}/git/status/`);
      if (response.ok) {
        const data = await response.json();
        setGitStatus(data);
      }
    } catch (error) {
      console.error('Error fetching git status:', error);
    }
  };

  useEffect(() => {
    fetchSettings();
    fetchGitStatus();
  }, []);

  // Save settings
  const handleSave = async () => {
    setSaving(true);
    try {
      const response = await fetch(`${API_URL}/save/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(settings),
      });

      if (response.ok) {
        toast.success('Configurações salvas com sucesso');
      } else {
        toast.error('Erro ao salvar configurações');
      }
    } catch (error) {
      toast.error('Erro de conexão');
    }
    setSaving(false);
  };

  // Test connection
  const testConnection = async (service: string) => {
    setTestingConnection(service);
    try {
      const response = await fetch(`${API_URL}/test/${service}/`, {
        method: 'POST',
      });

      const data = await response.json();
      if (data.success) {
        toast.success(`${service.toUpperCase()} conectado com sucesso`);
      } else {
        toast.error(data.error || `Erro ao conectar ${service.toUpperCase()}`);
      }
    } catch (error) {
      toast.error('Erro de conexão');
    }
    setTestingConnection(null);
  };

  // Git backup (push to GitHub)
  const handleGitBackup = async () => {
    setTestingConnection('github');
    try {
      const response = await fetch(`${API_URL}/git/backup/`, {
        method: 'POST',
      });

      const data = await response.json();
      if (data.success) {
        toast.success('Backup enviado para GitHub com sucesso');
        fetchGitStatus();
      } else {
        toast.error(data.error || 'Erro ao enviar backup');
      }
    } catch (error) {
      toast.error('Erro de conexão');
    }
    setTestingConnection(null);
  };

  // Git pull
  const handleGitPull = async () => {
    setTestingConnection('github-pull');
    try {
      const response = await fetch(`${API_URL}/git/pull/`, {
        method: 'POST',
      });

      const data = await response.json();
      if (data.success) {
        toast.success('Atualizado do GitHub com sucesso');
        fetchGitStatus();
      } else {
        toast.error(data.error || 'Erro ao atualizar');
      }
    } catch (error) {
      toast.error('Erro de conexão');
    }
    setTestingConnection(null);
  };

  // System backup
  const handleSystemBackup = async () => {
    setTestingConnection('system-backup');
    try {
      const response = await fetch(`${API_URL}/system/backup/`, {
        method: 'POST',
      });

      const data = await response.json();
      if (data.success) {
        toast.success('Backup do sistema iniciado');
      } else {
        toast.error(data.error || 'Erro ao iniciar backup');
      }
    } catch (error) {
      toast.error('Erro de conexão');
    }
    setTestingConnection(null);
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row gap-4 justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Configurações</h1>
          <p className="text-muted-foreground">
            Configurações do sistema LOR CGR e integrações
          </p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" onClick={() => { fetchSettings(); fetchGitStatus(); }} disabled={loading || isLoading}>
            <RefreshCw className={`h-4 w-4 mr-2 ${(loading || isLoading) ? 'animate-spin' : ''}`} />
            Atualizar
          </Button>
          {isAdmin && (
            <Button onClick={handleSave} disabled={saving}>
              {saving ? (
                <RefreshCw className="h-4 w-4 mr-2 animate-spin" />
              ) : (
                <Save className="h-4 w-4 mr-2" />
              )}
              Salvar
            </Button>
          )}
        </div>
      </div>

      <Tabs defaultValue={defaultTab} className="w-full">
        <TabsList className="grid w-full grid-cols-5">
          <TabsTrigger value="apis" className="gap-2">
            <Globe className="h-4 w-4" />
            APIs Externas
          </TabsTrigger>
          <TabsTrigger value="ai" className="gap-2">
            <Server className="h-4 w-4" />
            IA (Groq)
          </TabsTrigger>
          <TabsTrigger value="git" className="gap-2">
            <GitBranch className="h-4 w-4" />
            Git/Backup
          </TabsTrigger>
          <TabsTrigger value="ftp" className="gap-2">
            <Cloud className="h-4 w-4" />
            FTP
          </TabsTrigger>
          <TabsTrigger value="security" className="gap-2">
            <Shield className="h-4 w-4" />
            Segurança
          </TabsTrigger>
          <TabsTrigger value="system" className="gap-2">
            <Database className="h-4 w-4" />
            Sistema
          </TabsTrigger>
        </TabsList>

        {/* APIs Externas Tab */}
        <TabsContent value="apis" className="space-y-4 mt-4">
          {/* LibreNMS */}
          <Card>
            <CardHeader>
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Server className="h-5 w-5 text-blue-500" />
                  <CardTitle>LibreNMS</CardTitle>
                </div>
                <div className="flex items-center gap-2">
                  <Switch
                    checked={settings.librenms_enabled ?? false}
                    onCheckedChange={(checked) => setSettings({ ...settings, librenms_enabled: checked })}
                    disabled={!isAdmin}
                  />
                  <Badge variant={settings.librenms_enabled ? 'default' : 'secondary'}>
                    {settings.librenms_enabled ? 'Ativo' : 'Inativo'}
                  </Badge>
                </div>
              </div>
              <CardDescription>Sistema de monitoramento de rede</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="librenms_url">URL do LibreNMS</Label>
                  <Input
                    id="librenms_url"
                    value={settings.librenms_url || ''}
                    onChange={(e) => setSettings({ ...settings, librenms_url: e.target.value })}
                    placeholder="http://localhost:8081"
                    disabled={!isAdmin || !settings.librenms_enabled}
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="librenms_api_token">API Token</Label>
                  <Input
                    id="librenms_api_token"
                    type="password"
                    value={settings.librenms_api_token || ''}
                    onChange={(e) => setSettings({ ...settings, librenms_api_token: e.target.value })}
                    placeholder="••••••••••••"
                    disabled={!isAdmin || !settings.librenms_enabled}
                  />
                </div>
              </div>
              <Button
                variant="outline"
                onClick={() => testConnection('librenms')}
                disabled={!settings.librenms_enabled || testingConnection === 'librenms'}
              >
                {testingConnection === 'librenms' ? (
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                ) : (
                  <TestTube className="h-4 w-4 mr-2" />
                )}
                Testar Conexão
              </Button>
            </CardContent>
          </Card>

          {/* phpIPAM */}
          <Card>
            <CardHeader>
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Database className="h-5 w-5 text-green-500" />
                  <CardTitle>phpIPAM</CardTitle>
                </div>
                <div className="flex items-center gap-2">
                  <Switch
                    checked={settings.phpipam_enabled ?? false}
                    onCheckedChange={(checked) => setSettings({ ...settings, phpipam_enabled: checked })}
                    disabled={!isAdmin}
                  />
                  <Badge variant={settings.phpipam_enabled ? 'default' : 'secondary'}>
                    {settings.phpipam_enabled ? 'Ativo' : 'Inativo'}
                  </Badge>
                </div>
              </div>
              <CardDescription>Gerenciamento de endereços IP</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-3 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="phpipam_url">URL do phpIPAM</Label>
                  <Input
                    id="phpipam_url"
                    value={settings.phpipam_url || ''}
                    onChange={(e) => setSettings({ ...settings, phpipam_url: e.target.value })}
                    placeholder="http://localhost:9100"
                    disabled={!isAdmin || !settings.phpipam_enabled}
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="phpipam_app_id">App ID</Label>
                  <Input
                    id="phpipam_app_id"
                    value={settings.phpipam_app_id || ''}
                    onChange={(e) => setSettings({ ...settings, phpipam_app_id: e.target.value })}
                    placeholder="lorcgr"
                    disabled={!isAdmin || !settings.phpipam_enabled}
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="phpipam_api_key">API Key</Label>
                  <Input
                    id="phpipam_api_key"
                    type="password"
                    value={settings.phpipam_api_key || ''}
                    onChange={(e) => setSettings({ ...settings, phpipam_api_key: e.target.value })}
                    placeholder="••••••••"
                    disabled={!isAdmin || !settings.phpipam_enabled}
                  />
                </div>
              </div>
              <Button
                variant="outline"
                onClick={() => testConnection('phpipam')}
                disabled={!settings.phpipam_enabled || testingConnection === 'phpipam'}
              >
                {testingConnection === 'phpipam' ? (
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                ) : (
                  <TestTube className="h-4 w-4 mr-2" />
                )}
                Testar Conexão
              </Button>
            </CardContent>
          </Card>

          {/* Zabbix */}
          <Card>
            <CardHeader>
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Server className="h-5 w-5 text-red-500" />
                  <CardTitle>Zabbix</CardTitle>
                </div>
                <div className="flex items-center gap-2">
                  <Switch
                    checked={settings.zabbix_enabled ?? false}
                    onCheckedChange={(checked) => setSettings({ ...settings, zabbix_enabled: checked })}
                    disabled={!isAdmin}
                  />
                  <Badge variant={settings.zabbix_enabled ? 'default' : 'secondary'}>
                    {settings.zabbix_enabled ? 'Ativo' : 'Inativo'}
                  </Badge>
                </div>
              </div>
              <CardDescription>Monitoramento de infraestrutura</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-3 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="zabbix_url">URL do Zabbix</Label>
                  <Input
                    id="zabbix_url"
                    value={settings.zabbix_url || ''}
                    onChange={(e) => setSettings({ ...settings, zabbix_url: e.target.value })}
                    placeholder="http://localhost:8082"
                    disabled={!isAdmin || !settings.zabbix_enabled}
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="zabbix_user">Usuário</Label>
                  <Input
                    id="zabbix_user"
                    value={settings.zabbix_user || ''}
                    onChange={(e) => setSettings({ ...settings, zabbix_user: e.target.value })}
                    placeholder="Admin"
                    disabled={!isAdmin || !settings.zabbix_enabled}
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="zabbix_password">Senha</Label>
                  <Input
                    id="zabbix_password"
                    type="password"
                    value={settings.zabbix_password || ''}
                    onChange={(e) => setSettings({ ...settings, zabbix_password: e.target.value })}
                    placeholder="••••••••"
                    disabled={!isAdmin || !settings.zabbix_enabled}
                  />
                </div>
              </div>
              <Button
                variant="outline"
                onClick={() => testConnection('zabbix')}
                disabled={!settings.zabbix_enabled || testingConnection === 'zabbix'}
              >
                {testingConnection === 'zabbix' ? (
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                ) : (
                  <TestTube className="h-4 w-4 mr-2" />
                )}
                Testar Conexão
              </Button>
            </CardContent>
          </Card>

          {/* IXC Provedor */}
          <Card>
            <CardHeader>
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Globe className="h-5 w-5 text-purple-500" />
                  <CardTitle>IXC Provedor</CardTitle>
                </div>
                <div className="flex items-center gap-2">
                  <Switch
                    checked={settings.ixc_enabled ?? false}
                    onCheckedChange={(checked) => setSettings({ ...settings, ixc_enabled: checked })}
                    disabled={!isAdmin}
                  />
                  <Badge variant={settings.ixc_enabled ? 'default' : 'secondary'}>
                    {settings.ixc_enabled ? 'Ativo' : 'Inativo'}
                  </Badge>
                </div>
              </div>
              <CardDescription>Sistema de gestão de provedores</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="ixc_url">URL do IXC</Label>
                  <Input
                    id="ixc_url"
                    value={settings.ixc_url || ''}
                    onChange={(e) => setSettings({ ...settings, ixc_url: e.target.value })}
                    placeholder="https://seuixc.com.br"
                    disabled={!isAdmin || !settings.ixc_enabled}
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="ixc_token">Token de Acesso</Label>
                  <Input
                    id="ixc_token"
                    type="password"
                    value={settings.ixc_token || ''}
                    onChange={(e) => setSettings({ ...settings, ixc_token: e.target.value })}
                    placeholder="••••••••"
                    disabled={!isAdmin || !settings.ixc_enabled}
                  />
                </div>
              </div>
              <Button
                variant="outline"
                onClick={() => testConnection('ixc')}
                disabled={!settings.ixc_enabled || testingConnection === 'ixc'}
              >
                {testingConnection === 'ixc' ? (
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                ) : (
                  <TestTube className="h-4 w-4 mr-2" />
                )}
                Testar Conexão
              </Button>
            </CardContent>
          </Card>
        </TabsContent>

        {/* AI Tab */}
        <TabsContent value="ai" className="space-y-4 mt-4">
          <Card>
            <CardHeader>
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Server className="h-5 w-5 text-orange-500" />
                  <CardTitle>Groq AI</CardTitle>
                </div>
                <div className="flex items-center gap-2">
                  <Switch
                    checked={settings.groq_enabled ?? false}
                    onCheckedChange={(checked) => setSettings({ ...settings, groq_enabled: checked })}
                    disabled={!isAdmin}
                  />
                  <Badge variant={settings.groq_enabled ? 'default' : 'secondary'}>
                    {settings.groq_enabled ? 'Ativo' : 'Inativo'}
                  </Badge>
                </div>
              </div>
              <CardDescription>Integração com IA para análise e automação</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="groq_api_key">API Key</Label>
                  <Input
                    id="groq_api_key"
                    type="password"
                    value={settings.groq_api_key || ''}
                    onChange={(e) => setSettings({ ...settings, groq_api_key: e.target.value })}
                    placeholder="gsk_••••••••"
                    disabled={!isAdmin || !settings.groq_enabled}
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="groq_model">Modelo</Label>
                  <Select
                    value={settings.groq_model || 'llama-3.3-70b-versatile'}
                    onValueChange={(value) => setSettings({ ...settings, groq_model: value })}
                    disabled={!isAdmin || !settings.groq_enabled}
                  >
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="llama-3.3-70b-versatile">Llama 3.3 70B Versatile</SelectItem>
                      <SelectItem value="llama-3.1-70b-versatile">Llama 3.1 70B Versatile</SelectItem>
                      <SelectItem value="llama-3.1-8b-instant">Llama 3.1 8B Instant</SelectItem>
                      <SelectItem value="mixtral-8x7b-32768">Mixtral 8x7B</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>
              <Button
                variant="outline"
                onClick={() => testConnection('groq')}
                disabled={!settings.groq_enabled || testingConnection === 'groq'}
              >
                {testingConnection === 'groq' ? (
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                ) : (
                  <TestTube className="h-4 w-4 mr-2" />
                )}
                Testar Conexão
              </Button>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Git/Backup Tab */}
        <TabsContent value="git" className="space-y-4 mt-4">
          <Card>
            <CardHeader>
              <div className="flex items-center gap-2">
                <GitBranch className="h-5 w-5 text-gray-500" />
                <CardTitle>Backup no GitHub</CardTitle>
              </div>
              <CardDescription>Configure o repositório para backup automático do código</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="github_token">GitHub Token (PAT)</Label>
                  <Input
                    id="github_token"
                    type="password"
                    value={settings.github_token || ''}
                    onChange={(e) => setSettings({ ...settings, github_token: e.target.value })}
                    placeholder="ghp_••••••••"
                    disabled={!isAdmin}
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="github_repo">Repositório</Label>
                  <Input
                    id="github_repo"
                    value={settings.github_repo || ''}
                    onChange={(e) => setSettings({ ...settings, github_repo: e.target.value })}
                    placeholder="usuario/lor-cgr-backup"
                    disabled={!isAdmin}
                  />
                </div>
              </div>
              <div className="grid grid-cols-3 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="github_branch">Branch</Label>
                  <Input
                    id="github_branch"
                    value={settings.github_branch || 'main'}
                    onChange={(e) => setSettings({ ...settings, github_branch: e.target.value })}
                    placeholder="main"
                    disabled={!isAdmin}
                  />
                </div>
                <div className="space-y-2">
                  <Label>Backup Automático</Label>
                  <div className="flex items-center gap-2">
                    <Switch
                      checked={settings.auto_backup_enabled ?? false}
                      onCheckedChange={(checked) => setSettings({ ...settings, auto_backup_enabled: checked })}
                      disabled={!isAdmin}
                    />
                    <span className="text-sm">{settings.auto_backup_enabled ? 'Ativo' : 'Inativo'}</span>
                  </div>
                </div>
                <div className="space-y-2">
                  <Label>Frequência</Label>
                  <Select
                    value={settings.backup_frequency || 'daily'}
                    onValueChange={(value) => setSettings({ ...settings, backup_frequency: value })}
                    disabled={!isAdmin}
                  >
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {backupFrequencies.map((f) => (
                        <SelectItem key={f.value} value={f.value}>{f.label}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </div>

              {/* Git Status */}
              {gitStatus.branch && (
                <div className="p-4 bg-muted rounded-lg">
                  <div className="flex items-center justify-between mb-2">
                    <span className="font-medium">Status do Git</span>
                    <Badge variant="outline">{gitStatus.branch}</Badge>
                  </div>
                  <div className="grid grid-cols-4 gap-4 text-sm">
                    <div>
                      <span className="text-muted-foreground">Remote:</span>
                      <p className="font-mono text-xs truncate">{gitStatus.remote || '-'}</p>
                    </div>
                    <div>
                      <span className="text-muted-foreground">Ahead:</span>
                      <p className={gitStatus.ahead ? 'text-green-500' : ''}>{gitStatus.ahead || 0}</p>
                    </div>
                    <div>
                      <span className="text-muted-foreground">Behind:</span>
                      <p className={gitStatus.behind ? 'text-yellow-500' : ''}>{gitStatus.behind || 0}</p>
                    </div>
                    <div>
                      <span className="text-muted-foreground">Changes:</span>
                      <p className={(gitStatus.staged || gitStatus.unstaged) ? 'text-orange-500' : ''}>
                        {(gitStatus.staged || 0) + (gitStatus.unstaged || 0)}
                      </p>
                    </div>
                  </div>
                </div>
              )}

              <div className="flex gap-2">
                <Button
                  variant="outline"
                  onClick={handleGitPull}
                  disabled={testingConnection === 'github-pull'}
                >
                  {testingConnection === 'github-pull' ? (
                    <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                  ) : (
                    <Download className="h-4 w-4 mr-2" />
                  )}
                  Pull do GitHub
                </Button>
                <Button
                  onClick={handleGitBackup}
                  disabled={testingConnection === 'github'}
                >
                  {testingConnection === 'github' ? (
                    <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                  ) : (
                    <Upload className="h-4 w-4 mr-2" />
                  )}
                  Fazer Backup (Push)
                </Button>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* FTP Tab */}
        <TabsContent value="ftp" className="space-y-4 mt-4">
          <Card>
            <CardHeader>
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Cloud className="h-5 w-5 text-cyan-500" />
                  <CardTitle>Servidor FTP</CardTitle>
                </div>
                <div className="flex items-center gap-2">
                  <Switch
                    checked={settings.ftp_enabled ?? false}
                    onCheckedChange={(checked) => setSettings({ ...settings, ftp_enabled: checked })}
                    disabled={!isAdmin}
                  />
                  <Badge variant={settings.ftp_enabled ? 'default' : 'secondary'}>
                    {settings.ftp_enabled ? 'Ativo' : 'Inativo'}
                  </Badge>
                </div>
              </div>
              <CardDescription>Servidor FTP para armazenamento de backups</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="ftp_host">Host</Label>
                  <Input
                    id="ftp_host"
                    value={settings.ftp_host || ''}
                    onChange={(e) => setSettings({ ...settings, ftp_host: e.target.value })}
                    placeholder="ftp.seuservidor.com"
                    disabled={!isAdmin || !settings.ftp_enabled}
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="ftp_port">Porta</Label>
                  <Input
                    id="ftp_port"
                    type="number"
                    value={settings.ftp_port || 21}
                    onChange={(e) => setSettings({ ...settings, ftp_port: parseInt(e.target.value) })}
                    disabled={!isAdmin || !settings.ftp_enabled}
                  />
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="ftp_user">Usuário</Label>
                  <Input
                    id="ftp_user"
                    value={settings.ftp_user || ''}
                    onChange={(e) => setSettings({ ...settings, ftp_user: e.target.value })}
                    placeholder="backup_user"
                    disabled={!isAdmin || !settings.ftp_enabled}
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="ftp_password">Senha</Label>
                  <Input
                    id="ftp_password"
                    type="password"
                    value={settings.ftp_password || ''}
                    onChange={(e) => setSettings({ ...settings, ftp_password: e.target.value })}
                    placeholder="••••••••"
                    disabled={!isAdmin || !settings.ftp_enabled}
                  />
                </div>
              </div>
              <Button
                variant="outline"
                onClick={() => testConnection('ftp')}
                disabled={!settings.ftp_enabled || testingConnection === 'ftp'}
              >
                {testingConnection === 'ftp' ? (
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                ) : (
                  <TestTube className="h-4 w-4 mr-2" />
                )}
                Testar Conexão FTP
              </Button>
            </CardContent>
          </Card>
        </TabsContent>

        {/* System Tab */}
        <TabsContent value="system" className="space-y-4 mt-4">
          <Card>
            <CardHeader>
              <div className="flex items-center gap-2">
                <HardDrive className="h-5 w-5 text-amber-500" />
                <CardTitle>Backup do Sistema</CardTitle>
              </div>
              <CardDescription>Backup completo do servidor incluindo bancos de dados</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid gap-4 md:grid-cols-2">
                <div className="p-4 border rounded-lg">
                  <h4 className="font-medium mb-2 flex items-center gap-2">
                    <Database className="h-4 w-4" />
                    Componentes Incluídos
                  </h4>
                  <ul className="text-sm text-muted-foreground space-y-1">
                    <li>✓ LOR CGR (código + banco de dados)</li>
                    <li>✓ LibreNMS (configurações + dados)</li>
                    <li>✓ phpIPAM (banco de dados)</li>
                    <li>✓ Zabbix (configurações + banco)</li>
                    <li>✓ Grafana (dashboards)</li>
                    <li>✓ Arquivos de configuração</li>
                  </ul>
                </div>
                <div className="p-4 border rounded-lg">
                  <h4 className="font-medium mb-2 flex items-center gap-2">
                    <FileText className="h-4 w-4" />
                    Formato do Backup
                  </h4>
                  <ul className="text-sm text-muted-foreground space-y-1">
                    <li>• Arquivo .tar.gz compactado</li>
                    <li>• Nome com data e hora</li>
                    <li>• Arquivo README.txt incluído</li>
                    <li>• Logs de backup registrados</li>
                  </ul>
                </div>
              </div>

              <div className="flex gap-2">
                <Button
                  onClick={handleSystemBackup}
                  disabled={testingConnection === 'system-backup'}
                  className="flex-1"
                >
                  {testingConnection === 'system-backup' ? (
                    <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                  ) : (
                    <HardDrive className="h-4 w-4 mr-2" />
                  )}
                  Executar Backup Completo
                </Button>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <div className="flex items-center gap-2">
                <Upload className="h-5 w-5 text-green-500" />
                <CardTitle>Restaurar Backup</CardTitle>
              </div>
              <CardDescription>Restaure o sistema a partir de um backup anterior</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="p-4 bg-yellow-500/10 border border-yellow-500/20 rounded-lg flex items-start gap-3">
                <AlertTriangle className="h-5 w-5 text-yellow-500 mt-0.5" />
                <div>
                  <h4 className="font-medium text-yellow-600">Atenção</h4>
                  <p className="text-sm text-muted-foreground">
                    A restauração substituirá os dados atuais. Faça um backup antes de restaurar.
                  </p>
                </div>
              </div>

              <div className="grid gap-4 md:grid-cols-2">
                <div className="space-y-2">
                  <Label>Selecionar Backup</Label>
                  <Input type="file" accept=".tar.gz,.zip" disabled={!isAdmin} />
                </div>
                <div className="space-y-2">
                  <Label>Componente a Restaurar</Label>
                  <Select disabled={!isAdmin}>
                    <SelectTrigger>
                      <SelectValue placeholder="Selecione" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">Sistema Completo</SelectItem>
                      <SelectItem value="lorcgr">Apenas LOR CGR</SelectItem>
                      <SelectItem value="librenms">Apenas LibreNMS</SelectItem>
                      <SelectItem value="phpipam">Apenas phpIPAM</SelectItem>
                      <SelectItem value="zabbix">Apenas Zabbix</SelectItem>
                      <SelectItem value="grafana">Apenas Grafana</SelectItem>
                      <SelectItem value="database">Apenas Banco de Dados</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>

              <Button variant="outline" disabled={!isAdmin}>
                <Upload className="h-4 w-4 mr-2" />
                Restaurar Backup
              </Button>
            </CardContent>
          </Card>
        </TabsContent>
        <TabsContent value="security" className="space-y-4 mt-4">
          <SecuritySettings isAdmin={isAdmin} />
        </TabsContent>
      </Tabs>
    </div>
  );
}
