def normalize_station(
        raw: dict,
) -> dict:

    return {
        "code": raw.get("code"),
        "name": raw.get("name"),
        "zone": raw.get("zone"),
        "division": raw.get("division"),
        "latitude": raw.get("latitude"),
        "longitude": raw.get("longitude"),
    }