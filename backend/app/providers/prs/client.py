from __future__ import annotations

import httpx


class PrsClient:

    BASE_URL = (
        "https://indianrail.gov.in/enquiry/"
    )

    def __init__(self):

        self.client = httpx.AsyncClient(
            timeout=30,
            follow_redirects=True,
            headers={
                "User-Agent": (
                    "TransitGo/1.0 "
                    "railway-information-client"
                ),
                "Accept-Language": "en-IN,en;q=0.9",
            },
        )

    async def get(
            self,
            url: str,
    ):

        response = await self.client.get(
            url
        )

        response.raise_for_status()

        return response.text

    async def close(self):

        await self.client.aclose()