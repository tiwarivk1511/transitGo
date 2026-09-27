from __future__ import annotations

import json
from pathlib import Path

import aiosqlite


class SQLiteCache:

    def __init__(
            self,
            path: str,
    ):
        self.path = Path(path)

        self.path.parent.mkdir(
            parents=True,
            exist_ok=True,
        )

    async def initialize(self):

        async with aiosqlite.connect(
                self.path
        ) as db:

            await db.execute(
                """
                CREATE TABLE IF NOT EXISTS cache (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                )
                """
            )

            await db.commit()

    async def get(
            self,
            key: str,
    ):

        async with aiosqlite.connect(
                self.path
        ) as db:

            cursor = await db.execute(
                """
                SELECT value
                FROM cache
                WHERE key = ?
                """,
                (key,),
            )

            row = await cursor.fetchone()

            if not row:
                return None

            return json.loads(row[0])

    async def set(
            self,
            key: str,
            value,
            updated_at: str,
    ):

        async with aiosqlite.connect(
                self.path
        ) as db:

            await db.execute(
                """
                INSERT INTO cache (
                    key,
                    value,
                    updated_at
                )
                VALUES (?, ?, ?)
                ON CONFLICT(key)
                DO UPDATE SET
                    value = excluded.value,
                    updated_at = excluded.updated_at
                """,
                (
                    key,
                    json.dumps(
                        value,
                        default=str,
                    ),
                    updated_at,
                ),
            )

            await db.commit()