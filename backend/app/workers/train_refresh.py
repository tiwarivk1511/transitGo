from __future__ import annotations

import asyncio
from datetime import datetime


async def refresh_train(
        train_number: str,
        journey_date: str,
):

    from app.main import data_router

    result = await data_router.train_status(
        train_number,
        journey_date,
    )

    if not result.success:

        print(
            f"[TRAIN] {train_number} "
            f"failed: {result.error}"
        )

        return None

    print(
        f"[TRAIN] {train_number} "
        f"updated at {datetime.now()}"
    )

    return result


async def main():

    # In production this should be driven by
    # active tracking requests rather than
    # continuously polling every train.

    await refresh_train(
        "12418",
        datetime.now().date().isoformat(),
    )


if __name__ == "__main__":
    asyncio.run(main())