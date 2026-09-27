from __future__ import annotations

from playwright.async_api import (
    Browser,
    BrowserContext,
    Page,
    Playwright,
    async_playwright,
)


class NtesSession:

    def __init__(
            self,
            headless: bool = True,
    ):
        self.headless = headless

        self._playwright: Playwright | None = None
        self._browser: Browser | None = None
        self._context: BrowserContext | None = None

    async def start(self) -> None:
        self._playwright = await async_playwright().start()

        self._browser = await self._playwright.chromium.launch(
            headless=self.headless,
            args=[
                "--disable-blink-features=AutomationControlled",
            ],
        )

        self._context = await self._browser.new_context(
            locale="en-IN",
            timezone_id="Asia/Kolkata",
            viewport={
                "width": 1440,
                "height": 900,
            },
        )

    async def page(self) -> Page:

        if self._context is None:
            await self.start()

        assert self._context is not None

        return await self._context.new_page()

    async def close(self) -> None:

        if self._context:
            await self._context.close()

        if self._browser:
            await self._browser.close()

        if self._playwright:
            await self._playwright.stop()

        self._context = None
        self._browser = None
        self._playwright = None