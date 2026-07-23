import os
import tempfile
import unittest

from earnings.app import earnings_logic as logic


class ManualBalancesTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".json")
        self.tmp.close()
        self.previous_path = os.environ.get("EARNINGS_MANUAL_BALANCES_PATH")
        os.environ["EARNINGS_MANUAL_BALANCES_PATH"] = self.tmp.name
        logic.MANUAL_BALANCES_PATH = self.tmp.name

    def tearDown(self):
        if self.previous_path is None:
            os.environ.pop("EARNINGS_MANUAL_BALANCES_PATH", None)
        else:
            os.environ["EARNINGS_MANUAL_BALANCES_PATH"] = self.previous_path
        if os.path.exists(self.tmp.name):
            os.remove(self.tmp.name)

    def test_compute_manual_daily_average_uses_elapsed_days(self):
        logic.set_manual_balance(
            "repocket",
            0.10,
            timestamp="2026-07-01T00:00:00+00:00",
        )
        logic.set_manual_balance(
            "repocket",
            0.20,
            timestamp="2026-07-06T00:00:00+00:00",
        )

        average = logic.compute_manual_daily_average("repocket")

        self.assertAlmostEqual(average, 0.02, places=6)

    def test_compute_rolling_daily_average_ignores_single_outlier(self):
        changes = [1.0, 1.2, 1.1, 0.9, 0.8, 100.0]

        average = logic.compute_rolling_daily_average(changes)

        self.assertAlmostEqual(average, 1.0, places=6)


if __name__ == "__main__":
    unittest.main()
