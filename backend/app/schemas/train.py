
from typing import Any

from pydantic import BaseModel, ConfigDict, Field, field_validator


class TrainStatusQuery(BaseModel):
    model_config = ConfigDict(
        str_strip_whitespace=True,
        extra="forbid",
    )

    train_number: str = Field(
        ...,
        min_length=1,
        max_length=10,
        description="Indian Railways train number.",
        examples=["12951"],
    )

    date: str | None = Field(
        default=None,
        description="Journey date in YYYY-MM-DD format.",
        examples=["2026-09-28"],
    )

    @field_validator("train_number")
    @classmethod
    def validate_train_number(cls, value: str) -> str:
        if not value.isdigit():
            raise ValueError("Train number must contain only digits.")

        return value

    @field_validator("date")
    @classmethod
    def validate_date(cls, value: str | None) -> str | None:
        if value is None:
            return None

        from datetime import date

        try:
            date.fromisoformat(value)
        except ValueError as exc:
            raise ValueError(
                "Date must be in YYYY-MM-DD format."
            ) from exc

        return value


class TrainResponse(BaseModel):
    model_config = ConfigDict(
        str_strip_whitespace=True,
        extra="forbid",
    )

    train_number: str = Field(
        ...,
        min_length=1,
        max_length=10,
    )

    train_name: str = Field(
        ...,
        min_length=1,
    )

    status: str = Field(
        ...,
        min_length=1,
    )

    delay: int = Field(
        ...,
        ge=0,
        description="Delay in minutes.",
    )

    current_station_code: str | None = None

    current_station_name: str | None = None

    station_list: list[dict[str, Any]] = Field(
        default_factory=list,
    )

    source: str = Field(
        default="ntes",
        min_length=1,
    )