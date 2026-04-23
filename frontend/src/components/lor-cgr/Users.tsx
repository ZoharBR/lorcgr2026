'use client';

import { useState, useEffect } from 'react';
import {
  Plus,
  Search,
  Edit,
  Trash2,
  RefreshCw,
  Save,
  User as UserIcon,
  Shield,
  ShieldCheck,
  ShieldAlert,
  Eye,
  Settings,
  MoreVertical,
  Mail,
  Phone,
  Clock,
  CheckCircle,
  XCircle
} from 'lucide-react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Badge } from '@/components/ui/badge';
import { Switch } from '@/components/ui/switch';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { User, UserRole, UserPermissions } from '@/types/lor-cgr';
import { toast } from 'sonner';

interface UsersProps {
  loading: boolean;
  onRefresh: () => void;
  isAdmin?: boolean;
}

const API_URL = 'http://45.71.242.131:8000/api/users';

const roleLabels: Record<UserRole, string> = {
  ADMIN: 'Administrador',
  NOC: 'NOC (Operador)',
  VIEW: 'Visualizador',
  PERSONALIZADO: 'Personalizado',
};

const roleDescriptions: Record<UserRole, string> = {
  ADMIN: 'Acesso total a todas as funcionalidades e permissões de exclusão',
  NOC: 'Acesso a operações, sem acesso a usuários e exclusão',
  VIEW: 'Apenas visualização, sem permissão de edição ou exclusão',
  PERSONALIZADO: 'Permissões customizadas selecionadas abaixo',
};

const getRoleIcon = (role: UserRole) => {
  switch (role) {
    case 'ADMIN':
      return <ShieldCheck className="h-4 w-4 text-red-500" />;
    case 'NOC':
      return <Shield className="h-4 w-4 text-blue-500" />;
    case 'VIEW':
      return <Eye className="h-4 w-4 text-green-500" />;
    default:
      return <ShieldAlert className="h-4 w-4 text-yellow-500" />;
  }
};

const defaultPermissions: UserPermissions = {
  dashboard: true,
  equipment_view: true,
  equipment_edit: false,
  terminal: false,
  backups_view: true,
  backups_run: false,
  users_view: false,
  users_edit: false,
  logs_view: true,
  logs_delete: false,
  settings_view: false,
  settings_edit: false,
};

