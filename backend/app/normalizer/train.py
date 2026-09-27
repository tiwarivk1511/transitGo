from __future__ import annotations


def normalize_train_status(
        raw: dict,
) -> dict:

    return {
        "train_number": raw.get(
            "train_number"
        ),
        "train_name": raw.get(
            "train_name"
        ),
        "current_station": raw.get(
            "current_station"
        ),
        "next_station": raw.get(
            "next_station"
        ),
        "delay_minutes": raw.get(
            "delay_minutes"
        ),
        "expected_arrival": raw.get(
            "expected_arrival"
        ),
        "expected_departure": raw.get(
            "expected_departure"
        ),
        "latitude": raw.get(
            "latitude"
        ),
        "longitude": raw.get(
            "longitude"
        ),
        "source": raw.get(
            "source"
        ),
    }