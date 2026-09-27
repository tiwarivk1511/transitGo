import os
from dotenv import load_dotenv

load_dotenv()

class Settings:
    PROJECT_NAME: str = "TransitGo Backend"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"

    REDIS_URL: str = os.getenv("REDIS_URL", "redis://localhost:6379/0")
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite+aiosqlite:///./transitgo.db")

    RAIL_RADAR_API_KEY: str = os.getenv("RAIL_RADAR_API_KEY", "")

settings = Settings()
