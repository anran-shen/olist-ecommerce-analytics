\set ON_ERROR_STOP on

BEGIN;

DROP TABLE IF EXISTS mart.delivery_review_orders;

CREATE TABLE mart.delivery_review_orders AS
SELECT
    orders.order_id,
    orders.customer_unique_id,
    orders.purchase_date,
    orders.purchase_month,
    orders.customer_state,
    orders.delivery_days,
    (
        EXTRACT(EPOCH FROM (
            orders.delivered_customer_timestamp - orders.estimated_delivery_timestamp
        )) / 86400
    )::numeric(12, 6) AS days_vs_estimate,
    orders.is_late_delivery,
    orders.latest_review_score AS review_score,
    orders.item_count,
    orders.product_gmv,
    orders.freight_value
FROM core.fct_order AS orders
WHERE orders.is_delivered
  AND orders.delivered_customer_timestamp IS NOT NULL
  AND orders.estimated_delivery_timestamp IS NOT NULL
  AND orders.latest_review_score IS NOT NULL;

ALTER TABLE mart.delivery_review_orders
    ADD CONSTRAINT pk_delivery_review_orders PRIMARY KEY (order_id),
    ADD CONSTRAINT fk_delivery_review_customer FOREIGN KEY (customer_unique_id)
        REFERENCES core.dim_customer (customer_unique_id),
    ADD CONSTRAINT chk_delivery_days_nonnegative CHECK (delivery_days >= 0),
    ADD CONSTRAINT chk_delivery_review_score CHECK (review_score BETWEEN 1 AND 5),
    ADD CONSTRAINT chk_delivery_late_consistency CHECK (
        is_late_delivery = (days_vs_estimate > 0)
    );

CREATE INDEX idx_delivery_review_late
    ON mart.delivery_review_orders (is_late_delivery);
CREATE INDEX idx_delivery_review_month_state
    ON mart.delivery_review_orders (purchase_month, customer_state);

COMMIT;
