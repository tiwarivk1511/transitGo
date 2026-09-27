from __future__ import annotations

from app.providers.base import ProviderResult
from app.providers.ntes.client import NtesClient
from app.router.circuit_breaker import CircuitBreaker


class DataRouter:

    def __init__(
            self,
            ntes: NtesClient,
    ):

        self.ntes = ntes

        self.ntes_breaker = CircuitBreaker()

    async def train_status(
            self,
            train_number: str,
            journey_date: str,
    ) -> ProviderResult:

        if not self.ntes_breaker.is_open:

            result = await self.ntes.get_train_status(
                train_number,
                journey_date,
            )

            if result.success:

                self.ntes_breaker.success()

                return result

            self.ntes_breaker.failure()

        return ProviderResult(
            success=False,
            error=(
                "No live railway provider "
                "is currently available."
            ),
        )

    async def train_schedule(
            self,
            train_number: str,
    ) -> ProviderResult:

        if not self.ntes_breaker.is_open:

            result = await self.ntes.get_train_schedule(
                train_number
            )

            if result.success:

                self.ntes_breaker.success()

                return result

            self.ntes_breaker.failure()

        return ProviderResult(
            success=False,
            error=(
                "Train schedule provider "
                "is currently unavailable."
            ),
        )