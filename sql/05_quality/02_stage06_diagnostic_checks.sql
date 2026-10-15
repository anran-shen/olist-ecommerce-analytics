\set ON_ERROR_STOP on

SELECT qa.assert_equal('monthly decomposition row count', COUNT(*), 19)
FROM mart.monthly_kpi_decomposition;

SELECT qa.assert_equal('GMV two-level decomposition discrepancy cents',
    COALESCE(MAX(ABS(ROUND(
        (
            gmv_change
            - order_volume_gmv_contribution
            - basket_size_gmv_contribution
            - item_price_gmv_contribution
        ) * 100
    )))::bigint, 0),
    0
)
FROM mart.monthly_kpi_decomposition;

SELECT qa.assert_equal('order-count decomposition discrepancy hundredths',
    COALESCE(MAX(ABS(ROUND(
        (
            order_count_change
            - customer_count_order_contribution
            - purchase_frequency_order_contribution
        ) * 100
    )))::bigint, 0),
    0
)
FROM mart.monthly_kpi_decomposition;

SELECT qa.assert_equal('category monthly-change reconciliation discrepancy cents',
    COALESCE(MAX(ABS(discrepancy_cents))::bigint, 0),
    0
)
FROM (
    SELECT
        purchase_month,
        ROUND((SUM(gmv_change) - MAX(total_gmv_change)) * 100) AS discrepancy_cents
    FROM mart.monthly_category_gmv_change
    GROUP BY purchase_month
) AS checks;

SELECT qa.assert_equal('state monthly-change reconciliation discrepancy cents',
    COALESCE(MAX(ABS(discrepancy_cents))::bigint, 0),
    0
)
FROM (
    SELECT
        purchase_month,
        ROUND((SUM(gmv_change) - MAX(total_gmv_change)) * 100) AS discrepancy_cents
    FROM mart.monthly_state_gmv_change
    GROUP BY purchase_month
) AS checks;

SELECT qa.assert_equal('seller monthly-change reconciliation discrepancy cents',
    COALESCE(MAX(ABS(discrepancy_cents))::bigint, 0),
    0
)
FROM (
    SELECT
        purchase_month,
        ROUND((SUM(gmv_change) - MAX(total_gmv_change)) * 100) AS discrepancy_cents
    FROM mart.monthly_seller_gmv_change
    GROUP BY purchase_month
) AS checks;

