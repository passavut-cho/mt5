#!/usr/bin/env python3
"""SmartEA Monitor Dashboard (docs/specs/dashboard-v1.md) — Python stdlib เท่านั้น

อ่าน telemetry ที่ EA เขียน (data/files/telemetry/) แล้วสร้าง HTML ไฟล์เดียว (CSS/SVG inline ไม่โหลดอะไรจากเน็ต)
Read-only: ไม่มีปุ่มสั่งเทรด • ข้อมูลไม่ออกจากเครื่อง

ใช้:
  python scripts/dashboard.py                         # live: อ่าน telemetry -> data/dashboard/index.html
  python scripts/dashboard.py --report data/reports/SmartEA_ema_v1.htm   # backtest (execution = N/A)
"""
import argparse
import csv
import html
import json
import os
import sys
from collections import defaultdict
from datetime import datetime, timedelta, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tests", "python"))

TS = "%Y-%m-%d %H:%M:%S"
CONTRACT = 100.0   # XAUUSD: SYMBOL_TRADE_CONTRACT_SIZE
POINT = 0.01       # XAUUSD: SYMBOL_POINT -> 1 point x 1 lot = $1
NY_OFFSET_H = 7    # IC server = New York + 7h (คงที่ทุกฤดู)


# ───────────────────────── คำนวณ (pure functions — มี unit test) ─────────────────────────
def percentile(values, p):
    """percentile แบบ linear interpolation (เหมือน numpy default); p = 0..100"""
    v = sorted(values)
    if not v:
        return 0.0
    k = (len(v) - 1) * p / 100.0
    lo = int(k)
    hi = min(lo + 1, len(v) - 1)
    return v[lo] + (v[hi] - v[lo]) * (k - lo)


def grade(median, p90):
    """เกรด broker: A ≤0.3pt median & p90 ≤1.5, B ≤0.6/2.5, C อื่นๆ (slip บวก = แย่)"""
    median, p90 = round(median, 6), round(p90, 6)   # กัน float ลอย (0.30000000000000004 > 0.3)
    if median <= 0.3 and p90 <= 1.5:
        return "A"
    if median <= 0.6 and p90 <= 2.5:
        return "B"
    return "C"


def slip_stats(fills):
    """fills = แถวจาก fills.csv (dict) -> สถิติแยก entry/exit • กรอง fill>0 ก่อนเสมอ แล้วนับ reject แยก"""
    ok = [f for f in fills if f["fill"] > 0]
    rejects = len(fills) - len(ok)

    def block(rows):
        s = [r["slip_points"] for r in rows]
        return dict(n=len(s), median=percentile(s, 50), p90=percentile(s, 90), worst=max(s) if s else 0.0)

    ent = block([f for f in ok if f["action"] == "open"])
    ext = block([f for f in ok if f["action"] == "close"])
    allslip = [f["slip_points"] for f in ok]
    cost = sum(f["slip_points"] * f["lot"] * CONTRACT * POINT for f in ok)
    lat = [f["latency_ms"] for f in ok if f["latency_ms"] > 0]
    return dict(entry=ent, exit=ext, rejects=rejects, slip_cost=cost,
                grade=grade(percentile(allslip, 50), percentile(allslip, 90)) if allslip else "N/A",
                latency_median=percentile(lat, 50), latency_p90=percentile(lat, 90),
                latency_worst=max(lat) if lat else 0.0)


def trade_stats(trades):
    """trades = list ของ dict ที่มี profit (net หลังหัก comm/swap แล้ว) -> n, win%, PF, net, per-trade"""
    n = len(trades)
    if n == 0:
        return dict(n=0, net=0.0, win=0.0, pf=0.0, per=0.0)
    nets = [t["net"] for t in trades]
    gp = sum(x for x in nets if x > 0)
    gl = -sum(x for x in nets if x <= 0)
    return dict(n=n, net=sum(nets), win=sum(1 for x in nets if x > 0) / n * 100,
                pf=(gp / gl if gl > 0 else float("inf") if gp > 0 else 0.0), per=sum(nets) / n)


def session_of(t):
    """เอเชีย 01–10 / London 10–15:30 / NY 15:30–23:30 (server time) — นอกนั้น Other"""
    m = t.hour * 60 + t.minute
    if 60 <= m < 600:
        return "Asia"
    if 600 <= m < 930:
        return "London"
    if 930 <= m < 1410:
        return "NY"
    return "Other"


