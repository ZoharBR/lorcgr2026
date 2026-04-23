"""
urls.py - Versão Corrigida
Substituir em: /opt/lorcgr/devices/urls.py

Aceita URLs com ou sem barra final para evitar 404s
"""

from django.urls import path, re_path
from . import views_simple

urlpatterns = [
    # Devices - aceitar com ou sem barra
    re_path(r'^list/?$', views_simple.api_list_devices, name='api_list_devices'),
    re_path(r'^save/?$', views_simple.api_save_device, name='api_save_device'),
    re_path(r'^delete/?$', views_simple.api_delete_device, name='api_delete_device'),
    
    # Dashboard e Stats
    re_path(r'^dashboard/?$', views_simple.api_dashboard_stats, name='api_dashboard_stats'),
    re_path(r'^interfaces/stats/?$', views_simple.api_interfaces_stats, name='api_interfaces_stats'),
    
    # Outras APIs
    re_path(r'^device-types/?$', views_simple.api_device_types, name='api_device_types'),
    re_path(r'^discovery/?$', views_simple.api_discovery, name='api_discovery'),
    re_path(r'^icmp/check/?$', views_simple.api_icmp_check, name='api_icmp_check'),
    re_path(r'^icmp/check/(?P<device_id>\d+)/?$', views_simple.api_icmp_check, name='api_icmp_check_device'),
    re_path(r'^backup/list/?$', views_simple.api_backup_list, name='api_backup_list'),
    re_path(r'^backup/run/?$', views_simple.api_backup_run, name='api_backup_run'),
    re_path(r'^audit-logs/?$', views_simple.api_audit_logs, name='api_audit_logs'),
]
