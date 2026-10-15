\set ON_ERROR_STOP on

CREATE OR REPLACE FUNCTION qa.assert_equal(
    check_name text,
    actual_value bigint,
    expected_value bigint
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF actual_value IS DISTINCT FROM expected_value THEN
        RAISE EXCEPTION 'FAILED: % (actual %, expected %)',
            check_name, actual_value, expected_value;
    END IF;
    RAISE NOTICE 'PASSED: % = %', check_name, actual_value;
END;
$$;

-- Source row counts also force every staging expression to be evaluated.
SELECT qa.assert_equal('raw.customers row count', COUNT(*), 99441) FROM raw.customers;
SELECT qa.assert_equal('raw.geolocation row count', COUNT(*), 1000163) FROM raw.geolocation;
SELECT qa.assert_equal('raw.order_items row count', COUNT(*), 112650) FROM raw.order_items;
SELECT qa.assert_equal('raw.order_payments row count', COUNT(*), 103886) FROM raw.order_payments;
SELECT qa.assert_equal('raw.order_reviews row count', COUNT(*), 99224) FROM raw.order_reviews;
SELECT qa.assert_equal('raw.orders row count', COUNT(*), 99441) FROM raw.orders;
SELECT qa.assert_equal('raw.products row count', COUNT(*), 32951) FROM raw.products;
SELECT qa.assert_equal('raw.sellers row count', COUNT(*), 3095) FROM raw.sellers;
SELECT qa.assert_equal('raw.product_category_translation row count', COUNT(*), 71) FROM raw.product_category_translation;

SELECT qa.assert_equal('staging customers typed row count', COUNT(customer_zip_code_prefix), 99441) FROM staging.stg_customers;
SELECT qa.assert_equal('staging geolocation typed row count', COUNT(geolocation_lat), 1000163) FROM staging.stg_geolocation;
SELECT qa.assert_equal('staging order_items typed row count', COUNT(price), 112650) FROM staging.stg_order_items;
SELECT qa.assert_equal('staging order_payments typed row count', COUNT(payment_value), 103886) FROM staging.stg_order_payments;
SELECT qa.assert_equal('staging order_reviews typed row count', COUNT(review_score), 99224) FROM staging.stg_order_reviews;
SELECT qa.assert_equal('staging orders typed row count', COUNT(order_purchase_timestamp), 99441) FROM staging.stg_orders;
SELECT qa.assert_equal('staging products typed row count', COUNT(product_id), 32951) FROM staging.stg_products;
SELECT qa.assert_equal('staging sellers typed row count', COUNT(seller_id), 3095) FROM staging.stg_sellers;
SELECT qa.assert_equal('staging category translations typed row count', COUNT(product_category_name), 71) FROM staging.stg_product_category_translation;

-- Candidate-key uniqueness and completeness.
SELECT qa.assert_equal(
    'customers duplicate or null customer_id rows',
    COUNT(*) - COUNT(DISTINCT customer_id), 0
) FROM staging.stg_customers;
SELECT qa.assert_equal(
    'orders duplicate or null order_id rows',
    COUNT(*) - COUNT(DISTINCT order_id), 0
) FROM staging.stg_orders;
SELECT qa.assert_equal(
    'products duplicate or null product_id rows',
    COUNT(*) - COUNT(DISTINCT product_id), 0
) FROM staging.stg_products;
SELECT qa.assert_equal(
    'sellers duplicate or null seller_id rows',
    COUNT(*) - COUNT(DISTINCT seller_id), 0
) FROM staging.stg_sellers;
SELECT qa.assert_equal(
    'order_items duplicate or null composite-key rows',
    COUNT(*) - COUNT(DISTINCT (order_id, order_item_id)), 0
) FROM staging.stg_order_items;
SELECT qa.assert_equal(
    'order_payments duplicate or null composite-key rows',
    COUNT(*) - COUNT(DISTINCT (order_id, payment_sequential)), 0
) FROM staging.stg_order_payments;

-- Referential integrity at distinct-key level.
SELECT qa.assert_equal('orphan orders.customer_id', COUNT(*), 0)
FROM (
    SELECT DISTINCT customer_id FROM staging.stg_orders
    EXCEPT
    SELECT customer_id FROM staging.stg_customers
) AS orphan_keys;

SELECT qa.assert_equal('orphan order_items.order_id', COUNT(*), 0)
FROM (
    SELECT DISTINCT order_id FROM staging.stg_order_items
    EXCEPT
    SELECT order_id FROM staging.stg_orders
) AS orphan_keys;

SELECT qa.assert_equal('orphan order_items.product_id', COUNT(*), 0)
FROM (
    SELECT DISTINCT product_id FROM staging.stg_order_items
    EXCEPT
    SELECT product_id FROM staging.stg_products
) AS orphan_keys;

SELECT qa.assert_equal('orphan order_items.seller_id', COUNT(*), 0)
FROM (
    SELECT DISTINCT seller_id FROM staging.stg_order_items
    EXCEPT
    SELECT seller_id FROM staging.stg_sellers
) AS orphan_keys;

SELECT qa.assert_equal('orphan order_payments.order_id', COUNT(*), 0)
FROM (
    SELECT DISTINCT order_id FROM staging.stg_order_payments
    EXCEPT
    SELECT order_id FROM staging.stg_orders
) AS orphan_keys;

SELECT qa.assert_equal('orphan order_reviews.order_id', COUNT(*), 0)
FROM (
    SELECT DISTINCT order_id FROM staging.stg_order_reviews
    EXCEPT
    SELECT order_id FROM staging.stg_orders
) AS orphan_keys;

-- Domain checks required before core modeling.
SELECT qa.assert_equal('review scores outside 1-5', COUNT(*), 0)
FROM staging.stg_order_reviews
WHERE review_score NOT BETWEEN 1 AND 5;

SELECT qa.assert_equal('negative item prices', COUNT(*), 0)
FROM staging.stg_order_items
WHERE price < 0;

SELECT qa.assert_equal('negative freight values', COUNT(*), 0)
FROM staging.stg_order_items
WHERE freight_value < 0;

SELECT qa.assert_equal('negative payment values', COUNT(*), 0)
FROM staging.stg_order_payments
WHERE payment_value < 0;

SELECT qa.assert_equal('invalid customer state codes', COUNT(*), 0)
FROM staging.stg_customers
WHERE LENGTH(customer_state) <> 2;

SELECT qa.assert_equal('invalid seller state codes', COUNT(*), 0)
FROM staging.stg_sellers
WHERE LENGTH(seller_state) <> 2;

-- Known source characteristics are asserted so a silent source-version change fails.
SELECT qa.assert_equal(
    'distinct people by customer_unique_id',
    COUNT(DISTINCT customer_unique_id), 96096
) FROM staging.stg_customers;

SELECT qa.assert_equal(
    'orders without a payment record',
    COUNT(*), 1
)
FROM staging.stg_orders AS orders
LEFT JOIN staging.stg_order_payments AS payments USING (order_id)
WHERE payments.order_id IS NULL;

SELECT qa.assert_equal(
    'review rows beyond distinct order count',
    COUNT(*) - COUNT(DISTINCT order_id), 551
) FROM staging.stg_order_reviews;

