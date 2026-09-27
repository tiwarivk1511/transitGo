from __future__ import annotations

from datetime import date

from fastapi import APIRouter, HTTPException, Query

from app.router.data_router import DataRouter


router = APIRouter(
    prefix="/api/trains",
    tags=["Trains"],
)


def get_router() -> DataRouter:
    from app.main import data_router

    return data_router


@router.get("/{train_number}/status")
async def train_status(
        train_number: str,
        journey_date: date = Query(
            default_factory=date.today
        ),
):

    result = await get_router().train_status(
        train_number=train_number,
        journey_date=journey_date.isoformat(),
    )

    if not result.success:

        raise HTTPException(
            status_code=503,
            detail=result.error,
        )

    return {
        "success": True,
        "source": result.provider,
        "fetched_at": result.fetched_at,
        "data": result.data,
    }


@router.get("/{train_number}/schedule")
async def train_schedule(
        train_number: str,
):

    result = await get_router().train_schedule(
        train_number
    )

    if not result.success:

        raise HTTPException(
            status_code=503,
            detail=result.error,
        )

    return {
        "success": True,
        "source": result.provider,
        "fetched_at": result.fetched_at,
        "data": result.data,
    }