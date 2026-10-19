"""Command line entry point: python -m research.screener."""
from __future__ import annotations

import argparse
from bisect import bisect_right
from datetime import datetime, timedelta
import hashlib
from pathlib import Path

from .data import aggregate, apply_spread_policy, atr, load_bars
from .engine import Intent, simulate
from .hypotheses import HYPOTHESES, VARIANTS

DEFAULT_DATA = Path("data/research/xauusd_m15_2017-07_2022-12.csv")
DEFAULT_OUT = Path("docs/strategy/screen-results-v1.md")


def _calibration_signal(bars, strategy):
    """Reference configurations corresponding to the known S-A A2 and S-B B2 runs."""
    if strategy == "S-A A2":
        traded_days = set()
        def signal(i):
            b = bars[i]
            day = b.time.date()
            if day in traded_days:
                return None
            same = [x for x in bars[max(0, i - 80):i + 1] if x.time.date() == day and 1 <= x.time.hour < 10]
            if len(same) < 30 or not (10 <= b.time.hour < 21):
                return None
            hi, lo = max(x.high for x in same), min(x.low for x in same)
            if hi - lo <= 0:
                return None
            side = 1 if b.close > hi else -1 if b.close < lo else 0
            if not side:
                return None
            stop = lo if side == 1 else hi
            entry = b.close
            target = entry + side * 2 * abs(entry - stop)
            traded_days.add(day)
            return Intent(side, stop, target=target, label=strategy)
        return signal
    h4 = aggregate(bars, 240)
    h4_atr = atr(h4, 14)
    h4_closes = [bar.time + timedelta(hours=4) for bar in h4]
    def signal(i):
        b = bars[i]
        decision_time = b.time + timedelta(minutes=15)
        count = bisect_right(h4_closes, decision_time)
        if count < 21 or b.time.hour % 4 != 3 or b.time.minute != 45:
            return None
        prior = h4[count - 21:count - 1]
        hh, ll = max(x.high for x in prior), min(x.low for x in prior)
        side = 1 if b.close > hh else -1 if b.close < ll else 0
        if not side:
            return None
        # Locked S-B initial stop uses 2 x ATR(14,H4), approximated from closed bars.
        atr_value = h4_atr[count - 1]
        if atr_value is None:
            return None
        stop = b.close - side * 2 * atr_value
        def trailing(j):
            count = bisect_right(h4_closes, bars[j].time + timedelta(minutes=15))
            if count < 10:
                return None
            recent = h4[count - 10:count]
            return min(x.low for x in recent) if side == 1 else max(x.high for x in recent)
        return Intent(side, stop, trailing=trailing, partial_r=1.0, move_to_be=True,
                      weekend_lock=True, label=strategy)
    return signal


def calibration(bars, out=None):
    targets = [("S-A A2", 1124, 1.01, 261.71), ("S-B B2", 272, 1.02, 207.67)]
    lines = ["| Target | MT5 trades | Engine trades | MT5 PF | Engine PF | MT5 net $ | Engine net $ | Gate |",
             "|---|---:|---:|---:|---:|---:|---:|---|"]
    passed = True
    for name, target_count, target_pf, target_net in targets:
        signal = _calibration_signal(bars, name)
        result = simulate(bars, signal)
        ok_count = abs(result["count"] - target_count) <= target_count * 0.05
        ok_pf = abs(result["pf"] - target_pf) <= 0.05
        ok_direction = (result["net"] > 0) == (target_net > 0)
        ok = ok_count and ok_pf and ok_direction
        passed &= ok
        lines.append(f"| {name} | {target_count} | {result['count']} | {target_pf:.2f} | {result['pf']:.2f} | {target_net:.2f} | {result['net']:.2f} | {'PASS' if ok else 'FAIL'} |")
    report = "\n".join(lines)
    print(report)
    print(f"Calibration: {'PASS' if passed else 'FAIL'} (count ±5%, PF ±0.05, net R direction)")
    return passed


