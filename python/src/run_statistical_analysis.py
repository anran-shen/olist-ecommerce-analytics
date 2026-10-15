"""Run the Stage 8 delivery and review statistical analysis."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from scipy import stats

from statistical_utils import (
    fisher_correlation_interval,
    hedges_g,
    mann_whitney_effect,
    mean_confidence_interval,
    welch_mean_difference,
    wilson_interval,
)


REQUIRED_COLUMNS = {
    "order_id",
    "customer_unique_id",
    "purchase_date",
    "purchase_month",
    "customer_state",
    "delivery_days",
    "days_vs_estimate",
    "is_late_delivery",
    "review_score",
    "item_count",
    "product_gmv",
    "freight_value",
}


def load_analysis_data(path: Path) -> pd.DataFrame:
    data = pd.read_csv(path, parse_dates=["purchase_date", "purchase_month"])
    missing = REQUIRED_COLUMNS.difference(data.columns)
    if missing:
        raise ValueError(f"Missing required columns: {sorted(missing)}")
    data["is_late_delivery"] = (
        data["is_late_delivery"].astype(str).str.lower().map({"t": True, "f": False})
    )
    if data["is_late_delivery"].isna().any():
        raise ValueError("is_late_delivery contains values other than t/f.")
    if data["order_id"].duplicated().any():
        raise ValueError("The analysis dataset must contain one row per order.")
    if not data["review_score"].between(1, 5).all():
        raise ValueError("Review scores must be between 1 and 5.")
    if (data["delivery_days"] < 0).any():
        raise ValueError("Delivery duration cannot be negative.")
    return data


def describe_groups(data: pd.DataFrame) -> list[dict[str, float | int | str]]:
    rows: list[dict[str, float | int | str]] = []
    for is_late, group in data.groupby("is_late_delivery", observed=True):
        review = group["review_score"].to_numpy(dtype=float)
        delivery = group["delivery_days"].to_numpy(dtype=float)
        review_ci = mean_confidence_interval(review)
        rows.append(
            {
                "delivery_group": "late" if is_late else "on_time",
                "orders": int(group.shape[0]),
                "review_mean": float(np.mean(review)),
                "review_std": float(np.std(review, ddof=1)),
                "review_mean_ci_lower": review_ci.lower,
                "review_mean_ci_upper": review_ci.upper,
                "review_median": float(np.median(review)),
                "review_q25": float(np.quantile(review, 0.25)),
                "review_q75": float(np.quantile(review, 0.75)),
                "low_review_rate": float(np.mean(review <= 2)),
                "delivery_mean_days": float(np.mean(delivery)),
                "delivery_median_days": float(np.median(delivery)),
                "delivery_q90_days": float(np.quantile(delivery, 0.90)),
            }
        )
    return sorted(rows, key=lambda row: row["delivery_group"], reverse=True)


def compare_reviews(data: pd.DataFrame) -> dict[str, object]:
    late = data.loc[data["is_late_delivery"], "review_score"].to_numpy(dtype=float)
    on_time = data.loc[~data["is_late_delivery"], "review_score"].to_numpy(dtype=float)
    return {
        "contrast": "late minus on-time review score",
        "welch": welch_mean_difference(late, on_time),
        "hedges_g": hedges_g(late, on_time),
        "mann_whitney": mann_whitney_effect(late, on_time),
    }


def correlation_analysis(data: pd.DataFrame) -> dict[str, object]:
    spearman = stats.spearmanr(data["delivery_days"], data["review_score"])
    pearson = stats.pearsonr(data["delivery_days"], data["review_score"])
    interval = fisher_correlation_interval(float(spearman.statistic), data.shape[0])
    return {
        "primary_method": "Spearman rank correlation",
        "spearman_rho": float(spearman.statistic),
        "spearman_p_value": float(spearman.pvalue),
        "spearman_approximate_ci": interval.to_dict(),
        "pearson_r": float(pearson.statistic),
        "pearson_p_value": float(pearson.pvalue),
    }


def customer_independence_sensitivity(data: pd.DataFrame) -> dict[str, object]:
    first_order = (
        data.sort_values(["purchase_date", "order_id"])
        .drop_duplicates("customer_unique_id", keep="first")
        .copy()
    )
    result = compare_reviews(first_order)
    return {
        "method": "earliest eligible order per customer",
        "orders": int(first_order.shape[0]),
        "customers": int(first_order["customer_unique_id"].nunique()),
        **result,
    }


def stratified_consistency(
    data: pd.DataFrame, field: str, minimum_group_orders: int = 30
) -> dict[str, object]:
    """Check whether the late-minus-on-time mean difference is negative by stratum."""
    summary = (
        data.groupby([field, "is_late_delivery"], observed=True)["review_score"]
        .agg(["mean", "size"])
        .unstack("is_late_delivery")
    )
    eligible = summary.loc[
        (summary[("size", False)] >= minimum_group_orders)
        & (summary[("size", True)] >= minimum_group_orders)
    ].copy()
    differences = eligible[("mean", True)] - eligible[("mean", False)]
    return {
        "stratification": field,
        "minimum_orders_per_status": minimum_group_orders,
        "eligible_strata": int(differences.size),
        "strata_with_lower_late_mean": int((differences < 0).sum()),
        "smallest_difference": float(differences.min()),
        "largest_difference": float(differences.max()),
    }


def create_figures(data: pd.DataFrame, output_directory: Path) -> None:
    output_directory.mkdir(parents=True, exist_ok=True)
    colors = ["#2F6690", "#D1495B"]

    summaries = pd.DataFrame(describe_groups(data)).set_index("delivery_group")
    summaries = summaries.loc[["on_time", "late"]]
    errors = np.vstack(
        [
            summaries["review_mean"] - summaries["review_mean_ci_lower"],
            summaries["review_mean_ci_upper"] - summaries["review_mean"],
        ]
    )
    figure, axis = plt.subplots(figsize=(7, 4.5))
    axis.bar(["On time", "Late"], summaries["review_mean"], color=colors)
    axis.errorbar(
        [0, 1],
        summaries["review_mean"],
        yerr=errors,
        fmt="none",
        ecolor="#222222",
        capsize=5,
    )
    axis.set(ylim=(1, 5), ylabel="Mean review score")
    axis.set_title("Late deliveries receive substantially lower reviews")
    axis.grid(axis="y", alpha=0.2)
    figure.tight_layout()
    figure.savefig(output_directory / "review_score_by_delivery_status.png", dpi=180)
    plt.close(figure)

    bins = pd.cut(
        data["delivery_days"],
        bins=[0, 7, 14, 21, 28, 42, 70, np.inf],
        right=True,
        include_lowest=True,
    )
    trend = (
        data.assign(delivery_band=bins)
        .groupby("delivery_band", observed=True)
        .agg(mean_review=("review_score", "mean"), orders=("order_id", "size"))
        .reset_index()
    )
    figure, axis = plt.subplots(figsize=(8, 4.5))
    axis.plot(
        trend["delivery_band"].astype(str),
        trend["mean_review"],
        marker="o",
        color="#2F6690",
        linewidth=2,
    )
    axis.set(ylabel="Mean review score", xlabel="Delivery duration (days)", ylim=(1, 5))
    axis.set_title("Longer deliveries are associated with lower review scores")
    axis.tick_params(axis="x", rotation=25)
    axis.grid(axis="y", alpha=0.2)
    for index, row in trend.iterrows():
        axis.annotate(
            f"n={int(row['orders']):,}",
            (index, row["mean_review"]),
            textcoords="offset points",
            xytext=(0, 8),
            ha="center",
            fontsize=8,
        )
    figure.tight_layout()
    figure.savefig(output_directory / "review_score_by_delivery_days.png", dpi=180)
    plt.close(figure)


def run(input_path: Path, output_directory: Path) -> dict[str, object]:
    data = load_analysis_data(input_path)
    late_orders = int(data["is_late_delivery"].sum())
    results: dict[str, object] = {
        "analysis_unit": "delivered order with delivery promise and latest review",
        "sample_orders": int(data.shape[0]),
        "unique_customers": int(data["customer_unique_id"].nunique()),
        "late_orders": late_orders,
        "late_rate_wilson_ci": wilson_interval(late_orders, data.shape[0]).to_dict(),
        "descriptive_statistics": describe_groups(data),
        "late_vs_on_time": compare_reviews(data),
        "delivery_days_correlation": correlation_analysis(data),
        "customer_independence_sensitivity": customer_independence_sensitivity(data),
        "stratified_consistency": {
            "purchase_month": stratified_consistency(data, "purchase_month"),
            "customer_state": stratified_consistency(data, "customer_state"),
        },
    }
    output_directory.mkdir(parents=True, exist_ok=True)
    (output_directory / "stage08_results.json").write_text(
        json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    pd.DataFrame(results["descriptive_statistics"]).to_csv(
        output_directory / "stage08_descriptive_statistics.csv", index=False
    )
    create_figures(data, output_directory)
    return results


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    return parser.parse_args()


if __name__ == "__main__":
    arguments = parse_args()
    analysis_results = run(arguments.input, arguments.output_dir)
    print(json.dumps(analysis_results, indent=2, ensure_ascii=False))
