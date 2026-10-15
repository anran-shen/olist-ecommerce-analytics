# Customer Retention and RFM Analysis

## 1. Executive summary

The delivered-order population contains **93,358 customers**, of whom **2,801** purchased more than once. The observed all-time repeat rate is therefore **3.00%**. Because customers acquired near the end of the dataset have had less time to return, the more comparable fixed-window measure uses only the **75,320 customers** with a complete 90-day observation period: **1,714** repeated within 90 days, a rate of **2.28%**.

Repeat customers generated **5.51% of delivered GMV** and **5,921 orders**. Their order-level AOV was lower than that of one-time customers (123.02 versus 137.96), but their average lifetime GMV was approximately **260.05 per customer**, compared with **137.96** for one-time customers. Historical GMV was therefore overwhelmingly acquisition- and one-time-customer-dependent, while the small repeat group was more valuable over its observed lifetime.

The median interval from first to second delivered order among customers who repeated was **28.98 days**. This supports testing a second-order intervention within the first month after purchase, while recognizing that the dataset cannot identify the marketing or category mechanisms behind a return purchase.

## 2. Definitions and observation boundary

Only delivered orders are included. Customer identity uses `customer_unique_id`; the order-level `customer_id` is not treated as a persistent person identifier.

| Measure | Definition |
|---|---|
| All-time repeat rate | Customers with at least two delivered orders divided by all delivered-order customers |
| 90-day repeat rate | Customers whose second delivered order occurs within 90 days of the first, divided by customers with a complete 90-day observation window |
| Cohort month | Calendar month of the customer's first delivered order |
| Month-N retention | Share of a cohort with at least one delivered purchase in calendar month N after its first-order month |
| Recency | Days from the RFM snapshot date to the customer's last delivered order |
| Frequency | Number of delivered orders over the observed customer lifetime |
| Monetary | Delivered product GMV over the observed customer lifetime, excluding freight |

The last delivered purchase timestamp is **2018-08-29 15:00:37**. The RFM snapshot is the following day, **2018-08-30**, so recency is non-negative. A customer is eligible for the 90-day metric only when the first order occurred no later than 90 days before the final observed timestamp.

The cohort table measures return activity, not subscription survival. A customer can be inactive in month 1 and return in month 2; consequently, later-month rates need not decrease monotonically.

## 3. Repeat purchase economics

| Customer type | Customers | Orders | Delivered GMV | Order AOV | Orders/customer | GMV share |
|---|---:|---:|---:|---:|---:|---:|
| Repeat | 2,801 | 5,921 | 728,408.75 | 123.02 | 2.1139 | 5.51% |
| One-time | 90,557 | 90,557 | 12,493,089.36 | 137.96 | 1.0000 | 94.49% |

The repeat group does not have a higher order value; its higher customer value comes from placing more orders. This distinction matters operationally: a retention initiative should primarily target second-order conversion rather than assume existing repeat customers buy larger baskets.

The low observed repeat rate should not automatically be labeled churn. Olist is a multi-category marketplace, and many categories may have naturally long or irregular repurchase cycles. The data contains no browsing, marketing-contact, cancellation-intent or competitor-purchase fields.

## 4. Cohort findings

For fully observed cohorts from January 2017 through May 2018, 90-day repeat rates range from **1.62% to 3.63%**. January 2017 is highest at 3.63%; May 2018 is 1.62%. There is no sustained improvement across cohorts, although the late observed cohorts are lower. This is descriptive evidence, not proof that customer quality deteriorated, because category mix, acquisition channel and campaign exposure are unavailable.

Month-1 purchase activity is also consistently low. Across cohorts with at least six months of observation, it generally ranges from about **0.18% to 0.72%**. Month-2 through month-6 rates remain mostly below 0.55%. The result reinforces the acquisition-dependent growth diagnosis from Stage 6: rapid customer growth did not translate into visibly stronger repeat activity within the available horizon.

Two retention outputs are kept because they answer different questions:

