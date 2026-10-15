"""Validate and profile the immutable Olist source CSV files.

This script intentionally uses only the Python standard library so raw-data
validation can run before the project dependencies are installed.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path
from typing import Any


EXPECTED_SCHEMAS: dict[str, dict[str, Any]] = {
    "olist_customers_dataset.csv": {
        "columns": [
            "customer_id",
            "customer_unique_id",
            "customer_zip_code_prefix",
            "customer_city",
            "customer_state",
        ],
        "candidate_key": ["customer_id"],
    },
    "olist_geolocation_dataset.csv": {
        "columns": [
            "geolocation_zip_code_prefix",
            "geolocation_lat",
            "geolocation_lng",
            "geolocation_city",
            "geolocation_state",
        ],
        "candidate_key": [],
    },
    "olist_order_items_dataset.csv": {
        "columns": [
            "order_id",
            "order_item_id",
            "product_id",
            "seller_id",
            "shipping_limit_date",
            "price",
            "freight_value",
        ],
        "candidate_key": ["order_id", "order_item_id"],
    },
    "olist_order_payments_dataset.csv": {
        "columns": [
            "order_id",
            "payment_sequential",
            "payment_type",
            "payment_installments",
            "payment_value",
        ],
        "candidate_key": ["order_id", "payment_sequential"],
    },
    "olist_order_reviews_dataset.csv": {
        "columns": [
            "review_id",
            "order_id",
            "review_score",
            "review_comment_title",
            "review_comment_message",
            "review_creation_date",
            "review_answer_timestamp",
        ],
        "candidate_key": [],
    },
    "olist_orders_dataset.csv": {
        "columns": [
            "order_id",
            "customer_id",
            "order_status",
            "order_purchase_timestamp",
            "order_approved_at",
            "order_delivered_carrier_date",
            "order_delivered_customer_date",
            "order_estimated_delivery_date",
        ],
        "candidate_key": ["order_id"],
    },
    "olist_products_dataset.csv": {
        "columns": [
            "product_id",
            "product_category_name",
            "product_name_lenght",
            "product_description_lenght",
            "product_photos_qty",
            "product_weight_g",
            "product_length_cm",
            "product_height_cm",
            "product_width_cm",
        ],
        "candidate_key": ["product_id"],
    },
    "olist_sellers_dataset.csv": {
        "columns": [
            "seller_id",
            "seller_zip_code_prefix",
            "seller_city",
            "seller_state",
        ],
        "candidate_key": ["seller_id"],
    },
    "product_category_name_translation.csv": {
        "columns": ["product_category_name", "product_category_name_english"],
        "candidate_key": ["product_category_name"],
    },
}

DISTINCT_COLUMNS: dict[str, list[str]] = {
    "olist_customers_dataset.csv": [
        "customer_id",
        "customer_unique_id",
        "customer_zip_code_prefix",
        "customer_state",
    ],
    "olist_geolocation_dataset.csv": [
        "geolocation_zip_code_prefix",
        "geolocation_state",
    ],
    "olist_order_items_dataset.csv": ["order_id", "product_id", "seller_id"],
    "olist_order_payments_dataset.csv": ["order_id", "payment_type"],
    "olist_order_reviews_dataset.csv": ["review_id", "order_id", "review_score"],
    "olist_orders_dataset.csv": ["order_id", "customer_id", "order_status"],
    "olist_products_dataset.csv": ["product_id", "product_category_name"],
    "olist_sellers_dataset.csv": ["seller_id", "seller_state"],
    "product_category_name_translation.csv": ["product_category_name"],
}

FOREIGN_KEYS = [
    ("orders.customer_id", "olist_orders_dataset.csv", "customer_id", "olist_customers_dataset.csv", "customer_id"),
    ("order_items.order_id", "olist_order_items_dataset.csv", "order_id", "olist_orders_dataset.csv", "order_id"),
    ("order_items.product_id", "olist_order_items_dataset.csv", "product_id", "olist_products_dataset.csv", "product_id"),
    ("order_items.seller_id", "olist_order_items_dataset.csv", "seller_id", "olist_sellers_dataset.csv", "seller_id"),
    ("order_payments.order_id", "olist_order_payments_dataset.csv", "order_id", "olist_orders_dataset.csv", "order_id"),
    ("order_reviews.order_id", "olist_order_reviews_dataset.csv", "order_id", "olist_orders_dataset.csv", "order_id"),
]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def profile_csv(path: Path, schema: dict[str, Any]) -> dict[str, Any]:
    expected_columns = schema["columns"]
    key_columns = schema["candidate_key"]
    null_counts = {column: 0 for column in expected_columns}
    key_values: set[tuple[str, ...]] = set()
    distinct_values = {
        column: set() for column in DISTINCT_COLUMNS.get(path.name, [])
    }
    row_count = 0

    with path.open("r", encoding="utf-8-sig", newline="") as source:
        reader = csv.DictReader(source)
        actual_columns = reader.fieldnames or []
        schema_matches = actual_columns == expected_columns

        for row in reader:
            row_count += 1
            for column in actual_columns:
                if row.get(column, "") == "":
                    null_counts[column] += 1
            for column, values in distinct_values.items():
                if row.get(column, "") != "":
                    values.add(row[column])
            if key_columns:
                key_values.add(tuple(row[column] for column in key_columns))

    distinct_key_count = len(key_values) if key_columns else None
    duplicate_key_rows = (
        row_count - distinct_key_count if distinct_key_count is not None else None
    )

    return {
        "filename": path.name,
        "bytes": path.stat().st_size,
        "sha256": sha256(path),
        "row_count": row_count,
        "column_count": len(actual_columns),
        "columns": actual_columns,
        "schema_matches": schema_matches,
        "candidate_key": key_columns,
        "distinct_candidate_keys": distinct_key_count,
        "duplicate_candidate_key_rows": duplicate_key_rows,
        "distinct_counts": {
            column: len(values) for column, values in distinct_values.items()
        },
        "null_counts": null_counts,
    }


def read_distinct_values(path: Path, column: str) -> set[str]:
    with path.open("r", encoding="utf-8-sig", newline="") as source:
        return {
            row[column]
            for row in csv.DictReader(source)
            if row.get(column, "") != ""
        }


def validate_foreign_keys(raw_dir: Path) -> list[dict[str, Any]]:
    checks = []
    cache: dict[tuple[str, str], set[str]] = {}
    for name, child_file, child_column, parent_file, parent_column in FOREIGN_KEYS:
        child_key = (child_file, child_column)
        parent_key = (parent_file, parent_column)
        if child_key not in cache:
            cache[child_key] = read_distinct_values(raw_dir / child_file, child_column)
        if parent_key not in cache:
            cache[parent_key] = read_distinct_values(raw_dir / parent_file, parent_column)
        orphan_values = cache[child_key] - cache[parent_key]
        checks.append(
            {
                "relationship": name,
                "distinct_child_keys": len(cache[child_key]),
                "orphan_key_count": len(orphan_values),
            }
        )
    return checks


def validate(raw_dir: Path) -> dict[str, Any]:
    expected_names = set(EXPECTED_SCHEMAS)
    actual_names = {path.name for path in raw_dir.glob("*.csv")}
    missing_files = sorted(expected_names - actual_names)
    unexpected_files = sorted(actual_names - expected_names)
    profiles = []

    for filename, schema in EXPECTED_SCHEMAS.items():
        path = raw_dir / filename
        if path.exists():
            profiles.append(profile_csv(path, schema))

    foreign_key_checks = validate_foreign_keys(raw_dir) if not missing_files else []

    passed = (
        not missing_files
        and not unexpected_files
        and all(profile["schema_matches"] for profile in profiles)
        and all(
            profile["duplicate_candidate_key_rows"] in (None, 0)
            for profile in profiles
        )
        and all(check["orphan_key_count"] == 0 for check in foreign_key_checks)
    )
    return {
        "validation_passed": passed,
        "expected_csv_count": len(expected_names),
        "actual_csv_count": len(actual_names),
        "missing_files": missing_files,
        "unexpected_files": unexpected_files,
        "foreign_key_checks": foreign_key_checks,
        "files": profiles,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--raw-dir", type=Path, default=Path("data/raw"))
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("data/interim/raw_validation_report.json"),
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    report = validate(args.raw_dir)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["validation_passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
