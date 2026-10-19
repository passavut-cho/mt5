#!/usr/bin/env python3
"""T-042: สถิติ weekend gap จาก data/research/weekend_gaps_2018_2022.csv (stdlib เท่านั้น)

ใช้: python tests/python/weekend_gap_stats.py [csv]
แสดง percentile 50/90/95/99 + max ของ |gap|/ATR, จำนวนสัปดาห์ที่ > 1x / 2x ATR, 5 อันดับแรก
"""
import csv
import math
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "data/research/weekend_gaps_2018_2022.csv"
rows = []
with open(path, newline="", encoding="utf-8") as f:
    for r in csv.DictReader(f):
        gap, atr = float(r["gap"]), float(r["atr_h4"])
        rows.append((r["fri_bar_time"], r["mon_bar_time"], gap, atr, abs(gap) / atr))


def pct(sorted_vals, p):
    """percentile แบบ nearest-rank"""
    k = max(0, math.ceil(p / 100 * len(sorted_vals)) - 1)
    return sorted_vals[k]


ratios = sorted(x[4] for x in rows)
print(f"weeks = {len(rows)}  ({rows[0][0][:10]} .. {rows[-1][0][:10]})")
for p in (50, 90, 95, 99):
    print(f"p{p}: |gap|/ATR = {pct(ratios, p):.3f}")
print(f"max: {ratios[-1]:.3f}")
print(f"> 1xATR: {sum(1 for v in ratios if v > 1)}  > 2xATR: {sum(1 for v in ratios if v > 2)}")
print("top 5 (|gap|/ATR):")
for fri, mon, gap, atr, ratio in sorted(rows, key=lambda x: -x[4])[:5]:
    print(f"  {fri[:10]} -> {mon[:10]}  gap={gap:+.2f}  ATR={atr:.2f}  ratio={ratio:.2f}")
