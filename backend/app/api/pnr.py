from fastapi import APIRouter, HTTPException

router = APIRouter(
    prefix="/api/pnr",
    tags=["PNR"],
)


@router.get("/{pnr_number}")
async def pnr_status(
        pnr_number: str,
):

    if not pnr_number.isdigit():
        raise HTTPException(
            status_code=400,
            detail="Invalid PNR.",
        )

    if len(pnr_number) != 10:
        raise HTTPException(
            status_code=400,
            detail="PNR must contain 10 digits.",
        )

    return {
        "success": False,
        "message": (
            "PNR provider adapter is not "
            "configured yet."
        ),
    }