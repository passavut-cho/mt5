#!/usr/bin/env python3
"""สถิติ backtest หลังหัก commission จาก report .htm ของ MT5 (UTF-16)

Strategy Tester ไม่หัก commission ของ IC Raw (คอลัมน์ Commission = 0)
สคริปต์นี้จับคู่ deal in/out ต่อ position แล้วหัก commission_per_lot x volume (round turn)

ใช้: python tests/python/report_stats.py data/reports/SmartEA_ema_v1.htm [--commission 7.0] [--deposit 10000] [--out x.md]
"""
import argparse
import html
import re
import sys
from collections import defaultdict


def read_report(path):
    raw = open(path, "rb").read()
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return raw.decode("utf-16")
    return raw.decode("utf-8", errors="replace")


def num(s):
    s = s.replace("\xa0", "").replace(" ", "").replace(",", "")
    return float(s) if s not in ("", "-") else 0.0


def parse_deals(text):
    """คืน list ของ deal (dict) จากตาราง Deals"""
    start = text.find("<b>Deals</b>")
    if start < 0:
        raise ValueError("ไม่พบตาราง Deals ใน report")
    deals = []
    for row in re.findall(r"<tr[^>]*>(.*?)</tr>", text[start:], re.S):
        cells = [html.unescape(re.sub(r"<[^>]+>", "", c)).strip()
                 for c in re.findall(r"<td[^>]*>(.*?)</td>", row, re.S)]
        if len(cells) != 13 or not re.match(r"\d{4}\.\d\d\.\d\d", cells[0]):
            continue
        if cells[3] == "balance":
            continue
        deals.append(dict(time=cells[0], type=cells[3], dir=cells[4], vol=num(cells[5]),
                          price=num(cells[6]), comm=num(cells[8]), swap=num(cells[9]),
                          profit=num(cells[10]), comment=cells[12]))
    return deals


def pair_trades(deals, comm_per_lot):
    """จับคู่ in -> out (EA ถือได้ 1 position ต่อครั้ง) ; ไม้ที่ยังเปิดค้างจะไม่นับ"""
    trades, cur = [], None
    for d in deals:
        if d["dir"] == "in":
            cur = d
        elif d["dir"] == "out" and cur is not None:
            comm = -comm_per_lot * cur["vol"]
            gross = d["profit"]
            net = gross + d["swap"] + cur["comm"] + d["comm"] + comm
            trades.append(dict(open=cur["time"], close=d["time"], side="long" if cur["type"] == "buy" else "short",
                               vol=cur["vol"], gross=gross, swap=d["swap"], comm=comm + cur["comm"] + d["comm"], net=net))
            cur = None
    return trades


def stats(trades, deposit):
    n = len(trades)
    if n == 0:
        return None
    nets = [t["net"] for t in trades]
    wins = [x for x in nets if x > 0]
    loss = [x for x in nets if x <= 0]
    gp, gl = sum(wins), -sum(loss)
    bal, peak, mdd, mdd_pct = deposit, deposit, 0.0, 0.0
    for x in nets:
        bal += x
        peak = max(peak, bal)
        mdd = max(mdd, peak - bal)
        mdd_pct = max(mdd_pct, (peak - bal) / peak * 100)
    return dict(n=n, net=sum(nets), gross_net=sum(t["gross"] + t["swap"] for t in trades),
                comm=sum(t["comm"] for t in trades), pf=(gp / gl if gl > 0 else float("inf")),
                win=len(wins) / n * 100, exp=sum(nets) / n, avg_win=gp / len(wins) if wins else 0.0,
                avg_loss=-gl / len(loss) if loss else 0.0, mdd=mdd, mdd_pct=mdd_pct, lots=sum(t["vol"] for t in trades))


def row(name, s):
    if s is None:
        return f"| {name} | 0 | - | - | - | - | - | - |"
    pf = "inf" if s["pf"] == float("inf") else f"{s['pf']:.2f}"
    return (f"| {name} | {s['n']} | {s['net']:,.2f} | {pf} | {s['win']:.1f}% | {s['exp']:.2f} | "
            f"{s['mdd']:,.2f} ({s['mdd_pct']:.1f}%) | {s['comm']:,.2f} |")


def build_md(path, trades, deposit, comm_per_lot):
    head = "| กลุ่ม | ไม้ | Net หลังหัก comm | PF | Win% | Expectancy/ไม้ | Max DD (balance) | Commission |\n|---|---|---|---|---|---|---|---|"
    s = stats(trades, deposit)
    out = [f"# Stats หลังหัก commission — {path}", "",
           f"commission = {comm_per_lot} / lot (round turn) • deposit = {deposit:,.0f} • DD คำนวณจาก balance ปิดไม้ (ไม่รวม floating — equity DD ดูใน report)", "",
           "## รวม", head, row("ทั้งหมด", s)]
    if s:
        out += ["", f"- Net ก่อนหัก commission (รวม swap): {s['gross_net']:,.2f}",
                f"- Commission รวม: {s['comm']:,.2f} จาก {s['lots']:.2f} lot",
                f"- Net หลังหัก: **{s['net']:,.2f}**"]
    out += ["", "## แยกฝั่ง", head]
    for side in ("long", "short"):
        out.append(row(side, stats([t for t in trades if t["side"] == side], deposit)))
    out += ["", "## รายปี (ตามเวลาปิดไม้)", head]
    by_year = defaultdict(list)
    for t in trades:
        by_year[t["close"][:4]].append(t)
    for y in sorted(by_year):
        out.append(row(y, stats(by_year[y], deposit)))
    return "\n".join(out) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("report")
    ap.add_argument("--commission", type=float, default=7.0, help="InpCommissionPerLot (round turn)")
    ap.add_argument("--deposit", type=float, default=10000.0)
    ap.add_argument("--out", help="เขียนผลลง markdown file (ไม่ระบุ = stdout)")
    a = ap.parse_args()
    trades = pair_trades(parse_deals(read_report(a.report)), a.commission)
    if not trades:
        sys.exit("ไม่พบไม้ที่ปิดแล้วใน report")
    md = build_md(a.report, trades, a.deposit, a.commission)
    if a.out:
        open(a.out, "w", encoding="utf-8").write(md)
    sys.stdout.reconfigure(encoding="utf-8")
    print(md)


if __name__ == "__main__":
    main()
