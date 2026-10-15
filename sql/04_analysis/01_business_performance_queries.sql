\set ON_ERROR_STOP on

-- 1. Comparable monthly trend. Ineligible source-coverage months are excluded.
SELECT
    purchase_month,
    gmv,
    order_count,
    aov,
    purchasing_customer_count,
    orders_per_customer,
    items_per_order,
    average_item_price,
    gmv_mom_rate,
    gmv_3m_moving_average
FROM mart.monthly_business_kpis
WHERE is_complete_month
ORDER BY purchase_month;

-- 2. Largest positive and negative adjacent-month changes.
WITH ranked AS (
    SELECT
        decomposition.*,
        ROW_NUMBER() OVER (ORDER BY gmv_change DESC) AS increase_rank,
        ROW_NUMBER() OVER (ORDER BY gmv_change ASC) AS decline_rank
    FROM mart.monthly_kpi_decomposition AS decomposition
)
SELECT
    purchase_month,
    gmv_change,
    order_count_change,
    aov_change,
    order_volume_gmv_contribution,
    basket_size_gmv_contribution,
    item_price_gmv_contribution
FROM ranked
WHERE increase_rank <= 3 OR decline_rank <= 3
ORDER BY purchase_month;

-- 3. January-August year-over-year comparison on equal calendar coverage.
WITH period_metrics AS (
    SELECT
        EXTRACT(YEAR FROM order_purchase_timestamp)::integer AS year,
        SUM(product_gmv)::numeric(16, 2) AS gmv,
        COUNT(*)::integer AS order_count,
        COUNT(DISTINCT customer_unique_id)::integer AS customer_count,
        SUM(item_count)::bigint AS item_count
    FROM core.fct_order
    WHERE is_delivered
      AND order_purchase_timestamp >= TIMESTAMP '2017-01-01'
      AND order_purchase_timestamp < TIMESTAMP '2019-01-01'
      AND EXTRACT(MONTH FROM order_purchase_timestamp) BETWEEN 1 AND 8
    GROUP BY EXTRACT(YEAR FROM order_purchase_timestamp)
),
with_rates AS (
    SELECT
        *,
        (gmv / order_count)::numeric(12, 2) AS aov,
        (order_count::numeric / customer_count)::numeric(12, 4) AS orders_per_customer,
        (item_count::numeric / order_count)::numeric(12, 4) AS items_per_order,
        (gmv / item_count)::numeric(12, 2) AS average_item_price
    FROM period_metrics
)
SELECT
    *,
    (gmv / LAG(gmv) OVER (ORDER BY year) - 1)::numeric(12, 4) AS gmv_yoy_rate,
    (order_count::numeric / LAG(order_count) OVER (ORDER BY year) - 1)::numeric(12, 4)
        AS order_yoy_rate,
    (aov / LAG(aov) OVER (ORDER BY year) - 1)::numeric(12, 4) AS aov_yoy_rate
FROM with_rates
ORDER BY year;

-- 4. Top category and state contributors for the largest spike and contraction.
SELECT
    'category' AS dimension,
    purchase_month,
    product_category_display AS member,
    gmv_change,
    contribution_share
FROM mart.monthly_category_gmv_change
WHERE purchase_month IN (DATE '2017-11-01', DATE '2017-12-01')
  AND (
      positive_contribution_rank <= 5
      OR negative_contribution_rank <= 5
  )
UNION ALL
SELECT
    'customer_state',
    purchase_month,
    customer_state,
    gmv_change,
    contribution_share
FROM mart.monthly_state_gmv_change
WHERE purchase_month IN (DATE '2017-11-01', DATE '2017-12-01')
  AND (
      positive_contribution_rank <= 5
      OR negative_contribution_rank <= 5
  )
ORDER BY purchase_month, dimension, gmv_change DESC;

