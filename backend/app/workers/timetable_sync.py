async def sync_timetable(
        train_number: str,
):

    from app.main import data_router

    result = await data_router.train_schedule(
        train_number
    )

    if not result.success:
        raise RuntimeError(
            result.error
        )

    return result.data