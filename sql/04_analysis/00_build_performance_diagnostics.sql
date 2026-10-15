\set ON_ERROR_STOP on

BEGIN;

DROP TABLE IF EXISTS mart.monthly_seller_gmv_change;
DROP TABLE IF EXISTS mart.monthly_state_gmv_change;
DROP TABLE IF EXISTS mart.monthly_category_gmv_change;
DROP TABLE IF EXISTS mart.monthly_kpi_decomposition;

CREATE TABLE mart.monthly_kpi_decomposition AS
WITH exact_metrics AS (
    SELECT
        monthly.*,
        gmv / NULLIF(order_count, 0) AS exact_aov,
        order_count::numeric / NULLIF(purchasing_customer_count, 0)
            AS exact_orders_per_customer,
        item_count::numeric / NULLIF(order_count, 0) AS exact_items_per_order,
        gmv / NULLIF(item_count, 0) AS exact_average_item_price
    FROM mart.monthly_business_kpis AS monthly
),
lagged AS (
    SELECT
        exact_metrics.*,
        LAG(purchasing_customer_count) OVER (ORDER BY purchase_month)
            AS previous_month_customer_count,
        LAG(exact_orders_per_customer) OVER (ORDER BY purchase_month)
            AS previous_month_exact_orders_per_customer,
        LAG(exact_items_per_order) OVER (ORDER BY purchase_month)
            AS previous_month_exact_items_per_order,
        LAG(exact_average_item_price) OVER (ORDER BY purchase_month)
            AS previous_month_exact_average_item_price,
        LAG(exact_aov) OVER (ORDER BY purchase_month) AS previous_month_exact_aov
    FROM exact_metrics
),
components AS (
    SELECT
        lagged.*,
        (gmv - previous_month_gmv)::numeric(16, 2) AS gmv_change,
        (order_count - previous_month_order_count)::integer AS order_count_change,
        (aov - previous_month_aov)::numeric(12, 2) AS aov_change,
        (
            (order_count - previous_month_order_count)
            * (exact_aov + previous_month_exact_aov) / 2.0
        )::numeric(20, 6) AS order_volume_gmv_contribution,
        (
            (exact_aov - previous_month_exact_aov)
            * (order_count + previous_month_order_count) / 2.0
        )::numeric(20, 6) AS aov_gmv_contribution,
        (
            (order_count + previous_month_order_count) / 2.0
            * (exact_items_per_order - previous_month_exact_items_per_order)
            * (exact_average_item_price + previous_month_exact_average_item_price) / 2.0
        )::numeric(20, 6) AS basket_size_gmv_contribution,
        (
            (order_count + previous_month_order_count) / 2.0
            * (exact_average_item_price - previous_month_exact_average_item_price)
            * (exact_items_per_order + previous_month_exact_items_per_order) / 2.0
        )::numeric(20, 6) AS item_price_gmv_contribution,
        (
            (purchasing_customer_count - previous_month_customer_count)
            * (exact_orders_per_customer + previous_month_exact_orders_per_customer) / 2.0
        )::numeric(18, 6) AS customer_count_order_contribution,
        (
            (exact_orders_per_customer - previous_month_exact_orders_per_customer)
            * (purchasing_customer_count + previous_month_customer_count) / 2.0
        )::numeric(18, 6) AS purchase_frequency_order_contribution
    FROM lagged
    WHERE is_complete_month AND previous_month_is_complete
)
SELECT
    *,
    (order_volume_gmv_contribution / NULLIF(gmv_change, 0))::numeric(12, 4)
        AS order_volume_contribution_share,
    (aov_gmv_contribution / NULLIF(gmv_change, 0))::numeric(12, 4)
        AS aov_contribution_share
FROM components;

ALTER TABLE mart.monthly_kpi_decomposition
    ADD CONSTRAINT pk_monthly_kpi_decomposition PRIMARY KEY (purchase_month);

CREATE TABLE mart.monthly_category_gmv_change AS
WITH month_pairs AS (
    SELECT
        purchase_month,
        LAG(purchase_month) OVER (ORDER BY purchase_month) AS previous_month,
        gmv - LAG(gmv) OVER (ORDER BY purchase_month) AS total_gmv_change
    FROM mart.monthly_business_kpis
    WHERE is_complete_month
),
categories AS (
    SELECT DISTINCT product_category_display
    FROM core.dim_product
),
changes AS (
    SELECT
        months.purchase_month,
        months.previous_month,
        categories.product_category_display,
        COALESCE(previous.gmv, 0)::numeric(16, 2) AS previous_month_gmv,
        COALESCE(current.gmv, 0)::numeric(16, 2) AS current_month_gmv,
        (COALESCE(current.gmv, 0) - COALESCE(previous.gmv, 0))::numeric(16, 2)
            AS gmv_change,
        months.total_gmv_change
    FROM month_pairs AS months
    CROSS JOIN categories
    LEFT JOIN mart.monthly_category_kpis AS current
        ON current.purchase_month = months.purchase_month
       AND current.product_category_display = categories.product_category_display
    LEFT JOIN mart.monthly_category_kpis AS previous
        ON previous.purchase_month = months.previous_month
       AND previous.product_category_display = categories.product_category_display
    WHERE months.previous_month IS NOT NULL
)
SELECT
    *,
    (gmv_change / NULLIF(total_gmv_change, 0))::numeric(12, 4) AS contribution_share,
    ROW_NUMBER() OVER (
        PARTITION BY purchase_month ORDER BY gmv_change DESC, product_category_display
    )::integer AS positive_contribution_rank,
    ROW_NUMBER() OVER (
        PARTITION BY purchase_month ORDER BY gmv_change ASC, product_category_display
    )::integer AS negative_contribution_rank
