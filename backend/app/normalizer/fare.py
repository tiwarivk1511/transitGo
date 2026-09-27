def normalize_fare(
        raw: dict,
) -> dict:

    return {
        "train_number": raw.get(
            "train_number"
        ),
        "source": raw.get(
            "source"
        ),
        "destination": raw.get(
            "destination"
        ),
        "class": raw.get(
            "class"
        ),
        "quota": raw.get(
            "quota"
        ),
        "fare": raw.get(
            "fare"
        ),
    }