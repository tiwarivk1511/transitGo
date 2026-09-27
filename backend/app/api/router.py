from fastapi import APIRouter
from app.api import trains, stations, health

api_router = APIRouter()

api_router.include_router(health.router, prefix="/health", tags=["health"])
api_router.include_router(trains.router, prefix="/trains", tags=["trains"])
api_router.include_router(stations.router, prefix="/stations", tags=["stations"])
