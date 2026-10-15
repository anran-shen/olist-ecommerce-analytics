\set ON_ERROR_STOP on

SELECT qa.assert_equal(
    'customer metrics row count',
    COUNT(*),
    (SELECT COUNT(DISTINCT customer_unique_id) FROM core.fct_order WHERE is_delivered)
) FROM mart.customer_metrics;

SELECT qa.assert_equal(
    'customer frequency to delivered order count',
    SUM(delivered_order_count),
    (SELECT COUNT(*) FROM core.fct_order WHERE is_delivered)
) FROM mart.customer_metrics;

SELECT qa.assert_equal(
    'customer monetary to delivered GMV cents',
    ROUND(SUM(lifetime_gmv) * 100)::bigint,
    (SELECT ROUND(SUM(product_gmv) * 100)::bigint FROM core.fct_order WHERE is_delivered)
) FROM mart.customer_metrics;

SELECT qa.assert_equal('repeat flag inconsistency', COUNT(*), 0)
FROM mart.customer_metrics
WHERE is_repeat_customer IS DISTINCT FROM (delivered_order_count >= 2);

SELECT qa.assert_equal('invalid 90-day observation flags', COUNT(*), 0)
FROM mart.customer_metrics
WHERE repeated_within_90d IS NOT NULL
  AND NOT has_full_90d_observation;

SELECT qa.assert_equal('cohort month-zero retained-customer discrepancy', COUNT(*), 0)
FROM mart.cohort_retention
WHERE month_number = 0
  AND retained_customers <> cohort_size;

SELECT qa.assert_equal('cohort activity before first order', COUNT(*), 0)
FROM mart.cohort_retention
WHERE month_number < 0;

SELECT qa.assert_equal('invalid cohort retention rates', COUNT(*), 0)
FROM mart.cohort_retention
WHERE retention_rate NOT BETWEEN 0 AND 1;

SELECT qa.assert_equal(
    'RFM row count',
    COUNT(*),
    (SELECT COUNT(*) FROM mart.customer_metrics)
) FROM mart.rfm_customer_segments;

SELECT qa.assert_equal('unassigned RFM segments', COUNT(*), 0)
FROM mart.rfm_customer_segments
WHERE rfm_segment IS NULL;

SELECT qa.assert_equal(
    'RFM monetary reconciliation cents',
    ROUND(SUM(monetary) * 100)::bigint,
    (SELECT ROUND(SUM(lifetime_gmv) * 100)::bigint FROM mart.customer_metrics)
) FROM mart.rfm_customer_segments;