def max_drawdown(curve):
    """curve = list ของ equity/balance -> (DD $, DD %) จาก peak"""
    peak, dd, dd_pct = None, 0.0, 0.0
    for x in curve:
        peak = x if peak is None else max(peak, x)
        dd = max(dd, peak - x)
        if peak > 0:
            dd_pct = max(dd_pct, (peak - x) / peak * 100)
    return dd, dd_pct


# ───────────────────────── โหลดข้อมูล ─────────────────────────
def _f(s, default=0.0):
    try:
        return float(s)
    except (TypeError, ValueError):
        return default


def _t(s):
    try:
        return datetime.strptime(s, TS)
    except (TypeError, ValueError):
        return None


def read_csv(path):
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8-sig", newline="") as fh:
        return list(csv.DictReader(fh))


def load_fills(tdir):
    out = []
    for r in read_csv(os.path.join(tdir, "fills.csv")):
        out.append(dict(time=_t(r.get("time")), magic=r.get("magic", ""), action=r.get("action", ""),
                        side=r.get("side", ""), lot=_f(r.get("lot")), requested=_f(r.get("requested")),
                        fill=_f(r.get("fill")), slip_points=_f(r.get("slip_points")),
                        latency_ms=_f(r.get("latency_ms")), spread_points=_f(r.get("spread_points")),
                        retcode=r.get("retcode", ""), reason=r.get("reason", "")))
    return out


def load_trades(tdir):
    out = []
    for r in read_csv(os.path.join(tdir, "trades.csv")):
        ct = _t(r.get("close_time"))
        if ct is None:
            continue
        profit, comm, swap = _f(r.get("profit")), _f(r.get("commission")), _f(r.get("swap"))
        out.append(dict(magic=r.get("magic", ""), leg=r.get("leg", ""), side=r.get("side", ""),
                        lot=_f(r.get("lot")), open=_t(r.get("open_time")), close=ct,
                        net=profit + comm + swap, swap=swap, reason=r.get("exit_reason", ""),
                        risk_planned=_f(r.get("risk_planned")), risk_actual=_f(r.get("risk_actual"))))
    return sorted(out, key=lambda t: t["close"])


def load_trades_from_report(path, comm_per_lot, deposit):
    """โหมด backtest: ใช้ parser ตัวเดียวกับ tests/python/report_stats.py (หัก commission ตรงกัน)"""
    import report_stats as rs
    raw = rs.pair_trades(rs.parse_deals(rs.read_report(path)), comm_per_lot)
    out = []
    for t in raw:
        out.append(dict(magic="backtest", leg="backtest", side="buy" if t["side"] == "long" else "sell",
                        lot=t["vol"], open=datetime.strptime(t["open"], "%Y.%m.%d %H:%M:%S"),
                        close=datetime.strptime(t["close"], "%Y.%m.%d %H:%M:%S"),
                        net=t["net"], swap=t["swap"], reason="", risk_planned=0.0, risk_actual=0.0))
    return sorted(out, key=lambda t: t["close"])


def load_news_days(path):
    """คืน dict วันที่(date) -> ชื่อ event (NFP/CPI/FOMC) จาก data/files/news.csv"""
    days = {}
    if not os.path.exists(path):
        return days
    with open(path, encoding="utf-8-sig") as fh:
        rows = [ln for ln in fh if ln.strip() and not ln.startswith("#")]
    for r in csv.DictReader(rows):
        try:
            d = datetime.strptime(r["date"].strip(), "%Y-%m-%d").date()
        except (KeyError, ValueError):
            continue
        days.setdefault(d, []).append(r.get("event", "").strip())
    return days


def load_status(tdir):
    p = os.path.join(tdir, "status.json")
    try:
        with open(p, encoding="utf-8-sig") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return None


