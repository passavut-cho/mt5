"""The eight pre-registered hypothesis families (14 locked variants)."""
from __future__ import annotations

import csv
from datetime import datetime, timedelta
from pathlib import Path

from .data import Bar, aggregate, atr, bollinger, ema, rsi, sma
from .engine import Intent


def _idx_at(series: list[Bar], stamp: datetime, width: int) -> int:
    """Last fully closed higher-timeframe bar at a decision timestamp."""
    low, high = 0, len(series)
    while low < high:
        middle = (low + high) // 2
        if series[middle].time + timedelta(minutes=width) <= stamp:
            low = middle + 1
        else:
            high = middle
    return low - 1


def _crossed_up(previous: float | None, current: float | None, level: float) -> bool:
    return previous is not None and current is not None and previous <= level < current


def _crossed_down(previous: float | None, current: float | None, level: float) -> bool:
    return previous is not None and current is not None and previous >= level > current


def H1(bars: list[Bar], variant: str, **_: object):
    h1 = aggregate(bars, 60)
    close = [b.close for b in h1]
    sma200, rsi2, atr14 = sma(close, 200), rsi(close, 2), atr(h1, 14)
    threshold = (10, 90) if variant == "a" else (5, 95)
    def signal(i: int):
        t = bars[i].time + timedelta(minutes=15)
        j = _idx_at(h1, t, 60)
        if j < 1 or None in (sma200[j], rsi2[j], atr14[j]):
            return None
        side = 1 if h1[j].close > sma200[j] and rsi2[j] < threshold[0] else -1 if h1[j].close < sma200[j] and rsi2[j] > threshold[1] else 0
        if not side:
            return None
        stop = bars[i].close - side * (1.5 * atr14[j])
        # The 24-bar maximum holding period is expressed in H1 bars from server time.
        exit_time = bars[i].time + timedelta(hours=24)
        def exit_when(current_i: int) -> bool:
            if current_i < 1:
                return False
            closed_at = bars[current_i - 1].time + timedelta(minutes=15)
            current_h1 = _idx_at(h1, closed_at, 60)
            if current_h1 < 1 or rsi2[current_h1 - 1] is None or rsi2[current_h1] is None:
                return False
            return _crossed_up(rsi2[current_h1 - 1], rsi2[current_h1], 50) if side == 1 else _crossed_down(rsi2[current_h1 - 1], rsi2[current_h1], 50)
        return Intent(side, stop, exit_time=exit_time, exit_when=exit_when, label="H1")
    return signal


def H2(bars: list[Bar], variant: str, **_: object):
    h1 = aggregate(bars, 60)
    atr14 = atr(h1, 14)
    side, start, end = (1, 3, 10) if variant == "a" else (-1, 17, 23)
    def signal(i: int):
        b = bars[i]
        signal_hour, signal_minute = (start - 1, 45)
        if (b.time.hour, b.time.minute) != (signal_hour, signal_minute):
            return None
        j = _idx_at(h1, b.time + timedelta(minutes=15), 60)
        if j < 0 or atr14[j] is None:
            return None
        return Intent(side, b.close - side * atr14[j], exit_time=b.time.replace(hour=end, minute=0) + timedelta(days=(1 if end <= start else 0)), label="H2")
    return signal


def H3(bars: list[Bar], variant: str, **_: object):
    d1 = aggregate(bars, 1440)
    d1atr = atr(d1, 14)
    traded_days: set = set()
    def signal(i: int):
        b = bars[i]
        if b.time.date() in traded_days:
            return None
        j = _idx_at(d1, b.time + timedelta(minutes=15), 1440)
        if j < 1 or j - 1 >= len(d1):
            return None
        prev = d1[j - 1]
        if variant == "b" and (d1atr[j - 1] is None or prev.high - prev.low >= d1atr[j - 1]):
            return None
        entry_time = b.time + timedelta(minutes=15)
        if not (10 <= entry_time.hour < 21):
            return None
        side = 1 if b.close > prev.high else -1 if b.close < prev.low else 0
        if not side:
            return None
        stop = (prev.high + prev.low) / 2
        traded_days.add(b.time.date())
        return Intent(side, stop, exit_time=b.time.replace(hour=23, minute=30), label="H3")
    return signal


def H4(bars: list[Bar], variant: str = "a", **_: object):
    d1 = aggregate(bars, 1440)
    traded_days: set = set()
    def signal(i: int):
        b = bars[i]
        if b.time.date() in traded_days:
            return None
        j = _idx_at(d1, b.time + timedelta(minutes=15), 1440)
        if j < 2 or not (1 <= b.time.hour < 20):
            return None
        yesterday, before = d1[j - 1], d1[j - 2]
        if yesterday.high >= before.high or yesterday.low <= before.low:
            return None
        # Both pending stops are modeled independently; if both sides hit in a bar, SC1 resolves the open position conservatively.
        if b.high >= yesterday.high:
            traded_days.add(b.time.date())
            return Intent(1, yesterday.low, target=yesterday.high + 2 * (yesterday.high - yesterday.low), stop_entry=yesterday.high, exit_time=b.time.replace(hour=23, minute=30), label="H4")
        if b.low <= yesterday.low:
            traded_days.add(b.time.date())
            return Intent(-1, yesterday.high, target=yesterday.low - 2 * (yesterday.high - yesterday.low), stop_entry=yesterday.low, exit_time=b.time.replace(hour=23, minute=30), label="H4")
        return None
    return signal


