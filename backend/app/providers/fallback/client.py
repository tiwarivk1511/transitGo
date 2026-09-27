class FallbackProvider:

    async def get_cached(
            self,
            key: str,
    ):

        from app.main import sqlite_cache

        return await sqlite_cache.get(key)