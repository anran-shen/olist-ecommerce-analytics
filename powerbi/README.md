# Power BI workspace

The dashboard consumes validated PostgreSQL marts or reproducible CSV exports. It does not rebuild raw-data cleaning logic independently.

- `model_and_pages.md`: connection, relationships, page layouts and interaction rules.
- `dax_measures.md`: copy-ready measure definitions and formatting guidance.
- `theme/olist_portfolio_theme.json`: importable report theme.
- `screenshots/`: final portfolio page captures.

Prepare the views and fallback exports from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\sql\run_stage_10.ps1
```

Power BI Desktop is required to create and visually validate the PBIP/PBIX report.
