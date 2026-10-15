# DAX measure catalog

Create a dedicated `_Measures` table and place these measures in it. Hide the placeholder column.

## Executive metrics

```DAX
GMV =
CALCULATE(
    SUM('PBI Orders'[product_gmv]),
    'PBI Orders'[is_delivered] = TRUE()
)

Delivered Orders =
CALCULATE(
    DISTINCTCOUNT('PBI Orders'[order_id]),
    'PBI Orders'[is_delivered] = TRUE()
)

Purchasing Customers =
CALCULATE(
    DISTINCTCOUNT('PBI Orders'[customer_unique_id]),
    'PBI Orders'[is_delivered] = TRUE()
)

AOV = DIVIDE([GMV], [Delivered Orders])

Items per Order =
DIVIDE(
    CALCULATE(SUM('PBI Orders'[item_count]), 'PBI Orders'[is_delivered] = TRUE()),
    [Delivered Orders]
)

Freight Value =
CALCULATE(
    SUM('PBI Orders'[freight_value]),
    'PBI Orders'[is_delivered] = TRUE()
)
```

## Product and seller diagnostics

These measures use the item-grain table. Do not sum order-level GMV through this table.

```DAX
Item GMV =
CALCULATE(
    SUM('PBI Order Items'[price]),
    'PBI Order Items'[is_delivered] = TRUE()
)

Category Orders =
CALCULATE(
    DISTINCTCOUNT('PBI Order Items'[order_id]),
    'PBI Order Items'[is_delivered] = TRUE()
)

Item Count =
CALCULATE(
    COUNTROWS('PBI Order Items'),
    'PBI Order Items'[is_delivered] = TRUE()
)

Category GMV Share =
DIVIDE(
    [Item GMV],
    CALCULATE([Item GMV], REMOVEFILTERS('PBI Order Items'[product_category_display]))
)
```

## Customer metrics

```DAX
Delivered Customers = DISTINCTCOUNT('PBI Customers'[customer_unique_id])

Repeat Customers =
CALCULATE(
    [Delivered Customers],
    'PBI Customers'[is_repeat_customer] = TRUE()
)

All-time Repeat Rate = DIVIDE([Repeat Customers], [Delivered Customers])

Eligible 90D Customers =
CALCULATE(
    [Delivered Customers],
    'PBI Customers'[has_full_90d_observation] = TRUE()
)

Repeated within 90D =
CALCULATE(
    [Delivered Customers],
    'PBI Customers'[repeated_within_90d] = TRUE()
)

90D Repeat Rate = DIVIDE([Repeated within 90D], [Eligible 90D Customers])

Customer Lifetime GMV = SUM('PBI Customers'[lifetime_gmv])

RFM Customer Share =
DIVIDE(
    [Delivered Customers],
    CALCULATE([Delivered Customers], REMOVEFILTERS('PBI Customers'[rfm_segment]))
)
```

## Delivery and review metrics

```DAX
Delivery-Eligible Orders =
CALCULATE(
    DISTINCTCOUNT('PBI Orders'[order_id]),
    'PBI Orders'[is_delivered] = TRUE(),
    NOT ISBLANK('PBI Orders'[is_late_delivery])
)

Late Orders =
CALCULATE(
    DISTINCTCOUNT('PBI Orders'[order_id]),
    'PBI Orders'[is_delivered] = TRUE(),
    'PBI Orders'[is_late_delivery] = TRUE()
)

Late Rate = DIVIDE([Late Orders], [Delivery-Eligible Orders])

Reviewed Orders =
CALCULATE(
    DISTINCTCOUNT('PBI Orders'[order_id]),
    NOT ISBLANK('PBI Orders'[review_score])
)

Average Review Score = AVERAGE('PBI Orders'[review_score])

Low Review Orders =
CALCULATE(
    DISTINCTCOUNT('PBI Orders'[order_id]),
    'PBI Orders'[is_low_review] = TRUE()
)

Low Review Rate = DIVIDE([Low Review Orders], [Reviewed Orders])

Average Delivery Days = AVERAGE('PBI Orders'[delivery_days])
```

## Display and context helpers

```DAX
Data Through =
"Data through " & FORMAT(MAX('PBI Orders'[purchase_date]), "yyyy-MM-dd")

Selected Period =
VAR StartDate = MIN('Date'[date_key])
VAR EndDate = MAX('Date'[date_key])
RETURN FORMAT(StartDate, "yyyy-MM-dd") & " to " & FORMAT(EndDate, "yyyy-MM-dd")
```

Format currency measures as Brazilian real or neutral currency units consistently. Format rates as percentages with one or two decimal places.

