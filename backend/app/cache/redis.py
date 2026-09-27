from __future__ import annotations

import json

import redis.asyncio as redis


class RedisCache:

    def __init__(
            self,
            url: str,
    ):
        self.client = redis.from_url(
            url,
            decode_responses=True,
        )

    async def get(
            self,
            key: str,
    ):

        value = await self.client.get(key)

        if value is None:
            return None

        try:
            return json.loads(value)
        except json.JSONDecodeError:
            return value

    async def set(
            self,
            key: str,
            value,
            ttl: int,
    ):

        payload = json.dumps(
            value,
            default=str,
        )

        await self.client.set(
            key,
            payload,
            ex=ttl,
        )

    async def delete(
            self,
            key: str,
    ):

        await self.client.delete(key)

    async def close(self):

        await self.client.aclose()