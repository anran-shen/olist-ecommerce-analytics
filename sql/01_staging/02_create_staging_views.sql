\set ON_ERROR_STOP on

CREATE OR REPLACE VIEW staging.stg_customers AS
SELECT
    NULLIF(BTRIM(customer_id), '') AS customer_id,
    NULLIF(BTRIM(customer_unique_id), '') AS customer_unique_id,
    LPAD(NULLIF(BTRIM(customer_zip_code_prefix), ''), 5, '0') AS customer_zip_code_prefix,
    NULLIF(BTRIM(customer_city), '') AS customer_city,
    UPPER(NULLIF(BTRIM(customer_state), '')) AS customer_state
FROM raw.customers;

CREATE OR REPLACE VIEW staging.stg_geolocation AS
SELECT
    LPAD(NULLIF(BTRIM(geolocation_zip_code_prefix), ''), 5, '0') AS geolocation_zip_code_prefix,
    NULLIF(geolocation_lat, '')::numeric AS geolocation_lat,
    NULLIF(geolocation_lng, '')::numeric AS geolocation_lng,
    NULLIF(BTRIM(geolocation_city), '') AS geolocation_city,
    UPPER(NULLIF(BTRIM(geolocation_state), '')) AS geolocation_state
FROM raw.geolocation;

CREATE OR REPLACE VIEW staging.stg_order_items AS
SELECT
    NULLIF(BTRIM(order_id), '') AS order_id,
    NULLIF(order_item_id, '')::integer AS order_item_id,
    NULLIF(BTRIM(product_id), '') AS product_id,
    NULLIF(BTRIM(seller_id), '') AS seller_id,
    NULLIF(shipping_limit_date, '')::timestamp AS shipping_limit_timestamp,
    NULLIF(price, '')::numeric(12, 2) AS price,
    NULLIF(freight_value, '')::numeric(12, 2) AS freight_value
FROM raw.order_items;

CREATE OR REPLACE VIEW staging.stg_order_payments AS
SELECT
    NULLIF(BTRIM(order_id), '') AS order_id,
    NULLIF(payment_sequential, '')::integer AS payment_sequential,
    NULLIF(BTRIM(payment_type), '') AS payment_type,
    NULLIF(payment_installments, '')::integer AS payment_installments,
    NULLIF(payment_value, '')::numeric(12, 2) AS payment_value
FROM raw.order_payments;

CREATE OR REPLACE VIEW staging.stg_order_reviews AS
SELECT
    NULLIF(BTRIM(review_id), '') AS review_id,
    NULLIF(BTRIM(order_id), '') AS order_id,
    NULLIF(review_score, '')::smallint AS review_score,
    NULLIF(review_comment_title, '') AS review_comment_title,
    NULLIF(review_comment_message, '') AS review_comment_message,
    NULLIF(review_creation_date, '')::timestamp AS review_creation_timestamp,
    NULLIF(review_answer_timestamp, '')::timestamp AS review_answer_timestamp
FROM raw.order_reviews;

CREATE OR REPLACE VIEW staging.stg_orders AS
SELECT
    NULLIF(BTRIM(order_id), '') AS order_id,
    NULLIF(BTRIM(customer_id), '') AS customer_id,
    LOWER(NULLIF(BTRIM(order_status), '')) AS order_status,
    NULLIF(order_purchase_timestamp, '')::timestamp AS order_purchase_timestamp,
    NULLIF(order_approved_at, '')::timestamp AS order_approved_timestamp,
    NULLIF(order_delivered_carrier_date, '')::timestamp AS delivered_carrier_timestamp,
    NULLIF(order_delivered_customer_date, '')::timestamp AS delivered_customer_timestamp,
    NULLIF(order_estimated_delivery_date, '')::timestamp AS estimated_delivery_timestamp
FROM raw.orders;

CREATE OR REPLACE VIEW staging.stg_products AS
SELECT
    NULLIF(BTRIM(product_id), '') AS product_id,
    NULLIF(BTRIM(product_category_name), '') AS product_category_name,
    NULLIF(product_name_lenght, '')::integer AS product_name_length,
    NULLIF(product_description_lenght, '')::integer AS product_description_length,
    NULLIF(product_photos_qty, '')::integer AS product_photos_qty,
    NULLIF(product_weight_g, '')::numeric AS product_weight_g,
    NULLIF(product_length_cm, '')::numeric AS product_length_cm,
    NULLIF(product_height_cm, '')::numeric AS product_height_cm,
    NULLIF(product_width_cm, '')::numeric AS product_width_cm
FROM raw.products;

CREATE OR REPLACE VIEW staging.stg_sellers AS
SELECT
    NULLIF(BTRIM(seller_id), '') AS seller_id,
    LPAD(NULLIF(BTRIM(seller_zip_code_prefix), ''), 5, '0') AS seller_zip_code_prefix,
    NULLIF(BTRIM(seller_city), '') AS seller_city,
    UPPER(NULLIF(BTRIM(seller_state), '')) AS seller_state
FROM raw.sellers;

CREATE OR REPLACE VIEW staging.stg_product_category_translation AS
SELECT
    NULLIF(BTRIM(product_category_name), '') AS product_category_name,
    NULLIF(BTRIM(product_category_name_english), '') AS product_category_name_english
FROM raw.product_category_translation;

