from __future__ import annotations

from bs4 import BeautifulSoup


class NtesParser:

    @staticmethod
    def clean_text(value: str | None) -> str:
        if not value:
            return ""

        return " ".join(value.split())

    @classmethod
    def tables(cls, html: str) -> list[list[list[str]]]:

        soup = BeautifulSoup(html, "lxml")

        output = []

        for table in soup.find_all("table"):

            rows = []

            for row in table.find_all("tr"):

                cells = []

                for cell in row.find_all(
                        ["th", "td"]
                ):
                    cells.append(
                        cls.clean_text(cell.get_text(" "))
                    )

                if cells:
                    rows.append(cells)

            if rows:
                output.append(rows)

        return output

    @classmethod
    def parse_schedule(cls, html: str) -> dict:

        tables = cls.tables(html)

        return {
            "tables": tables,
        }

    @classmethod
    def parse_train_status(cls, html: str) -> dict:

        tables = cls.tables(html)

        text = cls.clean_text(
            BeautifulSoup(
                html,
                "lxml",
            ).get_text(" ")
        )

        return {
            "text": text,
            "tables": tables,
        }