from __future__ import annotations

from datetime import datetime, timezone

from app.providers.base import (
    ProviderResult,
    ProviderType,
)
from app.providers.ntes.parser import NtesParser
from app.providers.ntes.session import NtesSession


class NtesClient:

    provider_type = ProviderType.NTES

    def __init__(
            self,
            base_url: str,
            headless: bool = True,
    ):
        self.base_url = base_url.rstrip("/") + "/"

        self.session = NtesSession(
            headless=headless,
        )

    async def get_page(
            self,
            path: str = "",
    ):

        page = await self.session.page()

        url = self.base_url + path.lstrip("/")

        await page.goto(
            url,
            wait_until="domcontentloaded",
            timeout=30_000,
        )

        await page.wait_for_timeout(1500)

        return page

    async def get_train_schedule(
            self,
            train_number: str,
    ) -> ProviderResult:

        page = None

        try:

            page = await self.get_page()

            # IMPORTANT:
            # The exact current NTES DOM interaction should be
            # discovered from the live page rather than assuming
            # undocumented endpoints.

            content = await page.content()

            parsed = NtesParser.parse_schedule(
                content
            )

            return ProviderResult(
                success=True,
                data=parsed,
                provider=self.provider_type,
                fetched_at=datetime.now(
                    timezone.utc
                ),
            )

        except Exception as exc:

            return ProviderResult(
                success=False,
                provider=self.provider_type,
                error=str(exc),
            )

        finally:

            if page:
                await page.close()

    async def get_train_status(
            self,
            train_number: str,
            journey_date: str,
    ) -> ProviderResult:

        page = None

        try:

            page = await self.get_page()

            content = await page.content()

            parsed = NtesParser.parse_train_status(
                content
            )

            return ProviderResult(
                success=True,
                data=parsed,
                provider=self.provider_type,
                fetched_at=datetime.now(
                    timezone.utc
                ),
            )

        except Exception as exc:

            return ProviderResult(
                success=False,
                provider=self.provider_type,
                error=str(exc),
            )

        finally:

            if page:
                await page.close()

    async def close(self):

        await self.session.close()