def _screen_result(hypothesis, variant, bars):
    normal_signal = HYPOTHESES[hypothesis](bars, variant, root=Path.cwd())
    stress_signal = HYPOTHESES[hypothesis](bars, variant, root=Path.cwd())
    normal = simulate(bars, normal_signal)
    stress = simulate(bars, stress_signal, stress_points=20.0)
    both_sides = hypothesis in {"H1", "H3", "H4", "H5", "H6", "H7", "H8"}
    checks = [normal["pf"] >= 1.20, stress["pf"] >= 1.05, normal["count"] >= 150,
              normal["max_dd"] <= 0.25, normal["years_positive"] >= 4,
              not both_sides or (normal["long_pf"] >= 1.0 and normal["short_pf"] >= 1.0),
              normal["expectancy_r"] >= 0.10]
    return normal, stress, all(checks)


def screen(bars, out: Path, floors: dict[int, float], zero_count: int, checksum: str):
    rows = ["# Screen results — screen-list-v1", "", "LOCKED variants; single registered run on XAUUSD M15, 2018-01-01 through 2022-12-31.",
            "", f"Input SHA-256: `{checksum}`", f"Input bars with spread=0 before floor: {zero_count}", "", "## Spread floor by server hour", "",
            "| Server hour | Median positive spread (points), 2018–2020 |", "|---:|---:|"]
    rows.extend(f"| {hour:02d}:00 | {floors[hour]:g} |" for hour in range(24))
    rows.extend(["", "## Results", "", "| Variant | Trades | PF net | Stress PF | Net $ | Net R | Expectancy R | Max DD | Positive years | Long PF | Short PF | Verdict |",
                 "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|"])
    results = []
    for hypothesis, variant in VARIANTS:
        normal, stress, passed = _screen_result(hypothesis, variant, bars)
        results.append((hypothesis, variant, normal))
        rows.append(f"| {hypothesis}{variant} | {normal['count']} | {normal['pf']:.2f} | {stress['pf']:.2f} | {normal['net']:.2f} | {normal['net_r']:.2f} | {normal['expectancy_r']:.3f} | {normal['max_dd']:.1%} | {normal['years_positive']}/5 | {normal['long_pf']:.2f} | {normal['short_pf']:.2f} | {'PASS' if passed else 'FAIL'} |")
    rows.extend(["", "## Yearly net", "", "| Variant | 2018 | 2019 | 2020 | 2021 | 2022 |", "|---|---:|---:|---:|---:|---:|"])
    for hypothesis, variant, normal in results:
        values = [normal["by_year"].get(year, 0.0) for year in range(2018, 2023)]
        rows.append(f"| {hypothesis}{variant} | " + " | ".join(f"{value:.2f}" for value in values) + " |")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(rows) + "\n", encoding="utf-8")
    print(f"Wrote {out}")


def main(argv=None):
    parser = argparse.ArgumentParser(description="Pre-registered XAUUSD strategy screener")
    parser.add_argument("--data", type=Path, default=DEFAULT_DATA)
    parser.add_argument("--list", choices=["screen-list-v1"], default="screen-list-v1")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--calibrate", action="store_true")
    parser.add_argument("--spread", choices=["raw", "floor"], default=None,
                        help="raw is calibration only; floor replaces zero spreads with 2018–2020 hourly medians")
    args = parser.parse_args(argv)
    spread_policy = args.spread or ("raw" if args.calibrate else "floor")
    if args.calibrate != (spread_policy == "raw"):
        parser.error("--spread raw is for --calibrate only; screen-list-v1 requires --spread floor")
    bars = load_bars(args.data, end=datetime(2022, 12, 31, 23, 59, 59))
    bars, floors, zero_count = apply_spread_policy(bars, spread_policy)
    if args.calibrate:
        subset = [bar for bar in bars if datetime(2018, 1, 1) <= bar.time <= datetime(2022, 12, 31, 23, 59, 59)]
        if not calibration(subset):
            raise SystemExit(1)
    else:
        subset = [bar for bar in bars if datetime(2018, 1, 1) <= bar.time <= datetime(2022, 12, 31, 23, 59, 59)]
        checksum = hashlib.sha256(args.data.read_bytes()).hexdigest()
        screen(subset, args.out, floors, zero_count, checksum)


if __name__ == "__main__":
    main()