# ───────────────────────── รวมเป็น model สำหรับ render ─────────────────────────
def build_model(trades, fills, equity_rows, spread_rows, status, news_days, deposit, backtest):
    ref = trades[-1]["close"] if trades else datetime.now()
    if status and _t(status.get("heartbeat")):
        ref = _t(status["heartbeat"])
    m = dict(backtest=backtest, ref=ref, status=status)

    # KPI
    bal = deposit
    curve = [deposit]
    for t in trades:
        bal += t["net"]
        curve.append(bal)
    if equity_rows:
        curve_eq = [_f(r.get("equity")) for r in equity_rows]
        m["balance"] = _f(equity_rows[-1].get("balance"))
        m["equity"] = curve_eq[-1]
        m["dd"] = max_drawdown(curve_eq)
    else:
        m["balance"], m["equity"] = bal, bal
        m["dd"] = max_drawdown(curve)
    m["deposit"] = deposit

    def since(d):
        return sum(t["net"] for t in trades if t["close"] >= d)

    day0 = ref.replace(hour=0, minute=0, second=0, microsecond=0)
    m["today"] = since(day0)
    m["week"] = since(day0 - timedelta(days=day0.weekday()))
    m["month"] = since(day0.replace(day=1))
    m["total"] = trade_stats(trades)
    m["return_pct"] = (m["total"]["net"] / deposit * 100) if deposit else 0.0

    # legs (leg = magic)
    legs = defaultdict(list)
    for t in trades:
        legs[t["magic"]].append(t)
    m["legs"] = []
    for magic, ts in legs.items():
        m["legs"].append(dict(magic=magic, stats=trade_stats(ts), today=sum(t["net"] for t in ts if t["close"] >= day0),
                              month=sum(t["net"] for t in ts if t["close"] >= day0.replace(day=1)),
                              last20=[t["net"] > 0 for t in ts[-20:]]))

    # execution
    m["exec"] = None if backtest else slip_stats(fills)
    if m["exec"]:
        gp = sum(t["net"] for t in trades if t["net"] > 0)
        m["exec"]["vs_edge"] = (m["exec"]["slip_cost"] / gp * 100) if gp > 0 else 0.0
        byh = defaultdict(list)
        for f in fills:
            if f["fill"] > 0 and f["time"]:
                byh[f["time"].hour].append(f["slip_points"])
        m["exec"]["by_hour"] = {h: percentile(v, 50) for h, v in sorted(byh.items())}

    # by session (ตามเวลาเปิดไม้) + slip median ของ entry
    sess = defaultdict(list)
    for t in trades:
        if t["open"]:
            sess[session_of(t["open"])].append(t)
    slip_sess = defaultdict(list)
    for f in fills:
        if f["fill"] > 0 and f["action"] == "open" and f["time"]:
            slip_sess[session_of(f["time"])].append(f["slip_points"])
    m["sessions"] = []
    for name in ("Asia", "London", "NY", "Other"):
        ts = sess.get(name, [])
        m["sessions"].append(dict(name=name, n=len(ts), net=sum(t["net"] for t in ts),
                                  slip=percentile(slip_sess[name], 50) if slip_sess.get(name) else None))

    # news days
    def news_kind(t):
        ev = news_days.get(t["open"].date()) if t["open"] else None
        return ev
    groups = defaultdict(list)
    for t in trades:
        ev = news_kind(t)
        for k in (set(ev) if ev else ["Normal day"]):
            groups[k].append(t)
    m["news"] = {k: trade_stats(v) for k, v in sorted(groups.items())}

    # swap
    m["swap"] = {s: sum(t["swap"] for t in trades if t["side"] == s) for s in ("buy", "sell")}

    # spread by hour
    byh = defaultdict(list)
    for r in spread_rows:
        t = _t(r.get("time"))
        if t:
            byh[t.hour].append(_f(r.get("spread_points")))
    m["spread_hour"] = {h: (percentile(v, 50), percentile(v, 95)) for h, v in sorted(byh.items())}

    # daily P/L + equity curves (actual vs ไม่มี slippage)
    daily = defaultdict(float)
    for t in trades:
        daily[t["close"].date()] += t["net"]
    m["daily"] = dict(daily)
    slips = sorted((f["time"], f["slip_points"] * f["lot"] * CONTRACT * POINT)
                   for f in fills if f["fill"] > 0 and f["time"])
    actual, nosl, cum, cum_slip, si = [], [], 0.0, 0.0, 0
    for t in trades:
        cum += t["net"]
        while si < len(slips) and slips[si][0] <= t["close"]:
            cum_slip += slips[si][1]
            si += 1
        actual.append((t["close"], deposit + cum))
        nosl.append((t["close"], deposit + cum + cum_slip))
    m["curve_actual"], m["curve_noslip"] = actual, nosl
    m["trades"] = trades
    return m


