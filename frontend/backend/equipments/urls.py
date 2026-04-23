from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import EquipmentViewSet, EquipmentInterfaceViewSet, SyncLogViewSet

router = DefaultRouter()
router.register(r'equipments', EquipmentViewSet, basename='equipment')
router.register(r'interfaces', EquipmentInterfaceViewSet, basename='interface')
router.register(r'sync-logs', SyncLogViewSet, basename='synclog')

urlpatterns = [
    path('', include(router.urls)),
]
