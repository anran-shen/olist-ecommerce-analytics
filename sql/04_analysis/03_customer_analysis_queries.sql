\set ON_ERROR_STOP on

-- 1. Portfolio-level repeat metrics with observation-window controls.
SELECT
    COUNT(*) AS delivered_customer_count,
    COUNT(*) FILTER (WHERE is_repeat_customer) AS repeat_customer_count,
    (
        COUNT(*) FILTER (WHERE is_repeat_customer)::numeric / COUNT(*)
    )::numeric(12, 6) AS all_time_repeat_rate,
    COUNT(*) FILTER (WHERE has_full_90d_observation) AS eligible_90d_customer_count,
    COUNT(*) FILTER (WHERE repeated_within_90d) AS repeat_90d_customer_count,
    (
        COUNT(*) FILTER (WHERE repeated_within_90d)::numeric
        / NULLIF(COUNT(*) FILTER (WHERE has_full_90d_observation), 0)
    )::numeric(12, 6) AS repeat_rate_90d,
    PERCENTILE_CONT(0.5) WITHIN GROUP (
        ORDER BY days_to_second_order
    ) FILTER (WHERE is_repeat_customer)::numeric(10, 2) AS median_days_to_second_order,
    MAX(observation_end_timestamp) AS observation_end_timestamp
FROM mart.customer_metrics;

-- 2. Economic contribution of repeat versus one-time customers.
SELECT
    is_repeat_customer,
    COUNT(*) AS customer_count,
    SUM(delivered_order_count) AS order_count,
    SUM(lifetime_gmv)::numeric(16, 2) AS gmv,
    (SUM(lifetime_gmv) / SUM(delivered_order_count))::numeric(12, 2) AS aov,
    (AVG(delivered_order_count))::numeric(12, 4) AS orders_per_customer,
    (SUM(lifetime_gmv) / SUM(SUM(lifetime_gmv)) OVER ())::numeric(12, 6)
        AS gmv_share
FROM mart.customer_metrics
GROUP BY is_repeat_customer
ORDER BY is_repeat_customer DESC;

-- 3. Fixed-window repeat rate by cohort; 2016 pilot cohorts are excluded from comparison.
SELECT
    cohort_month,
    eligible_customer_count,
    repeated_customer_count,
    repeat_rate_90d
FROM mart.cohort_repeat_90d
WHERE cohort_month BETWEEN DATE '2017-01-01' AND DATE '2018-05-01'
ORDER BY cohort_month;

-- 4. Month 0-6 cohort retention matrix for sufficiently observed cohorts.
SELECT
    cohort_month,
    MAX(cohort_size) AS cohort_size,
    MAX(retention_rate) FILTER (WHERE month_number = 0) AS m0,
    MAX(retention_rate) FILTER (WHERE month_number = 1) AS m1,
    MAX(retention_rate) FILTER (WHERE month_number = 2) AS m2,
    MAX(retention_rate) FILTER (WHERE month_number = 3) AS m3,
    MAX(retention_rate) FILTER (WHERE month_number = 4) AS m4,
    MAX(retention_rate) FILTER (WHERE month_number = 5) AS m5,
    MAX(retention_rate) FILTER (WHERE month_number = 6) AS m6
FROM mart.cohort_retention
WHERE cohort_month BETWEEN DATE '2017-01-01' AND DATE '2018-02-01'
GROUP BY cohort_month
ORDER BY cohort_month;

-- 5. RFM segment size, value and behavioral profile.
SELECT
    segments.rfm_segment,
    COUNT(*) AS customer_count,
    (COUNT(*)::numeric / SUM(COUNT(*)) OVER ())::numeric(12, 6) AS customer_share,
    SUM(segments.monetary)::numeric(16, 2) AS lifetime_gmv,
    (SUM(segments.monetary) / SUM(SUM(segments.monetary)) OVER ())::numeric(12, 6)
        AS gmv_share,
    AVG(segments.recency_days)::numeric(12, 2) AS average_recency_days,
    AVG(segments.frequency)::numeric(12, 4) AS average_frequency,
    AVG(segments.monetary)::numeric(12, 2) AS average_customer_gmv
FROM mart.rfm_customer_segments AS segments
GROUP BY segments.rfm_segment
ORDER BY lifetime_gmv DESC;

