\set ON_ERROR_STOP on

SELECT qa.assert_equal(
    'Power BI order view row count',
    COUNT(*),
    (SELECT COUNT(*) FROM core.fct_order)
) FROM mart.pbi_orders;

SELECT qa.assert_equal(
    'Power BI item view row count',
    COUNT(*),
    (SELECT COUNT(*) FROM core.fct_order_item)
) FROM mart.pbi_order_items;

SELECT qa.assert_equal(
    'Power BI customer view row count',
    COUNT(*),
    (SELECT COUNT(*) FROM mart.customer_metrics)
) FROM mart.pbi_customers;

SELECT qa.assert_equal(
    'Power BI delivered order GMV cents',
    ROUND(SUM(product_gmv) FILTER (WHERE is_delivered) * 100)::bigint,
    (
        SELECT ROUND(SUM(product_gmv) * 100)::bigint
        FROM core.fct_order
        WHERE is_delivered
    )
) FROM mart.pbi_orders;

SELECT qa.assert_equal(
    'Power BI delivered item GMV cents',
    ROUND(SUM(price) FILTER (WHERE is_delivered) * 100)::bigint,
    (
        SELECT ROUND(SUM(items.price) * 100)::bigint
        FROM core.fct_order_item AS items
        INNER JOIN core.fct_order AS orders USING (order_id)
        WHERE orders.is_delivered
    )
) FROM mart.pbi_order_items;

SELECT qa.assert_equal('Power BI late flag inconsistencies', COUNT(*), 0)
FROM mart.pbi_orders
WHERE days_vs_estimate IS NOT NULL
  AND is_late_delivery IS DISTINCT FROM (days_vs_estimate > 0);

SELECT qa.assert_equal('Power BI unassigned customer segments', COUNT(*), 0)
FROM mart.pbi_customers
WHERE rfm_segment IS NULL;

SELECT qa.assert_equal(
    'Power BI month dimension row count',
    COUNT(*),
    (SELECT COUNT(*) FROM mart.monthly_business_kpis)
) FROM mart.pbi_months;

