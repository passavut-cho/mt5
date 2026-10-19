"""Bar-by-bar execution model for the locked screener rules."""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Callable

from .data import Bar

POINT = 0.01                 # XAUUSD quote point; $1/lot per point, per SC2.
COMMISSION_PER_LOT = 7.0    # Round turn.
LONG_SWAP = -57.03
SHORT_SWAP = 39.77


@dataclass(frozen=True)
class Intent:
    side: int                 # +1 buy, -1 sell
    stop: float
    target: float | None = None
    exit_time: datetime | None = None
    trailing: Callable[[int], float | None] | None = None
    partial_r: float | None = None
    move_to_be: bool = False
    exit_when: Callable[[int], bool] | None = None
    weekend_lock: bool = False
    exit_on_day_change: bool = False
    friday_cutoff: bool = False
    stop_entry: float | None = None
    label: str = ""


@dataclass
class Trade:
    side: int
    entry_time: datetime
    exit_time: datetime
    entry: float
    exit: float
    stop_distance: float
    lots: float
    gross: float
    commission: float
    swap: float
    stress: float
    net: float
    r: float
    year: int


def _nights(start: datetime, end: datetime) -> int:
    return max(0, (end.date() - start.date()).days)


def _swap(side: int, start: datetime, end: datetime, lots: float) -> float:
    amount = 0.0
    for offset in range(1, _nights(start, end) + 1):
        night = start.date() + timedelta(days=offset - 1)
        points = (LONG_SWAP if side == 1 else SHORT_SWAP) * (3 if night.weekday() == 2 else 1)
        amount += points * lots
    return amount


def _entry_fill(intent: Intent, bar: Bar) -> float:
    return bar.open + (bar.spread * POINT if intent.side == 1 else 0.0)


def market_open_for_entry(bar: Bar) -> bool:
    """The daily IC server rollover closure is 00:00–00:59; retcode 10018 window."""
    return bar.time.hour != 0


def _exit_fill(side: int, price: float, bar: Bar, *, gap: bool = False) -> float:
    if side == 1:
        return price
    return price + (bar.spread * POINT if not gap else 0.0)


def resolve_bar_exit(side: int, bar: Bar, stop: float, target: float | None) -> tuple[str, float] | None:
    """Resolve intra-bar SL/TP conservatively, including stop gaps at bar open."""
    spread = bar.spread * POINT
    if side == 1:
        stop_hit = bar.open <= stop or bar.low <= stop
        target_hit = target is not None and bar.high >= target
        if stop_hit:
            return "SL", bar.open if bar.open <= stop else stop
        if target_hit:
            return "TP", target
    else:
        stop_hit = bar.open + spread >= stop or bar.high + spread >= stop
        target_hit = target is not None and bar.low + spread <= target
        if stop_hit:
            return "SL", bar.open + spread if bar.open + spread >= stop else stop
        if target_hit:
            return "TP", target
    return None


def _profit(side: int, entry: float, exit_price: float, lots: float) -> float:
    return side * (exit_price - entry) / POINT * lots


