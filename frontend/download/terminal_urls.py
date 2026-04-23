# URLs para Terminal Sessions - Django
# Salvar em: /opt/lorcgr/terminal/urls.py

from django.urls import path
from . import views

urlpatterns = [
    path('sessions/', views.list_sessions, name='list_sessions'),
    path('sessions/save/', views.save_session, name='save_session'),
    path('sessions/delete/', views.delete_session, name='delete_session'),
    path('sessions/<str:session_id>/log/', views.get_session_log, name='get_session_log'),
]
