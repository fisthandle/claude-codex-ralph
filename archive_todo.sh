#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TASKS_DIR="${TASKS_DIR:-$ROOT_DIR/tasks}"
TODO_FILE="${1:-$TASKS_DIR/TODO.md}"
ARCHIVE_FILE="${2:-$TASKS_DIR/TODO_ARCHIVE.md}"

mkdir -p "$(dirname "$TODO_FILE")" "$(dirname "$ARCHIVE_FILE")"
if [[ ! -f "$TODO_FILE" ]]; then
  if [[ -f "$ROOT_DIR/docs/TODO.md" ]]; then
    cp "$ROOT_DIR/docs/TODO.md" "$TODO_FILE"
  else
    printf '# TODO\n\n' > "$TODO_FILE"
  fi
fi
if [[ ! -f "$ARCHIVE_FILE" ]]; then
  if [[ -f "$ROOT_DIR/docs/TODO_ARCHIVE.md" ]]; then
    cp "$ROOT_DIR/docs/TODO_ARCHIVE.md" "$ARCHIVE_FILE"
  else
    printf '# TODO Archive\n\n' > "$ARCHIVE_FILE"
  fi
fi

done_sections_before="$(grep -Ec '^## .*DONE' "$TODO_FILE" || true)"
if [[ -z "$done_sections_before" || ! "$done_sections_before" =~ ^[0-9]+$ ]]; then
  done_sections_before=0
fi

tmp_todo="$(mktemp)"
tmp_archive="$(mktemp)"

cleanup() {
  rm -f "$tmp_todo" "$tmp_archive"
}
trap cleanup EXIT

if [[ -f "$ARCHIVE_FILE" ]]; then
  cat "$ARCHIVE_FILE" > "$tmp_archive"
else
  printf '# TODO Archive\n\n' > "$tmp_archive"
fi

export TODO_OUT="$tmp_todo"
export ARCHIVE_OUT="$tmp_archive"

awk '
function flush_section() {
  if (!in_section) {
    return
  }

  if (section_is_done) {
    printf "%s", section_buffer >> ENVIRON["ARCHIVE_OUT"]
  } else {
    printf "%s", section_buffer >> ENVIRON["TODO_OUT"]
  }

  section_buffer = ""
  section_is_done = 0
  in_section = 0
}

{
  if ($0 ~ /^## /) {
    flush_section()
    in_section = 1
    section_buffer = $0 "\n"
    if ($0 ~ /DONE/) {
      section_is_done = 1
    }
    next
  }

  if (in_section) {
    section_buffer = section_buffer $0 "\n"
  } else {
    printf "%s\n", $0 >> ENVIRON["TODO_OUT"]
  }
}

END {
  flush_section()
}
' "$TODO_FILE"

mv "$tmp_todo" "$TODO_FILE"
mv "$tmp_archive" "$ARCHIVE_FILE"

done_sections_after="$(grep -Ec '^## .*DONE' "$TODO_FILE" || true)"
if [[ -z "$done_sections_after" || ! "$done_sections_after" =~ ^[0-9]+$ ]]; then
  done_sections_after=0
fi

sections_moved=$((done_sections_before - done_sections_after))
if (( sections_moved < 0 )); then
  sections_moved=0
fi

echo "Archived DONE sections (sections_moved=$sections_moved)"