# ───────────────────────── render HTML ─────────────────────────
CSS = """
body{background:#0f1419;color:#d7dde4;font:13px/1.45 Segoe UI,Arial,sans-serif;margin:0;padding:16px}
h1{font-size:18px;margin:0 0 4px}h2{font-size:13px;color:#8a97a6;text-transform:uppercase;letter-spacing:.06em;margin:0 0 8px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(340px,1fr));gap:12px;margin-top:12px}
.card{background:#171d25;border:1px solid #252e3a;border-radius:8px;padding:12px}
.tiles{display:flex;flex-wrap:wrap;gap:8px}.tile{background:#171d25;border:1px solid #252e3a;border-radius:8px;padding:8px 12px;min-width:110px}
.tile b{display:block;font-size:16px}.tile span{color:#8a97a6;font-size:11px}
table{border-collapse:collapse;width:100%}td,th{padding:3px 6px;text-align:right;border-bottom:1px solid #212a35}th{color:#8a97a6;font-weight:500}
td:first-child,th:first-child{text-align:left}
.pos{color:#3fb950}.neg{color:#f85149}.warn{color:#d29922}.mut{color:#8a97a6}
.badge{padding:2px 8px;border-radius:10px;font-weight:600;font-size:11px}
.ok{background:#12301c;color:#3fb950}.bad{background:#3a1618;color:#f85149}.amber{background:#3a2e10;color:#d29922}.gray{background:#252e3a;color:#8a97a6}
.dot{display:inline-block;width:9px;height:9px;border-radius:2px;margin-right:2px}
"""


def e(x):
    return html.escape(str(x))


def money(x, plus=True):
    cls = "pos" if x > 0 else "neg" if x < 0 else "mut"
    return f'<span class="{cls}">{x:+,.2f}</span>' if plus else f"{x:,.2f}"


def pf_txt(pf):
    return "∞" if pf == float("inf") else f"{pf:.2f}"


def na(note="N/A"):
    return f'<span class="mut">{e(note)}</span>'


def tile(label, value):
    return f'<div class="tile"><span>{e(label)}</span><b>{value}</b></div>'


def table(head, rows):
    h = "".join(f"<th>{e(c)}</th>" for c in head)
    body = "".join("<tr>" + "".join(f"<td>{c}</td>" for c in r) + "</tr>" for r in rows)
    return f"<table><tr>{h}</tr>{body}</table>"


def svg_lines(series, w=520, h=150):
    """series = [(color, [(datetime, y)...])] -> polyline SVG"""
    pts = [p for _, s in series for p in s]
    if len(pts) < 2:
        return na("ยังมีข้อมูลไม่พอ")
    t0, t1 = min(p[0] for p in pts), max(p[0] for p in pts)
    y0, y1 = min(p[1] for p in pts), max(p[1] for p in pts)
    span_t = max((t1 - t0).total_seconds(), 1)
    span_y = max(y1 - y0, 1e-9)
    out = [f'<svg viewBox="0 0 {w} {h}" width="100%" role="img">']
    for color, s in series:
        xy = " ".join(f"{(p[0] - t0).total_seconds() / span_t * (w - 10) + 5:.1f},{h - 15 - (p[1] - y0) / span_y * (h - 30):.1f}" for p in s)
        out.append(f'<polyline fill="none" stroke="{color}" stroke-width="1.5" points="{xy}"/>')
    out.append(f'<text x="5" y="11" fill="#8a97a6" font-size="10">{y1:,.0f}</text>'
               f'<text x="5" y="{h - 3}" fill="#8a97a6" font-size="10">{y0:,.0f} • {t0:%Y-%m-%d} → {t1:%Y-%m-%d}</text></svg>')
    return "".join(out)


def svg_bars(items, fmt="{:.1f}", w=520, h=110):
    """items = [(label, value)] -> bar chart (ค่าติดลบสีแดง)"""
    if not items:
        return na("ยังไม่มีข้อมูล")
    mx = max(abs(v) for _, v in items) or 1.0
    bw = (w - 10) / len(items)
    mid = h / 2 - 5
    out = [f'<svg viewBox="0 0 {w} {h}" width="100%" role="img">']
    for i, (lab, v) in enumerate(items):
        bh = abs(v) / mx * (mid - 12)
        y = mid - bh if v >= 0 else mid
        out.append(f'<rect x="{5 + i * bw + 1:.1f}" y="{y:.1f}" width="{max(bw - 2, 1):.1f}" height="{max(bh, 1):.1f}" '
                   f'fill="{"#3fb950" if v >= 0 else "#f85149"}"><title>{e(lab)}: {fmt.format(v)}</title></rect>')
        out.append(f'<text x="{5 + i * bw + bw / 2:.1f}" y="{h - 3}" fill="#8a97a6" font-size="9" text-anchor="middle">{e(lab)}</text>')
    out.append("</svg>")
    return "".join(out)


