"""Synthetic SC1–SC3 and SC7 contract tests; no market export is needed."""
import unittest
from datetime import datetime

from research.screener.data import Bar, apply_spread_policy
from research.screener.engine import Intent, _entry_fill, _exit_fill, _swap, market_open_for_entry, resolve_bar_exit


class FillModelTests(unittest.TestCase):
    def test_same_bar_stop_and_target_counts_as_stop(self):
        bar = Bar(datetime(2020, 1, 2, 12), 100, 106, 94, 101, 2)
        self.assertEqual(resolve_bar_exit(1, bar, 95, 105), ("SL", 95))

    def test_gap_through_stop_fills_at_open(self):
        bar = Bar(datetime(2020, 1, 2, 12), 90, 96, 89, 93, 2)
        self.assertEqual(resolve_bar_exit(1, bar, 95, None), ("SL", 90))

    def test_buy_pays_spread_at_entry(self):
        bar = Bar(datetime(2020, 1, 2, 12), 100, 101, 99, 100, 23)
        self.assertAlmostEqual(_entry_fill(Intent(1, 98), bar), 100.23)
        self.assertEqual(_entry_fill(Intent(-1, 102), bar), 100)
        self.assertAlmostEqual(_exit_fill(-1, 100, bar), 100.23)

    def test_wednesday_swap_is_triple(self):
        # Monday open through Thursday close crosses Mon, Tue, Wed rollovers.
        self.assertAlmostEqual(_swap(1, datetime(2020, 1, 6, 12), datetime(2020, 1, 9, 12), 1), -57.03 * 5)
        self.assertAlmostEqual(_swap(-1, datetime(2020, 1, 6, 12), datetime(2020, 1, 9, 12), 1), 39.77 * 5)
        self.assertAlmostEqual(_swap(1, datetime(2020, 1, 8, 12), datetime(2020, 1, 9, 12), 1), -57.03 * 3)

    def test_market_closed_window_blocks_entries_10018(self):
        self.assertFalse(market_open_for_entry(Bar(datetime(2020, 1, 2, 0, 45), 1, 1, 1, 1, 1)))
        self.assertTrue(market_open_for_entry(Bar(datetime(2020, 1, 2, 1, 0), 1, 1, 1, 1, 1)))


class SpreadFloorTests(unittest.TestCase):
    def test_zero_spread_uses_2018_2020_hourly_median(self):
        bars = []
        for year in (2018, 2019, 2020):
            for hour in range(24):
                day = datetime(year, 1, 1, hour)
                bars.extend((Bar(day, 1, 2, 0, 1, 2), Bar(day.replace(minute=15), 1, 2, 0, 1, 6),
                             Bar(day.replace(minute=30), 1, 2, 0, 1, 0)))
        adjusted, floors, zero_count = apply_spread_policy(bars, "floor")
        self.assertEqual(floors, {hour: 4.0 for hour in range(24)})
        self.assertEqual(zero_count, 72)
        self.assertEqual(adjusted[2].spread, 4.0)


if __name__ == "__main__":
    unittest.main()