def simulate(bars: list[Bar], signal: Callable[[int], Intent | None], *, start_equity: float = 10_000.0,
             stress_points: float = 0.0) -> dict:
    trades: list[Trade] = []
    equity = peak = start_equity
    max_dd = 0.0
    position: dict | None = None
    daily_start: dict = {}
    halted_days: set = set()
    pending: Intent | None = None

    def close_position(i: int, price: float, reason: str) -> None:
        nonlocal position, equity, peak, max_dd
        p = position
        bar = bars[i]
        is_gap = reason == "SL" and (
            ((p["side"] == 1 and bar.open <= p["stop"]) or
             (p["side"] == -1 and bar.open + bar.spread * POINT >= p["stop"])))
        exit_price = price if reason in {"SL", "TP"} or is_gap else _exit_fill(p["side"], price, bar)
        gross = p["partial_gross"] + _profit(p["side"], p["entry"], exit_price, p["lots"])
        commission = COMMISSION_PER_LOT * p["initial_lots"]
        swap = _swap(p["side"], p["time"], bar.time, p["initial_lots"])
        stress = stress_points * p["initial_lots"]
        net = gross - commission + swap - stress
        r = net / p["risk_cash"] if p["risk_cash"] else 0.0
        equity += net - p["partial_gross"]
        trades.append(Trade(p["side"], p["time"], bar.time, p["entry"], exit_price,
                            p["risk_distance"], p["lots"], gross, commission, swap, stress,
                            net, r, p["time"].year))
        peak = max(peak, equity)
        max_dd = max(max_dd, (peak - equity) / peak if peak else 0.0)
        position = None

    for i, bar in enumerate(bars):
        day = bar.time.date()
        daily_start.setdefault(day, equity)
        marked_equity = equity
        if position is not None:
            mark = bar.low if position["side"] == 1 else bar.high + bar.spread * POINT
            marked_equity += _profit(position["side"], position["entry"], mark, position["lots"])
        peak = max(peak, marked_equity)
        max_dd = max(max_dd, (peak - marked_equity) / peak if peak else 0.0)
        if day in halted_days or marked_equity <= daily_start[day] * 0.97:
            halted_days.add(day)
        if position is not None:
            if position["exit_on_day_change"] and day > position["time"].date():
                close_position(i, bar.open, "DAY")
            if position is not None and position["trailing"] is not None:
                new_stop = position["trailing"](i)
                if new_stop is not None:
                    if position["side"] == 1:
                        position["stop"] = max(position["stop"], new_stop)
                    else:
                        position["stop"] = min(position["stop"], new_stop)
            if position is not None:
                result = resolve_bar_exit(position["side"], bar, position["stop"], position["target"])
                if result is not None:
                    close_position(i, result[1], result[0])
            if position is not None and position["partial_r"] is not None and not position["partial_done"]:
                partial_level = position["entry"] + position["side"] * position["risk_distance"] * position["partial_r"]
                touched = bar.high >= partial_level if position["side"] == 1 else bar.low + bar.spread * POINT <= partial_level
                if touched:
                    # This screener has no broker volume-step input; 0.01 lot is the fixed floor.
                    half = int((position["lots"] * 0.5) / 0.01) * 0.01
                    remain = position["lots"] - half
                    if half >= 0.01 and remain >= 0.01:
                        p = position
                        partial_gross = _profit(p["side"], p["entry"], partial_level, half)
                        equity += partial_gross
                        p["partial_gross"] += partial_gross
                        p["lots"] = remain
                        p["partial_done"] = True
                        if p["move_to_be"]:
                            p["stop"] = max(p["stop"], p["entry"]) if p["side"] == 1 else min(p["stop"], p["entry"])
            if position is not None:
                result = resolve_bar_exit(position["side"], bar, position["stop"], position["target"])
                if result is not None:
                    reason, price = result
                    close_position(i, price, reason)
                elif position is not None and position["exit_when"] is not None and position["exit_when"](i):
                    close_position(i, bar.open, "TIME")
                elif position is not None and position["friday_cutoff"] and bar.time.weekday() == 4 and bar.time.hour >= 20:
                    close_position(i, bar.open, "FRIDAY")
                elif position is not None and position["exit_time"] and bar.time >= position["exit_time"]:
                    close_position(i, bar.open, "TIME")
                elif position is not None and position["weekend_lock"] and bar.time.weekday() == 4 and bar.time.hour >= 20:
                    loss_locked = position["stop"] < position["entry"] if position["side"] == 1 else position["stop"] > position["entry"]
                    if loss_locked:
                        close_position(i, bar.open, "WEEKEND")

        if position is None and pending is not None and day not in halted_days and market_open_for_entry(bar):
            entry_price = _entry_fill(pending, bar)
            if pending.stop_entry is None:
                position = _open(pending, bar, entry_price, equity)
            elif (pending.side == 1 and bar.high >= pending.stop_entry) or (pending.side == -1 and bar.low + bar.spread * POINT <= pending.stop_entry):
                entry_price = max(bar.open, pending.stop_entry) + (bar.spread * POINT if pending.side == 1 else 0.0) if pending.side == 1 else min(bar.open, pending.stop_entry)
                position = _open(pending, bar, entry_price, equity)
            pending = None
            if position is not None:
                result = resolve_bar_exit(position["side"], bar, position["stop"], position["target"])
                if result is not None:
                    close_position(i, result[1], result[0])

        if position is None and pending is None and i > 0 and day not in halted_days:
            # Signals from the previous completed bar are executed at this bar's open.
            candidate = signal(i - 1)
            friday_blocked = candidate is not None and candidate.friday_cutoff and bar.time.weekday() == 4 and bar.time.hour >= 20
            if candidate is not None and market_open_for_entry(bar) and not friday_blocked and not (candidate.weekend_lock and bar.time.weekday() == 4 and bar.time.hour >= 20):
                pending = candidate
                entry_price = _entry_fill(candidate, bar)
                if candidate.stop_entry is None:
                    position = _open(candidate, bar, entry_price, equity)
                    pending = None
                elif (candidate.side == 1 and bar.high >= candidate.stop_entry) or (candidate.side == -1 and bar.low + bar.spread * POINT <= candidate.stop_entry):
                    entry_price = max(bar.open, candidate.stop_entry) + (bar.spread * POINT if candidate.side == 1 else 0.0) if candidate.side == 1 else min(bar.open, candidate.stop_entry)
                    position = _open(candidate, bar, entry_price, equity)
                    pending = None
                if position is not None:
                    result = resolve_bar_exit(position["side"], bar, position["stop"], position["target"])
                    if result is not None:
                        close_position(i, result[1], result[0])

    if position is not None and bars:
        close_position(len(bars) - 1, bars[-1].close, "END")
    return summarize(trades, start_equity, equity, max_dd)


