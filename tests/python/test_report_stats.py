import importlib.util
import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("report_stats", ROOT / "report_stats.py")
report_stats = importlib.util.module_from_spec(spec)
spec.loader.exec_module(report_stats)


class ReportStatsTests(unittest.TestCase):
    def setUp(self):
        fixture = ROOT / "fixtures" / "report_stats_partial.htm"
        self.deals = report_stats.parse_deals(report_stats.read_report(fixture))

    def test_partial_exits_form_one_trade_with_all_costs(self):
        trades = report_stats.pair_trades(self.deals, 7.0)
        self.assertEqual(len(trades), 2)
        trade = trades[0]
        self.assertEqual(trade["vol"], 1.0)
        self.assertAlmostEqual(trade["gross"], 110.0)
        self.assertAlmostEqual(trade["swap"], -3.0)
        self.assertAlmostEqual(trade["comm"], -12.5)
        self.assertAlmostEqual(trade["net"], 94.5)

    def test_swap_nights_and_weekend_summary(self):
        trades = report_stats.pair_trades(self.deals, 7.0)
        self.assertEqual(report_stats.nights_held(trades[0]), 3)
        self.assertTrue(report_stats.crossed_weekend(trades[0]))
        self.assertFalse(report_stats.crossed_weekend(trades[1]))
        md = report_stats.build_md("fixture.htm", trades, 10000.0, 7.0)
        self.assertIn("| long | -3.00 | 3.00 | 1 | 94.50 |", md)
        self.assertIn("| short | 0.25 | 1.00 | 0 | 0.00 |", md)
        self.assertIn("ขาดทุนเกิน 1R: คำนวณไม่ได้", md)

    def test_incomplete_position_is_not_counted(self):
        deals = self.deals[:1]
        self.assertEqual(report_stats.pair_trades(deals, 7.0), [])


if __name__ == "__main__":
    unittest.main()
