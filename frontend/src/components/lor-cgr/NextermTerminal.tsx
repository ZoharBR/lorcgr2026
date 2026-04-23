'use client';

import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import {
  Maximize2,
  Minimize2,
  RefreshCw,
  ExternalLink,
  AlertCircle,
  Monitor,
  Loader2
} from 'lucide-react';

interface NextermTerminalProps {
  onLoad?: () => void;
  onError?: () => void;
}

export default function NextermTerminal({ onLoad, onError }: NextermTerminalProps) {
  const [isLoading, setIsLoading] = useState(true);
  const [hasError, setHasError] = useState(false);
  const [isFullscreen, setIsFullscreen] = useState(false);

  const nextermUrl = '/nexterm/';

  const handleIframeLoad = () => {
    setIsLoading(false);
    setHasError(false);
    onLoad?.();
  };

  const handleIframeError = () => {
    setIsLoading(false);
    setHasError(true);
    onError?.();
  };

  const handleRefresh = () => {
    setIsLoading(true);
    setHasError(false);
    // Force iframe reload
    const iframe = document.getElementById('nexterm-iframe') as HTMLIFrameElement;
    if (iframe) {
      iframe.src = iframe.src;
    }
  };

  const openInNewTab = () => {
    window.open(nextermUrl, '_blank');
  };

  const toggleFullscreen = () => {
    setIsFullscreen(!isFullscreen);
  };

  if (isFullscreen) {
    return (
      <div className="fixed inset-0 z-50 bg-background">
        {/* Fullscreen Header */}
        <div className="h-12 bg-card border-b flex items-center justify-between px-4">
          <div className="flex items-center gap-3">
            <Monitor className="h-5 w-5 text-primary" />
            <span className="font-semibold">Nexterm - Terminal & RDP</span>
            <Badge variant="secondary" className="text-xs">
              Tela Cheia
            </Badge>
          </div>
          <div className="flex items-center gap-2">
            <Button variant="ghost" size="sm" onClick={handleRefresh}>
              <RefreshCw className="h-4 w-4 mr-2" />
              Recarregar
            </Button>
            <Button variant="ghost" size="sm" onClick={openInNewTab}>
              <ExternalLink className="h-4 w-4 mr-2" />
              Nova Aba
            </Button>
            <Button variant="outline" size="sm" onClick={toggleFullscreen}>
              <Minimize2 className="h-4 w-4 mr-2" />
              Sair da Tela Cheia
            </Button>
          </div>
        </div>

        {/* Fullscreen Iframe */}
        <div className="calc-height-full">
          {isLoading && (
            <div className="absolute inset-0 flex items-center justify-center bg-background">
              <div className="flex flex-col items-center gap-4">
                <Loader2 className="h-8 w-8 animate-spin text-primary" />
                <span className="text-muted-foreground">Carregando Nexterm...</span>
              </div>
            </div>
          )}
          <iframe
            id="nexterm-iframe"
            src={nextermUrl}
            className="w-full h-full border-0"
            onLoad={handleIframeLoad}
            onError={handleIframeError}
            allow="clipboard-read; clipboard-write; fullscreen"
            title="Nexterm Terminal"
          />
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="p-2 bg-primary/10 rounded-lg">
            <Monitor className="h-6 w-6 text-primary" />
          </div>
          <div>
            <h2 className="text-2xl font-bold tracking-tight">Terminal & RDP</h2>
            <p className="text-muted-foreground">
              Acesso remoto via SSH, VNC e RDP - Powered by Nexterm
            </p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="outline" size="sm" onClick={handleRefresh}>
            <RefreshCw className="h-4 w-4 mr-2" />
            Recarregar
          </Button>
          <Button variant="outline" size="sm" onClick={openInNewTab}>
            <ExternalLink className="h-4 w-4 mr-2" />
            Nova Aba
          </Button>
          <Button variant="default" size="sm" onClick={toggleFullscreen}>
            <Maximize2 className="h-4 w-4 mr-2" />
            Tela Cheia
          </Button>
        </div>
      </div>

      {/* Info Banner */}
      <div className="bg-card border rounded-lg p-4">
        <div className="flex items-start gap-3">
          <Monitor className="h-5 w-5 text-primary mt-0.5" />
          <div className="flex-1">
            <h3 className="font-medium">Nexterm - Gerenciador de Servidores</h3>
            <p className="text-sm text-muted-foreground mt-1">
              Conecte-se aos seus dispositivos via SSH, VNC ou RDP. Adicione servidores,
              organize em pastas e gerencie acessos de forma centralizada.
            </p>
          </div>
          <Badge variant="secondary">
            v1.0
          </Badge>
        </div>
      </div>

      {/* Iframe Container */}
      <div className="relative bg-card border rounded-lg overflow-hidden" style={{ height: 'calc(100vh - 280px)', minHeight: '500px' }}>
        {isLoading && (
          <div className="absolute inset-0 flex items-center justify-center bg-background/80 z-10">
            <div className="flex flex-col items-center gap-4">
              <Loader2 className="h-8 w-8 animate-spin text-primary" />
              <span className="text-muted-foreground">Carregando Nexterm...</span>
            </div>
          </div>
        )}

        {hasError && (
          <div className="absolute inset-0 flex items-center justify-center bg-background z-10">
            <div className="flex flex-col items-center gap-4 text-center p-8">
              <AlertCircle className="h-12 w-12 text-destructive" />
              <div>
                <h3 className="text-lg font-semibold">Erro ao carregar Nexterm</h3>
                <p className="text-muted-foreground mt-1">
                  Não foi possível conectar ao serviço de terminal.
                </p>
              </div>
              <Button onClick={handleRefresh}>
                <RefreshCw className="h-4 w-4 mr-2" />
                Tentar Novamente
              </Button>
            </div>
          </div>
        )}

        <iframe
          id="nexterm-iframe"
          src={nextermUrl}
          className="w-full h-full border-0"
          onLoad={handleIframeLoad}
          onError={handleIframeError}
          allow="clipboard-read; clipboard-write; fullscreen"
          title="Nexterm Terminal"
        />
      </div>
    </div>
  );
}
