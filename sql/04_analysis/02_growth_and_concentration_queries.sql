\set ON_ERROR_STOP on

-- 1. Category contribution to Jan-Aug growth on equal calendar coverage.
WITH period_category AS (
    SELECT
        EXTRACT(YEAR FROM orders.order_purchase_timestamp)::integer AS year,
        products.product_category_display,
        SUM(items.price) AS gmv
    FROM core.fct_order_item AS items
    INNER JOIN core.fct_order AS orders USING (order_id)
    INNER JOIN core.dim_product AS products USING (product_id)
    WHERE orders.is_delivered
      AND EXTRACT(MONTH FROM orders.order_purchase_timestamp) BETWEEN 1 AND 8
      AND EXTRACT(YEAR FROM orders.order_purchase_timestamp) IN (2017, 2018)
    GROUP BY 1, 2
),
pivoted AS (
    SELECT
        product_category_display,
        COALESCE(SUM(gmv) FILTER (WHERE year = 2017), 0) AS gmv_2017,
        COALESCE(SUM(gmv) FILTER (WHERE year = 2018), 0) AS gmv_2018
    FROM period_category
    GROUP BY product_category_display
)
SELECT
    product_category_display,
    gmv_2017::numeric(14, 2),
    gmv_2018::numeric(14, 2),
    (gmv_2018 - gmv_2017)::numeric(14, 2) AS gmv_change
FROM pivoted
ORDER BY gmv_change DESC
LIMIT 10;

-- 2. Customer-state contribution to Jan-Aug growth.
WITH period_state AS (
    SELECT
        EXTRACT(YEAR FROM order_purchase_timestamp)::integer AS year,
        customer_state,
        SUM(product_gmv) AS gmv
    FROM core.fct_order
    WHERE is_delivered
      AND EXTRACT(MONTH FROM order_purchase_timestamp) BETWEEN 1 AND 8
      AND EXTRACT(YEAR FROM order_purchase_timestamp) IN (2017, 2018)
    GROUP BY 1, 2
),
pivoted AS (
    SELECT
        customer_state,
        COALESCE(SUM(gmv) FILTER (WHERE year = 2017), 0) AS gmv_2017,
        COALESCE(SUM(gmv) FILTER (WHERE year = 2018), 0) AS gmv_2018
    FROM period_state
    GROUP BY customer_state
)
SELECT
    customer_state,
    gmv_2017::numeric(14, 2),
    gmv_2018::numeric(14, 2),
    (gmv_2018 - gmv_2017)::numeric(14, 2) AS gmv_change
FROM pivoted
ORDER BY gmv_change DESC
LIMIT 10;

-- 3. Seller concentration over all delivered item GMV.
WITH seller_gmv AS (
    SELECT
        items.seller_id,
        SUM(items.price) AS gmv
    FROM core.fct_order_item AS items
    INNER JOIN core.fct_order AS orders USING (order_id)
    WHERE orders.is_delivered
    GROUP BY items.seller_id
),
ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (ORDER BY gmv DESC) AS seller_rank,
        SUM(gmv) OVER () AS total_gmv
    FROM seller_gmv
)
SELECT
    (SUM(gmv) FILTER (WHERE seller_rank <= 1) / MAX(total_gmv))::numeric(12, 4)
        AS top_1_seller_share,
    (SUM(gmv) FILTER (WHERE seller_rank <= 10) / MAX(total_gmv))::numeric(12, 4)
        AS top_10_seller_share,
    (SUM(gmv) FILTER (WHERE seller_rank <= 100) / MAX(total_gmv))::numeric(12, 4)
        AS top_100_seller_share
FROM ranked;

-- 4. Largest category and state offsets in the June/August 2018 slowdown.
SELECT
    'category' AS dimension,
    purchase_month,
    product_category_display AS member,
    gmv_change,
    contribution_share
FROM mart.monthly_category_gmv_change
WHERE purchase_month IN (DATE '2018-06-01', DATE '2018-08-01')
  AND negative_contribution_rank <= 8
UNION ALL
SELECT
    'customer_state',
    purchase_month,
    customer_state,
    gmv_change,
    contribution_share
FROM mart.monthly_state_gmv_change
WHERE purchase_month IN (DATE '2018-06-01', DATE '2018-08-01')
  AND negative_contribution_rank <= 5
ORDER BY purchase_month, dimension, gmv_change;

