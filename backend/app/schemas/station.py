
from typing import Any

from pydantic import BaseModel, ConfigDict, Field, field_validator


class StationTrafficQuery(BaseModel):
    model_config = ConfigDict(
        str_strip_whitespace=True,
        extra="forbid",
    )

    station_code: str = Field(
        ...,
        min_length=2,
        max_length=10,
        description="Indian Railways station code.",
        examples=["NDLS"],
    )

    hours: int = Field(
        default=4,
        ge=1,
        le=24,
        description="Number of hours to retrieve station traffic for.",
    )

    @field_validator("station_code")
    @classmethod
    def validate_station_code(cls, value: str) -> str:
        if not value.isalnum():
            raise ValueError(
                "Station code must contain only letters and digits."
            )

        return value.upper()


class StationResponse(BaseModel):
    model_config = ConfigDict(
        str_strip_whitespace=True,
        extra="forbid",
    )

    station_code: str = Field(
        ...,
        min_length=2,
        max_length=10,
    )

    station_name: str = Field(
        ...,
        min_length=1,
    )

    trains: list[dict[str, Any]] = Field(
        default_factory=list,
    )

    source: str = Field(
        default="ntes",
        min_length=1,
    )