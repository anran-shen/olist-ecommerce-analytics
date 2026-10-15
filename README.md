# Olist E-commerce Analytics

An end-to-end data analytics portfolio project based on the public Olist Brazilian E-Commerce dataset.

The project uses PostgreSQL for data cleaning, dimensional modeling and metric marts; Python for statistical inference and experiment design; and Power BI for interactive reporting.

## Business scope

The analysis follows one connected business narrative:

1. Monitor GMV, orders, AOV and purchasing customers.
2. Diagnose changes through customer, product, geography and seller dimensions.
3. Measure cohort retention, repeat purchase and RFM customer segments.
4. Evaluate the relationship between delivery performance and review scores.
5. Design an A/B test for a selected business intervention.

Metric definitions and analytical boundaries are documented in [Business Requirements](docs/01_business_requirements.md).

## Technology

- PostgreSQL 17 (local installation; Docker Compose is an optional fallback)
- Python 3.11–3.13
- Power BI Desktop
- Git and GitHub

## Repository map

```text
.
├── data/                    # Local datasets and generated analytical exports
│   ├── raw/                 # Immutable source CSV files (not committed)
│   ├── interim/             # Temporary local outputs (not committed)
│   └── exports/             # Power BI/statistical datasets (not committed)
├── docs/                    # Requirements, dictionaries and project documentation
├── powerbi/                 # PBIX report, theme and portfolio screenshots
│   ├── screenshots/
│   └── theme/
├── python/
│   ├── notebooks/           # Narrative statistical analyses
│   ├── src/                 # Reusable Python modules
│   └── tests/               # Python tests
├── sql/
│   ├── 00_setup/            # Database schemas and extensions
│   ├── 01_staging/          # Raw loading and typed staging models
│   ├── 02_core/             # Cleaned facts and dimensions
│   ├── 03_marts/            # Business metric datasets
│   ├── 04_analysis/         # Diagnostic and customer analysis queries
│   └── 05_quality/          # Data quality and reconciliation checks
├── .env.example             # Safe environment-variable template
├── docker-compose.yml       # Optional containerized PostgreSQL 17 fallback
└── requirements.txt         # Python analysis dependencies
```

## Project status

- [x] Stage 1 — Business requirements and metric definitions
- [x] Stage 2 — Repository structure and environment design
- [x] Stage 3 — Dataset download, validation and data dictionary
- [x] Stage 4 — PostgreSQL loading, cleaning and quality checks
- [x] Stage 5 — Core models and metric marts
- [x] Stage 6 — Performance diagnosis
- [x] Stage 7 – Cohort, retention and RFM
- [x] Stage 8 – Statistical inference
- [x] Stage 9 – A/B test design
- [ ] Stage 10 — Power BI dashboard
- [ ] Stage 11 — Portfolio publishing review

Setup and execution commands will be added as their corresponding stages are completed.

## Current execution

With the local credentials configured in `.env`, reproduce the database loading and Stage 4 validation with:

```powershell
.\sql\run_stage_04.ps1
```

The current run uses PostgreSQL 17.11 and completes 39 fail-fast SQL assertions. See [Database Loading and Quality Checks](docs/04_database_loading_and_quality.md) for the results and design decisions.

Build the core star model and performance marts after Stage 4 with:

```powershell
.\sql\run_stage_05.ps1
```

The current model contains five dimensions, four facts and four performance marts, with 24 additional grain and financial-reconciliation assertions. See [Core Model and Performance Marts](docs/05_core_model_and_marts.md).

Build and reproduce the performance diagnosis with:

```powershell
.\sql\run_stage_06.ps1
```

The diagnosis uses exact symmetric KPI decomposition and dimension-level change contribution. See [Business Performance Diagnosis](docs/06_business_performance_diagnosis.md).

Build and reproduce the customer retention and RFM analysis with:

```powershell
.\sql\run_stage_07.ps1
```

The stage builds customer-level metrics, fixed-window repeat rates, a cohort activity matrix and tie-aware RFM segments, with 11 additional assertions. See [Customer Retention and RFM Analysis](docs/07_customer_retention_and_rfm.md).

Build the delivery-review sample and reproduce the statistical analysis with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\sql\run_stage_08.ps1
```

The stage reports descriptive statistics, confidence intervals, Welch and Mann-Whitney tests, effect sizes, correlation and robustness checks. See [Delivery and Review Statistical Analysis](docs/08_delivery_review_statistical_analysis.md).

Reproduce the A/B test sample-size and feasibility analysis with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\python\run_stage_09.ps1
```

The design specifies customer-level randomization, a low-review primary metric, guardrails, MDE, power, enrollment scenarios and joint statistical/business decision rules. See [A/B Test Design](docs/09_ab_test_design.md).
