from fastapi import APIRouter

router = APIRouter(
    prefix="/api/traffic",
    tags=["Traffic"],
)


@router.get("/station/{station_code}")
async def station_traffic(
        station_code: str,
):

    return {
        "success": False,
        "station": station_code,
        "message": (
            "Live station provider adapter "
            "is not configured yet."
        ),
    }