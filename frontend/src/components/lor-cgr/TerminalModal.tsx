'use client';

import { useState } from 'react';
import { X, Maximize2, Minimize2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
} from '@/components/ui/dialog';
import Multiterminal from './Multiterminal';
import { Device } from '@/types/lor-cgr';

interface TerminalModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  devices: Device[];
  sessions?: { id: string; device: Device }[];
  onConnect: (deviceId: number) => void;
  initialDevice?: Device | null;
}

export default function TerminalModal({
  open,
  onOpenChange,
  devices,
  sessions,
  onConnect,
  initialDevice
}: TerminalModalProps) {
  const [isFullscreen, setIsFullscreen] = useState(false);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent
        className={`${isFullscreen ? 'max-w-full w-full h-screen m-0' : 'max-w-6xl w-[95vw] h-[85vh]'}`}
        showCloseButton={false}
      >
        <div className="flex flex-col h-full">
          {/* Header */}
          <div className="flex items-center justify-between border-b pb-2 mb-2">
            <div className="flex items-center gap-2">
              <h2 className="text-lg font-semibold">Terminal SSH</h2>
              {initialDevice && (
                <span className="text-sm text-muted-foreground">
                  - {initialDevice.name}
                </span>
              )}
            </div>
            <div className="flex items-center gap-1">
              <Button
                variant="ghost"
                size="icon"
                onClick={() => setIsFullscreen(!isFullscreen)}
              >
                {isFullscreen ? (
                  <Minimize2 className="h-4 w-4" />
                ) : (
                  <Maximize2 className="h-4 w-4" />
                )}
              </Button>
              <Button
                variant="ghost"
                size="icon"
                onClick={() => onOpenChange(false)}
              >
                <X className="h-4 w-4" />
              </Button>
            </div>
          </div>

          {/* Terminal Content */}
          <div className="flex-1 overflow-hidden">
            <Multiterminal
              devices={devices}
              sessions={sessions}
              onConnect={onConnect}
              isOpen={true}
              onClose={() => onOpenChange(false)}
            />
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
