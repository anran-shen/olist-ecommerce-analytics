# Data Source, Validation and Dictionary

## 1. Source and version

- Dataset: [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
- Publisher: Olist / Francisco Magioli
- Kaggle dataset version: 2
- Kaggle last update: 2021-10-01
- License: [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/)
- Downloaded archive size: 44,717,580 bytes
- Archive SHA-256: `967e41e04fc306fe604e2a693f488995a8b41e5047418f8a5c8e4abd6deca784`

The archive was downloaded from Kaggle's dataset API and contains exactly the nine expected CSV files. Olist's official [`work-at-olist-data`](https://github.com/olist/work-at-olist-data) repository was used as an additional source-identity check, not mixed into the final raw files.

## 2. Reproducible download

From the repository root in PowerShell:

```powershell
curl.exe -L --fail --output data\raw\olist_brazilian_ecommerce.zip `
  "https://www.kaggle.com/api/v1/datasets/download/olistbr/brazilian-ecommerce"

Expand-Archive `
  -LiteralPath data\raw\olist_brazilian_ecommerce.zip `
  -DestinationPath data\raw `
  -Force

python python\src\validate_raw_data.py
```

The raw ZIP and CSVs are excluded from Git. Re-run the validation script after every download and compare the output to [`data_manifest.csv`](data_manifest.csv).

## 3. Validation result

Validation date: 2026-09-26.

- 9 of 9 expected CSV files are present; no unexpected CSVs are present.
- All column names and column orders match the expected source schema.
- All declared candidate keys are unique.
- All six tested foreign-key relationships have zero orphan keys.
- CSV parsing respects quoted line breaks in review comments; row counts are logical CSV records, not physical newline counts.

| Dataset | Grain | Rows | Key / uniqueness note |
|---|---|---:|---|
| Customers | One order-specific customer record | 99,441 | `customer_id` unique; 96,096 distinct people by `customer_unique_id` |
| Geolocation | One observed coordinate/name for a ZIP prefix | 1,000,163 | No row key; only 19,015 distinct ZIP prefixes |
| Order items | One item sequence within an order | 112,650 | (`order_id`, `order_item_id`) unique |
| Order payments | One payment sequence within an order | 103,886 | (`order_id`, `payment_sequential`) unique |
| Order reviews | One submitted review record | 99,224 | 98,410 review IDs and 98,673 order IDs; neither is unique |
| Orders | One order | 99,441 | `order_id` unique; `customer_id` also unique in this source |
| Products | One product | 32,951 | `product_id` unique |
| Sellers | One seller | 3,095 | `seller_id` unique |
| Category translation | One Portuguese category mapping | 71 | `product_category_name` unique |

The complete byte sizes and SHA-256 values are stored in [`data_manifest.csv`](data_manifest.csv). The machine-readable local result is generated at `data/interim/raw_validation_report.json` and is intentionally not committed.

## 4. Relationship model

```text
customers ──1:1── orders ──1:N── order_items ──N:1── products
    │                  │                 └────N:1── sellers
    │                  ├────1:N── order_payments
customer_unique_id     └────1:N── order_reviews
groups repeat buyers

products ──N:1── category_translation
customer/seller ZIP prefix ──N:1── aggregated geolocation
```

Important modeling cautions:

- `customer_id` identifies the customer record attached to one order; use `customer_unique_id` for repeat-purchase and retention analysis.
- Items, payments and reviews are all one-to-many from orders. Joining them directly creates a many-to-many multiplication and inflates money.
- Geolocation has many rows per ZIP prefix. Aggregate it to one representative coordinate per prefix before joining.
- Reviews contain repeated `review_id` and repeated `order_id`. Preserve all raw records; define an explicit order-level selection rule in the core model.
- One order has no payment record; not every order has items or a review. Use relationship coverage checks rather than assuming mandatory children.

## 5. Data dictionary

Types below are intended analytical types. Stage 1/raw ingestion may initially load text so malformed source values remain observable.

### Customers — `olist_customers_dataset.csv`

| Column | Intended type | Meaning |
|---|---|---|
| `customer_id` | text | Order-specific customer key; joins to orders |
| `customer_unique_id` | text | Stable anonymized customer key across orders |
| `customer_zip_code_prefix` | char(5) | First five digits of delivery ZIP code; left-pad if needed |
| `customer_city` | text | Delivery city in source spelling |
| `customer_state` | char(2) | Brazilian state code |

### Geolocation — `olist_geolocation_dataset.csv`

| Column | Intended type | Meaning |
|---|---|---|
| `geolocation_zip_code_prefix` | char(5) | First five digits of ZIP code |
| `geolocation_lat` | numeric | Latitude |
| `geolocation_lng` | numeric | Longitude |
| `geolocation_city` | text | City in source spelling |
| `geolocation_state` | char(2) | Brazilian state code |

### Order items — `olist_order_items_dataset.csv`

| Column | Intended type | Meaning |
|---|---|---|
| `order_id` | text | Order key |
| `order_item_id` | integer | Item sequence within the order; repeated products occupy separate rows |
| `product_id` | text | Product key |
| `seller_id` | text | Fulfilling seller key |
| `shipping_limit_date` | timestamp | Seller shipping deadline |
| `price` | numeric(12,2) | Item selling price, excluding freight |
| `freight_value` | numeric(12,2) | Freight allocated to the item |

### Order payments — `olist_order_payments_dataset.csv`

| Column | Intended type | Meaning |
|---|---|---|
| `order_id` | text | Order key |
| `payment_sequential` | integer | Payment sequence within an order |
| `payment_type` | text | Payment method |
| `payment_installments` | integer | Number of installments |
| `payment_value` | numeric(12,2) | Amount of this payment record |

### Order reviews — `olist_order_reviews_dataset.csv`

| Column | Intended type | Meaning |
|---|---|---|
| `review_id` | text | Review identifier; not unique in the raw file |
| `order_id` | text | Reviewed order key; not unique in the raw file |
| `review_score` | smallint | Satisfaction score from 1 to 5 |
| `review_comment_title` | text | Optional review title |
| `review_comment_message` | text | Optional free-text review |
| `review_creation_date` | timestamp | Survey/review creation time |
| `review_answer_timestamp` | timestamp | Customer response time |

### Orders — `olist_orders_dataset.csv`

| Column | Intended type | Meaning |
|---|---|---|
| `order_id` | text | Unique order key |
| `customer_id` | text | Order-specific customer key |
| `order_status` | text | Current/final source status |
| `order_purchase_timestamp` | timestamp | Purchase time and analytical event date |
| `order_approved_at` | timestamp | Payment approval time |
| `order_delivered_carrier_date` | timestamp | Handover time to carrier |
| `order_delivered_customer_date` | timestamp | Actual customer delivery time |
| `order_estimated_delivery_date` | timestamp | Promised delivery date |

### Products — `olist_products_dataset.csv`

| Column | Intended type | Meaning |
|---|---|---|
| `product_id` | text | Unique product key |
| `product_category_name` | text | Portuguese category key |
| `product_name_lenght` | integer | Product-name character count; source spelling retained |
| `product_description_lenght` | integer | Description character count; source spelling retained |
| `product_photos_qty` | integer | Number of product photos |
| `product_weight_g` | numeric | Product weight in grams |
| `product_length_cm` | numeric | Product length in centimeters |
| `product_height_cm` | numeric | Product height in centimeters |
| `product_width_cm` | numeric | Product width in centimeters |

The misspelled source columns ending in `_lenght` will be renamed to `_length` in the core layer, while staging preserves source names.

### Sellers — `olist_sellers_dataset.csv`

| Column | Intended type | Meaning |
|---|---|---|
| `seller_id` | text | Unique seller key |
| `seller_zip_code_prefix` | char(5) | First five digits of seller ZIP code |
| `seller_city` | text | Seller city in source spelling |
| `seller_state` | char(2) | Brazilian state code |

### Category translation — `product_category_name_translation.csv`

| Column | Intended type | Meaning |
|---|---|---|
| `product_category_name` | text | Portuguese category key |
| `product_category_name_english` | text | English category label |

## 6. Initial quality observations

- Purchase timestamps span `2016-09-04 21:15:19` through `2018-10-17 17:30:18`; both boundary months are incomplete.
- Order statuses include 96,478 delivered, 1,107 shipped, 625 canceled, 609 unavailable and smaller in-progress groups.
- Orders contain 160 missing approval timestamps, 1,783 missing carrier dates and 2,965 missing customer delivery dates. These are often structurally related to status and must not be filled with zero dates.
- Review titles are missing on 87,656 rows and review messages on 58,247 rows. Review scores and review timestamps are complete.
- Products contain 610 missing categories and related descriptive fields; two rows lack physical measurements.
- Products use 73 non-null Portuguese categories, while the translation file maps 71. The unmapped categories are `pc_gamer` and `portateis_cozinha_e_preparadores_de_alimentos`.
- The geolocation table is intentionally repetitive. Joining it before aggregation would multiply customer and seller records.

These findings are profiling observations, not cleaning decisions. Transformation rules will be implemented and tested in the PostgreSQL staging/core stage.

