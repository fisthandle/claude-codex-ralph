#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="${1:-}"
ROOT_DIR="${2:-}"

find_root_from_log() {
  local log_path="$1"
  local current

  if [[ ! -f "$log_path" ]]; then
    return 1
  fi

  current="$(cd "$(dirname "$log_path")" && pwd)"
  while [[ "$current" != "/" ]]; do
    if [[ -d "$current/.git" && -d "$current/tasks" ]]; then
      printf '%s\n' "$current"
      return 0
    fi
    current="$(dirname "$current")"
  done

  return 1
}

if [[ -z "$LOG_FILE" ]]; then
  echo "protocol_check_skipped: missing log path"
  exit 0
fi

if [[ ! -f "$LOG_FILE" ]]; then
  echo "protocol_check_skipped: log file not found"
  exit 0
fi

if [[ -z "$ROOT_DIR" ]]; then
  ROOT_DIR="$(find_root_from_log "$LOG_FILE" || true)"
fi

if [[ -z "$ROOT_DIR" ]]; then
  echo "protocol_check_skipped: project root unresolved"
  exit 0
fi

NAPKIN_FILE="$ROOT_DIR/.claude/napkin.md"
if [[ -f "$NAPKIN_FILE" ]]; then
  first_exec_line="$(grep -nE '^exec$' "$LOG_FILE" | head -n 1 | cut -d: -f1 || true)"
  if [[ -z "$first_exec_line" ]]; then
    echo "protocol_violation: napkin_first_missing_exec"
    exit 1
  fi

  first_command_line="$(sed -n "$((first_exec_line + 1))p" "$LOG_FILE" | tr -d '\r' || true)"
  if [[ "$first_command_line" != *".claude/napkin.md"* ]]; then
    echo "protocol_violation: napkin_first_violation"
    exit 1
  fi
fi

mapfile -t spawn_lines < <(grep -nE '^[[:space:]]*(collab[[:space:]]+)?spawn_agent\(' "$LOG_FILE" | cut -d: -f1 || true)
announcement_re='^[[:space:]]*→[[:space:]]+\*\*[^*]+\*\*[[:space:]]+\([^()]*\):[[:space:]].+'
for line_no in "${spawn_lines[@]}"; do
  [[ -n "$line_no" ]] || continue
  prev_line="$(awk -v target="$line_no" 'NR<target && $0 ~ /[^[:space:]]/ {last=$0} END {print last}' "$LOG_FILE" | tr -d '\r' || true)"
  if ! [[ "$prev_line" =~ $announcement_re ]]; then
    echo "protocol_violation: subag_announcement_missing_before_spawn_agent@line_${line_no}"
    exit 1
  fi
done

echo "protocol_ok"
