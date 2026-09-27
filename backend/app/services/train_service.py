
from typing import Any

from app.router.data_router import DataRouter
from app.normalizer.train import normalize_train_running


class TrainService:
    def __init__(self, router: DataRouter):
        """
        Initialize TrainService with the shared DataRouter instance.
        """
        self.router = router

    async def get_live_status(
            self,
            train_number: str,
    ) -> dict[str, Any]:
        """
        Fetch and normalize live running status for a train.

        Returns:
            {
                "source": str,
                "data": dict | None,
                "error": str | None
            }
        """

        train_number = str(train_number).strip()

        if not train_number:
            return {
                "source": "invalid_request",
                "data": None,
                "error": "Train number is required.",
            }

        try:
            res = await self.router.get_live_train(train_number)

            if not isinstance(res, dict):
                return {
                    "source": "invalid_response",
                    "data": None,
                    "error": "Invalid response received from data provider.",
                }

            data = res.get("data")
            source = res.get("source", "unknown")

            if not data:
                return {
                    "source": source,
                    "data": None,
                    "error": res.get("error"),
                }

            normalized = normalize_train_running(data)

            if normalized is None:
                return {
                    "source": source,
                    "data": None,
                    "error": "Unable to normalize train running status.",
                }

            return {
                "source": source,
                "data": normalized,
                "error": None,
            }

        except Exception as exc:
            return {
                "source": "error",
                "data": None,
                "error": str(exc),
            }