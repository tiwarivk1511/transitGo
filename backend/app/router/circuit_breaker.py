from __future__ import annotations

import time


class CircuitBreaker:

    def __init__(
            self,
            failure_threshold: int = 5,
            recovery_timeout: int = 60,
    ):

        self.failure_threshold = (
            failure_threshold
        )

        self.recovery_timeout = (
            recovery_timeout
        )

        self.failures = 0
        self.opened_at: float | None = None

    @property
    def is_open(self) -> bool:

        if self.opened_at is None:
            return False

        elapsed = (
                time.monotonic()
                - self.opened_at
        )

        if elapsed >= self.recovery_timeout:

            self.opened_at = None
            self.failures = 0

            return False

        return True

    def success(self):

        self.failures = 0
        self.opened_at = None

    def failure(self):

        self.failures += 1

        if (
                self.failures
                >= self.failure_threshold
        ):
            self.opened_at = (
                time.monotonic()
            )