from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import health, ServiceConfigViewSet, SystemSettingsViewSet, SecurityConfigViewSet, dashboard_config
from .views_backup import (
    list_backups,
    create_backup,
    delete_backup,
    download_backup,
    restore_backup,
    restart_django,
    restart_nextjs,
    service_status
)

router = DefaultRouter()
router.register(r'services', ServiceConfigViewSet, basename='services')
router.register(r'settings', SystemSettingsViewSet, basename='settings')
router.register(r'security-configs', SecurityConfigViewSet, basename='security-configs')

urlpatterns = [
    path('health/', health),
    path('dashboard/', dashboard_config),
    # Backup & Restore APIs
    path('backups/', list_backups, name='list-backups'),
    path('backup/create/', create_backup, name='create-backup'),
    path('backup/delete/<str:filename>/', delete_backup, name='delete-backup'),
    path('backup/download/<str:filename>/', download_backup, name='download-backup'),
    path('backup/restore/', restore_backup, name='restore-backup'),
    # Service Management APIs
    path('restart/django/', restart_django, name='restart-django'),
    path('restart/nextjs/', restart_nextjs, name='restart-nextjs'),
    path('service/status/', service_status, name='service-status'),
    path('', include(router.urls)),
]
