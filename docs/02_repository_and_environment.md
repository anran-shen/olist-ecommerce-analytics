# Repository Structure and Environment

## 1. Architecture decision

This project separates responsibilities by tool:

| Layer | Tool | Responsibility |
|---|---|---|
| Storage and transformation | PostgreSQL 17 | Load source CSVs, clean data, enforce grain, build facts/dimensions and analytical marts |
| Statistical analysis | Python | Confidence intervals, hypothesis tests, effect sizes, correlations and experiment sample-size calculations |
| Business intelligence | Power BI Desktop | Semantic model, DAX measures, filters, drill-through and portfolio-ready dashboards |
| Version control | Git/GitHub | SQL, Python, documentation, configuration and dashboard screenshots |

SQL remains the source of truth for business metrics. Python and Power BI consume modeled tables or explicit exports instead of independently redefining metric logic.

## 2. PostgreSQL runtime choice

- PostgreSQL provides the joins, CTEs, window functions, date functions and analytical SQL required by the portfolio scope.
- The primary development runtime is the existing local PostgreSQL 17.11 installation.
- A project-specific `olist` login and `olist_ecommerce` database isolate the portfolio project from administrator and unrelated databases.
- Database credentials stay in a local `.env` file that Git ignores.
- Docker Compose remains an optional PostgreSQL 17 fallback for reviewers who do not have PostgreSQL installed.

## 3. Directory responsibilities

### `data/`

- `raw/`: original Kaggle CSVs, kept unchanged after download.
- `interim/`: disposable intermediate files generated during validation or exploration.
- `exports/`: reproducible datasets exported from SQL for Python or Power BI when a direct connection is not used.

Dataset files are intentionally excluded from Git. Only `.gitkeep` placeholders and documentation are committed.

### `sql/`

SQL scripts use numeric prefixes within each layer so execution order is explicit:

- `00_setup`: database schemas and shared helpers.
- `01_staging`: raw table definitions, imports and typed staging views/tables.
- `02_core`: cleaned order-level fact tables and conformed dimensions.
- `03_marts`: reusable KPI, cohort, RFM and delivery marts.
- `04_analysis`: business questions, trend decomposition and drill-down queries.
- `05_quality`: uniqueness, null, referential-integrity and financial reconciliation tests.

### `python/`

- `notebooks/`: readable analysis narrative and displayed results.
- `src/`: reusable loading, statistics, plotting and experiment-design functions.
- `tests/`: unit tests for reusable calculations.

Complex logic should live in `src`; notebooks should orchestrate functions and explain decisions rather than contain duplicated utility code.

### `powerbi/`

- The report file will live directly under `powerbi/` if its size is suitable for GitHub.
- `screenshots/` contains compressed images visible from the root README.
- `theme/` contains the report theme as version-controlled JSON.

Because PBIX is a binary format, important DAX measures, Power Query logic and data-model documentation will also be exported to text-based documentation where practical.

### `docs/`

Numbered documents follow the project workflow: requirements, environment, data dictionary, model, metric dictionary, analysis findings and experiment design.

## 4. Local environment observed on 2026-09-26

| Component | Status |
|---|---|
| Git | Available: 2.51.1 |
| Python | Available through `python`: 3.13.1 |
| pip | Available: 24.3.1 |
| Windows `py` launcher | Points to legacy Python 2.7; do not use for this project |
| Docker CLI | Available: 29.5.3 |
| Docker daemon | Not running during the check |
| Host `psql` | PostgreSQL 17.11 at `D:\PostgreSQL\17\bin\psql.exe`; not on `PATH` |
| Kaggle CLI | Not installed |
| Power BI Desktop | Not found in the standard executable paths; verify manually before the dashboard stage |

## 5. Planned local setup

The project uses the explicit PostgreSQL 17 client path, so it does not depend on the system `PATH`.

```powershell
Copy-Item .env.example .env
# Fill the local PostgreSQL credentials in .env.

python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt

.\sql\run_stage_04.ps1
```

Use `python`, not `py`, on this machine. Do not commit `.env`, the virtual environment, database files or downloaded source CSVs.

## 6. Reproducibility rules

- Preserve raw files unchanged and validate names, sizes, row counts and hashes after download.
- Execute SQL in numeric directory and filename order.
- Store every core metric definition in SQL and document it in the metric dictionary.
- Keep secrets and machine-specific paths out of committed files.
- Pin the resolved Python environment after dependencies have been installed and tested.
- Commit Power BI screenshots and textual model documentation even if the PBIX exceeds GitHub's practical size limit.
