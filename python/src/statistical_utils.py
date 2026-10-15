"""Reusable statistical helpers for the delivery and review analysis."""

from __future__ import annotations

from dataclasses import asdict, dataclass
from math import sqrt

import numpy as np
from scipy import stats


@dataclass(frozen=True)
class Interval:
    estimate: float
    lower: float
    upper: float
    confidence: float = 0.95

    def to_dict(self) -> dict[str, float]:
        return asdict(self)


def _clean(values: np.ndarray) -> np.ndarray:
    array = np.asarray(values, dtype=float)
    return array[np.isfinite(array)]


def mean_confidence_interval(
    values: np.ndarray, confidence: float = 0.95
) -> Interval:
    """Return a two-sided t interval for a population mean."""
    sample = _clean(values)
    if sample.size < 2:
        raise ValueError("At least two finite observations are required.")
    mean = float(np.mean(sample))
    standard_error = float(stats.sem(sample))
    critical = float(stats.t.ppf((1 + confidence) / 2, sample.size - 1))
    margin = critical * standard_error
    return Interval(mean, mean - margin, mean + margin, confidence)


def welch_mean_difference(
    group_a: np.ndarray,
    group_b: np.ndarray,
    confidence: float = 0.95,
) -> dict[str, float]:
    """Compare group A minus group B using Welch's unequal-variance method."""
    a = _clean(group_a)
    b = _clean(group_b)
    if a.size < 2 or b.size < 2:
        raise ValueError("Both groups require at least two finite observations.")

    variance_a = float(np.var(a, ddof=1))
    variance_b = float(np.var(b, ddof=1))
    component_a = variance_a / a.size
    component_b = variance_b / b.size
    standard_error = sqrt(component_a + component_b)
    degrees_freedom = (component_a + component_b) ** 2 / (
        component_a**2 / (a.size - 1) + component_b**2 / (b.size - 1)
    )
    difference = float(np.mean(a) - np.mean(b))
    critical = float(stats.t.ppf((1 + confidence) / 2, degrees_freedom))
    test = stats.ttest_ind(a, b, equal_var=False)

    return {
        "estimate": difference,
        "lower": difference - critical * standard_error,
        "upper": difference + critical * standard_error,
        "confidence": confidence,
        "standard_error": standard_error,
        "degrees_freedom": float(degrees_freedom),
        "t_statistic": float(test.statistic),
        "p_value": float(test.pvalue),
    }


def hedges_g(group_a: np.ndarray, group_b: np.ndarray) -> float:
    """Return bias-corrected standardized mean difference, group A minus B."""
    a = _clean(group_a)
    b = _clean(group_b)
    degrees_freedom = a.size + b.size - 2
    pooled_variance = (
        (a.size - 1) * np.var(a, ddof=1) + (b.size - 1) * np.var(b, ddof=1)
    ) / degrees_freedom
    correction = 1 - 3 / (4 * degrees_freedom - 1)
    return float(correction * (np.mean(a) - np.mean(b)) / sqrt(pooled_variance))


def mann_whitney_effect(group_a: np.ndarray, group_b: np.ndarray) -> dict[str, float]:
    """Return Mann-Whitney test and rank-biserial effect, group A minus B."""
    a = _clean(group_a)
    b = _clean(group_b)
    test = stats.mannwhitneyu(a, b, alternative="two-sided", method="asymptotic")
    rank_biserial = 2 * float(test.statistic) / (a.size * b.size) - 1
    return {
        "u_statistic": float(test.statistic),
        "p_value": float(test.pvalue),
        "rank_biserial": rank_biserial,
    }


def wilson_interval(successes: int, total: int, confidence: float = 0.95) -> Interval:
    """Return a Wilson score interval for a binomial proportion."""
    if total <= 0 or successes < 0 or successes > total:
        raise ValueError("Require 0 <= successes <= total and total > 0.")
    z_value = float(stats.norm.ppf((1 + confidence) / 2))
    proportion = successes / total
    denominator = 1 + z_value**2 / total
    center = (proportion + z_value**2 / (2 * total)) / denominator
    margin = z_value / denominator * sqrt(
        proportion * (1 - proportion) / total + z_value**2 / (4 * total**2)
    )
    return Interval(proportion, center - margin, center + margin, confidence)


def fisher_correlation_interval(
    correlation: float, sample_size: int, confidence: float = 0.95
) -> Interval:
    """Return the large-sample Fisher-z interval used for correlation sensitivity."""
    if sample_size <= 3 or not -1 < correlation < 1:
        raise ValueError("Correlation must be within (-1, 1) and n must exceed 3.")
    z_score = np.arctanh(correlation)
    standard_error = 1 / sqrt(sample_size - 3)
    critical = float(stats.norm.ppf((1 + confidence) / 2))
    lower, upper = np.tanh(
        [z_score - critical * standard_error, z_score + critical * standard_error]
    )
    return Interval(float(correlation), float(lower), float(upper), confidence)

