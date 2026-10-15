# Data workspace

This directory stores local data only. The Olist source CSV files and generated exports are excluded from Git.

- `raw/`: immutable files obtained from the official dataset source.
- `interim/`: temporary validation and transformation outputs.
- `exports/`: reproducible SQL exports consumed by Python or Power BI.

Download instructions, expected filenames, checksums and the full data dictionary are documented in [`docs/03_data_source_and_dictionary.md`](../docs/03_data_source_and_dictionary.md).

Run the standard-library validator from the repository root:

```powershell
python python\src\validate_raw_data.py
```

The current expected result is 9 CSV files and a passing validation report. Do not edit files under `raw/`; apply cleaning rules in SQL staging/core models.

