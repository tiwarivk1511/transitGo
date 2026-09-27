from fastapi import APIRouter

router = APIRouter(
    prefix="/api/schedules",
    tags=["Schedules"],
)


@router.get("/{train_number}")
async def schedule(
        train_number: str,
):

    from app.main import data_router

    result = await data_router.train_schedule(
        train_number
    )

    if not result.success:

        return {
            "success": False,
            "error": result.error,
        }

    return {
        "success": True,
        "source": result.provider,
        "data": result.data,
    }