import unittest

from python.src.experiment_utils import (
    cohens_h,
    enrollment_months,
    inflate_per_arm,
    sample_size_two_proportions,
)


class ExperimentUtilsTests(unittest.TestCase):
    def test_smaller_mde_requires_more_observations(self) -> None:
        small_effect = sample_size_two_proportions(0.54, 0.51)
        large_effect = sample_size_two_proportions(0.54, 0.46)
        self.assertGreater(small_effect, large_effect)

    def test_selected_portfolio_scenario_matches_documented_target(self) -> None:
        sample = sample_size_two_proportions(0.5406604881869208, 0.4906604881869208)
        self.assertEqual(sample, 1568)

    def test_effect_size_is_symmetric_and_positive(self) -> None:
        self.assertAlmostEqual(cohens_h(0.54, 0.49), cohens_h(0.49, 0.54))
        self.assertGreater(cohens_h(0.54, 0.49), 0)

    def test_attrition_inflates_target(self) -> None:
        self.assertEqual(inflate_per_arm(100, 0.80), 125)

    def test_enrollment_duration_rounds_up(self) -> None:
        self.assertEqual(enrollment_months(1001, 500), 3)

    def test_equal_rates_are_rejected(self) -> None:
        with self.assertRaises(ValueError):
            sample_size_two_proportions(0.50, 0.50)


if __name__ == "__main__":
    unittest.main()
