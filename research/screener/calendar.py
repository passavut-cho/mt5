"""Fail-closed holiday and timestamped news calendars for entry filtering."""
from __future__ import annotations

import csv
from datetime import date, datetime
from pathlib import Path


def _rows(path: Path):
    with path.open(encoding="utf-8-sig", newline="") as handle:
        lines = (line for line in handle if not line.lstrip().startswith("#"))
        yield from csv.DictReader(lines)


def _covered_years(path: Path) -> set[int]:
    years: set[int] = set()
    with path.open(encoding="utf-8-sig") as handle:
        for line in handle:
            if line.lower().startswith("# covered_years:"):
                years.update(int(value.strip()) for value in line.split(":", 1)[1].split(",") if value.strip())
                break
    if not years:
        raise ValueError(f"calendar has no # covered_years declaration: {path}")
    return years


def load_holidays(path: Path) -> tuple[set[date], set[int]]:
    years = _covered_years(path)
    holidays = {date.fromisoformat(row["date"].strip()) for row in _rows(path)}
    return holidays, years


def load_news(path: Path) -> tuple[list[datetime], set[int]]:
    years = _covered_years(path)
    events = [datetime.strptime(f'{row["date"].strip()} {row["time"].strip()}', "%Y-%m-%d %H:%M")
              for row in _rows(path)]
    return events, years
