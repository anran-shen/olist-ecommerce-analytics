# PostgreSQL Loading, Staging and Quality Checks

## 1. Stage outcome

Stage 4 was executed successfully against the local PostgreSQL 17.11 service on 2026-09-27.

| Item | Result |
|---|---|
| Database | `olist_ecommerce` |
| Database owner / project login | `olist` |
| Runtime | PostgreSQL 17.11 on Windows x86-64 |
| Database size after loading | 174 MB |
| Raw tables | 9 |
| Typed staging views | 9 |
| Automated SQL assertions | 39 passed, 0 failed |

No core fact/dimension tables or analytical marts were created in this stage.

## 2. Security and isolation

The existing `postgres` administrator login is used only by the bootstrap script. It creates or updates:

- a project-specific login named `olist`;
- a project-specific database named `olist_ecommerce`, owned by `olist`.

All project schemas, tables and views are then created through the lower-privilege `olist` login. Passwords are read from the local `.env` file, passed through the `PGPASSWORD` process environment, never printed, and excluded from Git.

## 3. Layer design

### Raw layer

The `raw` schema contains nine source-shaped tables. Columns are initially stored as text so source values remain observable and a malformed value causes an explicit staging failure rather than being silently changed during import.

Raw loading uses client-side `\copy`, which allows the local PostgreSQL client to read project-relative CSV paths. The load runs in one transaction:

1. truncate all nine raw tables;
2. load every CSV with header and UTF-8 handling;
3. commit only if every file succeeds.

This makes the raw import repeatable without appending duplicate rows.

### Staging layer

The `staging` schema contains typed views that:

- convert timestamps, integers and monetary values;
- convert blank optional fields to SQL `NULL`;
- normalize state codes to uppercase and order statuses to lowercase;
- left-pad ZIP prefixes to five characters;
- trim identifier fields;
- rename the source misspelling `_lenght` to `_length` without changing the raw schema.

Views keep the transformation logic visible and prevent a second physical copy of the dataset at this stage.

## 4. Loaded row counts

| Raw table | Rows |
|---|---:|
| `raw.customers` | 99,441 |
| `raw.geolocation` | 1,000,163 |
| `raw.order_items` | 112,650 |
| `raw.order_payments` | 103,886 |
| `raw.order_reviews` | 99,224 |
| `raw.orders` | 99,441 |
| `raw.products` | 32,951 |
| `raw.sellers` | 3,095 |
| `raw.product_category_translation` | 71 |

All database row counts match the Python file-validation manifest.

## 5. Quality-test coverage

The SQL quality suite contains 39 fail-fast assertions.

### Row count and castability

- All nine raw counts match the source manifest.
- All nine staging views return the expected typed row count.
- Counting typed fields forces PostgreSQL to evaluate numeric and timestamp casts across the full dataset.

### Keys

- `customer_id`, `order_id`, `product_id` and `seller_id` are complete and unique.
- (`order_id`, `order_item_id`) is complete and unique.
- (`order_id`, `payment_sequential`) is complete and unique.

### Referential integrity

Zero orphan keys were found for:

- orders → customers;
- order items → orders;
- order items → products;
- order items → sellers;
- payments → orders;
- reviews → orders.

### Domain checks

- no review score falls outside 1–5;
- no item price, freight value or payment value is negative;
- all customer and seller state codes have two characters.

### Known source characteristics

The suite deliberately asserts the following source-version characteristics:

- 96,096 distinct customers by `customer_unique_id`;
- exactly one order has no payment record;
- review rows exceed distinct reviewed orders by 551.

These are not treated as load failures. The review multiplicity will receive an explicit business-grain rule in the core model.

## 6. Execution

From the repository root:

```powershell
.\sql\run_stage_04.ps1
```

The runner performs the following steps in order:

1. validates `.env` and the PostgreSQL 17 client path;
2. tests administrator authentication;
3. creates or updates the project login and database;
4. verifies the project login;
5. creates schemas and raw tables;
6. reloads all raw CSVs transactionally;
7. creates or replaces staging views;
8. runs all 39 quality assertions with `ON_ERROR_STOP` enabled.

Any failed command stops the pipeline and returns a non-zero exit code.

## 7. Relevant files

- `sql/setup_local_postgres.ps1`: local role/database bootstrap.
- `sql/run_stage_04.ps1`: ordered Stage 4 runner.
- `sql/00_setup/00_create_schemas.sql`: schema definitions.
- `sql/01_staging/00_create_raw_tables.sql`: source-shaped tables.
- `sql/01_staging/01_load_raw_data.sql`: transactional CSV import.
- `sql/01_staging/02_create_staging_views.sql`: typed cleaning views.
- `sql/05_quality/00_stage04_quality_checks.sql`: fail-fast assertions.

