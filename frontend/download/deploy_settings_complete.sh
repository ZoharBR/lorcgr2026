#!/bin/bash
# ============================================
# DEPLOY COMPLETO - SETTINGS + GITHUB BACKUP
# LOR-CGR Network Management System
# Servidor: 45.71.242.131
# ============================================

set -e

echo "============================================"
echo "DEPLOY SETTINGS + GITHUB BACKUP - LOR-CGR"
echo "============================================"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Diretórios
PROJECT_DIR="/opt/lorcgr"
FRONTEND_DIR="${PROJECT_DIR}/frontend"
BACKEND_DIR="${PROJECT_DIR}"

# ============================================
# 1. CRIAR SETTINGS.JS NO FRONTEND
# ============================================
echo ""
echo -e "${YELLOW}[1/5] Criando componente Settings.js...${NC}"

mkdir -p ${FRONTEND_DIR}/src/components

cat > ${FRONTEND_DIR}/src/components/Settings.js << 'SETTINGSEOF'
import React, { useState, useEffect } from 'react';
import {
  Save, RefreshCw, Upload, Download, CheckCircle, XCircle, Eye, EyeOff,
  History, ExternalLink, Server, Activity, Bot, GitBranch, Plug, Settings as SettingsIcon,
  Loader2
} from 'lucide-react';

