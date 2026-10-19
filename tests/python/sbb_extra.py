"""T-045: ตัวเลขเสริมของ S-B — ปีที่กำไร, ไม้ที่เสียเกิน 1R (proxy) และ stress รายปี
proxy 1R: report ไม่มี SL เริ่มต้น → net ขาดทุนของ position (รวม partial/comm/swap) > 1.05% ของ balance ก่อนเปิดไม้"""
import sys
from report_stats import read_report, parse_deals, pair_trades, crossed_weekend, parse_time

path, deposit = sys.argv[1], 10000.0
trades = pair_trades(parse_deals(read_report(path)), 7.0)
bal, over = deposit, []
for t in trades:
    if t["net"] < -0.0105 * bal:
        over.append((t["open"], t["close"], t["side"], t["net"], t["net"] / bal * 100, crossed_weekend(t)))
    bal += t["net"]
by = {}
for t in trades:
    y = parse_time(t["close"]).year
    by[y] = by.get(y, 0.0) + t["net"]
print("profitable_years:", sum(1 for v in by.values() if v > 0), "/", len(by), {y: round(v, 2) for y, v in sorted(by.items())})
print("over_1R:", len(over))
for o in over:
    print(f"  {o[0]} -> {o[1]} {o[2]} net={o[3]:.2f} ({o[4]:.2f}% bal) weekend={o[5]}")
