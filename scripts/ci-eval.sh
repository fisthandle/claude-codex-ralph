#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
BASELINE_FILE="${BASELINE_FILE:-$ROOT_DIR/benchmarks/baseline.json}"
SCENARIO_FILE="${SCENARIO_FILE:-$ROOT_DIR/benchmarks/scenarios.tsv}"

result_file="$("$ROOT_DIR/benchmarks/run_eval.sh" --scenario "$SCENARIO_FILE")"
"$ROOT_DIR/benchmarks/compare.sh" "$BASELINE_FILE" "$result_file"
