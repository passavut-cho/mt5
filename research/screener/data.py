"""CSV loading, timeframe aggregation, indicators and spread policies."""
from __future__ import annotations

import csv
import statistics
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import Iterable


@dataclass(frozen=True)
class Bar:
    time: datetime
    open: float
    high: float
    low: float
    close: float
    spread: float
    tick_volume: float = 0.0


def _field(row: dict[str, str], *names: str, default: str | None = None) -> str:
    lower = {key.strip().lower(): value for key, value in row.items() if key}
    for name in names:
        if name in lower and lower[name] != "":
            return lower[name]
    if default is not None:
        return default
    raise ValueError(f"missing required CSV column: {'/'.join(names)}")


def load_bars(path: str | Path, *, end: datetime | None = None) -> list[Bar]:
    """Load server-time M15 bid bars; refuse any row after the approved export end."""
    bars: list[Bar] = []
    with Path(path).open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        for line, row in enumerate(reader, 2):
            try:
                raw_time = _field(row, "time", "datetime", "server_time", "date")
                try:
                    stamp = datetime.fromisoformat(raw_time.replace("Z", "+00:00"))
                except ValueError:
                    stamp = datetime.strptime(raw_time, "%Y.%m.%d %H:%M")
                if stamp.tzinfo is not None:
                    stamp = stamp.replace(tzinfo=None)
                if end is not None and stamp > end:
                    raise ValueError(f"data after approved end at row {line}: {stamp}")
                bars.append(Bar(
                    stamp,
                    float(_field(row, "open", "bid_open")),
                    float(_field(row, "high", "bid_high")),
                    float(_field(row, "low", "bid_low")),
                    float(_field(row, "close", "bid_close")),
                    float(_field(row, "spread", "spread_points", "spread_pts")),
                    float(_field(row, "tick_volume", "volume", default="0")),
                ))
            except (ValueError, TypeError) as exc:
                raise ValueError(f"invalid data row {line}: {exc}") from exc
    bars.sort(key=lambda bar: bar.time)
    if any(a.time == b.time for a, b in zip(bars, bars[1:])):
        raise ValueError("duplicate bar timestamps")
    return bars


def spread_floors(bars: Iterable[Bar]) -> tuple[dict[int, float], int]:
    """Median positive spread by server hour, sampled only in 2018–2020."""
    samples: dict[int, list[float]] = {hour: [] for hour in range(24)}
    zero_rows = 0
    for bar in bars:
        if bar.spread == 0:
            zero_rows += 1
        if 2018 <= bar.time.year <= 2020 and bar.spread > 0:
            samples[bar.time.hour].append(bar.spread)
    missing = [hour for hour, values in samples.items() if not values]
    if missing:
        raise ValueError(f"cannot calculate spread floor; no positive 2018–2020 samples for hours {missing}")
    return {hour: float(statistics.median(values)) for hour, values in samples.items()}, zero_rows


def apply_spread_policy(bars: Iterable[Bar], policy: str) -> tuple[list[Bar], dict[int, float] | None, int]:
    source = list(bars)
    if policy == "raw":
        return source, None, sum(bar.spread == 0 for bar in source)
    if policy != "floor":
        raise ValueError(f"unknown spread policy: {policy}")
    floors, zero_rows = spread_floors(source)
    return [Bar(b.time, b.open, b.high, b.low, b.close,
                floors[b.time.hour] if b.spread == 0 else b.spread, b.tick_volume) for b in source], floors, zero_rows


def aggregate(bars: list[Bar], minutes: int) -> list[Bar]:
    groups: dict[datetime, list[Bar]] = {}
    for bar in bars:
        if minutes >= 60:
            hours = minutes // 60
            key = bar.time.replace(hour=(bar.time.hour // hours) * hours, minute=0, second=0, microsecond=0)
        else:
            minute = (bar.time.minute // minutes) * minutes
            key = bar.time.replace(minute=minute, second=0, microsecond=0)
        groups.setdefault(key, []).append(bar)
    out = []
    for key, items in sorted(groups.items()):
        out.append(Bar(key, items[0].open, max(x.high for x in items), min(x.low for x in items),
                       items[-1].close, items[-1].spread, sum(x.tick_volume for x in items)))
    return out


def ema(values: list[float], period: int) -> list[float | None]:
    out: list[float | None] = [None] * len(values)
    if len(values) < period:
        return out
    current = sum(values[:period]) / period
    out[period - 1] = current
    alpha = 2.0 / (period + 1)
    for i in range(period, len(values)):
        current = alpha * values[i] + (1 - alpha) * current
        out[i] = current
    return out


def sma(values: list[float], period: int) -> list[float | None]:
    out: list[float | None] = [None] * len(values)
    for i in range(period - 1, len(values)):
        out[i] = sum(values[i - period + 1:i + 1]) / period
    return out


def rsi(values: list[float], period: int) -> list[float | None]:
    out: list[float | None] = [None] * len(values)
    if len(values) <= period:
        return out
    gains = [max(values[i] - values[i - 1], 0.0) for i in range(1, period + 1)]
    losses = [max(values[i - 1] - values[i], 0.0) for i in range(1, period + 1)]
    avg_gain, avg_loss = sum(gains) / period, sum(losses) / period
    out[period] = 100.0 if avg_loss == 0 else 100 - 100 / (1 + avg_gain / avg_loss)
    for i in range(period + 1, len(values)):
        gain, loss = max(values[i] - values[i - 1], 0.0), max(values[i - 1] - values[i], 0.0)
        avg_gain = (avg_gain * (period - 1) + gain) / period
        avg_loss = (avg_loss * (period - 1) + loss) / period
        out[i] = 100.0 if avg_loss == 0 else 100 - 100 / (1 + avg_gain / avg_loss)
    return out


def atr(bars: list[Bar], period: int) -> list[float | None]:
    tr: list[float] = []
    for i, bar in enumerate(bars):
        tr.append(max(bar.high - bar.low,
                      abs(bar.high - bars[i - 1].close) if i else bar.high - bar.low,
                      abs(bar.low - bars[i - 1].close) if i else bar.high - bar.low))
    out: list[float | None] = [None] * len(tr)
    if len(tr) < period:
        return out
    current = sum(tr[:period]) / period
    out[period - 1] = current
    for i in range(period, len(tr)):
        current = (current * (period - 1) + tr[i]) / period
        out[i] = current
    return out


def bollinger(values: list[float], period: int = 20, deviations: float = 2.0):
    middle = sma(values, period)
    upper: list[float | None] = [None] * len(values)
    lower: list[float | None] = [None] * len(values)
    width: list[float | None] = [None] * len(values)
    for i in range(period - 1, len(values)):
        sample = values[i - period + 1:i + 1]
        mean = middle[i]
        sd = (sum((x - mean) ** 2 for x in sample) / period) ** 0.5
        lower[i], upper[i] = mean - deviations * sd, mean + deviations * sd
        width[i] = (upper[i] - lower[i]) / mean if mean else 0.0
    return lower, middle, upper, width


def latest_closed(series: list[Bar], values: list[float | None], decision_time: datetime) -> float | None:
    """Return last HTF value whose bar has closed by decision_time."""
    answer = None
    for bar, value in zip(series, values):
        if bar.time + timedelta(hours=1) > decision_time:
            break
        answer = value
    return answer
