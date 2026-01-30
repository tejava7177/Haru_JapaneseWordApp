# Data Pipeline

## Run
```bash
python3 scripts/build_dictionary.py
```

## Notes
- Inputs: `input/n5.csv`, `input/n4.csv`, `input/JMdict_e.xml` (gitignored, local only)
- Outputs: `input/jlpt_n5.csv`, `input/jlpt_n4.csv`, `output/jlpt_starter.sqlite`, `output/coverage_report.json`
- Optional override: `input/kor_override.csv` (auto-created if missing)

## Validate (optional)
```bash
python3 scripts/validate_inputs.py
```
