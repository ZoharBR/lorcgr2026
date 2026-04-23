import subprocess
import time
from django.core.management.base import BaseCommand
from django.utils import timezone
from equipments.models import Equipment, EquipmentStatus, PingHistory


class Command(BaseCommand):
    help = 'Verifica status de todos equipamentos via ICMP ping'

    def add_arguments(self, parser):
        parser.add_argument(
            '--count', 
            type=int, 
            default=5, 
            help='Número de pings (padrão: 5)'
        )
        parser.add_argument(
            '--timeout', 
            type=int, 
            default=1, 
            help='Timeout em segundos (padrão: 1)'
        )

    def handle(self, *args, **options):
        count = options['count']
        timeout = options['timeout']
        
        self.stdout.write(f"🔍 Iniciando verificação de {count} pings por equipamento...")
        
        equipments = Equipment.objects.filter(primary_ip__isnull=False)
        total = equipments.count()
        
        for i, eq in enumerate(equipments, 1):
            self.stdout.write(f"\n[{i}/{total}] Verificando {eq.name} ({eq.primary_ip})...")
            
            # Executar ping
            latency, packet_loss = self.ping_host(eq.primary_ip, count, timeout)
            
            # Determinar status baseado na latência
            if packet_loss == 100:
                status = 'offline'
                is_flashing = True
            elif latency is None or latency > 100:
                status = 'degraded'
                is_flashing = False
            elif latency > 20:
                status = 'degraded'
                is_flashing = False
            else:
                status = 'online'
                is_flashing = False
            
            # Atualizar ou criar status
            status_obj, created = EquipmentStatus.objects.update_or_create(
                equipment=eq,
                defaults={
                    'status': status,
                    'latency_ms': latency,
                    'packet_loss': packet_loss,
                    'last_check': timezone.now(),
                    'is_flashing': is_flashing,
                    'consecutive_failures': (
                        0 if status != 'offline' else 
                        (EquipmentStatus.objects.filter(equipment=eq).first().consecutive_failures + 1) 
                        if not created else 1
                    ),
                    'last_success': timezone.now() if status != 'offline' else None
                }
            )
            
            # Salvar histórico (manter só últimos 1000 registros por equipamento)
            if latency is not None:
                PingHistory.objects.create(
                    equipment=eq,
                    latency_ms=latency,
                    success=(packet_loss < 100)
                )
                
                # Limpar histórico antigo
                old_records = PingHistory.objects.filter(
                    equipment=eq
                ).order_by('-timestamp')[1000:]
                for record in old_records:
                    record.delete()
            
            # Mostrar resultado
            color = {
                'online': '\033[92m',      # Verde
                'degraded': '\033[93m',    # Laranja/Amarelo
                'offline': '\033[91m'      # Vermelho
            }.get(status, '\033[0m')
            
            reset = '\033[0m'
            
            if status == 'offline':
                result = f"{color}❌ OFFLINE - Sem resposta{reset}"
            elif status == 'degraded':
                result = f"{color}⚠️ DEGRADED - {latency:.1f}ms ({packet_loss}% loss){reset}"
            else:
                result = f"{color}✅ ONLINE - {latency:.1f}ms{reset}"
            
            self.stdout.write(f"   Resultado: {result}")
        
        self.stdout.write(f"\n✅ Verificação concluída! {total} equipamentos verificados.")

    def ping_host(self, host, count=5, timeout=1):
        """Executa ping e retorna (latência média, % perda)"""
        try:
            # Comando ping (Linux)
            cmd = ['ping', '-c', str(count), '-W', str(timeout), host]
            
            output = subprocess.run(
                cmd, 
                capture_output=True, 
                text=True, 
                timeout=(count * timeout + 5)
            )
            
            # Parse do output
            lines = output.stdout.split('\n')
            
            # Encontrar linha de estatísticas
            stats_line = None
            for line in reversed(lines):
                if 'packet loss' in line or 'transmitted' in line:
                    stats_line = line
                    break
            
            if not stats_line and output.returncode != 0:
                return None, 100
            
            # Extrair packet loss
            import re
            loss_match = re.search(r'(\d+)%\s*(packet\s*)?loss', stats_line or '', re.IGNORECASE)
            packet_loss = int(loss_match.group(1)) if loss_match else 100
            
            if packet_loss == 100:
                return None, 100
            
            # Extrair latência média (ms)
            rtt_line = None
            for line in lines:
                if 'rtt min/avg/max/mdev' in line or 'round-trip' in line.lower():
                    rtt_line = line
                    break
            
            if rtt_line:
                # Formato: rtt min/avg/max/mdev = x/y/z/a ms
                avg_match = re.search(r'([\d.]+)/([\d.]+)/([\d.]+)', rtt_line)
                if avg_match:
                    latency = float(avg_match.group(2))  # avg é o segundo grupo
                    return latency, packet_loss
            
            return None, packet_loss
            
        except subprocess.TimeoutExpired:
            return None, 100
        except Exception as e:
            self.stderr.write(f"   Erro ao pingar {host}: {e}")
            return None, 100