FROM changes;

ALTER TABLE mart.monthly_category_gmv_change
    ADD CONSTRAINT pk_monthly_category_gmv_change
        PRIMARY KEY (purchase_month, product_category_display);

CREATE TABLE mart.monthly_state_gmv_change AS
WITH month_pairs AS (
    SELECT
        purchase_month,
        LAG(purchase_month) OVER (ORDER BY purchase_month) AS previous_month,
        gmv - LAG(gmv) OVER (ORDER BY purchase_month) AS total_gmv_change
    FROM mart.monthly_business_kpis
    WHERE is_complete_month
),
states AS (
    SELECT DISTINCT customer_state
    FROM core.dim_customer
),
changes AS (
    SELECT
        months.purchase_month,
        months.previous_month,
        states.customer_state,
        COALESCE(previous.gmv, 0)::numeric(16, 2) AS previous_month_gmv,
        COALESCE(current.gmv, 0)::numeric(16, 2) AS current_month_gmv,
        (COALESCE(current.gmv, 0) - COALESCE(previous.gmv, 0))::numeric(16, 2)
            AS gmv_change,
        months.total_gmv_change
    FROM month_pairs AS months
    CROSS JOIN states
    LEFT JOIN mart.monthly_customer_state_kpis AS current
        ON current.purchase_month = months.purchase_month
       AND current.customer_state = states.customer_state
    LEFT JOIN mart.monthly_customer_state_kpis AS previous
        ON previous.purchase_month = months.previous_month
       AND previous.customer_state = states.customer_state
    WHERE months.previous_month IS NOT NULL
)
SELECT
    *,
    (gmv_change / NULLIF(total_gmv_change, 0))::numeric(12, 4) AS contribution_share,
    ROW_NUMBER() OVER (
        PARTITION BY purchase_month ORDER BY gmv_change DESC, customer_state
    )::integer AS positive_contribution_rank,
    ROW_NUMBER() OVER (
        PARTITION BY purchase_month ORDER BY gmv_change ASC, customer_state
    )::integer AS negative_contribution_rank
FROM changes;

ALTER TABLE mart.monthly_state_gmv_change
    ADD CONSTRAINT pk_monthly_state_gmv_change
        PRIMARY KEY (purchase_month, customer_state);

CREATE TABLE mart.monthly_seller_gmv_change AS
WITH month_pairs AS (
    SELECT
        purchase_month,
        LAG(purchase_month) OVER (ORDER BY purchase_month) AS previous_month,
        gmv - LAG(gmv) OVER (ORDER BY purchase_month) AS total_gmv_change
    FROM mart.monthly_business_kpis
    WHERE is_complete_month
),
sellers AS (
    SELECT seller_id FROM core.dim_seller
),
changes AS (
    SELECT
        months.purchase_month,
        months.previous_month,
        sellers.seller_id,
        COALESCE(previous.gmv, 0)::numeric(16, 2) AS previous_month_gmv,
        COALESCE(current.gmv, 0)::numeric(16, 2) AS current_month_gmv,
        (COALESCE(current.gmv, 0) - COALESCE(previous.gmv, 0))::numeric(16, 2)
            AS gmv_change,
        months.total_gmv_change
    FROM month_pairs AS months
    CROSS JOIN sellers
    LEFT JOIN mart.monthly_seller_kpis AS current
        ON current.purchase_month = months.purchase_month
       AND current.seller_id = sellers.seller_id
    LEFT JOIN mart.monthly_seller_kpis AS previous
        ON previous.purchase_month = months.previous_month
       AND previous.seller_id = sellers.seller_id
    WHERE months.previous_month IS NOT NULL
)
SELECT
    *,
    (gmv_change / NULLIF(total_gmv_change, 0))::numeric(12, 4) AS contribution_share,
    ROW_NUMBER() OVER (
        PARTITION BY purchase_month ORDER BY gmv_change DESC, seller_id
    )::integer AS positive_contribution_rank,
    ROW_NUMBER() OVER (
        PARTITION BY purchase_month ORDER BY gmv_change ASC, seller_id
    )::integer AS negative_contribution_rank
FROM changes;

ALTER TABLE mart.monthly_seller_gmv_change
    ADD CONSTRAINT pk_monthly_seller_gmv_change
        PRIMARY KEY (purchase_month, seller_id);

COMMIT;
