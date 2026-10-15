\set ON_ERROR_STOP on

BEGIN;

DROP TABLE IF EXISTS mart.rfm_customer_segments;
DROP TABLE IF EXISTS mart.cohort_repeat_90d;
DROP TABLE IF EXISTS mart.cohort_retention;
DROP TABLE IF EXISTS mart.customer_metrics;

CREATE TABLE mart.customer_metrics AS
WITH delivered_orders AS (
    SELECT
        customer_unique_id,
        order_id,
        order_purchase_timestamp,
        product_gmv,
        item_count,
        ROW_NUMBER() OVER (
            PARTITION BY customer_unique_id
            ORDER BY order_purchase_timestamp, order_id
        ) AS customer_order_number
    FROM core.fct_order
    WHERE is_delivered
),
observation AS (
    SELECT
        MAX(order_purchase_timestamp) AS observation_end_timestamp,
        MAX(order_purchase_timestamp)::date + 1 AS rfm_snapshot_date
    FROM delivered_orders
),
customer_aggregates AS (
    SELECT
        customer_unique_id,
        MIN(order_purchase_timestamp) AS first_order_timestamp,
        MAX(order_purchase_timestamp) AS last_order_timestamp,
        MIN(order_purchase_timestamp) FILTER (WHERE customer_order_number = 2)
            AS second_order_timestamp,
        COUNT(*)::integer AS delivered_order_count,
        SUM(product_gmv)::numeric(16, 2) AS lifetime_gmv,
        SUM(item_count)::bigint AS lifetime_item_count
    FROM delivered_orders
    GROUP BY customer_unique_id
)
SELECT
    customers.customer_unique_id,
    customers.first_order_timestamp,
    DATE_TRUNC('month', customers.first_order_timestamp)::date AS cohort_month,
    customers.last_order_timestamp,
    customers.second_order_timestamp,
    customers.delivered_order_count,
    customers.lifetime_gmv,
    customers.lifetime_item_count,
    (customers.lifetime_gmv / customers.delivered_order_count)::numeric(12, 2)
        AS customer_aov,
    (observation.rfm_snapshot_date - customers.last_order_timestamp::date)::integer
        AS recency_days,
    (customers.delivered_order_count >= 2) AS is_repeat_customer,
    CASE
        WHEN customers.second_order_timestamp IS NULL THEN NULL
        ELSE EXTRACT(EPOCH FROM (
            customers.second_order_timestamp - customers.first_order_timestamp
        )) / 86400
    END::numeric(10, 2) AS days_to_second_order,
    (
        customers.first_order_timestamp
        <= observation.observation_end_timestamp - INTERVAL '90 days'
    ) AS has_full_90d_observation,
    CASE
        WHEN customers.first_order_timestamp
            > observation.observation_end_timestamp - INTERVAL '90 days' THEN NULL
        ELSE COALESCE(
            customers.second_order_timestamp
                <= customers.first_order_timestamp + INTERVAL '90 days',
            false
        )
    END AS repeated_within_90d,
    observation.observation_end_timestamp,
    observation.rfm_snapshot_date
FROM customer_aggregates AS customers
CROSS JOIN observation;

ALTER TABLE mart.customer_metrics
    ADD CONSTRAINT pk_customer_metrics PRIMARY KEY (customer_unique_id),
    ADD CONSTRAINT fk_customer_metrics_customer FOREIGN KEY (customer_unique_id)
        REFERENCES core.dim_customer (customer_unique_id),
    ADD CONSTRAINT chk_customer_frequency_positive CHECK (delivered_order_count >= 1),
    ADD CONSTRAINT chk_customer_recency_nonnegative CHECK (recency_days >= 0);

CREATE INDEX idx_customer_metrics_cohort
    ON mart.customer_metrics (cohort_month);
CREATE INDEX idx_customer_metrics_repeat
    ON mart.customer_metrics (is_repeat_customer);

CREATE TABLE mart.cohort_retention AS
WITH customer_activity AS (
    SELECT DISTINCT
        orders.customer_unique_id,
        customers.cohort_month,
        orders.purchase_month AS activity_month,
        (
            (EXTRACT(YEAR FROM orders.purchase_month) - EXTRACT(YEAR FROM customers.cohort_month)) * 12
            + EXTRACT(MONTH FROM orders.purchase_month)
            - EXTRACT(MONTH FROM customers.cohort_month)
        )::integer AS months_since_first_order
    FROM core.fct_order AS orders
    INNER JOIN mart.customer_metrics AS customers USING (customer_unique_id)
    WHERE orders.is_delivered
),
cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(*)::integer AS cohort_size
    FROM mart.customer_metrics
    GROUP BY cohort_month
),
observation AS (
    SELECT MAX(purchase_month) AS last_activity_month
    FROM core.fct_order
    WHERE is_delivered
),
cohort_grid AS (
    SELECT
        cohorts.cohort_month,
        offsets.month_number,
        (cohorts.cohort_month + offsets.month_number * INTERVAL '1 month')::date
            AS activity_month,
        cohorts.cohort_size
    FROM cohort_sizes AS cohorts
    CROSS JOIN observation
    CROSS JOIN LATERAL GENERATE_SERIES(
        0,
        (
            (EXTRACT(YEAR FROM observation.last_activity_month) - EXTRACT(YEAR FROM cohorts.cohort_month)) * 12
            + EXTRACT(MONTH FROM observation.last_activity_month)
            - EXTRACT(MONTH FROM cohorts.cohort_month)
        )::integer
    ) AS offsets(month_number)
),
retained AS (
    SELECT
        cohort_month,
        months_since_first_order AS month_number,
        COUNT(DISTINCT customer_unique_id)::integer AS retained_customers
    FROM customer_activity
    GROUP BY cohort_month, months_since_first_order
)
SELECT
    grid.cohort_month,
    grid.month_number,
    grid.activity_month,
    grid.cohort_size,
    COALESCE(retained.retained_customers, 0)::integer AS retained_customers,
    (
        COALESCE(retained.retained_customers, 0)::numeric / grid.cohort_size
    )::numeric(12, 6) AS retention_rate
