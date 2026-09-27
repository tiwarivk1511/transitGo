from __future__ import annotations

import httpx


class OfficialWebClient:

    def __init__(
            self,
            base_url: str,
    ):

        self.base_url = base_url.rstrip("/")

        self.client = httpx.AsyncClient(
            timeout=30,
            follow_redirects=True,
        )

    async def fetch(
            self,
            path: str,
    ):

        response = await self.client.get(
            f"{self.base_url}/{path.lstrip('/')}"
        )

        response.raise_for_status()

        return response.text

    async def close(self):

        await self.client.aclose()