\set ON_ERROR_STOP on

-- Dimension and fact grains.
SELECT qa.assert_equal('dim_date row count', COUNT(*),
    (SELECT MAX(purchase_date) - MIN(purchase_date) + 1 FROM core.fct_order)
) FROM core.dim_date;
SELECT qa.assert_equal('dim_customer row count', COUNT(*), 96096) FROM core.dim_customer;
SELECT qa.assert_equal('dim_product row count', COUNT(*), 32951) FROM core.dim_product;
SELECT qa.assert_equal('dim_seller row count', COUNT(*), 3095) FROM core.dim_seller;
SELECT qa.assert_equal('dim_geolocation row count', COUNT(*), 19015) FROM core.dim_geolocation;
SELECT qa.assert_equal('fct_order row count', COUNT(*), 99441) FROM core.fct_order;
SELECT qa.assert_equal('fct_order_item row count', COUNT(*), 112650) FROM core.fct_order_item;
SELECT qa.assert_equal('fct_payment row count', COUNT(*), 103886) FROM core.fct_payment;
SELECT qa.assert_equal('fct_review row count', COUNT(*), 99224) FROM core.fct_review;

-- One selected latest review per reviewed order.
SELECT qa.assert_equal('latest review rows', COUNT(*), 98673)
FROM core.fct_review
WHERE latest_review_rank = 1;

-- Money reconciliations are compared in integer cents.
SELECT qa.assert_equal(
    'item GMV staging to item fact cents',
    (SELECT ROUND(SUM(price) * 100)::bigint FROM staging.stg_order_items),
    (SELECT ROUND(SUM(price) * 100)::bigint FROM core.fct_order_item)
);
SELECT qa.assert_equal(
    'item GMV item fact to order fact cents',
    (SELECT ROUND(SUM(price) * 100)::bigint FROM core.fct_order_item),
    (SELECT ROUND(SUM(product_gmv) * 100)::bigint FROM core.fct_order)
);
SELECT qa.assert_equal(
    'freight item fact to order fact cents',
    (SELECT ROUND(SUM(freight_value) * 100)::bigint FROM core.fct_order_item),
    (SELECT ROUND(SUM(freight_value) * 100)::bigint FROM core.fct_order)
);
SELECT qa.assert_equal(
    'payment fact to order fact cents',
    (SELECT ROUND(SUM(payment_value) * 100)::bigint FROM core.fct_payment),
    (SELECT ROUND(SUM(payment_value) * 100)::bigint FROM core.fct_order)
);

-- Known optional child coverage.
SELECT qa.assert_equal('orders without item rows', COUNT(*), 775)
FROM core.fct_order WHERE item_count IS NULL;
SELECT qa.assert_equal('orders without payment rows', COUNT(*), 1)
FROM core.fct_order WHERE payment_record_count IS NULL;
SELECT qa.assert_equal('orders without review rows', COUNT(*), 768)
FROM core.fct_order WHERE review_record_count IS NULL;

-- Mart reconciliation for delivered orders only.
SELECT qa.assert_equal(
    'monthly mart delivered GMV cents',
    (SELECT ROUND(SUM(gmv) * 100)::bigint FROM mart.monthly_business_kpis),
    (SELECT ROUND(SUM(product_gmv) * 100)::bigint FROM core.fct_order WHERE is_delivered)
);
SELECT qa.assert_equal(
    'category mart delivered GMV cents',
    (SELECT ROUND(SUM(gmv) * 100)::bigint FROM mart.monthly_category_kpis),
    (
        SELECT ROUND(SUM(items.price) * 100)::bigint
        FROM core.fct_order_item AS items
        INNER JOIN core.fct_order AS orders USING (order_id)
        WHERE orders.is_delivered
    )
);
SELECT qa.assert_equal(
    'state mart delivered GMV cents',
    (SELECT ROUND(SUM(gmv) * 100)::bigint FROM mart.monthly_customer_state_kpis),
    (SELECT ROUND(SUM(product_gmv) * 100)::bigint FROM core.fct_order WHERE is_delivered)
);
SELECT qa.assert_equal(
    'seller mart delivered GMV cents',
    (SELECT ROUND(SUM(gmv) * 100)::bigint FROM mart.monthly_seller_kpis),
    (
        SELECT ROUND(SUM(items.price) * 100)::bigint
        FROM core.fct_order_item AS items
        INNER JOIN core.fct_order AS orders USING (order_id)
        WHERE orders.is_delivered
    )
);

-- Boundary months must be flagged as incomplete.
SELECT qa.assert_equal('complete-month flags on boundary months', COUNT(*), 0)
FROM mart.monthly_business_kpis
WHERE is_complete_month
  AND purchase_month IN (
      (SELECT MIN(purchase_month) FROM core.fct_order),
      (SELECT MAX(purchase_month) FROM core.fct_order)
  );

SELECT qa.assert_equal('analysis-eligible month count', COUNT(*), 20)
FROM mart.monthly_business_kpis
WHERE is_complete_month;

SELECT qa.assert_equal('first eligible month has no MoM comparison', COUNT(*), 0)
FROM mart.monthly_business_kpis
WHERE purchase_month = DATE '2017-01-01'
  AND gmv_mom_rate IS NOT NULL;
