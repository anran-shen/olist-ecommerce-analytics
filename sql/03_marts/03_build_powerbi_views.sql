\set ON_ERROR_STOP on

BEGIN;

CREATE OR REPLACE VIEW mart.pbi_orders AS
SELECT
    orders.order_id,
    orders.customer_unique_id,
    orders.purchase_date,
    orders.purchase_month,
    orders.customer_state,
    orders.customer_city,
    orders.order_status,
    orders.is_delivered,
    orders.item_count,
    orders.product_gmv,
    orders.freight_value,
    orders.gross_order_value,
    orders.payment_value,
    orders.delivery_days,
    CASE
        WHEN orders.delivered_customer_timestamp IS NULL
            OR orders.estimated_delivery_timestamp IS NULL THEN NULL
        ELSE (
            EXTRACT(EPOCH FROM (
                orders.delivered_customer_timestamp - orders.estimated_delivery_timestamp
            )) / 86400
        )::numeric(12, 6)
    END AS days_vs_estimate,
    orders.is_late_delivery,
    orders.latest_review_score AS review_score,
    CASE
        WHEN orders.latest_review_score IS NULL THEN NULL
        ELSE orders.latest_review_score <= 2
    END AS is_low_review
FROM core.fct_order AS orders;

CREATE OR REPLACE VIEW mart.pbi_order_items AS
SELECT
    items.order_id,
    items.order_item_id,
    orders.customer_unique_id,
    orders.purchase_date,
    orders.purchase_month,
    orders.customer_state,
    orders.order_status,
    orders.is_delivered,
    items.product_id,
    products.product_category_display,
    items.seller_id,
    sellers.seller_state,
    items.price,
    items.freight_value,
    items.gross_item_value
FROM core.fct_order_item AS items
INNER JOIN core.fct_order AS orders USING (order_id)
INNER JOIN core.dim_product AS products USING (product_id)
INNER JOIN core.dim_seller AS sellers USING (seller_id);

CREATE OR REPLACE VIEW mart.pbi_customers AS
SELECT
    metrics.customer_unique_id,
    dimensions.customer_state,
    dimensions.customer_city,
    metrics.cohort_month,
    metrics.first_order_timestamp::date AS first_order_date,
    metrics.last_order_timestamp::date AS last_order_date,
    metrics.delivered_order_count,
    metrics.lifetime_gmv,
    metrics.customer_aov,
    metrics.recency_days,
    metrics.is_repeat_customer,
    metrics.days_to_second_order,
    metrics.has_full_90d_observation,
    metrics.repeated_within_90d,
    segments.recency_score,
    segments.frequency_score,
    segments.monetary_score,
    segments.rfm_segment,
    metrics.rfm_snapshot_date
FROM mart.customer_metrics AS metrics
INNER JOIN mart.rfm_customer_segments AS segments USING (customer_unique_id)
INNER JOIN core.dim_customer AS dimensions USING (customer_unique_id);

CREATE OR REPLACE VIEW mart.pbi_months AS
SELECT
    monthly.purchase_month,
    EXTRACT(YEAR FROM monthly.purchase_month)::integer AS year,
    EXTRACT(QUARTER FROM monthly.purchase_month)::integer AS quarter,
    EXTRACT(MONTH FROM monthly.purchase_month)::integer AS month_number,
    TO_CHAR(monthly.purchase_month, 'YYYY-MM') AS year_month,
    monthly.is_complete_month
FROM mart.monthly_business_kpis AS monthly;

COMMIT;

