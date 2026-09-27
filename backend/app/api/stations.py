from fastapi import APIRouter

router = APIRouter(
    prefix="/api/stations",
    tags=["Stations"],
)


@router.get("/search")
async def search_stations(
        q: str,
):

    # This endpoint should query the local
    # railway station database.

    return {
        "success": True,
        "query": q,
        "data": [],
    }


@router.get("/{station_code}")
async def station(
        station_code: str,
):

    return {
        "success": True,
        "station_code": station_code,
        "data": None,
    }