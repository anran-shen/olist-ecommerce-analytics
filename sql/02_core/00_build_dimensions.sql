\set ON_ERROR_STOP on

BEGIN;

-- Rebuilding dimensions invalidates downstream facts and marts by design.
DROP TABLE IF EXISTS core.fct_review CASCADE;
DROP TABLE IF EXISTS core.fct_payment CASCADE;
DROP TABLE IF EXISTS core.fct_order_item CASCADE;
DROP TABLE IF EXISTS core.fct_order CASCADE;
DROP TABLE IF EXISTS core.dim_date CASCADE;
DROP TABLE IF EXISTS core.dim_customer CASCADE;
DROP TABLE IF EXISTS core.dim_product CASCADE;
DROP TABLE IF EXISTS core.dim_seller CASCADE;
DROP TABLE IF EXISTS core.dim_geolocation CASCADE;

CREATE TABLE core.dim_date AS
SELECT
    calendar_date::date AS date_key,
    EXTRACT(YEAR FROM calendar_date)::integer AS year,
    EXTRACT(QUARTER FROM calendar_date)::integer AS quarter,
    EXTRACT(MONTH FROM calendar_date)::integer AS month_number,
    TO_CHAR(calendar_date, 'YYYY-MM') AS year_month,
    DATE_TRUNC('month', calendar_date)::date AS month_start,
    (DATE_TRUNC('month', calendar_date) + INTERVAL '1 month - 1 day')::date AS month_end,
    EXTRACT(ISODOW FROM calendar_date)::smallint AS iso_day_of_week,
    TO_CHAR(calendar_date, 'Dy') AS day_name_short,
    (EXTRACT(ISODOW FROM calendar_date) IN (6, 7)) AS is_weekend
FROM GENERATE_SERIES(
    (SELECT MIN(order_purchase_timestamp)::date FROM staging.stg_orders),
    (SELECT MAX(order_purchase_timestamp)::date FROM staging.stg_orders),
    INTERVAL '1 day'
) AS dates(calendar_date);

ALTER TABLE core.dim_date
    ADD CONSTRAINT pk_dim_date PRIMARY KEY (date_key);

CREATE TABLE core.dim_customer AS
WITH customer_history AS (
    SELECT
        customers.customer_unique_id,
        customers.customer_id AS latest_customer_id,
        customers.customer_zip_code_prefix,
        customers.customer_city,
        customers.customer_state,
        MIN(orders.order_purchase_timestamp) OVER (
            PARTITION BY customers.customer_unique_id
        ) AS first_order_timestamp,
        MAX(orders.order_purchase_timestamp) OVER (
            PARTITION BY customers.customer_unique_id
        ) AS last_order_timestamp,
        COUNT(*) OVER (
            PARTITION BY customers.customer_unique_id
        )::integer AS source_order_count,
        ROW_NUMBER() OVER (
            PARTITION BY customers.customer_unique_id
            ORDER BY orders.order_purchase_timestamp DESC, customers.customer_id DESC
        ) AS latest_row_number
    FROM staging.stg_customers AS customers
    INNER JOIN staging.stg_orders AS orders USING (customer_id)
)
SELECT
    customer_unique_id,
    latest_customer_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state,
    first_order_timestamp,
    last_order_timestamp,
    source_order_count
FROM customer_history
WHERE latest_row_number = 1;

ALTER TABLE core.dim_customer
    ADD CONSTRAINT pk_dim_customer PRIMARY KEY (customer_unique_id);

CREATE INDEX idx_dim_customer_state
    ON core.dim_customer (customer_state);

CREATE TABLE core.dim_product AS
SELECT
    products.product_id,
    products.product_category_name,
    translations.product_category_name_english,
    COALESCE(
        translations.product_category_name_english,
        products.product_category_name,
        'unknown'
    ) AS product_category_display,
    (products.product_category_name IS NULL) AS is_category_missing,
    (
        products.product_category_name IS NOT NULL
        AND translations.product_category_name IS NULL
    ) AS is_category_untranslated,
    products.product_name_length,
    products.product_description_length,
    products.product_photos_qty,
    products.product_weight_g,
    products.product_length_cm,
    products.product_height_cm,
    products.product_width_cm
FROM staging.stg_products AS products
LEFT JOIN staging.stg_product_category_translation AS translations
    USING (product_category_name);

ALTER TABLE core.dim_product
    ADD CONSTRAINT pk_dim_product PRIMARY KEY (product_id);

CREATE INDEX idx_dim_product_category
    ON core.dim_product (product_category_display);

CREATE TABLE core.dim_seller AS
SELECT
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
FROM staging.stg_sellers;

ALTER TABLE core.dim_seller
    ADD CONSTRAINT pk_dim_seller PRIMARY KEY (seller_id);

CREATE INDEX idx_dim_seller_state
    ON core.dim_seller (seller_state);

CREATE TABLE core.dim_geolocation AS
WITH coordinates AS (
    SELECT
        geolocation_zip_code_prefix,
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY geolocation_lat
        )::numeric(10, 6) AS latitude,
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY geolocation_lng
        )::numeric(10, 6) AS longitude,
        COUNT(*)::integer AS source_coordinate_count
    FROM staging.stg_geolocation
    GROUP BY geolocation_zip_code_prefix
),
location_frequency AS (
    SELECT
        geolocation_zip_code_prefix,
        geolocation_city,
        geolocation_state,
        COUNT(*) AS location_count,
        ROW_NUMBER() OVER (
            PARTITION BY geolocation_zip_code_prefix
            ORDER BY COUNT(*) DESC, geolocation_state, geolocation_city
        ) AS location_rank
    FROM staging.stg_geolocation
    GROUP BY
        geolocation_zip_code_prefix,
        geolocation_city,
        geolocation_state
)
SELECT
    coordinates.geolocation_zip_code_prefix,
    locations.geolocation_city,
    locations.geolocation_state,
    coordinates.latitude,
    coordinates.longitude,
    coordinates.source_coordinate_count
FROM coordinates
INNER JOIN location_frequency AS locations
    USING (geolocation_zip_code_prefix)
WHERE locations.location_rank = 1;

ALTER TABLE core.dim_geolocation
    ADD CONSTRAINT pk_dim_geolocation PRIMARY KEY (geolocation_zip_code_prefix);

COMMIT;

