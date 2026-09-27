from fastapi import APIRouter

router = APIRouter(
    prefix="/api/fares",
    tags=["Fares"],
)


@router.get("/")
async def fare(
        train_number: str,
        from_station: str,
        to_station: str,
        journey_date: str,
        travel_class: str,
        quota: str,
):

    return {
        "success": False,
        "message": (
            "Fare web provider adapter "
            "is not configured yet."
        ),
        "query": {
            "train_number": train_number,
            "from": from_station,
            "to": to_station,
            "journey_date": journey_date,
            "class": travel_class,
            "quota": quota,
        },
    }