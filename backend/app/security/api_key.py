
import secrets

from fastapi import HTTPException, Security, status
from fastapi.security.api_key import APIKeyHeader

from app.config import settings


api_key_header = APIKeyHeader(
    name="X-API-Key",
    auto_error=False,
)


async def get_api_key(
        api_key: str | None = Security(api_key_header),
) -> str:
    """
    Validate the TransitGo API key.

    The expected key must be configured through environment settings.
    Requests are rejected if the key is missing or invalid.
    """

    expected_api_key = settings.RAIL_RADAR_API_KEY

    # Fail closed when the server API key is not configured.
    if not expected_api_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="API authentication is not configured.",
        )

    if not api_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="API key is required.",
            headers={"WWW-Authenticate": "API-Key"},
        )

    if not secrets.compare_digest(
            api_key.encode("utf-8"),
            expected_api_key.encode("utf-8"),
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid API key.",
        )

    return api_key