"""Generate the Stage 9 A/B test sample-size and feasibility outputs."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from experiment_utils import (
    cohens_h,
    enrollment_months,
    inflate_per_arm,
    sample_size_two_proportions,
)


ALPHA = 0.05
POWER = 0.80
ANALYZABLE_FRACTION = 0.90
MDE_VALUES = (0.03, 0.05, 0.08, 0.10)
VOLUME_SCENARIOS = (500, 1000, 1500)


def historical_late_low_review_rate(stage08_results: dict[str, object]) -> float:
    for group in stage08_results["descriptive_statistics"]:
        if group["delivery_group"] == "late":
            return float(group["low_review_rate"])
    raise ValueError("Stage 8 results do not contain the late-delivery group.")


def build_sample_scenarios(baseline_rate: float) -> pd.DataFrame:
    rows = []
    for mde in MDE_VALUES:
        treatment_rate = baseline_rate - mde
        per_arm = sample_size_two_proportions(
            baseline_rate, treatment_rate, alpha=ALPHA, power=POWER
        )
        adjusted_per_arm = inflate_per_arm(per_arm, ANALYZABLE_FRACTION)
        rows.append(
            {
                "absolute_mde": mde,
                "relative_reduction": mde / baseline_rate,
                "planned_treatment_rate": treatment_rate,
                "cohens_h": cohens_h(baseline_rate, treatment_rate),
                "sample_per_arm": per_arm,
                "total_analyzable_sample": per_arm * 2,
                "adjusted_sample_per_arm": adjusted_per_arm,
                "total_enrollment_target": adjusted_per_arm * 2,
            }
        )
    return pd.DataFrame(rows)


def build_duration_scenarios(
    total_enrollment_target: int, historical_monthly_volume: float
) -> list[dict[str, float | int | str]]:
    volumes: list[tuple[str, float]] = [
        ("historical actual-late proxy", historical_monthly_volume),
        *[(f"{volume} eligible orders/month", float(volume)) for volume in VOLUME_SCENARIOS],
    ]
    return [
        {
            "scenario": label,
            "eligible_orders_per_month": volume,
            "estimated_enrollment_months": enrollment_months(
                total_enrollment_target, volume
            ),
        }
        for label, volume in volumes
    ]


def create_power_figure(
    baseline_rate: float, output_directory: Path, selected_mde: float
) -> None:
    mdes = np.arange(0.02, 0.101, 0.005)
    totals = []
    for mde in mdes:
        per_arm = sample_size_two_proportions(
            baseline_rate, baseline_rate - mde, alpha=ALPHA, power=POWER
        )
        totals.append(inflate_per_arm(per_arm, ANALYZABLE_FRACTION) * 2)

    figure, axis = plt.subplots(figsize=(8, 4.8))
    axis.plot(mdes * 100, totals, color="#2F6690", linewidth=2)
    selected_index = int(np.argmin(np.abs(mdes - selected_mde)))
    axis.scatter(
        [mdes[selected_index] * 100],
        [totals[selected_index]],
        color="#D1495B",
        s=70,
        zorder=3,
    )
    axis.annotate(
        f"Selected: {selected_mde * 100:.0f} pp\nn={totals[selected_index]:,}",
        (mdes[selected_index] * 100, totals[selected_index]),
        textcoords="offset points",
        xytext=(12, 10),
    )
    axis.set(
        xlabel="Minimum detectable absolute reduction (percentage points)",
        ylabel="Total enrollment target",
        title="Smaller effects require sharply larger experiments",
    )
    axis.grid(alpha=0.2)
    figure.tight_layout()
    figure.savefig(output_directory / "stage09_sample_size_curve.png", dpi=180)
    plt.close(figure)


def run(
    stage08_path: Path, monthly_capacity_path: Path, output_directory: Path
) -> dict[str, object]:
    stage08_results = json.loads(stage08_path.read_text(encoding="utf-8"))
    capacity = pd.read_csv(monthly_capacity_path, parse_dates=["purchase_month"])
    required_capacity_columns = {"purchase_month", "late_reviewed_orders"}
    if not required_capacity_columns.issubset(capacity.columns):
        raise ValueError("Monthly capacity export is missing required columns.")

    baseline_rate = historical_late_low_review_rate(stage08_results)
    scenarios = build_sample_scenarios(baseline_rate)
    selected = scenarios.loc[scenarios["absolute_mde"].eq(0.05)].iloc[0]
    historical_monthly_volume = float(capacity["late_reviewed_orders"].mean())

    results: dict[str, object] = {
        "experiment": "proactive delay notification with updated ETA",
        "planning_baseline_low_review_rate": baseline_rate,
        "selected_absolute_mde": 0.05,
        "selected_relative_reduction": float(0.05 / baseline_rate),
        "alpha_two_sided": ALPHA,
        "power": POWER,
        "analyzable_fraction": ANALYZABLE_FRACTION,
        "sample_per_arm": int(selected["sample_per_arm"]),
        "total_analyzable_sample": int(selected["total_analyzable_sample"]),
        "adjusted_sample_per_arm": int(selected["adjusted_sample_per_arm"]),
        "total_enrollment_target": int(selected["total_enrollment_target"]),
        "historical_monthly_actual_late_proxy": historical_monthly_volume,
        "historical_monthly_proxy_minimum": int(capacity["late_reviewed_orders"].min()),
        "historical_monthly_proxy_maximum": int(capacity["late_reviewed_orders"].max()),
        "duration_scenarios": build_duration_scenarios(
            int(selected["total_enrollment_target"]), historical_monthly_volume
        ),
        "sample_size_scenarios": scenarios.to_dict(orient="records"),
    }

    output_directory.mkdir(parents=True, exist_ok=True)
    (output_directory / "stage09_experiment_design.json").write_text(
        json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    scenarios.to_csv(output_directory / "stage09_sample_size_scenarios.csv", index=False)
    create_power_figure(baseline_rate, output_directory, selected_mde=0.05)
    return results


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage08-results", type=Path, required=True)
    parser.add_argument("--monthly-capacity", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    return parser.parse_args()


if __name__ == "__main__":
    arguments = parse_args()
    design = run(
        arguments.stage08_results, arguments.monthly_capacity, arguments.output_dir
    )
    print(json.dumps(design, indent=2, ensure_ascii=False))

