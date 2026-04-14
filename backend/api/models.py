from django.db import models

class ServiceConfig(models.Model):
    """Configuração dos serviços de rede"""
    SERVICE_TYPES = [
        ('librenms', 'LibreNMS'),
        ('phpipam', 'phpIPAM'),
        ('zabbix', 'Zabbix'),
        ('grafana', 'Grafana'),
        ('nexterm', 'Nexterm'),
    ]
    
    service_type = models.CharField(max_length=20, choices=SERVICE_TYPES, unique=True)
    name = models.CharField(max_length=50)
    url = models.CharField(max_length=255)
    api_url = models.CharField(max_length=255, blank=True, default='')
    api_key = models.CharField(max_length=255, blank=True, default='')
    api_secret = models.CharField(max_length=255, blank=True, default='')
    username = models.CharField(max_length=100, blank=True, default='')
    password = models.CharField(max_length=255, blank=True, default='')
    enabled = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        ordering = ['service_type']
    
    def __str__(self):
        return self.name

class SystemSettings(models.Model):
    """Configurações gerais do sistema"""
    key = models.CharField(max_length=100, unique=True)
    value = models.TextField()
    description = models.CharField(max_length=255, blank=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return self.key


class SecurityConfig(models.Model):
    """Configurações de segurança - Gerenciável via Admin LOR-CGR"""
    
    CONFIG_TYPES = [
        ('cors', 'CORS - Origens Permitidas'),
        ('allowed_hosts', 'Allowed Hosts - Domínios/IPs Permitidos'),
    ]
    
    config_type = models.CharField(
        max_length=20, 
        choices=CONFIG_TYPES, 
        unique=True,
        verbose_name="Tipo de Configuração"
    )
    
    value = models.TextField(
        verbose_name="Valores",
        help_text="Lista de URLs/IPs separados por vírgula. Ex: http://localhost:3000,http://45.71.242.131:3000"
    )
    
    is_active = models.BooleanField(
        default=True,
        verbose_name="Ativo",
        help_text="Se desativado, usa configuração padrão (permite todos)"
    )
    
    description = models.CharField(
        max_length=255, 
        blank=True, 
        verbose_name="Descrição",
        help_text="Descrição opcional desta configuração"
    )
    
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Criado em")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="Atualizado em")
    
    class Meta:
        ordering = ['config_type']
        verbose_name = "Configuração de Segurança"
        verbose_name_plural = "Configurações de Segurança"
    
    def __str__(self):
        return f"{self.get_config_type_display()}"
    
    def get_values_list(self):
        """Retorna lista de valores limpos"""
        if not self.value:
            return []
        return [v.strip() for v in self.value.split(',') if v.strip()]
