\set ON_ERROR_STOP on

SELECT
    order_id,
    customer_unique_id,
    purchase_date,
    purchase_month,
    customer_state,
    delivery_days,
    days_vs_estimate,
    is_late_delivery,
    review_score,
    item_count,
    product_gmv,
    freight_value
FROM mart.delivery_review_orders
ORDER BY order_id;

