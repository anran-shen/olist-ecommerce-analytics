# Python workflow

Python is reserved for statistical inference, supporting visualization and A/B test design. Business metric transformations remain in PostgreSQL.

- `src/statistical_utils.py`: reusable confidence-interval, test and effect-size functions.
- `src/run_statistical_analysis.py`: reproducible Stage 8 analysis entry point.
- `src/experiment_utils.py`: reusable effect-size, sample-size and duration functions.
- `src/design_ab_test.py`: reproducible Stage 9 experiment-planning entry point.
- `tests/`: standard-library unit tests for reusable statistical logic.
- `outputs/`: versioned machine-readable results and portfolio figures.
- `notebooks/`: optional exploratory presentation; the production workflow does not depend on notebook state.

The preferred entry point is the project runner:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\sql\run_stage_08.ps1
```

To run only the tests:

```powershell
python -m unittest discover -s python/tests -p "test_*.py" -v
```

Generate the Stage 9 experiment design after Stage 8:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\python\run_stage_09.ps1
```
