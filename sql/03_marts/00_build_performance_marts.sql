\set ON_ERROR_STOP on

BEGIN;

DROP TABLE IF EXISTS mart.monthly_seller_kpis;
DROP TABLE IF EXISTS mart.monthly_customer_state_kpis;
DROP TABLE IF EXISTS mart.monthly_category_kpis;
DROP TABLE IF EXISTS mart.monthly_business_kpis;

CREATE TABLE mart.monthly_business_kpis AS
WITH month_bounds AS (
    SELECT
        MIN(purchase_month) AS first_month,
        MAX(purchase_month) AS last_month
    FROM core.fct_order
),
calendar_months AS (
    SELECT
        GENERATE_SERIES(first_month, last_month, INTERVAL '1 month')::date AS purchase_month,
        first_month,
        last_month
    FROM month_bounds
),
monthly AS (
    SELECT
        purchase_month,
        COUNT(*)::integer AS order_count,
        COUNT(DISTINCT customer_unique_id)::integer AS purchasing_customer_count,
        SUM(product_gmv)::numeric(16, 2) AS gmv,
        SUM(freight_value)::numeric(16, 2) AS freight_value,
        SUM(gross_order_value)::numeric(16, 2) AS gross_order_value,
        SUM(payment_value)::numeric(16, 2) AS payment_value,
        SUM(item_count)::bigint AS item_count
    FROM core.fct_order
    WHERE is_delivered
    GROUP BY purchase_month
),
base AS (
    SELECT
        months.purchase_month,
        (
            months.purchase_month BETWEEN DATE '2017-01-01' AND DATE '2018-08-01'
        ) AS is_complete_month,
        COALESCE(monthly.order_count, 0) AS order_count,
        COALESCE(monthly.purchasing_customer_count, 0) AS purchasing_customer_count,
        COALESCE(monthly.gmv, 0)::numeric(16, 2) AS gmv,
        COALESCE(monthly.freight_value, 0)::numeric(16, 2) AS freight_value,
        COALESCE(monthly.gross_order_value, 0)::numeric(16, 2) AS gross_order_value,
        COALESCE(monthly.payment_value, 0)::numeric(16, 2) AS payment_value,
        COALESCE(monthly.item_count, 0)::bigint AS item_count,
        (monthly.gmv / NULLIF(monthly.order_count, 0))::numeric(12, 2) AS aov,
        (monthly.order_count::numeric / NULLIF(monthly.purchasing_customer_count, 0))::numeric(12, 4)
            AS orders_per_customer,
        (monthly.item_count::numeric / NULLIF(monthly.order_count, 0))::numeric(12, 4)
            AS items_per_order,
        (monthly.gmv / NULLIF(monthly.item_count, 0))::numeric(12, 2)
            AS average_item_price
    FROM calendar_months AS months
    LEFT JOIN monthly USING (purchase_month)
),
with_previous AS (
    SELECT
        base.*,
        LAG(is_complete_month) OVER (ORDER BY purchase_month) AS previous_month_is_complete,
        LAG(gmv) OVER (ORDER BY purchase_month) AS previous_month_gmv,
        LAG(order_count) OVER (ORDER BY purchase_month) AS previous_month_order_count,
        LAG(aov) OVER (ORDER BY purchase_month) AS previous_month_aov
    FROM base
)
SELECT
    *,
    CASE WHEN is_complete_month AND previous_month_is_complete
        THEN ((gmv / NULLIF(previous_month_gmv, 0)) - 1)::numeric(12, 4)
    END AS gmv_mom_rate,
    CASE WHEN is_complete_month AND previous_month_is_complete
        THEN ((order_count::numeric / NULLIF(previous_month_order_count, 0)) - 1)::numeric(12, 4)
    END AS order_count_mom_rate,
    CASE WHEN is_complete_month AND previous_month_is_complete
        THEN ((aov / NULLIF(previous_month_aov, 0)) - 1)::numeric(12, 4)
    END AS aov_mom_rate,
    CASE
        WHEN is_complete_month AND purchase_month >= DATE '2017-03-01'
        THEN AVG(gmv) OVER (
            ORDER BY purchase_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        )::numeric(16, 2)
    END AS gmv_3m_moving_average
FROM with_previous;

ALTER TABLE mart.monthly_business_kpis
    ADD CONSTRAINT pk_monthly_business_kpis PRIMARY KEY (purchase_month);

CREATE TABLE mart.monthly_category_kpis AS
SELECT
    orders.purchase_month,
    products.product_category_display,
    COUNT(*)::bigint AS item_count,
    COUNT(DISTINCT items.order_id)::integer AS order_count,
    COUNT(DISTINCT orders.customer_unique_id)::integer AS purchasing_customer_count,
    SUM(items.price)::numeric(16, 2) AS gmv,
    SUM(items.freight_value)::numeric(16, 2) AS freight_value,
    (SUM(items.price) / NULLIF(COUNT(DISTINCT items.order_id), 0))::numeric(12, 2)
        AS category_gmv_per_order
FROM core.fct_order_item AS items
INNER JOIN core.fct_order AS orders USING (order_id)
INNER JOIN core.dim_product AS products USING (product_id)
WHERE orders.is_delivered
GROUP BY orders.purchase_month, products.product_category_display;

ALTER TABLE mart.monthly_category_kpis
    ADD CONSTRAINT pk_monthly_category_kpis
        PRIMARY KEY (purchase_month, product_category_display);

CREATE TABLE mart.monthly_customer_state_kpis AS
SELECT
    purchase_month,
    customer_state,
    COUNT(*)::integer AS order_count,
    COUNT(DISTINCT customer_unique_id)::integer AS purchasing_customer_count,
    SUM(product_gmv)::numeric(16, 2) AS gmv,
    SUM(freight_value)::numeric(16, 2) AS freight_value,
    (SUM(product_gmv) / NULLIF(COUNT(*), 0))::numeric(12, 2) AS aov
FROM core.fct_order
WHERE is_delivered
GROUP BY purchase_month, customer_state;

ALTER TABLE mart.monthly_customer_state_kpis
    ADD CONSTRAINT pk_monthly_customer_state_kpis
        PRIMARY KEY (purchase_month, customer_state);

CREATE TABLE mart.monthly_seller_kpis AS
SELECT
    orders.purchase_month,
    items.seller_id,
    sellers.seller_state,
    COUNT(*)::bigint AS item_count,
    COUNT(DISTINCT items.order_id)::integer AS order_count,
    SUM(items.price)::numeric(16, 2) AS gmv,
    SUM(items.freight_value)::numeric(16, 2) AS freight_value
FROM core.fct_order_item AS items
INNER JOIN core.fct_order AS orders USING (order_id)
INNER JOIN core.dim_seller AS sellers USING (seller_id)
WHERE orders.is_delivered
GROUP BY orders.purchase_month, items.seller_id, sellers.seller_state;

ALTER TABLE mart.monthly_seller_kpis
    ADD CONSTRAINT pk_monthly_seller_kpis
        PRIMARY KEY (purchase_month, seller_id);

COMMIT;
