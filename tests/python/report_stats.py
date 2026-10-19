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
from datetime import datetime, timedelta
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


def parse_time(value):
    """แปลงเวลาจากตาราง Deals ของ MT5 (เวลาของ server)"""
    for fmt in ("%Y.%m.%d %H:%M:%S", "%Y.%m.%d %H:%M"):
        try:
            return datetime.strptime(value, fmt)
        except ValueError:
            pass
    return datetime.strptime(value[:10], "%Y.%m.%d")


def pair_trades(deals, comm_per_lot):
    """รวม deal เข้า/ออกทั้งหมดของ position เดียว; position ค้างเมื่อจบ report ไม่นับ"""
    trades, cur = [], None
    for d in deals:
        if d["dir"] == "in":
            # EA เปิดได้ครั้งละ 1 position; รองรับ entry deal ที่ถูกแบ่งเป็นหลายส่วนด้วย
            if cur is None:
                cur = dict(open=d["time"], type=d["type"], vol=0.0, exit_vol=0.0,
                           gross=0.0, swap=0.0, deal_comm=0.0, close=d["time"])
            cur["vol"] += d["vol"]
            cur["swap"] += d["swap"]
            cur["deal_comm"] += d["comm"]
        elif d["dir"] == "out" and cur is not None:
            cur["exit_vol"] += d["vol"]
            cur["gross"] += d["profit"]
            cur["swap"] += d["swap"]
            cur["deal_comm"] += d["comm"]
            cur["close"] = d["time"]
            if cur["exit_vol"] + 1e-8 >= cur["vol"]:
                comm = -comm_per_lot * cur["vol"]
                net = cur["gross"] + cur["swap"] + cur["deal_comm"] + comm
                trades.append(dict(open=cur["open"], close=cur["close"],
                                   side="long" if cur["type"] == "buy" else "short",
                                   vol=cur["vol"], gross=cur["gross"], swap=cur["swap"],
                                   comm=comm + cur["deal_comm"], net=net))
                cur = None
    return trades


def nights_held(trade):
    return max(0, (parse_time(trade["close"]).date() - parse_time(trade["open"]).date()).days)


def crossed_weekend(trade):
    """True เมื่อถือผ่านวันจันทร์ 00:00 server หลังวันศุกร์ 20:00"""
    opened, closed = parse_time(trade["open"]), parse_time(trade["close"])
    for offset in range(-7, 8):
        day = opened.date() + timedelta(days=offset)
        if day.weekday() != 4:
            continue
        cutoff = datetime.combine(day, datetime.min.time()).replace(hour=20)
        monday = cutoff + timedelta(days=2, hours=4)
        if opened < monday and closed >= monday:
            return True
    return False


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


def apply_stress(trades, extra_points, contract_size, point):
    """สร้างชุดไม้ stress: หักต้นทุนเพิ่ม extra_points x contract_size x point x volume ต่อไม้ (round turn)"""
    out = []
    for t in trades:
        extra = extra_points * contract_size * point * t["vol"]
        out.append(dict(t, net=t["net"] - extra, comm=t["comm"] - extra))
    return out


def build_stress_md(trades, stress, deposit, extra_points):
    head = "| ชุด | ไม้ | Net | PF | Win% | Expectancy/ไม้ | Max DD (balance) | ต้นทุนรวม (comm+extra) |\n|---|---|---|---|---|---|---|---|"
    extra = sum(a["net"] - b["net"] for a, b in zip(trades, stress))
    return ["", f"## Cost stress (+{extra_points:g} points ต่อ round turn)", head,
            row("base", stats(trades, deposit)), row(f"stress +{extra_points:g}", stats(stress, deposit)),
            "", f"- ต้นทุนเพิ่มรวม: {extra:,.2f} จาก {sum(t['vol'] for t in trades):.2f} lot"]


def build_md(path, trades, deposit, comm_per_lot, extra_points=0.0, contract_size=100.0, point=0.01):
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
    out += ["", "## Swap และระยะเวลาถือ", "",
            "| ฝั่ง | Swap รวม | คืนถือเฉลี่ย | ไม้ข้ามสุดสัปดาห์ | Net ไม้ข้ามสุดสัปดาห์ |",
            "|---|---:|---:|---:|---:|"]
    for side in ("long", "short"):
        group = [t for t in trades if t["side"] == side]
        weekends = [t for t in group if crossed_weekend(t)]
        avg_nights = sum(nights_held(t) for t in group) / len(group) if group else 0.0
        out.append(f"| {side} | {sum(t['swap'] for t in group):,.2f} | {avg_nights:.2f} | "
                   f"{len(weekends)} | {sum(t['net'] for t in weekends):,.2f} |")
    total_weekends = [t for t in trades if crossed_weekend(t)]
    out += ["", f"- ถือข้ามสุดสัปดาห์รวม: {len(total_weekends)} ไม้, net {sum(t['net'] for t in total_weekends):,.2f}",
            "- ขาดทุนเกิน 1R: คำนวณไม่ได้จาก Deals table เพียงอย่างเดียว เพราะ report ไม่มี initial SL/ระยะ 1R ของแต่ละ position"]
    if extra_points:
        out += build_stress_md(trades, apply_stress(trades, extra_points, contract_size, point), deposit, extra_points)
    return "\n".join(out) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("report")
    ap.add_argument("--commission", type=float, default=7.0, help="InpCommissionPerLot (round turn)")
    ap.add_argument("--deposit", type=float, default=10000.0)
    ap.add_argument("--extra-cost-points", type=float, default=0.0, help="cost stress: points เพิ่มต่อ round turn (ทอง 20 = $20/lot)")
    ap.add_argument("--contract-size", type=float, default=100.0, help="SYMBOL_TRADE_CONTRACT_SIZE (XAUUSD = 100)")
    ap.add_argument("--point", type=float, default=0.01, help="SYMBOL_POINT (XAUUSD = 0.01)")
    ap.add_argument("--out", help="เขียนผลลง markdown file (ไม่ระบุ = stdout)")
    a = ap.parse_args()
    trades = pair_trades(parse_deals(read_report(a.report)), a.commission)
    if not trades:
        sys.exit("ไม่พบไม้ที่ปิดแล้วใน report")
    md = build_md(a.report, trades, a.deposit, a.commission, a.extra_cost_points, a.contract_size, a.point)
    if a.out:
        open(a.out, "w", encoding="utf-8").write(md)
    sys.stdout.reconfigure(encoding="utf-8")
    print(md)


if __name__ == "__main__":
    main()