def H5(bars: list[Bar], variant: str, **_: object):
    h1 = aggregate(bars, 60)
    close = [b.close for b in h1]
    lower, middle, upper, width = bollinger(close)
    def signal(i: int):
        t = bars[i].time + timedelta(minutes=15)
        j = _idx_at(h1, t, 60)
        if j < 119 or None in (lower[j], middle[j], upper[j], width[j]):
            return None
        if width[j] != min(v for v in width[j - 119:j + 1] if v is not None):
            return None
        side = 1 if h1[j].close > upper[j] else -1 if h1[j].close < lower[j] else 0
        if not side:
            return None
        stop = middle[j]
        risk = abs(h1[j].close - stop)
        target = h1[j].close + side * 2 * risk if variant == "b" else None
        def trailing(current_i: int):
            current_time = bars[current_i - 1].time + timedelta(minutes=15) if current_i else bars[0].time
            current_h1 = _idx_at(h1, current_time, 60)
            if current_h1 < 0:
                return None
            return lower[current_h1] if side == 1 else upper[current_h1]
        return Intent(side, stop, target=target, trailing=trailing, label="H5")
    return signal


def H6(bars: list[Bar], variant: str, **_: object):
    h1 = aggregate(bars, 60)
    d1 = aggregate(bars, 1440)
    hclose = [b.close for b in h1]
    dclose = [b.close for b in d1]
    h_ema, d_ema = ema(hclose, 20), ema(dclose, 50)
    def signal(i: int):
        t = bars[i].time + timedelta(minutes=15)
        j, k = _idx_at(h1, t, 60), _idx_at(d1, t, 1440)
        if j < 10 or k < 0 or h_ema[j] is None or d_ema[k] is None:
            return None
        side = 1 if d1[k].close > d_ema[k] and h1[j].low <= h_ema[j] < h1[j].close else -1 if d1[k].close < d_ema[k] and h1[j].high >= h_ema[j] > h1[j].close else 0
        if not side:
            return None
        swing = min(x.low for x in h1[j - 9:j + 1]) if side == 1 else max(x.high for x in h1[j - 9:j + 1])
        risk = abs(h1[j].close - swing)
        if risk == 0:
            return None
        return Intent(side, swing, target=h1[j].close + side * 2 * risk if variant == "a" else None,
                      partial_r=1.0 if variant == "b" else None, move_to_be=variant == "b", label="H6")
    return signal


def _news_dates(path: Path) -> set:
    dates = set()
    if not path.exists():
        return dates
    with path.open(encoding="utf-8-sig", newline="") as handle:
        lines = (line for line in handle if not line.lstrip().startswith("#"))
        for row in csv.DictReader(lines):
            joined = " ".join(row.values()).upper()
            if "NFP" not in joined and "CPI" not in joined:
                continue
            try:
                dates.add(datetime.strptime(row["date"].strip(), "%Y-%m-%d").date())
            except (ValueError, KeyError, AttributeError):
                continue
    return dates


def H7(bars: list[Bar], variant: str, *, root: Path | None = None):
    dates = _news_dates((root or Path.cwd()) / "data/files/news.csv")
    news_bars = {bar.time.date(): bar for bar in bars
                 if bar.time.date() in dates and bar.time.hour == 15 and bar.time.minute == 30}
    def signal(i: int):
        b = bars[i]
        target_hour = 15 if variant == "a" else 16
        target_minute = 30 if variant == "a" else 15
        event_bar = news_bars.get(b.time.date())
        if event_bar is None or (b.time.hour, b.time.minute) != (target_hour, target_minute):
            return None
        side = 1 if event_bar.close > event_bar.open else -1 if event_bar.close < event_bar.open else 0
        if not side:
            return None
        return Intent(side, event_bar.low if side == 1 else event_bar.high,
                      exit_time=b.time.replace(hour=23, minute=30), label="H7")
    return signal


def _gap_map(path: Path) -> dict:
    result = {}
    if not path.exists():
        return result
    with path.open(encoding="utf-8-sig", newline="") as handle:
        for row in csv.DictReader(handle):
            try:
                stamp = datetime.strptime(row["mon_bar_time"], "%Y.%m.%d %H:%M")
                result[stamp.date()] = (float(row["gap"]), float(row["atr_h4"]))
            except (ValueError, KeyError):
                continue
    return result


def H8(bars: list[Bar], variant: str = "a", *, root: Path | None = None):
    gaps = _gap_map((root or Path.cwd()) / "data/research/weekend_gaps_2018_2022.csv")
    def signal(i: int):
        b = bars[i]
        if b.time.weekday() != 0 or (b.time.hour, b.time.minute) != (1, 0) or b.time.date() not in gaps:
            return None
        gap, atr_value = gaps[b.time.date()]
        if abs(gap) <= 0.3 * atr_value:
            return None
        side = -1 if gap > 0 else 1
        stop = b.close - side * atr_value
        target = b.close + side * abs(gap)
        return Intent(side, stop, target=target, label="H8")
    return signal


HYPOTHESES = {"H1": H1, "H2": H2, "H3": H3, "H4": H4, "H5": H5, "H6": H6, "H7": H7, "H8": H8}
VARIANTS = [(hypothesis, variant) for hypothesis, choices in {
    "H1": "ab", "H2": "ab", "H3": "ab", "H4": "a", "H5": "ab", "H6": "ab", "H7": "ab", "H8": "a"
}.items() for variant in choices]
