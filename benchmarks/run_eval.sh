#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SCENARIO_FILE="$ROOT_DIR/benchmarks/scenarios.tsv"
OUT_DIR="$ROOT_DIR/tasks/logs/benchmarks"
OUT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scenario)
      SCENARIO_FILE="${2:-$SCENARIO_FILE}"
      shift 2
      ;;
    --output)
      OUT_FILE="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

if [[ ! -f "$SCENARIO_FILE" ]]; then
  echo "Scenario file not found: $SCENARIO_FILE" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
run_id="$(date +%Y%m%d-%H%M%S)"
if [[ -z "$OUT_FILE" ]]; then
  OUT_FILE="$OUT_DIR/${run_id}.json"
fi

infer_failure_class() {
  local log_file="$1"
  if grep -Eqi 'ETIMEDOUT|ECONNRESET|ENOTFOUND|timed out|timeout|rate limit|429|service unavailable|network' "$log_file"; then
    echo "infra_network"
    return 0
  fi
  if grep -Eqi 'lint|phpstan|eslint|flake8|pylint|style check|format check' "$log_file"; then
    echo "lint_failure"
    return 0
  fi
  if grep -Eqi 'tests? failed|test suite failed|assertion|FAILURES!|failing test|\\bFAILED\\b|\\bfail\\b' "$log_file"; then
    echo "test_failure"
    return 0
  fi
  echo "unknown"
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

objects=()
while IFS=$'\t' read -r task_id command; do
  [[ -z "${task_id// }" ]] && continue
  [[ "$task_id" =~ ^# ]] && continue
  [[ -z "${command// }" ]] && continue

  log_file="$(mktemp)"
  started_epoch="$(date +%s)"
  set +e
  bash -lc "$command" > "$log_file" 2>&1
  exit_code=$?
  set -e
  finished_epoch="$(date +%s)"
  duration_seconds=$((finished_epoch - started_epoch))
  test_seconds="$(grep -Eo 'RALPH_TEST_SECONDS=[0-9]+' "$log_file" | tail -n 1 | cut -d= -f2 || true)"
  [[ -z "$test_seconds" ]] && test_seconds=0

  if [[ "$exit_code" -eq 0 ]]; then
    success=true
    failure_class="none"
  else
    success=false
    failure_class="$(infer_failure_class "$log_file")"
  fi

  escaped_task_id="$(json_escape "$task_id")"
  escaped_command="$(json_escape "$command")"
  objects+=("{\"run_id\":\"$run_id\",\"task_id\":\"$escaped_task_id\",\"command\":\"$escaped_command\",\"success\":$success,\"failure_class\":\"$failure_class\",\"duration_seconds\":$duration_seconds,\"test_seconds\":$test_seconds,\"retry_count\":0}")
  rm -f "$log_file"
done < "$SCENARIO_FILE"

{
  echo "["
  for i in "${!objects[@]}"; do
    if [[ "$i" -lt $((${#objects[@]} - 1)) ]]; then
      echo "  ${objects[$i]},"
    else
      echo "  ${objects[$i]}"
    fi
  done
  echo "]"
} > "$OUT_FILE"

echo "$OUT_FILE"
