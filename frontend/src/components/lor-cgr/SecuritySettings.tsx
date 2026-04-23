'use client';

import { useState, useEffect } from 'react';
import {
  Shield,
  Globe,
  Lock,
  Unlock,
  Save,
  RefreshCw,
  CheckCircle,
  AlertTriangle,
  Info,
  Power,
  Upload,
  Download,
  Trash2,
  Database,
  Server,
  HardDrive,
  FileText,
  Clock
} from 'lucide-react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';
import { Badge } from '@/components/ui/badge';
import { Switch } from '@/components/ui/switch';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { toast } from 'sonner';

const SECURITY_API_URL = 'http://45.71.242.131:8000/api/security-configs/';
const BACKUP_API_URL = 'http://45.71.242.131:8000/api/backup/';

interface SecurityConfigData {
  id?: number;
  config_type: string;
  value: string;
  is_active: boolean;
  description: string;
}

interface BackupFile {
  name: string;
  size: string;
  date: string;
  type: 'postgresql' | 'frontend' | 'backend' | 'configs' | 'manifest';
}

export default function SecuritySettings({ isAdmin = true }: { isAdmin?: boolean }) {
  // Estados de Configurações de Segurança
  const [corsConfig, setCorsConfig] = useState<SecurityConfigData>({
    config_type: 'cors', value: '', is_active: false, description: ''
  });
  const [hostsConfig, setHostsConfig] = useState<SecurityConfigData>({
    config_type: 'allowed_hosts', value: '', is_active: false, description: ''
  });

  // Estados gerais
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState<string | null>(null);
  
  // Estados de Restart
  const [restartingDjango, setRestartingDjango] = useState(false);
  const [restartingNextjs, setRestartingNextjs] = useState(false);
  
  // Estados de Backup
  const [backups, setBackups] = useState<BackupFile[]>([]);
  const [loadingBackups, setLoadingBackups] = useState(false);
  const [backupInProgress, setBackupInProgress] = useState(false);
  
  // Estado de Restore
  const [restoreFile, setRestoreFile] = useState<string>('');

  // Carregar configurações de segurança
  const fetchSecurityConfigs = async () => {
    setLoading(true);
    try {
      const response = await fetch(SECURITY_API_URL);
      if (response.ok) {
        const data = await response.json();
        const cors = data.find((c: SecurityConfigData) => c.config_type === 'cors');
        if (cors) setCorsConfig(cors);
        const hosts = data.find((c: SecurityConfigData) => c.config_type === 'allowed_hosts');
        if (hosts) setHostsConfig(hosts);
      }
    } catch (error) {
      console.error('Erro ao carregar configs:', error);
      toast.error('Erro ao carregar configurações');
    }
    setLoading(false);
  };

  // Carregar lista de backups
  const fetchBackups = async () => {
    setLoadingBackups(true);
    try {
      const response = await fetch('/api/backups');
      if (response.ok) {
        const data = await response.json();
        setBackups(data.files || []);
      }
    } catch (error) {
      console.error('Erro ao carregar backups:', error);
    }
    setLoadingBackups(false);
  };

  useEffect(() => {
    fetchSecurityConfigs();
    fetchBackups();
  }, []);

  // Salvar configuração
  const saveConfig = async (config: SecurityConfigData, type: 'cors' | 'hosts') => {
    setSaving(type);
    try {
      const url = config.id ? `${SECURITY_API_URL}${config.id}/` : SECURITY_API_URL;
      const method = config.id ? 'PUT' : 'POST';
      
      const response = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(config),
      });

      if (response.ok) {
        const data = await response.json();
        if (type === 'cors') setCorsConfig(data);
        else setHostsConfig(data);
        toast.success(`${type === 'cors' ? 'CORS' : 'Allowed Hosts'} salvo!`);
      } else {
        toast.error('Erro ao salvar');
      }
    } catch (error) {
      console.error('Erro:', error);
      toast.error('Erro de conexão');
    }
    setSaving(null);
  };

  // Reiniciar Django
  const restartDjango = async () => {
    setRestartingDjango(true);
    try {
      const response = await fetch('/api/restart/django', { method: 'POST' });
      if (response.ok) {
        toast.success('Django reiniciado!');
      } else {
        toast.error('Erro ao reiniciar Django');
      }
    } catch (error) {
      toast.error('Erro de conexão');
    }
    setTimeout(() => setRestartingDjango(false), 3000);
  };

  // Reiniciar Next.js
  const restartNextjs = async () => {
    setRestartingNextjs(true);
    try {
      const response = await fetch('/api/restart/nextjs', { method: 'POST' });
      if (response.ok) {
        toast.success('Next.js reiniciado! A página vai recarregar...');
        setTimeout(() => window.location.reload(), 3000);
      } else {
        toast.error('Erro ao reiniciar Next.js');
      }
    } catch (error) {
      toast.error('Erro de conexão');
    }
    setTimeout(() => setRestartingNextjs(false), 5000);
  };

  // Fazer backup agora
  const createBackup = async () => {
    setBackupInProgress(true);
    try {
      const response = await fetch('/api/backup/create', { method: 'POST' });
      if (response.ok) {
        const data = await response.json();
        toast.success(`Backup criado: ${data.message}`);
        fetchBackups(); // Atualizar lista
      } else {
        toast.error('Erro ao criar backup');
      }
    } catch (error) {
      toast.error('Erro de conexão');
    }
    setBackupInProgress(false);
  };

  // Deletar backup
  const deleteBackup = async (filename: string) => {
    if (!confirm(`Tem certeza que deseja deletar ${filename}?`)) return;
    
    try {
      const response = await fetch(`/api/backup/delete/${filename}`, { method: 'DELETE' });
      if (response.ok) {
        toast.success('Backup deletado!');
        fetchBackups();
      } else {
        toast.error('Erro ao deletar');
      }
    } catch (error) {
      toast.error('Erro de conexão');
    }
  };

  // Download backup
  const downloadBackup = (filename: string) => {
    window.open(`/api/backup/download/${filename}`, '_blank');
  };

  // Restaurar backup
  const restoreBackup = async (filename: string) => {
    if (!confirm(`ATENÇÃO: Restaurar ${filename} vai substituir os dados atuais! Continuar?`)) return;
    
    try {
      const response = await fetch('/api/backup/restore', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ filename })
      });
      
      if (response.ok) {
        toast.success('Restauração iniciada! Pode levar alguns minutos...');
      } else {
        const error = await response.json();
        toast.error(`Erro: ${error.message}`);
      }
    } catch (error) {
      toast.error('Erro de conexão');
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center p-8">
        <RefreshCw className="h-6 w-6 animate-spin" />
        <span className="ml-2">Carregando...</span>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header Principal */}
      <Card className="border-orange-200 bg-gradient-to-r from-orange-50 to-red-50">
        <CardContent className="pt-6">
          <div className="flex items-center gap-3">
            <Shield className="h-8 w-8 text-orange-600" />
            <div>
              <h2 className="text-xl font-bold text-orange-900">Painel de Segurança & Backup</h2>
              <p className="text-sm text-orange-700 mt-1">Gerencie segurança, serviços e backups do sistema LOR-CGR</p>
            </div>
          </div>
        </CardContent>
      </Card>

      <Tabs defaultValue="security" className="w-full">
        <TabsList className="grid w-full grid-cols-3">
          <TabsTrigger value="security" className="gap-2">
            <Shield className="h-4 w-4" /> Segurança
          </TabsTrigger>
          <TabsTrigger value="services" className="gap-2">
            <Server className="h-4 w-4" /> Serviços
          </TabsTrigger>
          <TabsTrigger value="backup" className="gap-2">
            <HardDrive className="h-4 w-4" /> Backup
          </TabsTrigger>
        </TabsList>

        {/* ==================== TAB 1: SEGURANÇA ==================== */}
        <TabsContent value="security" className="space-y-6 mt-4">
          
          {/* CORS - Estilo Webmin */}
          <Card>
            <CardHeader>
              <div className="flex items-center justify-between flex-wrap gap-2">
                <div className="flex items-center gap-2">
                  <Globe className="h-5 w-5 text-blue-600" />
                  <CardTitle className="text-lg">CORS - Origens Permitidas</CardTitle>
                </div>
                <div className="flex items-center gap-3">
                  <Badge variant={corsConfig.is_active ? "default" : "secondary"} 
                        className={corsConfig.is_active ? "bg-green-600" : "bg-yellow-100 text-yellow-800"}>
                    {corsConfig.is_active ? "🔒 Ativo" : "🔓 Modo Dev"}
                  </Badge>
                  <Switch checked={corsConfig.is_active} 
                          onCheckedChange={(v) => setCorsConfig({...corsConfig, is_active: v})}
                          disabled={!isAdmin} />
                </div>
              </div>
              <CardDescription>
                Edite as origens permitidas para acessar a API. Uma origem por linha.
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div>
                <Label className="text-sm font-medium mb-2 flex items-center gap-2">
                  <Database className="h-4 w-4" /> Origens CORS (uma por linha):
                </Label>
                <Textarea
                  value={corsConfig.value}
                  onChange={(e) => setCorsConfig({...corsConfig, value: e.target.value})}
                  placeholder={"http://localhost:3000\nhttp://45.71.242.131:3000\nhttps://seu-dominio.com"}
                  className="min-h-[120px] font-mono text-sm"
                  disabled={!isAdmin}
                />
              </div>
              
              <div className="flex gap-2">
                <Button 
                  onClick={() => saveConfig(corsConfig, 'cors')} 
                  disabled={saving === 'cors' || !isAdmin}
                  className="flex-1"
                >
                  {saving === 'cors' ? <><RefreshCw className="h-4 w-4 mr-2 animate-spin" /> Salvando...</> 
                                        : <><Save className="h-4 w-4 mr-2" /> Salvar CORS</>}
                </Button>
              </div>

              <div className="bg-blue-50 border border-blue-200 rounded p-3 text-xs text-blue-800">
                <strong>💡 Dica:</strong> Em modo desenvolvimento (inativo), qualquer origem pode acessar. 
                Ative em produção e adicione apenas seus domínios.
              </div>
            </CardContent>
          </Card>

          {/* Allowed Hosts - Estilo Webmin */}
          <Card>
            <CardHeader>
              <div className="flex items-center justify-between flex-wrap gap-2">
                <div className="flex items-center gap-2">
                  <Lock className="h-5 w-5 text-purple-600" />
                  <CardTitle className="text-lg">Allowed Hosts</CardTitle>
                </div>
                <div className="flex items-center gap-3">
                  <Badge variant={hostsConfig.is_active ? "default" : "secondary"} 
                        className={hostsConfig.is_active ? "bg-green-600" : "bg-yellow-100 text-yellow-800"}>
                    {hostsConfig.is_active ? "🔒 Ativo" : "🔓 Modo Dev"}
                  </Badge>
                  <Switch checked={hostsConfig.is_active} 
                          onCheckedChange={(v) => setHostsConfig({...hostsConfig, is_active: v})}
                          disabled={!isAdmin} />
                </div>
              </div>
              <CardDescription>
                Domínios e IPs que podem acessar o sistema. Um por linha.
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div>
                <Label className="text-sm font-medium mb-2 flex items-center gap-2">
                  <Globe className="h-4 w-4" /> Hosts Permitidos (um por linha):
                </Label>
                <Textarea
                  value={hostsConfig.value}
                  onChange={(e) => setHostsConfig({...hostsConfig, value: e.target.value})}
                  placeholder={"45.71.242.131\nlocalhost\n127.0.0.1\n192.168.1.0/24\napp.lorcgr.com.br"}
                  className="min-h-[120px] font-mono text-sm"
                  disabled={!isAdmin}
                />
              </div>
              
              <div className="flex gap-2">
                <Button 
                  onClick={() => saveConfig(hostsConfig, 'hosts')} 
                  disabled={saving === 'hosts' || !isAdmin}
                  className="flex-1"
                >
                  {saving === 'hosts' ? <><RefreshCw className="h-4 w-4 mr-2 animate-spin" /> Salvando...</> 
                                        : <><Save className="h-4 w-4 mr-2" /> Salvar Hosts</>}
                </Button>
              </div>

              <div className="bg-purple-50 border border-purple-200 rounded p-3 text-xs text-purple-800">
                <strong>⚠️ Importante:</strong> Após alterar, reinicie os serviços na aba "Serviços".
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* ==================== TAB 2: SERVIÇOS ==================== */}
        <TabsContent value="services" className="space-y-6 mt-4">
          
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Power className="h-5 w-5 text-red-600" /> Reiniciar Serviços
              </CardTitle>
              <CardDescription>
                Reinicie os serviços para aplicar alterações de configuração.
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              {/* Django/Gunicorn */}
              <div className="border rounded-lg p-4 space-y-3">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <Server className="h-8 w-8 text-blue-600 bg-blue-100 p-2 rounded-lg" />
                    <div>
                      <h3 className="font-semibold">Backend Django (API)</h3>
                      <p className="text-sm text-gray-500">Porta 8000 • Gunicorn</p>
                    </div>
                  </div>
                  <Button 
                    onClick={restartDjango}
                    disabled={restartingDjango || !isAdmin}
                    variant={restartingDjango ? "default" : "outline"}
                    className={restartingDjango ? "bg-yellow-500 hover:bg-yellow-600" : ""}
                  >
                    {restartingDjango ? <><RefreshCw className="h-4 w-4 mr-2 animate-spin" /> Reiniciando...</> 
                                      : <><Power className="h-4 w-4 mr-2" /> Reiniciar Django</>}
                  </Button>
                </div>
              </div>

              {/* Next.js */}
              <div className="border rounded-lg p-4 space-y-3">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <Globe className="h-8 w-8 text-green-600 bg-green-100 p-2 rounded-lg" />
                    <div>
                      <h3 className="font-semibold">Frontend Next.js</h3>
                      <p className="text-sm text-gray-500">Porta 80/3000 • Node.js</p>
                    </div>
                  </div>
                  <Button 
                    onClick={restartNextjs}
                    disabled={restartingNextjs || !isAdmin}
                    variant={restartingNextjs ? "default" : "outline"}
                    className={restartingNextjs ? "bg-yellow-500 hover:bg-yellow-600" : ""}
                  >
                    {restartingNextjs ? <><RefreshCw className="h-4 w-4 mr-2 animate-spin" /> Reiniciando...</> 
                                      : <><Power className="h-4 w-4 mr-2" /> Reiniciar Next.js</>}
                  </Button>
                </div>
              </div>

              <div className="bg-yellow-50 border border-yellow-200 rounded p-3 text-xs text-yellow-800">
                <strong>⚠️ Atenção:</strong> Reiniciar o Next.js vai recarregar esta página automaticamente. 
                Certifique-se de salvar todas as alterações antes!
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* ==================== TAB 3: BACKUP ==================== */}
        <TabsContent value="backup" className="space-y-6 mt-4">
          
          {/* Criar Backup Rápido */}
          <Card className="border-green-200 bg-green-50">
            <CardContent className="pt-6">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <HardDrive className="h-10 w-10 text-green-600" />
                  <div>
                    <h3 className="font-bold text-green-900">Backup Completo do Sistema</h3>
                    <p className="text-sm text-green-700">Banco de dados + Frontend + Backend + Configs</p>
                  </div>
                </div>
                <Button 
                  onClick={createBackup}
                  disabled={backupInProgress || !isAdmin}
                  size="lg"
                  className="bg-green-600 hover:bg-green-700"
                >
                  {backupInProgress ? <><RefreshCw className="h-5 w-5 mr-2 animate-spin" /> Criando...</> 
                                    : <><Save className="h-5 w-5 mr-2" /> Fazer Backup Agora</>}
                </Button>
              </div>
            </CardContent>
          </Card>

          {/* Lista de Backups */}
          <Card>
            <CardHeader>
              <div className="flex items-center justify-between">
                <CardTitle className="flex items-center gap-2">
                  <FileText className="h-5 w-5" /> Backups Disponíveis ({backups.length})
                </CardTitle>
                <Button onClick={fetchBackups} variant="outline" size="sm">
                  <RefreshCw className="h-4 w-4 mr-1" /> Atualizar
                </Button>
              </div>
            </CardHeader>
            <CardContent>
              {loadingBackups ? (
                <div className="flex items-center justify-center py-8">
                  <RefreshCw className="h-6 w-6 animate-spin mr-2" /> Carregando...
                </div>
              ) : backups.length === 0 ? (
                <div className="text-center py-8 text-gray-500">
                  <HardDrive className="h-12 w-12 mx-auto mb-3 opacity-30" />
                  <p>Nenhum backup encontrado</p>
                  <p className="text-sm">Clique em "Fazer Backup Agora" para criar um!</p>
                </div>
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead>
                      <tr className="border-b bg-gray-50">
                        <th className="text-left p-3">Arquivo</th>
                        <th className="text-left p-3">Tipo</th>
                        <th className="text-left p-3">Tamanho</th>
                        <th className="text-left p-3">Data</th>
                        <th className="text-right p-3">Ações</th>
                      </tr>
                    </thead>
                    <tbody>
                      {backups.map((backup, idx) => (
                        <tr key={idx} className="border-b hover:bg-gray-50">
                          <td className="p-3 font-mono text-xs">{backup.name}</td>
                          <td className="p-3">
                            <Badge variant="secondary" className={
                              backup.type === 'postgresql' ? 'bg-blue-100 text-blue-800' :
                              backup.type === 'frontend' ? 'bg-green-100 text-green-800' :
                              backup.type === 'backend' ? 'bg-purple-100 text-purple-800' :
                              'bg-gray-100'
                            }>
                              {backup.type}
                            </Badge>
                          </td>
                          <td className="p-3">{backup.size}</td>
                          <td className="p-3 text-xs text-gray-500">{backup.date}</td>
                          <td className="p-3 text-right space-x-2">
                            <Button size="sm" variant="outline" onClick={() => downloadBackup(backup.name)}>
                              <Download className="h-3 w-3" />
                            </Button>
                            <Button size="sm" variant="outline" onClick={() => restoreBackup(backup.name)}
                                    className="text-blue-600 border-blue-600 hover:bg-blue-50">
                              <Upload className="h-3 w-3 mr-1" /> Restaurar
                            </Button>
                            <Button size="sm" variant="outline" onClick={() => deleteBackup(backup.name)}
                                    className="text-red-600 border-red-600 hover:bg-red-50">
                              <Trash2 className="h-3 w-3" />
                            </Button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}
