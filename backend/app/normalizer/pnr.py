def normalize_pnr(
        raw: dict,
) -> dict:

    return {
        "pnr": raw.get("pnr"),
        "train_number": raw.get(
            "train_number"
        ),
        "train_name": raw.get(
            "train_name"
        ),
        "booking_status": raw.get(
            "booking_status"
        ),
        "current_status": raw.get(
            "current_status"
        ),
        "chart_status": raw.get(
            "chart_status"
        ),
        "fare": raw.get(
            "fare"
        ),
    }