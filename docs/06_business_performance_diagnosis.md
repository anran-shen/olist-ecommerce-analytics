# Business Performance Diagnosis

## 1. Executive summary

The comparable trend window is January 2017 through August 2018. The earlier 2016 records are a sparse pilot period, while September–October 2018 contain no delivered orders. Treating all timestamp-bounded months as complete would create misleading growth rates.

Within equal January–August coverage, 2018 GMV increased **141.13%** year over year. This growth was almost entirely volume-led:

- orders increased **139.94%**;
- purchasing customers increased **141.13%**;
- AOV increased only **0.49%**;
- monthly purchase frequency decreased slightly rather than driving growth.

The clearest short-term events are the November 2017 spike, the December reversal, and the June–August 2018 slowdown. Each has a different factor mix and should not receive the same business response.

## 2. Scope and methodology

Only delivered orders are included in GMV and operating KPI calculations. GMV excludes freight.

### Comparable coverage

The raw purchase timestamps span September 2016–October 2018, but delivered-order counts reveal discontinuous coverage:

- September 2016: 1 delivered order;
- November 2016: 0;
- December 2016: 1;
- September and October 2018: 0.

The analytical comparison flag is therefore explicitly limited to `2017-01` through `2018-08`. The first eligible month has no MoM rate because its preceding month is not comparable.

### Exact change decomposition

GMV is decomposed through:

```text
GMV = order count × AOV
AOV = items per order × average item price
order count = purchasing customers × orders per customer
```

The SQL uses symmetric two-period decomposition:

```text
ΔGMV = Δorders × average(AOV) + ΔAOV × average(orders)
ΔAOV = Δitems/order × average(item price)
     + Δitem price × average(items/order)
```

All calculations use unrounded ratios. Six automated assertions confirm that factor and category/state/seller contributions reconcile to the exact monthly GMV change in cents.

## 3. Long-term growth: acquisition scale, not monetization

Equal January–August periods show:

| Metric | 2017 Jan–Aug | 2018 Jan–Aug | Change |
|---|---:|---:|---:|
| GMV | 2,993,456.13 | 7,218,125.12 | +141.13% |
| Orders | 21,998 | 52,783 | +139.94% |
| Purchasing customers | 21,404 | 51,612 | +141.13% |
| AOV | 136.08 | 136.75 | +0.49% |
| Orders per customer | 1.0278 | 1.0227 | −0.49% |
| Items per order | 1.1339 | 1.1429 | +0.79% |
| Average item price | 120.01 | 119.66 | −0.30% |

Interpretation:

- Customer and order growth explain the expansion; neither price nor basket size materially increased.
- Monthly orders per customer stayed close to one and declined slightly. This does not prove weak lifetime retention, but it makes retention the appropriate next diagnostic.
- AOV stability means topline growth is exposed to any slowdown in customer acquisition or order volume.

The largest Jan–Aug category growth contributions came from `health_beauty` (+512,202.80), `watches_gifts` (+486,717.34), `sports_leisure` (+300,441.93), `computers_accessories` (+281,638.03) and `bed_bath_table` (+277,914.03).

Geographically, São Paulo contributed +1,840,066.51, followed by Minas Gerais (+508,202.88) and Rio de Janeiro (+447,026.98). This shows where growth occurred, not which region caused it.

## 4. November 2017 spike

GMV rose from 648,247.65 to 987,765.37, an increase of **52.37%** or **339,517.72**.

### Factor decomposition

| Driver | GMV contribution |
|---|---:|
| Order volume | +393,929.73 |
| Basket size | −1,167.89 |
| Average item price | −53,244.12 |
| **Net change** | **+339,517.72** |

Orders increased by 2,811, while AOV fell from 144.76 to 135.51. Of the order increase, the customer-count component contributed 2,805.51 orders and monthly purchase frequency only 5.49. The spike was therefore driven by many more purchasing customers, not higher spend or more frequent purchasing.

The five largest positive category contributions totaled 171,311.42, or 50.46% of the net increase: `bed_bath_table`, `health_beauty`, `furniture_decor`, `watches_gifts` and `toys`.

SP, RJ and MG together contributed 69.29% of the net increase. The five largest seller contributions totaled only 16.21%, so the event was not dependent on one or two sellers. This pattern is consistent with a broad seasonal/promotional demand event, but the dataset contains no campaign field and cannot establish that cause.

## 5. December 2017 reversal

GMV fell **26.50%**, from 987,765.37 to 726,033.19, a decrease of 261,732.18.

| Driver | GMV contribution |
|---|---:|
| Order volume | −237,281.84 |
| Basket size | −30,283.90 |
| Average item price | +5,833.57 |
| **Net change** | **−261,732.18** |

The reversal was mainly a 1,776-order volume contraction. Customer count explained 1,755.80 of that order decline. The five largest negative category contributions represented 55.42% of the decline, led by `bed_bath_table`, `computers_accessories`, `furniture_decor`, `watches_gifts` and `cool_stuff`.

SP, MG and RJ represented 58.42% of the net decline. The overlap with November's strongest regions and categories supports a post-spike normalization hypothesis, not evidence of a permanent structural decline.

## 6. June–August 2018 slowdown

After near-flat GMV in April and May, June declined 12.43%, July recovered only 1.39%, and August declined 3.38%.

### June

June GMV fell 121,466.83:

- order volume: −92,692.12;
- average item price: −22,547.69;
- basket size: −6,227.01.

The largest negative category contribution was `watches_gifts` (−34,337.41), followed by `garden_tools` and `sports_leisure`. SP alone contributed −84,031.42 of the net change, while RJ contributed −23,978.21. Positive offsets in other states mean these contribution shares should not be interpreted as market shares.

### August

August is a different diagnosis: orders increased by 192, contributing +26,204.44 to GMV, but average item price contributed −51,043.90 and basket size −4,537.36. The result was a net decline of 29,376.82.

`watches_gifts` contributed −25,397.73, equivalent to 86.46% of the net decline before positive category offsets. August should therefore be investigated as a category mix/price issue rather than a broad demand-volume problem.

## 7. Seller concentration

Across delivered GMV:

| Seller group | GMV share |
|---|---:|
| Top 1 | 1.72% |
| Top 10 | 13.27% |
| Top 100 | 45.52% |

The platform is not dependent on a single dominant seller. Seller-level monitoring remains useful, but the major monthly movements are broader than one seller account.

## 8. Recommended actions

1. **Separate acquisition from retention.** Customer acquisition drove historical scale, while monthly frequency did not improve. Proceed to cohort, repeat-purchase and RFM analysis before increasing acquisition spend.
2. **Plan for the November–December cycle.** Prepare capacity for a broad November surge and design post-purchase retention activity to reduce the December falloff. An A/B test can later assess the retention intervention.
3. **Investigate product mix in August.** Review availability, seller participation and price distribution for `watches_gifts` and other high-value declining categories. The data supports a mix/price diagnosis, not a confirmed pricing cause.
4. **Monitor regional concentration.** SP drives a large part of both growth and contraction. Use absolute contribution together with within-state growth rates so large regions do not automatically dominate every prioritization.
5. **Use moving averages for management reporting.** Monthly promotional volatility is large; the three-month GMV average better separates the underlying trajectory from one-month spikes.

## 9. Limitations

- No traffic, campaign, promotion, inventory or discount fields are available, so operational causes remain hypotheses.
- GMV is product value on delivered orders, not profit or cash revenue.
- Category/state contributions are accounting decompositions, not causal effects.
- Monthly customer counts cannot replace lifetime retention analysis.
- Contribution shares can exceed 100% when positive and negative dimension members offset each other.

