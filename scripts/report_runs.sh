#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
RUNS_DIR="$ROOT_DIR/tasks/logs/runs"
REPORT_DIR="$ROOT_DIR/tasks/logs/reports"
DATE_FILTER="$(date +%F)"

if [[ "${1:-}" == "--date" ]]; then
  DATE_FILTER="${2:-$DATE_FILTER}"
fi

median_from_numbers() {
  local input="$1"
  if [[ -z "$input" ]]; then
    echo "0"
    return 0
  fi
  printf '%s\n' "$input" | sort -n | awk '
    { a[NR]=$1 }
    END {
      if (NR == 0) { print 0; exit }
      if (NR % 2 == 1) { print a[(NR+1)/2]; exit }
      print int((a[NR/2] + a[NR/2+1]) / 2)
    }'
}

mkdir -p "$REPORT_DIR"

meta_files=()
while IFS= read -r meta; do
  [[ -f "$meta" ]] || continue
  started="$(grep -E '^started=' "$meta" | tail -n 1 | cut -d= -f2- || true)"
  started_date="${started%% *}"
  [[ "$started_date" == "$DATE_FILTER" ]] && meta_files+=("$meta")
done < <(find "$RUNS_DIR" -mindepth 2 -maxdepth 2 -type f -name meta.txt 2>/dev/null | sort)

total_runs=0
success_runs=0
failed_runs=0
retry_total=0
durations=()
tests=()
phase_prepare=()
phase_agent=()
phase_policy=()
phase_maintenance=()
phase_finalize=()
declare -A failure_counts

for meta in "${meta_files[@]}"; do
  total_runs=$((total_runs + 1))
  exit_code="$(grep -E '^exit_code=' "$meta" | tail -n 1 | cut -d= -f2 || echo 1)"
  failure_class="$(grep -E '^failure_class=' "$meta" | tail -n 1 | cut -d= -f2 || echo unknown)"
  retry_count="$(grep -E '^retry_count=' "$meta" | tail -n 1 | cut -d= -f2 || echo 0)"
  duration_seconds="$(grep -E '^duration_seconds=' "$meta" | tail -n 1 | cut -d= -f2 || echo 0)"
  test_seconds="$(grep -E '^test_seconds=' "$meta" | tail -n 1 | cut -d= -f2 || echo 0)"
  phase_prepare_seconds="$(grep -E '^phase_prepare_seconds=' "$meta" | tail -n 1 | cut -d= -f2 || echo 0)"
  phase_agent_seconds="$(grep -E '^phase_agent_seconds=' "$meta" | tail -n 1 | cut -d= -f2 || echo 0)"
  phase_policy_seconds="$(grep -E '^phase_policy_seconds=' "$meta" | tail -n 1 | cut -d= -f2 || echo 0)"
  phase_maintenance_seconds="$(grep -E '^phase_maintenance_seconds=' "$meta" | tail -n 1 | cut -d= -f2 || echo 0)"
  phase_finalize_seconds="$(grep -E '^phase_finalize_seconds=' "$meta" | tail -n 1 | cut -d= -f2 || echo 0)"

  failure_counts["$failure_class"]=$(( ${failure_counts["$failure_class"]:-0} + 1 ))
  retry_total=$((retry_total + retry_count))

  if [[ "$exit_code" =~ ^0$ ]]; then
    success_runs=$((success_runs + 1))
  else
    failed_runs=$((failed_runs + 1))
  fi
  if [[ "$duration_seconds" =~ ^[0-9]+$ ]]; then
    durations+=("$duration_seconds")
  fi
  if [[ "$test_seconds" =~ ^[0-9]+$ ]]; then
    tests+=("$test_seconds")
  fi
  if [[ "$phase_prepare_seconds" =~ ^[0-9]+$ ]]; then
    phase_prepare+=("$phase_prepare_seconds")
  fi
  if [[ "$phase_agent_seconds" =~ ^[0-9]+$ ]]; then
    phase_agent+=("$phase_agent_seconds")
  fi
  if [[ "$phase_policy_seconds" =~ ^[0-9]+$ ]]; then
    phase_policy+=("$phase_policy_seconds")
  fi
  if [[ "$phase_maintenance_seconds" =~ ^[0-9]+$ ]]; then
    phase_maintenance+=("$phase_maintenance_seconds")
  fi
  if [[ "$phase_finalize_seconds" =~ ^[0-9]+$ ]]; then
    phase_finalize+=("$phase_finalize_seconds")
  fi
done

duration_blob="$(printf '%s\n' "${durations[@]:-}" | sed '/^$/d' || true)"
test_blob="$(printf '%s\n' "${tests[@]:-}" | sed '/^$/d' || true)"
phase_prepare_blob="$(printf '%s\n' "${phase_prepare[@]:-}" | sed '/^$/d' || true)"
phase_agent_blob="$(printf '%s\n' "${phase_agent[@]:-}" | sed '/^$/d' || true)"
phase_policy_blob="$(printf '%s\n' "${phase_policy[@]:-}" | sed '/^$/d' || true)"
phase_maintenance_blob="$(printf '%s\n' "${phase_maintenance[@]:-}" | sed '/^$/d' || true)"
phase_finalize_blob="$(printf '%s\n' "${phase_finalize[@]:-}" | sed '/^$/d' || true)"
median_duration="$(median_from_numbers "$duration_blob")"
median_test="$(median_from_numbers "$test_blob")"
median_phase_prepare="$(median_from_numbers "$phase_prepare_blob")"
median_phase_agent="$(median_from_numbers "$phase_agent_blob")"
median_phase_policy="$(median_from_numbers "$phase_policy_blob")"
median_phase_maintenance="$(median_from_numbers "$phase_maintenance_blob")"
median_phase_finalize="$(median_from_numbers "$phase_finalize_blob")"

failure_json_items=()
for key in "${!failure_counts[@]}"; do
  failure_json_items+=("\"$key\": ${failure_counts[$key]}")
done
failure_json="$(printf '%s' "$(printf '%s\n' "${failure_json_items[@]}" | sort | paste -sd, -)")"
if [[ -z "$failure_json" ]]; then
  failure_json="\"none\": 0"
fi

report_file="$REPORT_DIR/$DATE_FILTER.json"
cat > "$report_file" <<EOF
{
  "date": "$DATE_FILTER",
  "total_runs": $total_runs,
  "success_runs": $success_runs,
  "failed_runs": $failed_runs,
  "retry_total": $retry_total,
  "median_duration_seconds": $median_duration,
  "median_test_seconds": $median_test,
  "median_phase_prepare_seconds": $median_phase_prepare,
  "median_phase_agent_seconds": $median_phase_agent,
  "median_phase_policy_seconds": $median_phase_policy,
  "median_phase_maintenance_seconds": $median_phase_maintenance,
  "median_phase_finalize_seconds": $median_phase_finalize,
  "failure_classes": { $failure_json },
  "generated_at": "$(date +'%F %T')"
}
EOF

echo "$report_file"
