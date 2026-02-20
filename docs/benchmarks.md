# Benchmarks and Eval Gate

Ralph ships with a simple benchmark harness and regression gate.

## Files

- `benchmarks/run_eval.sh`: runs benchmark scenarios and saves JSON results.
- `benchmarks/compare.sh`: compares a benchmark run against baseline thresholds.
- `benchmarks/baseline.json`: baseline metrics and allowed regression thresholds.
- `benchmarks/scenarios.tsv`: scenario list (`task_id<TAB>command`).

## Run Benchmarks

```bash
benchmarks/run_eval.sh
```

Custom scenario/output:

```bash
benchmarks/run_eval.sh \
  --scenario benchmarks/scenarios.tsv \
  --output tasks/logs/benchmarks/manual-run.json
```

## Compare to Baseline

```bash
benchmarks/compare.sh benchmarks/baseline.json tasks/logs/benchmarks/<run>.json
```

Exit code:

- `0` => PASS (within thresholds),
- `1` => FAIL (regression beyond threshold).

## Thresholds

Configured in `benchmarks/baseline.json`:

- `success_rate_pp_drop`: max drop in percentage points.
- `median_duration_pct_increase`: max increase in median duration.
- `retry_rate_pct_increase`: max increase in retry rate.