FROM cohort_grid AS grid
LEFT JOIN retained
    ON retained.cohort_month = grid.cohort_month
   AND retained.month_number = grid.month_number;

ALTER TABLE mart.cohort_retention
    ADD CONSTRAINT pk_cohort_retention PRIMARY KEY (cohort_month, month_number),
    ADD CONSTRAINT chk_retention_rate CHECK (retention_rate BETWEEN 0 AND 1);

CREATE TABLE mart.cohort_repeat_90d AS
SELECT
    cohort_month,
    COUNT(*) FILTER (WHERE has_full_90d_observation)::integer AS eligible_customer_count,
    COUNT(*) FILTER (
        WHERE has_full_90d_observation AND repeated_within_90d
    )::integer AS repeated_customer_count,
    (
        COUNT(*) FILTER (
            WHERE has_full_90d_observation AND repeated_within_90d
        )::numeric
        / NULLIF(COUNT(*) FILTER (WHERE has_full_90d_observation), 0)
    )::numeric(12, 6) AS repeat_rate_90d
FROM mart.customer_metrics
GROUP BY cohort_month
HAVING COUNT(*) FILTER (WHERE has_full_90d_observation) > 0;

ALTER TABLE mart.cohort_repeat_90d
    ADD CONSTRAINT pk_cohort_repeat_90d PRIMARY KEY (cohort_month),
    ADD CONSTRAINT chk_repeat_rate_90d CHECK (repeat_rate_90d BETWEEN 0 AND 1);

CREATE TABLE mart.rfm_customer_segments AS
WITH scored AS (
    SELECT
        metrics.*,
        LEAST(
            5,
            CEIL(CUME_DIST() OVER (ORDER BY recency_days DESC) * 5)
        )::smallint AS recency_score,
        CASE
            WHEN delivered_order_count = 1 THEN 1
            WHEN delivered_order_count = 2 THEN 3
            ELSE 5
        END::smallint AS frequency_score,
        LEAST(
            5,
            CEIL(CUME_DIST() OVER (ORDER BY lifetime_gmv) * 5)
        )::smallint AS monetary_score
    FROM mart.customer_metrics AS metrics
),
segmented AS (
    SELECT
        scored.*,
        CASE
            WHEN recency_score >= 4 AND frequency_score >= 3 AND monetary_score >= 4
                THEN 'champions'
            WHEN recency_score >= 3 AND frequency_score >= 3
                THEN 'loyal_repeat'
            WHEN recency_score = 5 AND frequency_score = 1 AND monetary_score >= 4
                THEN 'recent_high_value'
            WHEN recency_score >= 4 AND frequency_score = 1
                THEN 'new_or_potential'
            WHEN recency_score <= 2 AND (frequency_score >= 3 OR monetary_score >= 4)
                THEN 'at_risk_high_value'
            WHEN recency_score <= 2
                THEN 'hibernating'
            ELSE 'needs_attention'
        END AS rfm_segment
    FROM scored
)
SELECT
    customer_unique_id,
    rfm_snapshot_date,
    recency_days,
    delivered_order_count AS frequency,
    lifetime_gmv AS monetary,
    recency_score,
    frequency_score,
    monetary_score,
    rfm_segment
FROM segmented;

ALTER TABLE mart.rfm_customer_segments
    ADD CONSTRAINT pk_rfm_customer_segments PRIMARY KEY (customer_unique_id),
    ADD CONSTRAINT fk_rfm_customer_segments_customer FOREIGN KEY (customer_unique_id)
        REFERENCES core.dim_customer (customer_unique_id),
    ADD CONSTRAINT chk_rfm_recency_score CHECK (recency_score BETWEEN 1 AND 5),
    ADD CONSTRAINT chk_rfm_frequency_score CHECK (frequency_score IN (1, 3, 5)),
    ADD CONSTRAINT chk_rfm_monetary_score CHECK (monetary_score BETWEEN 1 AND 5);

CREATE INDEX idx_rfm_segment
    ON mart.rfm_customer_segments (rfm_segment);

COMMIT;
