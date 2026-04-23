from django.urls import path
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
import json

# Import existing views
from . import views

# Import GBIC API
from .gbic_api import gbic_list, gbic_detail

urlpatterns = [
    # Device APIs
    path('api/list/', views.device_list, name='device_list'),
    path('api/dashboard/', views.dashboard_stats, name='dashboard_stats'),
    path('api/save/', views.device_save, name='device_save'),
    path('api/delete/', views.device_delete, name='device_delete'),
    path('api/discovery/', views.device_discovery, name='device_discovery'),
    
    # Backup APIs
    path('api/backup/list/', views.backup_list, name='backup_list'),
    path('api/backup/run/', views.backup_run, name='backup_run'),
    path('api/backup/download/', views.backup_download, name='backup_download'),
    path('api/backup/delete/', views.backup_delete, name='backup_delete'),
    
    # Interface APIs
    path('api/interfaces/', views.interface_list, name='interface_list'),
    path('api/interfaces/stats/', views.interface_stats, name='interface_stats'),
    
    # Audit Logs
    path('api/audit-logs/', views.audit_logs, name='audit_logs'),
    
    # Terminal Sessions
    path('api/terminal-sessions/', views.terminal_sessions, name='terminal_sessions'),
    
    # Manual
    path('api/manual/', views.manual_list, name='manual_list'),
    path('api/manual/save/', views.manual_save, name='manual_save'),
    
    # GBIC APIs - Monitoramento individual
    path('api/gbic/list/', gbic_list, name='gbic_list'),
    path('api/gbic/<int:gbic_id>/', gbic_detail, name='gbic_detail'),
]