const Settings = () => {
  const [activeTab, setActiveTab] = useState('apis');
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState({ type: '', text: '' });
  const [settings, setSettings] = useState({
    librenms_enabled: true,
    librenms_url: '',
    librenms_api_token: '',
    phpipam_enabled: true,
    phpipam_url: '',
    phpipam_app_id: '',
    phpipam_app_key: '',
    phpipam_user: '',
    phpipam_password: '',
    ai_enabled: true,
    ai_provider: 'groq',
    groq_api_key: '',
    groq_model: 'llama-3.3-70b-versatile',
    ai_temperature: 0.7,
    ai_max_tokens: 4096,
    ai_system_prompt: '',
    git_enabled: false,
    git_token: '',
    git_repo_url: '',
    git_branch: 'main',
    git_auto_backup: false,
    git_backup_frequency: 'daily',
  });
  const [gitStatus, setGitStatus] = useState(null);
  const [gitLogs, setGitLogs] = useState([]);
  const [showPasswords, setShowPasswords] = useState({});

  const tabs = [
    { id: 'apis', label: 'APIs Externas', icon: Plug, color: 'from-blue-600 to-blue-700' },
    { id: 'ai', label: 'IA (Groq)', icon: Bot, color: 'from-purple-600 to-purple-700' },
    { id: 'git', label: 'Git/Backup', icon: GitBranch, color: 'from-orange-600 to-orange-700' },
  ];

  useEffect(() => {
    loadSettings();
  }, []);

  useEffect(() => {
    if (activeTab === 'git') {
      loadGitStatus();
      loadGitLogs();
    }
  }, [activeTab]);

  const loadSettings = async () => {
    try {
      const res = await fetch('/api/settings/get/');
      const data = await res.json();
      if (data.success && data.settings) {
        setSettings(prev => ({ ...prev, ...data.settings }));
      }
    } catch (e) {
      console.log('Settings not available yet');
    }
  };

  const saveSettings = async () => {
    setLoading(true);
    setMessage({ type: '', text: '' });
    try {
      const res = await fetch('/api/settings/save/', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(settings),
      });
      const data = await res.json();
      if (data.success) {
        setMessage({ type: 'success', text: 'Configurações salvas com sucesso!' });
      } else {
        setMessage({ type: 'error', text: data.error || 'Erro ao salvar' });
      }
    } catch (e) {
      setMessage({ type: 'error', text: 'Erro de conexão' });
    }
    setLoading(false);
  };

  const testLibreNMS = async () => {
    setLoading(true);
    setMessage({ type: '', text: '' });
    try {
      const res = await fetch('/api/settings/test/librenms/', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          url: settings.librenms_url,
          token: settings.librenms_api_token,
        }),
      });
      const data = await res.json();
      setMessage({ 
        type: data.success ? 'success' : 'error', 
        text: data.success ? 'LibreNMS: Conexão OK!' : `LibreNMS: ${data.error}` 
      });
    } catch (e) {
      setMessage({ type: 'error', text: 'Erro ao testar LibreNMS' });
    }
    setLoading(false);
  };

  const testPhpIPAM = async () => {
    setLoading(true);
    setMessage({ type: '', text: '' });
    try {
      const res = await fetch('/api/settings/test/phpipam/', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          url: settings.phpipam_url,
          app_id: settings.phpipam_app_id,
          app_key: settings.phpipam_app_key,
          user: settings.phpipam_user,
          password: settings.phpipam_password,
        }),
      });
      const data = await res.json();
      setMessage({ 
        type: data.success ? 'success' : 'error', 
        text: data.success ? 'phpIPAM: Conexão OK!' : `phpIPAM: ${data.error}` 
      });
    } catch (e) {
      setMessage({ type: 'error', text: 'Erro ao testar phpIPAM' });
    }
    setLoading(false);
  };

  const testGroq = async () => {
    setLoading(true);
    setMessage({ type: '', text: '' });
    try {
      const res = await fetch('/api/settings/test/groq/', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          api_key: settings.groq_api_key,
          model: settings.groq_model,
        }),
      });
      const data = await res.json();
      setMessage({ 
        type: data.success ? 'success' : 'error', 
        text: data.success ? 'Groq AI: Conexão OK!' : `Groq AI: ${data.error}` 
      });
    } catch (e) {
      setMessage({ type: 'error', text: 'Erro ao testar Groq' });
    }
    setLoading(false);
  };

  const loadGitStatus = async () => {
    try {
      const res = await fetch('/api/settings/git/status/');
      const data = await res.json();
      if (data.success) {
        setGitStatus(data);
      }
    } catch (e) {
      console.log('Git status not available');
    }
  };

  const loadGitLogs = async () => {
    try {
      const res = await fetch('/api/settings/git/logs/');
      const data = await res.json();
      if (data.success && data.commits) {
        setGitLogs(data.commits);
      }
    } catch (e) {
      console.log('Git logs not available');
    }
  };

  const runGitBackup = async () => {
    setLoading(true);
    setMessage({ type: 'info', text: 'Enviando backup para GitHub...' });
    try {
      const res = await fetch('/api/settings/git/backup/', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          token: settings.git_token,
          repo_url: settings.git_repo_url,
          branch: settings.git_branch,
        }),
      });
      const data = await res.json();
      if (data.success) {
        setMessage({ type: 'success', text: `Backup enviado! Commit: ${data.commit_hash?.substring(0, 7) || 'OK'}` });
        loadGitStatus();
        loadGitLogs();
      } else {
        setMessage({ type: 'error', text: data.error || 'Erro no backup' });
      }
    } catch (e) {
      setMessage({ type: 'error', text: 'Erro de conexão' });
    }
    setLoading(false);
  };

  const runGitPull = async () => {
    setLoading(true);
    setMessage({ type: 'info', text: 'Baixando atualizações...' });
    try {
      const res = await fetch('/api/settings/git/pull/', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      });
      const data = await res.json();
      if (data.success) {
        setMessage({ type: 'success', text: 'Atualizações baixadas!' });
        loadGitStatus();
      } else {
        setMessage({ type: 'error', text: data.error || 'Erro no pull' });
      }
    } catch (e) {
      setMessage({ type: 'error', text: 'Erro de conexão' });
    }
    setLoading(false);
  };

  const togglePassword = (field) => {
    setShowPasswords(prev => ({ ...prev, [field]: !prev[field] }));
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <SettingsIcon className="h-7 w-7 text-blue-400" />
            Configurações
          </h1>
          <p className="text-gray-400">Gerencie as configurações do sistema LOR-CGR</p>
        </div>
        <button
          onClick={saveSettings}
          disabled={loading}
          className="flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-blue-600 to-blue-700 text-white rounded-lg hover:from-blue-500 hover:to-blue-600 transition disabled:opacity-50"
        >
          {loading ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            <Save className="h-4 w-4" />
          )}
          Salvar Tudo
        </button>
      </div>

      {/* Message */}
      {message.text && (
        <div className={`flex items-center gap-2 p-4 rounded-lg ${
          message.type === 'success' ? 'bg-green-600/20 text-green-400 border border-green-600/30' :
          message.type === 'error' ? 'bg-red-600/20 text-red-400 border border-red-600/30' :
          'bg-blue-600/20 text-blue-400 border border-blue-600/30'
        }`}>
          {message.type === 'success' ? <CheckCircle className="h-5 w-5" /> : 
           message.type === 'error' ? <XCircle className="h-5 w-5" /> : 
           <Loader2 className="h-5 w-5 animate-spin" />}
          <span>{message.text}</span>
        </div>
      )}

      {/* Tabs */}
      <div className="flex gap-2 overflow-x-auto pb-2">
        {tabs.map(tab => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg font-medium transition whitespace-nowrap ${
              activeTab === tab.id
                ? `bg-gradient-to-r ${tab.color} text-white`
                : 'bg-gray-800 text-gray-400 hover:bg-gray-700 hover:text-white'
            }`}
          >
            <tab.icon className="h-4 w-4" />
            {tab.label}
          </button>
        ))}
      </div>

      {/* APIs Externas Tab */}
      {activeTab === 'apis' && (
        <div className="grid gap-6 lg:grid-cols-2">
          {/* LibreNMS */}
          <div className="bg-gray-800 rounded-lg p-6 border border-gray-700">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2">
                <Activity className="h-5 w-5 text-blue-400" />
                <h2 className="text-lg font-semibold text-white">LibreNMS</h2>
              </div>
              <label className="flex items-center gap-2 cursor-pointer">
                <span className="text-sm text-gray-400">Ativo</span>
                <div className="relative">
                  <input
                    type="checkbox"
                    checked={settings.librenms_enabled}
                    onChange={(e) => setSettings(prev => ({ ...prev, librenms_enabled: e.target.checked }))}
                    className="sr-only"
                  />
                  <div className={`w-10 h-6 rounded-full transition ${settings.librenms_enabled ? 'bg-blue-600' : 'bg-gray-600'}`}>
                    <div className={`w-4 h-4 mt-1 ml-1 rounded-full bg-white transition transform ${settings.librenms_enabled ? 'translate-x-4' : ''}`} />
                  </div>
                </div>
              </label>
            </div>
            <div className="space-y-4">
              <div>
                <label className="block text-sm text-gray-400 mb-1">URL do Servidor</label>
                <input
                  type="text"
                  placeholder="http://localhost:8081"
                  value={settings.librenms_url}
                  onChange={(e) => setSettings(prev => ({ ...prev, librenms_url: e.target.value }))}
                  disabled={!settings.librenms_enabled}
                  className="w-full bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-blue-500 disabled:opacity-50"
                />
              </div>
              <div>
                <label className="block text-sm text-gray-400 mb-1">API Token</label>
                <div className="relative">
                  <input
                    type={showPasswords.librenms_token ? 'text' : 'password'}
                    placeholder="Token de API"
                    value={settings.librenms_api_token}
                    onChange={(e) => setSettings(prev => ({ ...prev, librenms_api_token: e.target.value }))}
                    disabled={!settings.librenms_enabled}
                    className="w-full bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 pr-10 text-white placeholder-gray-500 focus:outline-none focus:border-blue-500 disabled:opacity-50"
                  />
                  <button
                    type="button"
                    onClick={() => togglePassword('librenms_token')}
                    className="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400 hover:text-white"
                  >
                    {showPasswords.librenms_token ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                  </button>
                </div>
              </div>
              <button
                onClick={testLibreNMS}
                disabled={loading || !settings.librenms_enabled}
                className="w-full flex items-center justify-center gap-2 px-4 py-2 bg-blue-600/20 text-blue-400 border border-blue-600/30 rounded-lg hover:bg-blue-600/30 transition disabled:opacity-50"
              >
                <CheckCircle className="h-4 w-4" />
                Testar Conexão
              </button>
            </div>
          </div>

          {/* phpIPAM */}
          <div className="bg-gray-800 rounded-lg p-6 border border-gray-700">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2">
                <Server className="h-5 w-5 text-green-400" />
                <h2 className="text-lg font-semibold text-white">phpIPAM</h2>
              </div>
              <label className="flex items-center gap-2 cursor-pointer">
                <span className="text-sm text-gray-400">Ativo</span>
                <div className="relative">
                  <input
                    type="checkbox"
                    checked={settings.phpipam_enabled}
                    onChange={(e) => setSettings(prev => ({ ...prev, phpipam_enabled: e.target.checked }))}
                    className="sr-only"
                  />
                  <div className={`w-10 h-6 rounded-full transition ${settings.phpipam_enabled ? 'bg-green-600' : 'bg-gray-600'}`}>
                    <div className={`w-4 h-4 mt-1 ml-1 rounded-full bg-white transition transform ${settings.phpipam_enabled ? 'translate-x-4' : ''}`} />
                  </div>
                </div>
              </label>
            </div>
            <div className="space-y-4">
              <div>
                <label className="block text-sm text-gray-400 mb-1">URL do Servidor</label>
                <input
                  type="text"
                  placeholder="http://localhost:9100"
                  value={settings.phpipam_url}
                  onChange={(e) => setSettings(prev => ({ ...prev, phpipam_url: e.target.value }))}
                  disabled={!settings.phpipam_enabled}
                  className="w-full bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-green-500 disabled:opacity-50"
                />
              </div>
              <div className="grid grid-cols-2 gap-2">
                <div>
                  <label className="block text-sm text-gray-400 mb-1">App ID</label>
                  <input
                    type="text"
                    placeholder="app_id"
                    value={settings.phpipam_app_id}
                    onChange={(e) => setSettings(prev => ({ ...prev, phpipam_app_id: e.target.value }))}
                    disabled={!settings.phpipam_enabled}
                    className="w-full bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-green-500 disabled:opacity-50"
                  />
                </div>
                <div>
                  <label className="block text-sm text-gray-400 mb-1">App Key</label>
                  <input
                    type={showPasswords.phpipam_key ? 'text' : 'password'}
                    placeholder="app_key"
                    value={settings.phpipam_app_key}
                    onChange={(e) => setSettings(prev => ({ ...prev, phpipam_app_key: e.target.value }))}
                    disabled={!settings.phpipam_enabled}
                    className="w-full bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-green-500 disabled:opacity-50"
                  />
                </div>
              </div>
              <div className="grid grid-cols-2 gap-2">
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Usuário</label>
                  <input
                    type="text"
                    placeholder="admin"
                    value={settings.phpipam_user}
                    onChange={(e) => setSettings(prev => ({ ...prev, phpipam_user: e.target.value }))}
                    disabled={!settings.phpipam_enabled}
                    className="w-full bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-green-500 disabled:opacity-50"
                  />
                </div>
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Senha</label>
                  <div className="relative">
                    <input
                      type={showPasswords.phpipam_password ? 'text' : 'password'}
                      placeholder="senha"
                      value={settings.phpipam_password}
                      onChange={(e) => setSettings(prev => ({ ...prev, phpipam_password: e.target.value }))}
                      disabled={!settings.phpipam_enabled}
                      className="w-full bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 pr-10 text-white placeholder-gray-500 focus:outline-none focus:border-green-500 disabled:opacity-50"
                    />
                    <button
                      type="button"
                      onClick={() => togglePassword('phpipam_password')}
                      className="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400 hover:text-white"
                    >
                      {showPasswords.phpipam_password ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                    </button>
                  </div>
                </div>
              </div>
              <button
                onClick={testPhpIPAM}
                disabled={loading || !settings.phpipam_enabled}
                className="w-full flex items-center justify-center gap-2 px-4 py-2 bg-green-600/20 text-green-400 border border-green-600/30 rounded-lg hover:bg-green-600/30 transition disabled:opacity-50"
              >
                <CheckCircle className="h-4 w-4" />
                Testar Conexão
              </button>
            </div>
          </div>
        </div>
      )}

      {/* AI Tab */}
      {activeTab === 'ai' && (
        <div className="bg-gray-800 rounded-lg p-6 border border-gray-700">
          <div className="flex items-center justify-between mb-6">
            <div className="flex items-center gap-2">
              <Bot className="h-5 w-5 text-purple-400" />
              <h2 className="text-lg font-semibold text-white">Inteligência Artificial</h2>
            </div>
            <label className="flex items-center gap-2 cursor-pointer">
              <span className="text-sm text-gray-400">Ativo</span>
              <div className="relative">
                <input
                  type="checkbox"
                  checked={settings.ai_enabled}
                  onChange={(e) => setSettings(prev => ({ ...prev, ai_enabled: e.target.checked }))}
                  className="sr-only"
                />
                <div className={`w-10 h-6 rounded-full transition ${settings.ai_enabled ? 'bg-purple-600' : 'bg-gray-600'}`}>
                  <div className={`w-4 h-4 mt-1 ml-1 rounded-full bg-white transition transform ${settings.ai_enabled ? 'translate-x-4' : ''}`} />
                </div>
              </div>
            </label>
          </div>

          <div className="grid gap-6 lg:grid-cols-2">
            <div>
              <label className="block text-sm text-gray-400 mb-1">Provedor</label>
              <select
                value={settings.ai_provider}
                onChange={(e) => setSettings(prev => ({ ...prev, ai_provider: e.target.value }))}
                disabled={!settings.ai_enabled}
                className="w-full bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 text-white focus:outline-none focus:border-purple-500 disabled:opacity-50"
              >
                <option value="groq">Groq</option>
                <option value="openai">OpenAI</option>
                <option value="anthropic">Anthropic</option>
              </select>
            </div>
            <div>
              <label className="block text-sm text-gray-400 mb-1">Modelo</label>
              <select
                value={settings.groq_model}
                onChange={(e) => setSettings(prev => ({ ...prev, groq_model: e.target.value }))}
                disabled={!settings.ai_enabled}
                className="w-full bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 text-white focus:outline-none focus:border-purple-500 disabled:opacity-50"
              >
                <option value="llama-3.3-70b-versatile">Llama 3.3 70B Versatile</option>
                <option value="llama-3.3-8b-versatile">Llama 3.3 8B Versatile</option>
                <option value="mixtral-8x7b-32768">Mixtral 8x7B</option>
                <option value="gemma2-9b-it">Gemma 2 9B</option>
              </select>
            </div>
          </div>

          <div className="mt-4">
            <label className="block text-sm text-gray-400 mb-1">API Key</label>
            <div className="relative">
              <input
                type={showPasswords.groq_key ? 'text' : 'password'}
                placeholder="gsk_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
                value={settings.groq_api_key}
                onChange={(e) => setSettings(prev => ({ ...prev, groq_api_key: e.target.value }))}
                disabled={!settings.ai_enabled}
                className="w-full bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 pr-10 text-white placeholder-gray-500 focus:outline-none focus:border-purple-500 disabled:opacity-50"
              />
              <button
                type="button"
                onClick={() => togglePassword('groq_key')}
                className="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400 hover:text-white"
              >
                {showPasswords.groq_key ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
              </button>
            </div>
          </div>

          <div className="grid gap-6 lg:grid-cols-2 mt-4">
            <div>
              <label className="block text-sm text-gray-400 mb-1">Temperatura: {settings.ai_temperature.toFixed(1)}</label>
              <input
                type="range"
                min="0"
                max="1"
                step="0.1"
                value={settings.ai_temperature}
                onChange={(e) => setSettings(prev => ({ ...prev, ai_temperature: parseFloat(e.target.value) }))}
                disabled={!settings.ai_enabled}
                className="w-full accent-purple-500 disabled:opacity-50"
              />
            </div>
            <div>
              <label className="block text-sm text-gray-400 mb-1">Max Tokens: {settings.ai_max_tokens}</label>
              <input
                type="range"
                min="256"
                max="8192"
                step="256"
                value={settings.ai_max_tokens}
                onChange={(e) => setSettings(prev => ({ ...prev, ai_max_tokens: parseInt(e.target.value) }))}
                disabled={!settings.ai_enabled}
                className="w-full accent-purple-500 disabled:opacity-50"
              />
            </div>
          </div>

          <button
            onClick={testGroq}
            disabled={loading || !settings.ai_enabled || !settings.groq_api_key}
            className="mt-4 w-full flex items-center justify-center gap-2 px-4 py-2 bg-purple-600/20 text-purple-400 border border-purple-600/30 rounded-lg hover:bg-purple-600/30 transition disabled:opacity-50"
          >
            <CheckCircle className="h-4 w-4" />
            Testar Conexão IA
          </button>
        </div>
      )}

      {/* Git/Backup Tab */}
      {activeTab === 'git' && (
        <div className="grid gap-6 lg:grid-cols-2">
          {/* Git Configuration */}
          <div className="bg-gray-800 rounded-lg p-6 border border-gray-700">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2">
                <GitBranch className="h-5 w-5 text-orange-400" />
                <h2 className="text-lg font-semibold text-white">GitHub Backup</h2>
              </div>
              <label className="flex items-center gap-2 cursor-pointer">
                <span className="text-sm text-gray-400">Ativo</span>
                <div className="relative">
                  <input
                    type="checkbox"
                    checked={settings.git_enabled}
                    onChange={(e) => setSettings(prev => ({ ...prev, git_enabled: e.target.checked }))}
                    className="sr-only"
                  />
                  <div className={`w-10 h-6 rounded-full transition ${settings.git_enabled ? 'bg-orange-600' : 'bg-gray-600'}`}>
                    <div className={`w-4 h-4 mt-1 ml-1 rounded-full bg-white transition transform ${settings.git_enabled ? 'translate-x-4' : ''}`} />
                  </div>
                </div>
              </label>
            </div>

            <div className="space-y-4">
              <div>
                <label className="block text-sm text-gray-400 mb-1">GitHub Token (PAT)</label>
                <div className="relative">
                  <input
                    type={showPasswords.git_token ? 'text' : 'password'}
                    placeholder="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
                    value={settings.git_token}
                    onChange={(e) => setSettings(prev => ({ ...prev, git_token: e.target.value }))}
                    disabled={!settings.git_enabled}
                    className="w-full bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 pr-10 text-white placeholder-gray-500 focus:outline-none focus:border-orange-500 disabled:opacity-50"
                  />
                  <button
                    type="button"
                    onClick={() => togglePassword('git_token')}
                    className="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400 hover:text-white"
                  >
                    {showPasswords.git_token ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                  </button>
                </div>
                <p className="text-xs text-gray-500 mt-1">Personal Access Token com permissões de repo</p>
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-1">URL do Repositório</label>
                <input
                  type="text"
                  placeholder="https://github.com/usuario/repositorio.git"
                  value={settings.git_repo_url}
                  onChange={(e) => setSettings(prev => ({ ...prev, git_repo_url: e.target.value }))}
                  disabled={!settings.git_enabled}
                  className="w-full bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-orange-500 disabled:opacity-50"
                />
              </div>

              <div>
                <label className="block text-sm text-gray-400 mb-1">Branch</label>
                <input
                  type="text"
                  placeholder="main"
                  value={settings.git_branch}
                  onChange={(e) => setSettings(prev => ({ ...prev, git_branch: e.target.value }))}
                  disabled={!settings.git_enabled}
                  className="w-full bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 text-white placeholder-gray-500 focus:outline-none focus:border-orange-500 disabled:opacity-50"
                />
              </div>

              <div className="flex items-center justify-between py-2">
                <span className="text-gray-300">Backup Automático</span>
                <div className="relative">
                  <input
                    type="checkbox"
                    checked={settings.git_auto_backup}
                    onChange={(e) => setSettings(prev => ({ ...prev, git_auto_backup: e.target.checked }))}
                    disabled={!settings.git_enabled}
                    className="sr-only"
                  />
                  <div className={`w-10 h-6 rounded-full transition ${settings.git_auto_backup ? 'bg-orange-600' : 'bg-gray-600'}`}>
                    <div className={`w-4 h-4 mt-1 ml-1 rounded-full bg-white transition transform ${settings.git_auto_backup ? 'translate-x-4' : ''}`} />
                  </div>
                </div>
              </div>

              {settings.git_auto_backup && (
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Frequência</label>
                  <select
                    value={settings.git_backup_frequency}
                    onChange={(e) => setSettings(prev => ({ ...prev, git_backup_frequency: e.target.value }))}
                    disabled={!settings.git_enabled}
                    className="w-full bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 text-white focus:outline-none focus:border-orange-500 disabled:opacity-50"
                  >
                    <option value="hourly">A cada hora</option>
                    <option value="daily">Diário</option>
                    <option value="weekly">Semanal</option>
                    <option value="monthly">Mensal</option>
                  </select>
                </div>
              )}

              <div className="grid grid-cols-2 gap-2">
                <button
                  onClick={runGitPull}
                  disabled={loading || !settings.git_enabled}
                  className="flex items-center justify-center gap-2 px-4 py-2 bg-blue-600/20 text-blue-400 border border-blue-600/30 rounded-lg hover:bg-blue-600/30 transition disabled:opacity-50"
                >
                  <Download className="h-4 w-4" />
                  Pull
                </button>
                <button
                  onClick={runGitBackup}
                  disabled={loading || !settings.git_enabled || !settings.git_token || !settings.git_repo_url}
                  className="flex items-center justify-center gap-2 px-4 py-2 bg-orange-600 text-white rounded-lg hover:bg-orange-500 transition disabled:opacity-50"
                >
                  {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Upload className="h-4 w-4" />}
                  Backup Agora
                </button>
              </div>
            </div>
          </div>

          {/* Git Status */}
          <div className="bg-gray-800 rounded-lg p-6 border border-gray-700">
            <div className="flex items-center gap-2 mb-4">
              <History className="h-5 w-5 text-blue-400" />
              <h2 className="text-lg font-semibold text-white">Status do Repositório</h2>
            </div>

            {gitStatus ? (
              <div className="space-y-4">
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <p className="text-xs text-gray-500">Branch</p>
                    <div className="flex items-center gap-2 mt-1">
                      <GitBranch className="h-4 w-4 text-orange-400" />
                      <span className="text-white font-medium">{gitStatus.branch}</span>
                    </div>
                  </div>
                  <div>
                    <p className="text-xs text-gray-500">Remote</p>
                    <a 
                      href={gitStatus.remote}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="flex items-center gap-1 text-blue-400 hover:underline text-sm truncate mt-1"
                    >
                      {gitStatus.remote?.replace('https://github.com/', '').replace('.git', '')}
                      <ExternalLink className="h-3 w-3 flex-shrink-0" />
                    </a>
                  </div>
                </div>

                <div className="grid grid-cols-3 gap-2 text-center">
                  <div className="bg-gray-700/50 rounded-lg p-3">
                    <p className="text-2xl font-bold text-yellow-400">{gitStatus.staged || 0}</p>
                    <p className="text-xs text-gray-500">Staged</p>
                  </div>
                  <div className="bg-gray-700/50 rounded-lg p-3">
                    <p className="text-2xl font-bold text-orange-400">{gitStatus.unstaged || 0}</p>
                    <p className="text-xs text-gray-500">Unstaged</p>
                  </div>
                  <div className="bg-gray-700/50 rounded-lg p-3">
                    <p className="text-2xl font-bold text-red-400">{gitStatus.untracked || 0}</p>
                    <p className="text-xs text-gray-500">Untracked</p>
                  </div>
                </div>

                <div className="space-y-2">
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-gray-400">Ahead</span>
                    <span className={`px-2 py-0.5 rounded text-xs ${gitStatus.ahead > 0 ? 'bg-green-600/20 text-green-400' : 'bg-gray-700 text-gray-400'}`}>
                      {gitStatus.ahead || 0} commits
                    </span>
                  </div>
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-gray-400">Behind</span>
                    <span className={`px-2 py-0.5 rounded text-xs ${gitStatus.behind > 0 ? 'bg-red-600/20 text-red-400' : 'bg-gray-700 text-gray-400'}`}>
                      {gitStatus.behind || 0} commits
                    </span>
                  </div>
                </div>

                {gitStatus.last_commit && (
                  <div className="bg-gray-700/50 rounded-lg p-3">
                    <p className="text-xs text-gray-500 mb-1">Último Commit</p>
                    <p className="text-sm font-mono text-white">{gitStatus.last_commit?.substring(0, 7)}</p>
                    {gitStatus.last_commit_date && (
                      <p className="text-xs text-gray-500 mt-1">
                        {new Date(gitStatus.last_commit_date).toLocaleString('pt-BR')}
                      </p>
                    )}
                  </div>
                )}
              </div>
            ) : (
              <div className="text-center py-8 text-gray-500">
                <GitBranch className="h-12 w-12 mx-auto mb-2 opacity-50" />
                <p>Configure o Git para ver o status</p>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Commit History */}
      {activeTab === 'git' && gitLogs.length > 0 && (
        <div className="bg-gray-800 rounded-lg p-6 border border-gray-700">
          <div className="flex items-center gap-2 mb-4">
            <History className="h-5 w-5 text-green-400" />
            <h2 className="text-lg font-semibold text-white">Histórico de Commits</h2>
          </div>
          <div className="space-y-2 max-h-[300px] overflow-y-auto">
            {gitLogs.slice(0, 10).map((commit, index) => (
              <div 
                key={commit.hash || index}
                className="flex items-start gap-3 p-3 bg-gray-700/50 rounded-lg hover:bg-gray-700 transition"
              >
                <div className="flex-shrink-0 w-8 h-8 bg-gradient-to-br from-blue-600 to-blue-700 rounded-full flex items-center justify-center text-white text-xs font-mono">
                  {commit.hash?.substring(0, 6) || index}
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-white truncate">{commit.message}</p>
                  <p className="text-xs text-gray-500">
                    {commit.author} - {commit.date ? new Date(commit.date).toLocaleString('pt-BR') : ''}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};

export default Settings;
SETTINGSEOF

echo -e "${GREEN}[OK] Settings.js criado${NC}"

# ============================================
# 2. CRIAR VIEWS DJANGO PARA SETTINGS
# ============================================
echo ""
echo -e "${YELLOW}[2/5] Criando views Django para Settings...${NC}"

cat > ${BACKEND_DIR}/settings_views.py << 'VIEWSEOF'
# Django Views para Settings - LOR-CGR

import os
import json
import subprocess
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from django.conf import settings

SETTINGS_FILE = os.path.join(settings.BASE_DIR, 'settings.json')

DEFAULT_SETTINGS = {
    'librenms_enabled': True,
    'librenms_url': '',
    'librenms_api_token': '',
    'phpipam_enabled': True,
    'phpipam_url': '',
    'phpipam_app_id': '',
    'phpipam_app_key': '',
    'phpipam_user': '',
    'phpipam_password': '',
    'ai_enabled': True,
    'ai_provider': 'groq',
    'groq_api_key': '',
    'groq_model': 'llama-3.3-70b-versatile',
    'ai_temperature': 0.7,
    'ai_max_tokens': 4096,
    'ai_system_prompt': '',
    'git_enabled': False,
    'git_token': '',
    'git_repo_url': '',
    'git_branch': 'main',
    'git_auto_backup': False,
    'git_backup_frequency': 'daily',
}

def load_settings():
    if os.path.exists(SETTINGS_FILE):
        try:
            with open(SETTINGS_FILE, 'r') as f:
                saved = json.load(f)
                return {**DEFAULT_SETTINGS, **saved}
        except: pass
    return DEFAULT_SETTINGS.copy()

def save_settings(data):
    try:
        with open(SETTINGS_FILE, 'w') as f:
            json.dump(data, f, indent=2)
        return True
    except: return False

@csrf_exempt
@require_http_methods(["GET"])
def settings_get(request):
    settings_data = load_settings()
    safe = settings_data.copy()
    for k in ['librenms_api_token', 'phpipam_app_key', 'phpipam_password', 'groq_api_key', 'git_token']:
        if safe.get(k): safe[k] = '***'
    return JsonResponse({'success': True, 'settings': safe})

@csrf_exempt
@require_http_methods(["POST"])
def settings_save(request):
    try:
        data = json.loads(request.body)
        current = load_settings()
        for key in DEFAULT_SETTINGS:
            if key in data and data[key] != '***':
                current[key] = data[key]
        if save_settings(current):
            return JsonResponse({'success': True, 'message': 'Salvo!'})
        return JsonResponse({'success': False, 'error': 'Erro ao salvar'}, status=500)
    except Exception as e:
        return JsonResponse({'success': False, 'error': str(e)}, status=400)

@csrf_exempt
@require_http_methods(["POST"])
def settings_test_librenms(request):
    try:
        import requests
        data = json.loads(request.body)
        s = load_settings()
        url = data.get('url') or s.get('librenms_url', '')
        token = data.get('token') or s.get('librenms_api_token', '')
        r = requests.get(f"{url.rstrip('/')}/api/v0/system", headers={'X-Auth-Token': token}, timeout=10)
        return JsonResponse({'success': r.status_code == 200, 'message' if r.status_code == 200 else 'error': 'OK' if r.status_code == 200 else f'HTTP {r.status_code}'})
    except Exception as e:
        return JsonResponse({'success': False, 'error': str(e)})

@csrf_exempt
@require_http_methods(["POST"])
def settings_test_phpipam(request):
    try:
        import requests
        data = json.loads(request.body)
        s = load_settings()
        url = data.get('url') or s.get('phpipam_url', '')
        app_id = data.get('app_id') or s.get('phpipam_app_id', '')
        app_key = data.get('app_key') or s.get('phpipam_app_key', '')
        r = requests.get(f"{url.rstrip('/')}/api/{app_id}/user/", headers={'token': app_key}, timeout=10)
        return JsonResponse({'success': r.status_code == 200, 'message' if r.status_code == 200 else 'error': 'OK' if r.status_code == 200 else f'HTTP {r.status_code}'})
    except Exception as e:
        return JsonResponse({'success': False, 'error': str(e)})

@csrf_exempt
@require_http_methods(["POST"])
def settings_test_groq(request):
    try:
        import requests
        data = json.loads(request.body)
        s = load_settings()
        key = data.get('api_key') or s.get('groq_api_key', '')
        model = data.get('model') or s.get('groq_model', 'llama-3.3-70b-versatile')
        r = requests.post('https://api.groq.com/openai/v1/chat/completions',
            headers={'Authorization': f'Bearer {key}', 'Content-Type': 'application/json'},
            json={'model': model, 'messages': [{'role': 'user', 'content': 'Hi'}], 'max_tokens': 5}, timeout=30)
        return JsonResponse({'success': r.status_code == 200, 'message' if r.status_code == 200 else 'error': 'OK' if r.status_code == 200 else r.json().get('error', {}).get('message', f'HTTP {r.status_code}')})
    except Exception as e:
        return JsonResponse({'success': False, 'error': str(e)})

@csrf_exempt
@require_http_methods(["GET"])
def settings_git_status(request):
    try:
        base = settings.BASE_DIR
        def run(args):
            return subprocess.run(['git']+args, cwd=base, capture_output=True, text=True, timeout=30).stdout.strip()
        branch = run(['rev-parse', '--abbrev-ref', 'HEAD'])
        remote = run(['config', '--get', 'remote.origin.url'])
        ab = run(['rev-list', '--left-right', '--count', f'origin/{branch}...{branch}']).split()
        ahead, behind = int(ab[1]) if len(ab)>1 else 0, int(ab[0]) if ab else 0
        last = run(['rev-parse', 'HEAD'])
        last_date = run(['log', '-1', '--format=%ci'])
        status = run(['status', '--porcelain'])
        staged = unstaged = untracked = 0
        for line in status.split('\n'):
            if not line: continue
            if line[0] in 'MADRC': staged += 1
            elif len(line)>1 and line[1] in 'MD': unstaged += 1
            elif line.startswith('??'): untracked += 1
        return JsonResponse({'success': True, 'branch': branch, 'remote': remote, 'ahead': ahead, 'behind': behind, 'last_commit': last, 'last_commit_date': last_date, 'staged': staged, 'unstaged': unstaged, 'untracked': untracked})
    except Exception as e:
        return JsonResponse({'success': False, 'error': str(e)})

@csrf_exempt
@require_http_methods(["GET"])
def settings_git_logs(request):
    try:
        base = settings.BASE_DIR
        r = subprocess.run(['git', 'log', '--oneline', '-20', '--format=%H|%s|%an|%ci'], cwd=base, capture_output=True, text=True, timeout=30)
        commits = [{'hash': l.split('|')[0], 'message': l.split('|')[1], 'author': l.split('|')[2], 'date': l.split('|')[3]} for l in r.stdout.strip().split('\n') if l and len(l.split('|'))>=4]
        return JsonResponse({'success': True, 'commits': commits})
    except Exception as e:
        return JsonResponse({'success': False, 'error': str(e)})

@csrf_exempt
@require_http_methods(["POST"])
def settings_git_backup(request):
    try:
        from datetime import datetime
        data = json.loads(request.body)
        s = load_settings()
        token = data.get('token') or s.get('git_token', '')
        repo = data.get('repo_url') or s.get('git_repo_url', '')
        branch = data.get('branch') or s.get('git_branch', 'main')
        if not token or not repo:
            return JsonResponse({'success': False, 'error': 'Token e URL são obrigatórios'})
        base = settings.BASE_DIR
        def run(args):
            return subprocess.run(['git']+args, cwd=base, capture_output=True, text=True, timeout=60)
        auth_url = repo.replace('https://', f'https://{token}@') if repo.startswith('https://') else repo
        run(['remote', 'set-url', 'origin', auth_url])
        run(['add', '-A'])
        status = run(['status', '--porcelain']).stdout.strip()
        if not status:
            return JsonResponse({'success': True, 'message': 'Nenhuma mudança', 'commit_hash': ''})
        msg = f"Backup LOR-CGR - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
        run(['commit', '-m', msg])
        r = run(['push', 'origin', branch])
        if r.returncode != 0:
            return JsonResponse({'success': False, 'error': r.stderr or 'Push failed'})
        h = run(['rev-parse', 'HEAD']).stdout.strip()
        return JsonResponse({'success': True, 'message': 'Backup enviado!', 'commit_hash': h, 'files_changed': len(status.split('\n'))})
    except Exception as e:
        return JsonResponse({'success': False, 'error': str(e)})

@csrf_exempt
@require_http_methods(["POST"])
def settings_git_pull(request):
    try:
        s = load_settings()
        base = settings.BASE_DIR
        token = s.get('git_token', '')
        repo = s.get('git_repo_url', '')
        branch = s.get('git_branch', 'main')
        if token and repo.startswith('https://'):
            auth = repo.replace('https://', f'https://{token}@')
            subprocess.run(['git', 'remote', 'set-url', 'origin', auth], cwd=base, capture_output=True, timeout=30)
        r = subprocess.run(['git', 'pull', 'origin', branch], cwd=base, capture_output=True, text=True, timeout=60)
        return JsonResponse({'success': r.returncode == 0, 'message' if r.returncode == 0 else 'error': 'OK' if r.returncode == 0 else r.stderr})
    except Exception as e:
        return JsonResponse({'success': False, 'error': str(e)})
VIEWSEOF

echo -e "${GREEN}[OK] settings_views.py criado${NC}"

# ============================================
# 3. ADICIONAR URLS AO URLS.PY
# ============================================
echo ""
echo -e "${YELLOW}[3/5] Adicionando URLs...${NC}"

# Verificar se as URLs já existem
if grep -q "settings_get" ${BACKEND_DIR}/lorcgr/urls.py 2>/dev/null; then
    echo -e "${GREEN}[OK] URLs já existem${NC}"
else
    # Adicionar imports e URLs
    cat >> ${BACKEND_DIR}/lorcgr/urls.py << 'URLSEOF'

# Settings API
from settings_views import (
    settings_get, settings_save, settings_test_librenms, settings_test_phpipam,
    settings_test_groq, settings_git_status, settings_git_logs, settings_git_backup, settings_git_pull
)

urlpatterns += [
    path('api/settings/get/', settings_get, name='settings_get'),
    path('api/settings/save/', settings_save, name='settings_save'),
    path('api/settings/test/librenms/', settings_test_librenms, name='settings_test_librenms'),
    path('api/settings/test/phpipam/', settings_test_phpipam, name='settings_test_phpipam'),
    path('api/settings/test/groq/', settings_test_groq, name='settings_test_groq'),
    path('api/settings/git/status/', settings_git_status, name='settings_git_status'),
    path('api/settings/git/logs/', settings_git_logs, name='settings_git_logs'),
    path('api/settings/git/backup/', settings_git_backup, name='settings_git_backup'),
    path('api/settings/git/pull/', settings_git_pull, name='settings_git_pull'),
]
URLSEOF
    echo -e "${GREEN}[OK] URLs adicionadas${NC}"
fi

# ============================================
# 4. ATUALIZAR APP.JS DO FRONTEND
# ============================================
echo ""
echo -e "${YELLOW}[4/5] Verificando App.js...${NC}"

# Verificar se Settings já está importado
if grep -q "Settings" ${FRONTEND_DIR}/src/App.js 2>/dev/null; then
    echo -e "${GREEN}[OK] Settings já está no App.js${NC}"
else
    echo ""
    echo -e "${RED}============================================${NC}"
    echo -e "${RED}AÇÃO MANUAL NECESSÁRIA NO APP.JS${NC}"
    echo -e "${RED}============================================${NC}"
    echo ""
    echo "Adicione as seguintes linhas ao App.js:"
    echo ""
    echo "1. No topo, adicione o import:"
    echo "   import Settings from './components/Settings';"
    echo ""
    echo "2. No menu de navegação, adicione:"
    echo "   { id: 'settings', label: 'Configurações', icon: Settings }"
    echo ""
    echo "3. No switch de renderização, adicione:"
    echo "   case 'settings': return <Settings />;"
    echo ""
fi

# ============================================
# 5. RECONSTRUIR FRONTEND E REINICIAR
# ============================================
echo ""
echo -e "${YELLOW}[5/5] Reconstruindo frontend...${NC}"

cd ${FRONTEND_DIR}
npm run build 2>&1 | tail -20

echo ""
echo -e "${YELLOW}Reiniciando serviços...${NC}"
systemctl restart lorcgr 2>/dev/null || echo "[AVISO] systemctl não disponível"

echo ""
echo "============================================"
echo -e "${GREEN}DEPLOY CONCLUÍDO!${NC}"
echo "============================================"
echo ""
echo "Agora acesse a interface e clique em 'Configurações'"
echo "no menu lateral para configurar o GitHub Backup."
