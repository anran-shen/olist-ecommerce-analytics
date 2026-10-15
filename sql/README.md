# SQL workflow

PostgreSQL scripts are organized by execution layer:

1. `00_setup`
2. `01_staging`
3. `02_core`
4. `03_marts`
5. `04_analysis`
6. `05_quality`

Every modeled table must document its grain and key. Core financial metrics must be reconciled at order grain before dimensional joins.

## Stage 4 execution

The primary runtime is the local PostgreSQL 17 installation. After configuring the ignored `.env` file, run from the repository root:

```powershell
.\sql\run_stage_04.ps1
```

This bootstraps the project login/database, reloads all raw tables, creates typed staging views and runs the fail-fast quality suite. The raw load is transactional and repeatable.

## Stage 5 execution

After Stage 4 succeeds:

```powershell
.\sql\run_stage_05.ps1
```

This replaces the project-scoped core model and dependent performance marts, then reconciles item, order, payment and mart amounts in integer cents.

## Stage 6 execution

After Stage 5 succeeds:

```powershell
.\sql\run_stage_06.ps1
```

This builds exact month-over-month factor decompositions and category/state/seller contribution tables, validates all change reconciliations, and prints the diagnostic queries.

## Stage 7 execution

After Stage 6 succeeds:

```powershell
.\sql\run_stage_07.ps1
```

This builds customer-level repeat metrics, monthly cohort retention, fixed 90-day repeat rates and RFM segments. It then runs 11 customer-model assertions and prints the analysis outputs.

## Stage 8 execution

After Stage 7 succeeds:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\sql\run_stage_08.ps1
```

This builds and validates the one-row-per-order delivery-review mart, exports the analysis sample, runs the Python statistical workflow and executes its unit tests.

## Stage 9 planning input

Stage 9 introduces no fabricated experiment table. Its Python runner executes `04_analysis/05_ab_test_planning_inputs.sql` to export recent historical capacity, then combines that input with the Stage 8 baseline for sample-size and duration planning.