- `mart.cohort_retention` supports a month-by-month heatmap and shows when customers return.
- `mart.cohort_repeat_90d` provides a single fixed-window comparison that avoids giving recent cohorts less opportunity to repeat.

## 5. RFM methodology

RFM is scored as of 2018-08-30. Recency and monetary scores use tie-preserving `CUME_DIST()` ranks mapped to scores 1-5. High scores mean more recent or higher-value behavior.

Frequency is deliberately not divided into five arbitrary quantiles. With 90,557 of 93,358 customers having exactly one delivered order, quantile splitting would assign different scores to behaviorally identical customers. The project therefore uses:

- 1 order: frequency score 1;
- 2 orders: frequency score 3;
- 3 or more orders: frequency score 5.

This rule preserves the real distribution and makes the segmentation reproducible.

## 6. RFM segments and actions

| Segment | Customers | Customer share | Lifetime GMV | GMV share | Avg. recency | Avg. frequency | Avg. customer GMV |
|---|---:|---:|---:|---:|---:|---:|---:|
| At risk, high value | 14,866 | 15.92% | 4,055,071.89 | 30.67% | 395.47 | 1.0714 | 272.77 |
| New or potential | 29,109 | 31.18% | 3,180,437.18 | 24.06% | 102.42 | 1.0000 | 109.26 |
| Needs attention | 18,118 | 19.41% | 2,351,227.39 | 17.78% | 221.63 | 1.0000 | 129.77 |
| Recent high value | 7,236 | 7.75% | 1,921,240.53 | 14.53% | 47.29 | 1.0000 | 265.51 |
| Hibernating | 22,210 | 23.79% | 1,227,323.78 | 9.28% | 396.39 | 1.0000 | 55.26 |
| Champions | 941 | 1.01% | 307,543.11 | 2.33% | 90.21 | 2.1902 | 326.83 |
| Loyal repeat | 878 | 0.94% | 178,654.23 | 1.35% | 178.79 | 2.0695 | 203.48 |

Recommended treatments follow the segment definitions:

1. **At risk, high value:** prioritize a measured win-back offer because 15.92% of customers represent 30.67% of GMV. Separate prior repeat buyers from high-value one-time buyers in campaign reporting.
2. **Recent high value:** target second-order conversion shortly after delivery, with product-category cross-sell or replenishment messaging where appropriate.
3. **New or potential:** use onboarding, review requests and relevant cross-sell rather than broad discounting. This is the largest segment and therefore needs cost controls.
4. **Champions and loyal repeat:** protect experience quality and test loyalty or referral benefits. Their small size makes retention valuable but limits near-term topline impact.
5. **Hibernating:** use low-cost channels or suppress expensive incentives; their average observed customer GMV is only 55.26.
6. **Needs attention:** test selective re-engagement after prioritizing the higher-value at-risk group.

## 7. Quality controls and reproducibility

Stage 7 adds 11 fail-fast assertions covering:

- one row per delivered customer;
- reconciliation of customer frequency to delivered orders;
- reconciliation of customer monetary value to delivered GMV in integer cents;
- repeat and 90-day observation-flag consistency;
- cohort month-zero completeness and valid retention rates;
- complete RFM assignment, valid scores and monetary reconciliation.

Run the stage after the core model exists:

```powershell
.\sql\run_stage_07.ps1
```

The script rebuilds four marts, runs the checks and prints the portfolio, cohort and RFM analyses. It is transactional and repeatable.

## 8. Limitations

- Both lifetime and RFM values are right-censored by the dataset end date.
- The fixed 90-day rate improves cohort comparability but does not capture purchases after 90 days.
- Monthly retention is calendar-month activity, so customers near a month boundary have different exact elapsed time in month 1.
- RFM segments are prioritization rules, not causal or predictive models.
- No campaign, traffic, discount, margin or acquisition-channel data is available.
- Associations between segment membership and value do not establish that a proposed intervention will increase purchases; that requires an experiment.