def _open(intent: Intent, bar: Bar, entry: float, equity: float) -> dict | None:
    distance = abs(entry - intent.stop)
    risk_cash = equity * 0.01
    if distance <= 0:
        return None
    cash_per_price_per_lot = 1.0 / POINT
    lots = int((risk_cash / (distance * cash_per_price_per_lot)) / 0.01) * 0.01
    if lots < 0.01:
        return None
    target = intent.target
    if target is None and intent.partial_r is not None:
        target = None
    return {"side": intent.side, "time": bar.time, "entry": entry, "stop": intent.stop,
            "initial_stop": intent.stop, "target": target, "risk_distance": distance,
            "risk_cash": distance * cash_per_price_per_lot * lots, "lots": lots, "initial_lots": lots,
            "trailing": intent.trailing, "exit_time": intent.exit_time,
            "exit_when": intent.exit_when,
            "weekend_lock": intent.weekend_lock,
            "exit_on_day_change": intent.exit_on_day_change,
            "friday_cutoff": intent.friday_cutoff,
            "partial_r": intent.partial_r, "partial_done": False,
            "move_to_be": intent.move_to_be, "partial_gross": 0.0}


def summarize(trades: list[Trade], start: float, final: float, max_dd: float) -> dict:
    wins = sum(max(t.net, 0.0) for t in trades)
    losses = -sum(min(t.net, 0.0) for t in trades)
    by_side = {side: trades_for_side(trades, side) for side in (1, -1)}
    by_year: dict[int, float] = {}
    for trade in trades:
        by_year[trade.year] = by_year.get(trade.year, 0.0) + trade.net
    return {"trades": trades, "count": len(trades), "pf": wins / losses if losses else (float("inf") if wins else 0.0),
            "net": sum(t.net for t in trades), "net_r": sum(t.r for t in trades),
            "expectancy_r": sum(t.r for t in trades) / len(trades) if trades else 0.0,
            "max_dd": max_dd, "years_positive": sum(value > 0 for value in by_year.values()),
            "by_year": by_year, "long_pf": _pf(by_side[1]), "short_pf": _pf(by_side[-1]),
            "final_equity": final, "start_equity": start}


def trades_for_side(trades: list[Trade], side: int) -> list[Trade]:
    return [trade for trade in trades if trade.side == side]


def _pf(trades: list[Trade]) -> float:
    wins = sum(max(t.net, 0.0) for t in trades)
    losses = -sum(min(t.net, 0.0) for t in trades)
    return wins / losses if losses else (float("inf") if wins else 0.0)
