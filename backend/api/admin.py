from django.contrib import admin
from .models import ServiceConfig, SystemSettings, SecurityConfig

@admin.register(ServiceConfig)
class ServiceConfigAdmin(admin.ModelAdmin):
    list_display = ('service_type', 'name', 'url', 'enabled', 'updated_at')
    list_filter = ('service_type', 'enabled')
    search_fields = ('name', 'url', 'service_type')
    readonly_fields = ('created_at', 'updated_at')
    
    fieldsets = (
        ('Informações Básicas', {
            'fields': ('service_type', 'name', 'enabled')
        }),
        ('URLs do Serviço', {
            'fields': ('url', 'api_url'),
            'description': 'URLs de acesso ao serviço'
        }),
        ('Credenciais de Acesso', {
            'fields': ('username', 'password', 'api_key', 'api_secret'),
            'classes': ('collapse',),
            'description': '⚠️ Credenciais sensíveis - Mantenha seguras!'
        }),
        ('Metadados', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    def get_readonly_fields(self, request, obj=None):
        if obj:  # Editando objeto existente
            return self.readonly_fields + ('service_type',)
        return self.readonly_fields

@admin.register(SystemSettings)
class SystemSettingsAdmin(admin.ModelAdmin):
    list_display = ('key', 'description', 'updated_at')
    search_fields = ('key', 'description')
    readonly_fields = ('updated_at',)
    
    fieldsets = (
        ('Configuração', {
            'fields': ('key', 'value', 'description')
        }),
        ('Metadados', {
            'fields': ('updated_at',),
            'classes': ('collapse',)
        }),
    )

# Título customizado no Admin
admin.site.site_header = "LOR-CGR Administração"
admin.site.site_title = "LOR-CGR Admin"
admin.site.index_title = "Bem-vindo ao Painel LOR-CGR"



# ===========================================
# ADMIN DE CONFIGURAÇÕES DE SEGURANÇA
# ===========================================

@admin.register(SecurityConfig)
class SecurityConfigAdmin(admin.ModelAdmin):
    list_display = ('config_type', 'is_active', 'updated_at', 'description')
    list_filter = ('config_type', 'is_active')
    search_fields = ('description', 'value')
    
    fieldsets = (
        ('Tipo de Configuração', {
            'fields': ('config_type', 'is_active', 'description'),
            'description': 'Selecione o tipo e se está ativo'
        }),
        ('Valores Permitidos', {
            'fields': ('value',),
            'description': '''
                <strong>Formato:</strong> URLs ou IPs separados por vírgula<br><br>
                
                <strong>Exemplos de CORS:</strong><br>
                • http://localhost:3000<br>
                • http://45.71.242.131:3000<br>
                • https://seu-dominio.com<br><br>
                
                <strong>Exemplos de Allowed Hosts:</strong><br>
                • 45.71.242.131<br>
                • localhost<br>
                • seu-dominio.com<br><br>
                
                ⚠️ <strong>Dica:</strong> Deixe vazio e desmarque "Ativo" para permitir todos (modo desenvolvimento)
            '''
        }),
        ('Metadados', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    readonly_fields = ('created_at', 'updated_at')
