"""Reusable functions for two-arm experiment planning."""

from __future__ import annotations

from math import asin, ceil, sqrt

from scipy import stats


def cohens_h(control_rate: float, treatment_rate: float) -> float:
    """Return the absolute arcsine effect size for two proportions."""
    _validate_rates(control_rate, treatment_rate)
    return abs(
        2 * asin(sqrt(treatment_rate)) - 2 * asin(sqrt(control_rate))
    )


def sample_size_two_proportions(
    control_rate: float,
    treatment_rate: float,
    alpha: float = 0.05,
    power: float = 0.80,
) -> int:
    """Return equal-allocation sample size per arm using a normal approximation."""
    _validate_rates(control_rate, treatment_rate)
    if control_rate == treatment_rate:
        raise ValueError("Control and treatment rates must differ.")
    if not 0 < alpha < 1 or not 0 < power < 1:
        raise ValueError("alpha and power must be within (0, 1).")

    pooled_rate = (control_rate + treatment_rate) / 2
    difference = abs(treatment_rate - control_rate)
    critical_alpha = stats.norm.ppf(1 - alpha / 2)
    critical_power = stats.norm.ppf(power)
    numerator = (
        critical_alpha * sqrt(2 * pooled_rate * (1 - pooled_rate))
        + critical_power
        * sqrt(
            control_rate * (1 - control_rate)
            + treatment_rate * (1 - treatment_rate)
        )
    ) ** 2
    return ceil(numerator / difference**2)


def inflate_per_arm(sample_size: int, analyzable_fraction: float) -> int:
    """Inflate an arm's target for missing or non-analyzable outcomes."""
    if sample_size <= 0:
        raise ValueError("sample_size must be positive.")
    if not 0 < analyzable_fraction <= 1:
        raise ValueError("analyzable_fraction must be within (0, 1].")
    return ceil(sample_size / analyzable_fraction)


def enrollment_months(total_sample: int, eligible_orders_per_month: float) -> int:
    """Return whole calendar months needed to reach the target sample."""
    if total_sample <= 0 or eligible_orders_per_month <= 0:
        raise ValueError("Sample and monthly enrollment must be positive.")
    return ceil(total_sample / eligible_orders_per_month)


def _validate_rates(*rates: float) -> None:
    if any(rate <= 0 or rate >= 1 for rate in rates):
        raise ValueError("Rates must be strictly within (0, 1).")

