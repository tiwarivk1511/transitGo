from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime
from enum import Enum
from typing import Any


class ProviderType(str, Enum):
    NTES = "ntes"
    PRS = "prs"
    OFFICIAL_WEB = "official_web"
    AUTHORIZED_API = "authorized_api"
    FALLBACK = "fallback"


@dataclass
class ProviderResult:
    success: bool
    data: Any = None
    provider: ProviderType | None = None
    fetched_at: datetime | None = None
    error: str | None = None
    stale: bool = False


class RailwayProvider(ABC):

    provider_type: ProviderType

    @abstractmethod
    async def get_train_status(
            self,
            train_number: str,
            journey_date: str,
    ) -> ProviderResult:
        raise NotImplementedError

    @abstractmethod
    async def get_train_schedule(
            self,
            train_number: str,
    ) -> ProviderResult:
        raise NotImplementedError

    async def close(self) -> None:
        return None