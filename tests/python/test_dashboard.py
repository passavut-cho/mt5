"""unit test ของ scripts/dashboard.py — รัน: python -m unittest tests/python/test_dashboard.py"""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(HERE)), "scripts"))
import dashboard as d  # noqa: E402

FIX = os.path.join(HERE, "fixtures", "telemetry")
REPORT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "data", "reports", "SmartEA_ema_v1.htm")


class TestSlip(unittest.TestCase):
    def test_percentile(self):
        self.assertAlmostEqual(d.percentile([1, 2, 3, 4], 50), 2.5)
        self.assertAlmostEqual(d.percentile([5], 90), 5)
        self.assertEqual(d.percentile([], 50), 0.0)

    def test_grade_boundaries(self):
        self.assertEqual(d.grade(0.3, 1.5), "A")
        self.assertEqual(d.grade(0.31, 1.0), "B")
        self.assertEqual(d.grade(0.3, 1.6), "B")
        self.assertEqual(d.grade(0.6, 2.5), "B")
        self.assertEqual(d.grade(0.7, 1.0), "C")
        self.assertEqual(d.grade(-1.0, 0.0), "A")   # slip ลบ = ดีต่อเรา

    def test_fixture_entry_slip_and_reject_filter(self):
        st = d.slip_stats(d.load_fills(FIX))
        e = st["entry"]
        self.assertEqual(e["n"], 10)                 # reject 2 แถว (fill=0, slip 50) ต้องไม่ปนเข้ามา
        self.assertEqual(st["rejects"], 2)
        self.assertAlmostEqual(e["median"], 0.3)     # (0.2+0.4)/2
        self.assertAlmostEqual(e["p90"], 1.46)       # 1.4 + 0.1*(2.0-1.4)
        self.assertAlmostEqual(e["worst"], 2.0)
        self.assertEqual(st["exit"]["n"], 2)
        # slip cost $ = sum(slip x lot x 1$/pt): entry 4.8 pt + exit 0 -> x0.10 lot = 0.48
        self.assertAlmostEqual(st["slip_cost"], 0.48)
        self.assertEqual(st["grade"], "A")           # รวมทุก fill: median 0.3 / p90 <= 1.5

    def test_session(self):
        from datetime import datetime
        self.assertEqual(d.session_of(datetime(2026, 1, 1, 3, 0)), "Asia")
        self.assertEqual(d.session_of(datetime(2026, 1, 1, 12, 0)), "London")
        self.assertEqual(d.session_of(datetime(2026, 1, 1, 15, 30)), "NY")
        self.assertEqual(d.session_of(datetime(2026, 1, 1, 23, 45)), "Other")


class TestModel(unittest.TestCase):
    def test_live_fixture_renders(self):
        trades = d.load_trades(FIX)
        self.assertEqual(len(trades), 2)
        self.assertAlmostEqual(sum(t["net"] for t in trades), -1.97)   # 100-0.7 + (-100-0.7-0.57)
        m = d.build_model(trades, d.load_fills(FIX), d.read_csv(os.path.join(FIX, "equity_snap.csv")),
                          d.read_csv(os.path.join(FIX, "spread_snap.csv")), None, {}, 10000.0, False)
        out = d.render(m)
        self.assertIn("Broker grade", out)
        self.assertNotIn("http://", out.replace("http-equiv", ""))     # ไม่โหลดอะไรจากเน็ต

    @unittest.skipUnless(os.path.exists(REPORT), "ไม่มี report ema_v1 (data/reports ถูก gitignore)")
    def test_report_mode_matches_report_stats(self):
        trades = d.load_trades_from_report(REPORT, 7.0, 10000.0)
        self.assertEqual(len(trades), 426)
        self.assertAlmostEqual(sum(t["net"] for t in trades), -3777.38, places=2)


if __name__ == "__main__":
    unittest.main()