def calendar(daily):
    if not daily:
        return na("ยังไม่มีไม้ปิด")
    mx = max(abs(v) for v in daily.values()) or 1.0
    months = sorted({(d.year, d.month) for d in daily})[-6:]
    out = []
    for y, mo in months:
        cells = []
        for d in sorted(d for d in daily if (d.year, d.month) == (y, mo)):
            v = daily[d]
            a = 0.25 + 0.75 * abs(v) / mx
            col = f"rgba(63,185,80,{a:.2f})" if v > 0 else f"rgba(248,81,73,{a:.2f})"
            cells.append(f'<span title="{d} {v:+,.2f}" style="display:inline-block;width:22px;height:22px;margin:1px;'
                         f'background:{col};border-radius:3px;font-size:9px;text-align:center;line-height:22px">{d.day}</span>')
        out.append(f'<div><span class="mut">{y}-{mo:02d}</span> {"".join(cells)}</div>')
    return "".join(out)


def render(m):
    s = m["status"] or {}
    bt = m["backtest"]
    hb_age = None
    if s.get("heartbeat"):
        # heartbeat เป็น server time; heartbeat_utc เทียบกับนาฬิกาเครื่องได้ตรงกว่า
        if s.get("heartbeat_utc"):
            hb_age = datetime.now(timezone.utc).timestamp() - float(s["heartbeat_utc"])
    if bt:
        state = '<span class="badge gray">BACKTEST</span>'
    elif hb_age is not None and hb_age < 90:
        state = '<span class="badge ok">RUNNING</span>'
    else:
        state = '<span class="badge bad">STALE / NO DATA</span>'
    mode = s.get("account_mode", "")
    mode_b = ('<span class="badge ok">DEMO</span>' if mode == "DEMO" else
              '<span class="badge bad">REAL — BLOCKED</span>' if mode == "REAL" else
              f'<span class="badge amber">{e(mode or "—")}</span>')
    ref = m["ref"]
    ny = ref - timedelta(hours=NY_OFFSET_H)
    title = e(s.get("strategy", "SmartEA")) + (" · " + e(s["symbol"]) + " " + e(s.get("tf", "")) if s.get("symbol") else " · XAUUSD")
    head = (f"<h1>SmartEA {title} {state} {mode_b}</h1>"
            f'<div class="mut">server {ref:%Y-%m-%d %H:%M} • New York {ny:%H:%M} • '
            f'{"backtest — execution quality N/A ใน tester" if bt else "v" + e(s.get("ea_version", "?")) + " • " + e(s.get("server", ""))}</div>')

    # Gold header
    gold = ""
    if s and not bt:
        sp = s.get("spread_now", 0)
        asian = s.get("asian") or {}
        width, atr = asian.get("width", 0), s.get("atr_d1", 0)
        nn = s.get("next_news")
        nn_txt = f'{e(nn.get("event", ""))} ใน {nn.get("minutes", "?")} นาที' if nn else "ไม่มีในไฟล์"
        gold = '<div class="tiles">' + "".join([
            tile("Bid / Ask", f'{s.get("bid", 0):.2f} / {s.get("ask", 0):.2f}'),
            tile("Spread", f"{sp} pts (${sp * POINT * CONTRACT * 0.01:.2f}/0.01 lot)"),
            tile("ATR M15 / D1 ($)", f'{s.get("atr_m15", 0):.2f} / {atr:.2f}'),
            tile("Asian range", (f'{asian.get("low", 0):.2f}–{asian.get("high", 0):.2f} (กว้าง {width:.2f}' +
                                 (f" = {width / atr:.2f}×ATR D1)" if atr else ")")) if asian.get("valid") else "ยังไม่ valid"),
            tile("ข่าวถัดไป", nn_txt)]) + "</div>"

    # KPI
    dd, dd_pct = m["dd"]
    kpi = '<div class="tiles">' + "".join([
        tile("Balance", f'{m["balance"]:,.2f}'), tile("Equity", f'{m["equity"]:,.2f}'),
        tile("Today", money(m["today"])), tile("Week", money(m["week"])), tile("Month", money(m["month"])),
        tile("Return", f'{m["return_pct"]:+.2f}%'), tile("Max DD", f"{dd:,.2f} ({dd_pct:.1f}%)"),
        tile("Trades / PF", f'{m["total"]["n"]} / {pf_txt(m["total"]["pf"])}')]) + "</div>"

    cards = []
    # Safety + data coverage
    if s and not bt:
        cov = []
        for k, lab in (("holidays_covered_until", "holidays"), ("news_covered_until", "news")):
            y = s.get(k)
            if not y:
                cov.append((lab, '<span class="neg">ไม่มี → EA หยุดเปิดไม้</span>'))
                continue
            left = (datetime(int(y), 12, 31) - ref).days
            cls = "neg" if left < 0 else "warn" if left <= 30 else "pos"
            cov.append((lab, f'<span class="{cls}">ถึง 31 ธ.ค. {y} · เหลือ {left} วัน</span>'))
        headroom = s.get("equity", 0) - s.get("breaker_limit", 0)
        cards.append(("Safety", table(["รายการ", "ค่า"], [
            ["Live guard", e(s.get("live_guard", "?"))],
            ["Breaker headroom", f'{headroom:,.2f} (limit {s.get("breaker_limit", 0):,.2f})'],
            ["Halted", '<span class="neg">YES</span>' if s.get("halted") else '<span class="pos">no</span>'],
            ["Connected", e(s.get("connected"))],
            *[[f"Data coverage: {a}", b] for a, b in cov]])))
        cards.append(("Guards", table(["Guard", "สถานะ"], [
            ["Spread vs max", f'{s.get("spread_now", 0)} / {s.get("spread_max", 0)} pts'],
            ["News window", "ACTIVE" if s.get("news_window_active") else "-"],
            ["Holiday today", "YES" if s.get("holiday_today") else "-"],
            ["Session", "open" if s.get("session_open") else "closed"],
            ["Telemetry heartbeat", e(s.get("heartbeat", "-")) + (f" ({hb_age:.0f}s)" if hb_age is not None else "")]])))
        pos = s.get("open_positions") or []
        cards.append(("Open now", table(["ticket", "side", "lot", "entry", "SL", "TP", "อายุ(นาที)", "P/L", "risk@SL"],
            [[e(p.get("ticket")), e(p.get("side")), p.get("lot"), p.get("entry"), p.get("sl"), p.get("tp"),
              p.get("age_min"), money(_f(p.get("pl"))), e(p.get("risk_at_sl", "-"))] for p in pos]) if pos else na("ไม่มีไม้เปิด")))

    # Legs
    rows = []
    for lg in m["legs"]:
        st = lg["stats"]
        dots = "".join(f'<span class="dot" style="background:{"#3fb950" if w else "#f85149"}"></span>' for w in lg["last20"])
        rows.append([e(lg["magic"]), money(lg["today"]), money(lg["month"]), st["n"], f'{st["win"]:.0f}%',
                     pf_txt(st["pf"]), money(st["per"]), dots])
    cards.append(("Legs (1 magic = 1 leg)", table(["magic", "today", "month", "ไม้", "win", "PF", "ต่อไม้", "20 ล่าสุด"], rows) if rows else na("ยังไม่มีไม้")))

    # Execution
    ex = m["exec"]
    if ex is None:
        cards.append(("Execution quality", na("N/A ใน tester — ไม่มี slippage จริง")))
    elif not (ex["entry"]["n"] or ex["exit"]["n"]):
        cards.append(("Execution quality", na("ยังไม่มี fill") + f' • reject {ex["rejects"]}'))
    else:
        def r(name, b):
            return [name, b["n"], f'{b["median"]:+.2f}', f'{b["p90"]:+.2f}', f'{b["worst"]:+.2f}']
        gcls = {"A": "ok", "B": "amber", "C": "bad"}.get(ex["grade"], "gray")
        cards.append(("Execution quality (slip points, + = แย่)",
                      table(["", "n", "median", "p90", "worst"], [r("Entry", ex["entry"]), r("Exit", ex["exit"])]) +
                      f'<p>Broker grade <span class="badge {gcls}">{ex["grade"]}</span> • latency median {ex["latency_median"]:.0f} / p90 {ex["latency_p90"]:.0f} / worst {ex["latency_worst"]:.0f} ms<br>'
                      f'Slip cost {money(-ex["slip_cost"])} • slip vs edge {ex["vs_edge"]:.1f}% • reject/requote {ex["rejects"]}</p>'
                      + svg_bars([(f"{h:02d}", v) for h, v in ex["by_hour"].items()], "{:+.2f} pt")))

    # Sessions
    cards.append(("By session (ตามเวลาเปิดไม้, server)", table(["session", "ไม้", "P/L", "slip median"],
        [[x["name"], x["n"], money(x["net"]), f'{x["slip"]:+.2f}' if x["slip"] is not None else na("N/A")] for x in m["sessions"]])))
    cards.append(("News days", table(["วัน", "ไม้", "P/L", "win", "PF"],
        [[e(k), v["n"], money(v["net"]), f'{v["win"]:.0f}%', pf_txt(v["pf"])] for k, v in m["news"].items()]) if m["news"] else na("ยังไม่มีไม้")))
    cards.append(("Swap สะสม", table(["ฝั่ง", "swap $"], [["long", money(m["swap"]["buy"])], ["short", money(m["swap"]["sell"])]])))
    cards.append(("Gold spread by hour (p95, pts)", svg_bars([(f"{h:02d}", p95) for h, (_, p95) in m["spread_hour"].items()], "{:.0f}")
                  if m["spread_hour"] else na("ไม่มี spread_snap")))

    body = [head, gold, kpi, '<div class="grid">']
    body += [f'<div class="card"><h2>{e(t)}</h2>{c}</div>' for t, c in cards]
    body.append(f'<div class="card" style="grid-column:1/-1"><h2>Equity: จริง (ฟ้า) vs ถ้าไม่มี slippage (เทา)</h2>'
                + svg_lines([("#6b7785", m["curve_noslip"]), ("#58a6ff", m["curve_actual"])]) + "</div>")
    body.append(f'<div class="card" style="grid-column:1/-1"><h2>Daily P/L (6 เดือนล่าสุด)</h2>{calendar(m["daily"])}</div></div>')
    refresh = "" if bt else '<meta http-equiv="refresh" content="30">'
    return (f'<!doctype html><html><head><meta charset="utf-8">{refresh}<title>SmartEA Dashboard</title>'
            f"<style>{CSS}</style></head><body>{''.join(body)}"
            f'<p class="mut">สร้างเมื่อ {datetime.now():%Y-%m-%d %H:%M:%S} (เครื่องนี้) • read-only • ไม่มีข้อมูลออกจากเครื่อง</p></body></html>')


