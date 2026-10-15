\set ON_ERROR_STOP on

SELECT qa.assert_equal(
    'delivery-review mart row count',
    COUNT(*),
    (
        SELECT COUNT(*)
        FROM core.fct_order
        WHERE is_delivered
          AND delivered_customer_timestamp IS NOT NULL
          AND estimated_delivery_timestamp IS NOT NULL
          AND latest_review_score IS NOT NULL
    )
) FROM mart.delivery_review_orders;

SELECT qa.assert_equal('delivery-review null required fields', COUNT(*), 0)
FROM mart.delivery_review_orders
WHERE customer_unique_id IS NULL
   OR delivery_days IS NULL
   OR days_vs_estimate IS NULL
   OR is_late_delivery IS NULL
   OR review_score IS NULL;

SELECT qa.assert_equal('delivery-review invalid scores', COUNT(*), 0)
FROM mart.delivery_review_orders
WHERE review_score NOT BETWEEN 1 AND 5;

SELECT qa.assert_equal('delivery-review negative delivery durations', COUNT(*), 0)
FROM mart.delivery_review_orders
WHERE delivery_days < 0;

SELECT qa.assert_equal('delivery-review inconsistent late flags', COUNT(*), 0)
FROM mart.delivery_review_orders
WHERE is_late_delivery IS DISTINCT FROM (days_vs_estimate > 0);

SELECT qa.assert_equal(
    'delivery-review GMV cents reconciliation',
    ROUND(SUM(product_gmv) * 100)::bigint,
    (
        SELECT ROUND(SUM(product_gmv) * 100)::bigint
        FROM core.fct_order
        WHERE is_delivered
          AND delivered_customer_timestamp IS NOT NULL
          AND estimated_delivery_timestamp IS NOT NULL
          AND latest_review_score IS NOT NULL
    )
) FROM mart.delivery_review_orders;

