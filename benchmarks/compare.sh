#!/usr/bin/env bash
set -euo pipefail

BASELINE_FILE="${1:-}"
CURRENT_FILE="${2:-}"

if [[ -z "$BASELINE_FILE" || -z "$CURRENT_FILE" ]]; then
  echo "Usage: benchmarks/compare.sh <baseline.json> <current_eval.json>" >&2
  exit 2
fi
if [[ ! -f "$BASELINE_FILE" ]]; then
  echo "Baseline not found: $BASELINE_FILE" >&2
  exit 1
fi
if [[ ! -f "$CURRENT_FILE" ]]; then
  echo "Current eval not found: $CURRENT_FILE" >&2
  exit 1
fi

extract_baseline_number() {
  local key="$1"
  grep -E "\"$key\"" "$BASELINE_FILE" | head -n 1 | grep -Eo '[0-9]+([.][0-9]+)?' | head -n 1
}

median_from_file_key() {
  local key="$1"
  local values
  values="$(grep -Eo "\"$key\":[[:space:]]*[0-9]+" "$CURRENT_FILE" | grep -Eo '[0-9]+' || true)"
  if [[ -z "$values" ]]; then
    echo "0"
    return 0
  fi
  printf '%s\n' "$values" | sort -n | awk '
    { a[NR]=$1 }
    END {
      if (NR == 0) { print 0; exit }
      if (NR % 2 == 1) { print a[(NR+1)/2]; exit }
      print int((a[NR/2] + a[NR/2+1]) / 2)
    }'
}

total_runs="$(grep -c '"task_id"' "$CURRENT_FILE" || true)"
if [[ "$total_runs" -eq 0 ]]; then
  echo "No tasks found in current eval: $CURRENT_FILE" >&2
  exit 1
fi
success_runs="$(grep -Ec '"success":[[:space:]]*true' "$CURRENT_FILE" || true)"
retry_total="$(grep -Eo '"retry_count":[[:space:]]*[0-9]+' "$CURRENT_FILE" | grep -Eo '[0-9]+' | awk '{s+=$1} END{print s+0}')"

current_success_rate="$(awk -v s="$success_runs" -v t="$total_runs" 'BEGIN { printf "%.6f", (t==0 ? 0 : s/t) }')"
current_retry_rate="$(awk -v r="$retry_total" -v t="$total_runs" 'BEGIN { printf "%.6f", (t==0 ? 0 : r/t) }')"
current_median_duration="$(median_from_file_key "duration_seconds")"
current_median_test="$(median_from_file_key "test_seconds")"

baseline_success_rate="$(extract_baseline_number "success_rate")"
baseline_median_duration="$(extract_baseline_number "median_duration_seconds")"
baseline_median_test="$(extract_baseline_number "median_test_seconds")"
baseline_retry_rate="$(extract_baseline_number "retry_rate")"
threshold_success_pp="$(extract_baseline_number "success_rate_pp_drop")"
threshold_duration_pct="$(extract_baseline_number "median_duration_pct_increase")"
threshold_retry_pct="$(extract_baseline_number "retry_rate_pct_increase")"

success_drop_pp="$(awk -v b="$baseline_success_rate" -v c="$current_success_rate" 'BEGIN { printf "%.4f", (b-c)*100 }')"
duration_increase_pct="$(awk -v b="$baseline_median_duration" -v c="$current_median_duration" 'BEGIN { if (b==0) print 0; else printf "%.4f", ((c-b)/b)*100 }')"
retry_increase_pct="$(awk -v b="$baseline_retry_rate" -v c="$current_retry_rate" 'BEGIN { if (b==0) { if (c==0) print 0; else print 999999; } else printf "%.4f", ((c-b)/b)*100 }')"

echo "Current metrics:"
echo "  success_rate=$current_success_rate"
echo "  median_duration_seconds=$current_median_duration"
echo "  median_test_seconds=$current_median_test"
echo "  retry_rate=$current_retry_rate"
echo
echo "Deltas vs baseline:"
echo "  success_drop_pp=$success_drop_pp (max $threshold_success_pp)"
echo "  duration_increase_pct=$duration_increase_pct (max $threshold_duration_pct)"
echo "  retry_increase_pct=$retry_increase_pct (max $threshold_retry_pct)"

pass=1
if awk -v v="$success_drop_pp" -v t="$threshold_success_pp" 'BEGIN { exit !(v <= t) }'; then :; else
  echo "Gate failed: success rate drop too high" >&2
  pass=0
fi
if awk -v v="$duration_increase_pct" -v t="$threshold_duration_pct" 'BEGIN { exit !(v <= t) }'; then :; else
  echo "Gate failed: median duration increase too high" >&2
  pass=0
fi
if awk -v v="$retry_increase_pct" -v t="$threshold_retry_pct" 'BEGIN { exit !(v <= t) }'; then :; else
  echo "Gate failed: retry rate increase too high" >&2
  pass=0
fi

if [[ "$pass" -eq 1 ]]; then
  echo "Eval gate: PASS"
  exit 0
fi

echo "Eval gate: FAIL"
exit 1
