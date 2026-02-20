#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-}"
HEAD_BEFORE="${2:-}"
HEAD_AFTER="${3:-}"

if [[ -z "$ROOT_DIR" || -z "$HEAD_BEFORE" || -z "$HEAD_AFTER" ]]; then
  echo "policy_check_skipped: missing args"
  exit 0
fi

if [[ "$HEAD_BEFORE" == "$HEAD_AFTER" ]]; then
  echo "policy_ok: no new commits"
  exit 0
fi

if ! git -C "$ROOT_DIR" rev-parse "$HEAD_BEFORE" >/dev/null 2>&1; then
  echo "policy_check_skipped: invalid HEAD_BEFORE"
  exit 0
fi
if ! git -C "$ROOT_DIR" rev-parse "$HEAD_AFTER" >/dev/null 2>&1; then
  echo "policy_check_skipped: invalid HEAD_AFTER"
  exit 0
fi

while IFS= read -r commit; do
  [[ -n "$commit" ]] || continue
  subject="$(git -C "$ROOT_DIR" log -n 1 --pretty=%s "$commit")"
  if [[ "${#subject}" -gt 72 ]]; then
    echo "policy_violation: commit subject too long (${#subject} > 72) in $commit"
    exit 1
  fi

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    case "$path" in
      tasks/logs/*|tasks/agent.stop|tasks/agent.restart|*.pid|*.log|.claude/*)
        echo "policy_violation: forbidden runtime/local path committed: $path"
        exit 1
        ;;
    esac
  done < <(git -C "$ROOT_DIR" diff-tree --no-commit-id --name-only -r "$commit")
done < <(git -C "$ROOT_DIR" rev-list "${HEAD_BEFORE}..${HEAD_AFTER}")

echo "policy_ok"
