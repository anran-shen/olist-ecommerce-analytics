\set ON_ERROR_STOP on

BEGIN;

CREATE TABLE core.fct_order AS
WITH item_aggregates AS (
    SELECT
        order_id,
        COUNT(*)::integer AS item_count,
        COUNT(DISTINCT product_id)::integer AS distinct_product_count,
        COUNT(DISTINCT seller_id)::integer AS distinct_seller_count,
        SUM(price)::numeric(14, 2) AS product_gmv,
        SUM(freight_value)::numeric(14, 2) AS freight_value,
        SUM(price + freight_value)::numeric(14, 2) AS gross_order_value
    FROM staging.stg_order_items
    GROUP BY order_id
),
payment_aggregates AS (
    SELECT
        order_id,
        COUNT(*)::integer AS payment_record_count,
        SUM(payment_value)::numeric(14, 2) AS payment_value,
        STRING_AGG(DISTINCT payment_type, ', ' ORDER BY payment_type) AS payment_types,
        MAX(payment_installments)::integer AS max_payment_installments
    FROM staging.stg_order_payments
    GROUP BY order_id
),
ranked_reviews AS (
    SELECT
        reviews.*,
        COUNT(*) OVER (PARTITION BY order_id)::integer AS review_record_count,
        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY review_answer_timestamp DESC, review_creation_timestamp DESC, review_id DESC
        ) AS latest_review_rank
    FROM staging.stg_order_reviews AS reviews
),
latest_reviews AS (
    SELECT
        order_id,
        review_id AS latest_review_id,
        review_score AS latest_review_score,
        review_creation_timestamp AS latest_review_creation_timestamp,
        review_answer_timestamp AS latest_review_answer_timestamp,
        review_record_count
    FROM ranked_reviews
    WHERE latest_review_rank = 1
)
SELECT
    orders.order_id,
    orders.customer_id,
    customers.customer_unique_id,
    customers.customer_zip_code_prefix,
    customers.customer_city,
    customers.customer_state,
    orders.order_status,
    orders.order_purchase_timestamp,
    orders.order_purchase_timestamp::date AS purchase_date,
    DATE_TRUNC('month', orders.order_purchase_timestamp)::date AS purchase_month,
    orders.order_approved_timestamp,
    orders.delivered_carrier_timestamp,
    orders.delivered_customer_timestamp,
    orders.estimated_delivery_timestamp,
    (orders.order_status = 'delivered') AS is_delivered,
    CASE
        WHEN orders.delivered_customer_timestamp IS NULL THEN NULL
        ELSE (
            EXTRACT(EPOCH FROM (
                orders.delivered_customer_timestamp - orders.order_purchase_timestamp
            )) / 86400
        )::numeric(10, 2)
    END AS delivery_days,
    CASE
        WHEN orders.delivered_customer_timestamp IS NULL
            OR orders.estimated_delivery_timestamp IS NULL THEN NULL
        ELSE orders.delivered_customer_timestamp > orders.estimated_delivery_timestamp
    END AS is_late_delivery,
    items.item_count,
    items.distinct_product_count,
    items.distinct_seller_count,
    items.product_gmv,
    items.freight_value,
    items.gross_order_value,
    payments.payment_record_count,
    payments.payment_value,
    payments.payment_types,
    payments.max_payment_installments,
    reviews.latest_review_id,
    reviews.latest_review_score,
    reviews.latest_review_creation_timestamp,
    reviews.latest_review_answer_timestamp,
    reviews.review_record_count
FROM staging.stg_orders AS orders
INNER JOIN staging.stg_customers AS customers USING (customer_id)
LEFT JOIN item_aggregates AS items USING (order_id)
LEFT JOIN payment_aggregates AS payments USING (order_id)
LEFT JOIN latest_reviews AS reviews USING (order_id);

ALTER TABLE core.fct_order
    ADD CONSTRAINT pk_fct_order PRIMARY KEY (order_id),
    ADD CONSTRAINT fk_fct_order_customer FOREIGN KEY (customer_unique_id)
        REFERENCES core.dim_customer (customer_unique_id),
    ADD CONSTRAINT fk_fct_order_purchase_date FOREIGN KEY (purchase_date)
        REFERENCES core.dim_date (date_key);

CREATE INDEX idx_fct_order_purchase_month
    ON core.fct_order (purchase_month);
CREATE INDEX idx_fct_order_customer
    ON core.fct_order (customer_unique_id);
CREATE INDEX idx_fct_order_state
    ON core.fct_order (customer_state);
CREATE INDEX idx_fct_order_status
    ON core.fct_order (order_status);

CREATE TABLE core.fct_order_item AS
SELECT
    items.order_id,
    items.order_item_id,
    items.product_id,
    items.seller_id,
    items.shipping_limit_timestamp,
    items.price,
    items.freight_value,
    (items.price + items.freight_value)::numeric(12, 2) AS gross_item_value
FROM staging.stg_order_items AS items;

ALTER TABLE core.fct_order_item
    ADD CONSTRAINT pk_fct_order_item PRIMARY KEY (order_id, order_item_id),
    ADD CONSTRAINT fk_fct_order_item_order FOREIGN KEY (order_id)
        REFERENCES core.fct_order (order_id),
    ADD CONSTRAINT fk_fct_order_item_product FOREIGN KEY (product_id)
        REFERENCES core.dim_product (product_id),
    ADD CONSTRAINT fk_fct_order_item_seller FOREIGN KEY (seller_id)
        REFERENCES core.dim_seller (seller_id);

CREATE INDEX idx_fct_order_item_product
    ON core.fct_order_item (product_id);
CREATE INDEX idx_fct_order_item_seller
    ON core.fct_order_item (seller_id);

CREATE TABLE core.fct_payment AS
SELECT
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
FROM staging.stg_order_payments;

ALTER TABLE core.fct_payment
    ADD CONSTRAINT pk_fct_payment PRIMARY KEY (order_id, payment_sequential),
    ADD CONSTRAINT fk_fct_payment_order FOREIGN KEY (order_id)
        REFERENCES core.fct_order (order_id);

CREATE INDEX idx_fct_payment_type
    ON core.fct_payment (payment_type);

CREATE TABLE core.fct_review AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY
            order_id,
            review_answer_timestamp,
            review_creation_timestamp,
            review_id,
            COALESCE(review_comment_title, ''),
            COALESCE(review_comment_message, '')
    )::bigint AS review_record_key,
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_timestamp,
    review_answer_timestamp,
    ROW_NUMBER() OVER (
        PARTITION BY order_id
        ORDER BY review_answer_timestamp DESC, review_creation_timestamp DESC, review_id DESC
    )::integer AS latest_review_rank
FROM staging.stg_order_reviews;

ALTER TABLE core.fct_review
    ADD CONSTRAINT pk_fct_review PRIMARY KEY (review_record_key),
    ADD CONSTRAINT fk_fct_review_order FOREIGN KEY (order_id)
        REFERENCES core.fct_order (order_id),
    ADD CONSTRAINT chk_fct_review_score CHECK (review_score BETWEEN 1 AND 5);

CREATE INDEX idx_fct_review_order
    ON core.fct_review (order_id);

COMMIT;