# ───────────────────────── main ─────────────────────────
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--telemetry", default=os.path.join(ROOT, "data", "files", "telemetry"))
    ap.add_argument("--report", help="MT5 backtest report .htm (โหมด backtest)")
    ap.add_argument("--out", default=os.path.join(ROOT, "data", "dashboard", "index.html"))
    ap.add_argument("--news", default=os.path.join(ROOT, "data", "files", "news.csv"))
    ap.add_argument("--commission", type=float, default=7.0, help="InpCommissionPerLot (ใช้เฉพาะ --report)")
    ap.add_argument("--deposit", type=float, default=10000.0)
    a = ap.parse_args()

    news = load_news_days(a.news)
    if a.report:
        trades = load_trades_from_report(a.report, a.commission, a.deposit)
        m = build_model(trades, [], [], [], None, news, a.deposit, True)
    else:
        status = load_status(a.telemetry)
        eq = read_csv(os.path.join(a.telemetry, "equity_snap.csv"))
        dep = _f(eq[0].get("balance"), a.deposit) if eq else a.deposit
        m = build_model(load_trades(a.telemetry), load_fills(a.telemetry), eq,
                        read_csv(os.path.join(a.telemetry, "spread_snap.csv")), status, news, dep, False)
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    with open(a.out, "w", encoding="utf-8") as fh:
        fh.write(render(m))
    sys.stdout.reconfigure(encoding="utf-8")
    t = m["total"]
    print(f"dashboard -> {a.out} • trades={t['n']} net={t['net']:,.2f} PF={pf_txt(t['pf'])}")


if __name__ == "__main__":
    main()