export default function Users({ loading, onRefresh, isAdmin = true }: UsersProps) {
  const [users, setUsers] = useState<User[]>([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [dialogOpen, setDialogOpen] = useState(false);
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [selectedUser, setSelectedUser] = useState<User | null>(null);
  const [saving, setSaving] = useState(false);
  const [isLoading, setIsLoading] = useState(true);

  const [formData, setFormData] = useState<Partial<User> & { password?: string; confirm_password?: string }>({
    name: '',
    login: '',
    password: '',
    confirm_password: '',
    email: '',
    phone: '',
    role: 'VIEW',
    is_active: true,
    permissions: defaultPermissions,
  });

  // Fetch users from API
  const fetchUsers = async () => {
    setIsLoading(true);
    try {
      const response = await fetch(`${API_URL}/list/`);
      if (response.ok) {
        const data = await response.json();
        setUsers(data.users || []);
      } else {
        // Fallback com dados mock se API não existir
        setUsers([
          {
            id: 1,
            name: 'Leonardo',
            login: 'admin',
            email: 'admin@lorcgr.local',
            phone: '(11) 99999-9999',
            role: 'ADMIN',
            is_active: true,
            last_login: new Date().toISOString(),
            created_at: '2026-01-01T00:00:00Z',
          },
        ]);
      }
    } catch (error) {
      console.error('Error fetching users:', error);
      // Fallback mock data
      setUsers([
        {
          id: 1,
          name: 'Administrador',
          login: 'admin',
          email: 'admin@lorcgr.local',
          role: 'ADMIN',
          is_active: true,
        },
      ]);
    }
    setIsLoading(false);
  };

  useEffect(() => {
    fetchUsers();
  }, []);

  const filteredUsers = users.filter(user =>
    user.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    user.login.toLowerCase().includes(searchTerm.toLowerCase()) ||
    user.email?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const handleOpenAdd = () => {
    setSelectedUser(null);
    setFormData({
      name: '',
      login: '',
      password: '',
      confirm_password: '',
      email: '',
      phone: '',
      role: 'VIEW',
      is_active: true,
      permissions: defaultPermissions,
    });
    setDialogOpen(true);
  };

  const handleOpenEdit = (user: User) => {
    setSelectedUser(user);
    setFormData({
      id: user.id,
      name: user.name,
      login: user.login,
      email: user.email || '',
      phone: user.phone || '',
      role: user.role,
      is_active: user.is_active,
      permissions: user.permissions || defaultPermissions,
    });
    setDialogOpen(true);
  };

  const handleOpenDelete = (user: User) => {
    setSelectedUser(user);
    setDeleteDialogOpen(true);
  };

  const handleSave = async () => {
    if (!formData.name || !formData.login) {
      toast.error('Nome e login são obrigatórios');
      return;
    }

    if (!selectedUser && formData.password !== formData.confirm_password) {
      toast.error('As senhas não coincidem');
      return;
    }

    if (!selectedUser && !formData.password) {
      toast.error('Senha é obrigatória para novo usuário');
      return;
    }

    setSaving(true);
    try {
      const url = selectedUser ? `${API_URL}/update/` : `${API_URL}/create/`;
      const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData),
      });

      if (response.ok) {
        toast.success(selectedUser ? 'Usuário atualizado' : 'Usuário criado com sucesso');
        fetchUsers();
        setDialogOpen(false);
      } else {
        const data = await response.json();
        toast.error(data.error || 'Erro ao salvar usuário');
      }
    } catch (error) {
      toast.error('Erro de conexão');
    }
    setSaving(false);
  };

  const handleDelete = async () => {
    if (!selectedUser) return;

    setSaving(true);
    try {
      const response = await fetch(`${API_URL}/delete/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: selectedUser.id }),
      });

      if (response.ok) {
        toast.success('Usuário removido com sucesso');
        fetchUsers();
        setDeleteDialogOpen(false);
      } else {
        toast.error('Erro ao remover usuário');
      }
    } catch (error) {
      toast.error('Erro de conexão');
    }
    setSaving(false);
  };

  const formatDate = (dateStr?: string) => {
    if (!dateStr) return '-';
    return new Date(dateStr).toLocaleString('pt-BR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row gap-4 justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Usuários</h1>
          <p className="text-muted-foreground">
            Gerenciamento de usuários e permissões do LOR CGR
          </p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" onClick={() => { fetchUsers(); onRefresh(); }} disabled={loading || isLoading}>
            <RefreshCw className={`h-4 w-4 mr-2 ${(loading || isLoading) ? 'animate-spin' : ''}`} />
            Atualizar
          </Button>
          {isAdmin && (
            <Button onClick={handleOpenAdd}>
              <Plus className="h-4 w-4 mr-2" />
              Novo Usuário
            </Button>
          )}
        </div>
      </div>

      {/* Stats */}
      <div className="grid gap-4 md:grid-cols-4">
        <Card>
          <CardContent className="pt-6">
            <div className="text-2xl font-bold">{users.length}</div>
            <p className="text-xs text-muted-foreground">Total de Usuários</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-6">
            <div className="text-2xl font-bold text-red-500">
              {users.filter(u => u.role === 'ADMIN').length}
            </div>
            <p className="text-xs text-muted-foreground">Administradores</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-6">
            <div className="text-2xl font-bold text-blue-500">
              {users.filter(u => u.role === 'NOC').length}
            </div>
            <p className="text-xs text-muted-foreground">Operadores NOC</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-6">
            <div className="text-2xl font-bold text-green-500">
              {users.filter(u => u.is_active).length}
            </div>
            <p className="text-xs text-muted-foreground">Usuários Ativos</p>
          </CardContent>
        </Card>
      </div>

      {/* Search and List */}
      <Card>
        <CardHeader>
          <CardTitle>Lista de Usuários</CardTitle>
          <CardDescription>
            {filteredUsers.length} de {users.length} usuários
          </CardDescription>
        </CardHeader>
        <CardContent>
          {/* Search */}
          <div className="relative mb-4">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <Input
              placeholder="Buscar por nome, login ou email..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="pl-9"
            />
          </div>

          {/* User List */}
          <div className="space-y-4">
            {filteredUsers.map((user) => (
              <div
                key={user.id}
                className="flex items-center justify-between p-4 border rounded-lg hover:bg-muted/50 transition-colors"
              >
                <div className="flex items-center gap-4">
                  <div className={`p-3 rounded-full ${
                    user.role === 'ADMIN' ? 'bg-red-500/10 text-red-500' :
                    user.role === 'NOC' ? 'bg-blue-500/10 text-blue-500' :
                    'bg-green-500/10 text-green-500'
                  }`}>
                    {getRoleIcon(user.role)}
                  </div>
                  <div>
                    <div className="font-medium text-lg flex items-center gap-2">
                      {user.name}
                      {!user.is_active && (
                        <Badge variant="outline" className="text-gray-500">Inativo</Badge>
                      )}
                    </div>
                    <div className="text-sm text-muted-foreground flex items-center gap-4">
                      <span className="flex items-center gap-1">
                        <UserIcon className="h-3 w-3" />
                        @{user.login}
                      </span>
                      {user.email && (
                        <span className="flex items-center gap-1">
                          <Mail className="h-3 w-3" />
                          {user.email}
                        </span>
                      )}
                      {user.phone && (
                        <span className="flex items-center gap-1">
                          <Phone className="h-3 w-3" />
                          {user.phone}
                        </span>
                      )}
                    </div>
                    {user.last_login && (
                      <div className="text-xs text-muted-foreground mt-1 flex items-center gap-1">
                        <Clock className="h-3 w-3" />
                        Último acesso: {formatDate(user.last_login)}
                      </div>
                    )}
                  </div>
                </div>

                <div className="flex items-center gap-3">
                  <Badge variant="outline" className="flex items-center gap-1">
                    {getRoleIcon(user.role)}
                    {roleLabels[user.role]}
                  </Badge>

                  {isAdmin && (
                    <DropdownMenu>
                      <DropdownMenuTrigger asChild>
                        <Button variant="ghost" size="icon">
                          <MoreVertical className="h-4 w-4" />
                        </Button>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent align="end">
                        <DropdownMenuItem onClick={() => handleOpenEdit(user)}>
                          <Edit className="h-4 w-4 mr-2" />
                          Editar
                        </DropdownMenuItem>
                        <DropdownMenuSeparator />
                        <DropdownMenuItem
                          className="text-red-500"
                          onClick={() => handleOpenDelete(user)}
                          disabled={user.role === 'ADMIN' && users.filter(u => u.role === 'ADMIN').length === 1}
                        >
                          <Trash2 className="h-4 w-4 mr-2" />
                          Remover
                        </DropdownMenuItem>
                      </DropdownMenuContent>
                    </DropdownMenu>
                  )}
                </div>
              </div>
            ))}

            {filteredUsers.length === 0 && (
              <div className="text-center py-12 text-muted-foreground">
                <UserIcon className="h-12 w-12 mx-auto mb-4 opacity-50" />
                <p>Nenhum usuário encontrado</p>
              </div>
            )}
          </div>
        </CardContent>
      </Card>

      {/* Role Info Cards */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Shield className="h-5 w-5" />
            Tipos de Usuário
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
            {(Object.keys(roleLabels) as UserRole[]).map((role) => (
              <div key={role} className="p-4 border rounded-lg">
                <div className="flex items-center gap-2 mb-2">
                  {getRoleIcon(role)}
                  <span className="font-medium">{roleLabels[role]}</span>
                </div>
                <p className="text-sm text-muted-foreground">{roleDescriptions[role]}</p>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Add/Edit Dialog */}
      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>
              {selectedUser ? 'Editar Usuário' : 'Novo Usuário'}
            </DialogTitle>
            <DialogDescription>
              Preencha os dados do usuário
            </DialogDescription>
          </DialogHeader>

          <Tabs defaultValue="basic" className="w-full">
            <TabsList className="grid w-full grid-cols-2">
              <TabsTrigger value="basic">Dados Básicos</TabsTrigger>
              <TabsTrigger value="permissions" disabled={formData.role !== 'PERSONALIZADO'}>
                Permissões
              </TabsTrigger>
            </TabsList>

            <TabsContent value="basic" className="space-y-4 mt-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="name">Nome Completo *</Label>
                  <Input
                    id="name"
                    value={formData.name || ''}
                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                    placeholder="João Silva"
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="login">Login *</Label>
                  <Input
                    id="login"
                    value={formData.login || ''}
                    onChange={(e) => setFormData({ ...formData, login: e.target.value })}
                    placeholder="joao.silva"
                    disabled={!!selectedUser}
                  />
                </div>
              </div>

              {!selectedUser && (
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <Label htmlFor="password">Senha *</Label>
                    <Input
                      id="password"
                      type="password"
                      value={formData.password || ''}
                      onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                      placeholder="••••••••"
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="confirm_password">Confirmar Senha *</Label>
                    <Input
                      id="confirm_password"
                      type="password"
                      value={formData.confirm_password || ''}
                      onChange={(e) => setFormData({ ...formData, confirm_password: e.target.value })}
                      placeholder="••••••••"
                    />
                  </div>
                </div>
              )}

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="email">E-mail</Label>
                  <Input
                    id="email"
                    type="email"
                    value={formData.email || ''}
                    onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                    placeholder="joao@empresa.com"
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="phone">Telefone (com DDD)</Label>
                  <Input
                    id="phone"
                    value={formData.phone || ''}
                    onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                    placeholder="(11) 99999-9999"
                  />
                </div>
              </div>

              <div className="space-y-2">
                <Label htmlFor="role">Tipo de Usuário</Label>
                <Select
                  value={formData.role || 'VIEW'}
                  onValueChange={(value: UserRole) => setFormData({ ...formData, role: value })}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {(Object.keys(roleLabels) as UserRole[]).map((role) => (
                      <SelectItem key={role} value={role}>
                        <div className="flex items-center gap-2">
                          {getRoleIcon(role)}
                          {roleLabels[role]}
                        </div>
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                <p className="text-xs text-muted-foreground">
                  {roleDescriptions[formData.role as UserRole]}
                </p>
              </div>

              <div className="flex items-center justify-between p-4 border rounded-lg">
                <div className="space-y-0.5">
                  <Label>Usuário Ativo</Label>
                  <p className="text-sm text-muted-foreground">
                    Usuários inativos não podem fazer login
                  </p>
                </div>
                <Switch
                  checked={formData.is_active ?? true}
                  onCheckedChange={(checked) => setFormData({ ...formData, is_active: checked })}
                />
              </div>
            </TabsContent>

            <TabsContent value="permissions" className="space-y-4 mt-4">
              <div className="p-4 border rounded-lg bg-yellow-500/10 border-yellow-500/20">
                <p className="text-sm text-yellow-600">
                  Configure as permissões específicas para este usuário personalizado.
                </p>
              </div>

              <div className="grid grid-cols-2 gap-4">
                {Object.entries(defaultPermissions).map(([key, defaultValue]) => (
                  <div key={key} className="flex items-center justify-between p-3 border rounded-lg">
                    <Label className="text-sm">
                      {key.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())}
                    </Label>
                    <Switch
                      checked={formData.permissions?.[key as keyof UserPermissions] ?? defaultValue}
                      onCheckedChange={(checked) => setFormData({
                        ...formData,
                        permissions: {
                          ...defaultPermissions,
                          ...formData.permissions,
                          [key]: checked
                        }
                      })}
                    />
                  </div>
                ))}
              </div>
            </TabsContent>
          </Tabs>

          <DialogFooter>
            <Button variant="outline" onClick={() => setDialogOpen(false)}>
              Cancelar
            </Button>
            <Button onClick={handleSave} disabled={saving}>
              {saving ? (
                <RefreshCw className="h-4 w-4 mr-2 animate-spin" />
              ) : (
                <Save className="h-4 w-4 mr-2" />
              )}
              Salvar
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete Confirmation Dialog */}
      <Dialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Confirmar Remoção</DialogTitle>
            <DialogDescription>
              Tem certeza que deseja remover o usuário <strong>{selectedUser?.name}</strong>?
              Esta ação não pode ser desfeita.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeleteDialogOpen(false)}>
              Cancelar
            </Button>
            <Button variant="destructive" onClick={handleDelete} disabled={saving}>
              {saving && <RefreshCw className="h-4 w-4 mr-2 animate-spin" />}
              Remover
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
