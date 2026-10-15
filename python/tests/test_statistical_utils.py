import unittest

import numpy as np

from python.src.statistical_utils import (
    hedges_g,
    mean_confidence_interval,
    welch_mean_difference,
    wilson_interval,
)


class StatisticalUtilsTests(unittest.TestCase):
    def test_mean_interval_contains_sample_mean(self) -> None:
        interval = mean_confidence_interval(np.array([1, 2, 3, 4, 5]))
        self.assertEqual(interval.estimate, 3.0)
        self.assertLess(interval.lower, interval.estimate)
        self.assertGreater(interval.upper, interval.estimate)

    def test_welch_difference_uses_group_a_minus_b(self) -> None:
        result = welch_mean_difference(
            np.array([1.0, 2.0, 3.0]), np.array([4.0, 5.0, 6.0])
        )
        self.assertAlmostEqual(result["estimate"], -3.0)
        self.assertLess(result["t_statistic"], 0)

    def test_hedges_g_sign_matches_mean_difference(self) -> None:
        effect = hedges_g(
            np.array([1.0, 2.0, 3.0]), np.array([4.0, 5.0, 6.0])
        )
        self.assertLess(effect, 0)

    def test_wilson_interval_for_half_successes(self) -> None:
        interval = wilson_interval(50, 100)
        self.assertAlmostEqual(interval.estimate, 0.5)
        self.assertLess(interval.lower, 0.5)
        self.assertGreater(interval.upper, 0.5)

    def test_wilson_interval_rejects_invalid_counts(self) -> None:
        with self.assertRaises(ValueError):
            wilson_interval(11, 10)


if __name__ == "__main__":
    unittest.main()

