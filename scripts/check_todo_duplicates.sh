#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
  echo "usage: $0 <path-to-TODO.md>" >&2
  exit 2
fi

TODO_FILE="$1"
if [[ ! -f "$TODO_FILE" ]]; then
  echo "error: TODO file not found: $TODO_FILE" >&2
  exit 2
fi

awk '
function trim(s) {
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
  return s
}

function normalize_title(raw, t) {
  t = raw
  sub(/^##[[:space:]]+/, "", t)
  gsub(/~~/, "", t)
  sub(/[[:space:]]+DONE.*/, "", t)
  t = trim(t)
  sub(/^[0-9]+[a-z]?([.)]|[[:space:]])+[[:space:]]*/, "", t)
  t = tolower(t)
  gsub(/[^[:alnum:]]+/, " ", t)
  t = trim(t)
  return t
}

function normalize_body(raw, b) {
  b = tolower(raw)
  gsub(/[[:space:]]+/, " ", b)
  b = trim(b)
  return b
}

function register_section(   title_norm, body_norm, key) {
  if (section_header == "") {
    return
  }
  if (section_header ~ /DONE/) {
    section_header = ""
    section_body = ""
    return
  }

  title_norm = normalize_title(section_header)
  body_norm = normalize_body(section_body)
  key = title_norm "|" body_norm

  count[key]++
  if (labels[key] == "") {
    labels[key] = section_label
  } else {
    labels[key] = labels[key] ", " section_label
  }

  section_header = ""
  section_body = ""
}

BEGIN {
  section_header = ""
  section_body = ""
}

/^##[[:space:]]+/ {
  register_section()
  section_header = $0
  section_label = $0
  sub(/^##[[:space:]]+/, "", section_label)
  section_label = trim(section_label)
  next
}

{
  if (section_header != "") {
    if (section_body == "") {
      section_body = $0
    } else {
      section_body = section_body "\n" $0
    }
  }
}

END {
  register_section()

  duplicate_count = 0
  duplicate_groups = 0
  for (key in count) {
    if (count[key] > 1) {
      duplicate_groups++
      duplicate_count += (count[key] - 1)
      details[duplicate_groups] = sprintf("duplicate_group_%d=count:%d sections:%s", duplicate_groups, count[key], labels[key])
    }
  }

  print "todo_duplicates_count=" duplicate_count
  for (i = 1; i <= duplicate_groups; i++) {
    print details[i]
  }
}
' "$TODO_FILE"
