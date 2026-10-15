\set ON_ERROR_STOP on

SELECT
    purchase_month,
    COUNT(*) AS reviewed_delivered_orders,
    COUNT(*) FILTER (WHERE is_late_delivery) AS late_reviewed_orders,
    (
        AVG((review_score <= 2)::integer) FILTER (WHERE is_late_delivery)
    )::numeric(12, 6) AS late_low_review_rate
FROM mart.delivery_review_orders
WHERE purchase_month BETWEEN DATE '2018-01-01' AND DATE '2018-08-01'
GROUP BY purchase_month
ORDER BY purchase_month;

