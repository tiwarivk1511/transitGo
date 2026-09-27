
from typing import Any

from pydantic import BaseModel, ConfigDict, Field


class ApiResponse(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
    )

    success: bool

    message: str | None = None

    data: Any | None = None

    source: str = Field(
        default="transitgo",
        min_length=1,
    )