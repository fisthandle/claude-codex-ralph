---
name: todo
description: Use when user describes a feature, bug, or change to plan - analyzes relevant code, writes implementation spec as numbered section in tasks/TODO.md
---

# Todo — Add task to TODO.md

Accepts a request (feature, bug, refactor), analyzes relevant code, and appends
a structured section to `tasks/TODO.md` for Ralph to pick up.

**Announce:** "Adding to TODO.md — analyzing code and writing spec."

## When to use

- User describes a feature, bug, UI change, or refactor
- User says "add to todo", "plan this", "write a task for this"
- NOT when user wants immediate implementation

## Workflow

```
User describes task
    |
    v
[1] Find next section number in TODO.md
    |
    v
[2] Analyze relevant code (Grep/Read)
    |
    v
[3] Write section using the template below
    |
    v
[4] Append to TODO.md (Edit, not Write)
    |
    v
[5] Summarize what was added
```

## Step 1: Section number

If `tasks/` does not exist — `mkdir -p tasks/`.
Read end of `tasks/TODO.md`, find last `## N.`, use N+1.

If TODO.md does not exist — create:
```markdown
# TODO

---

## 1. [title]
```

## Step 2: Code analysis

**Read before writing.** Never spec code you haven't seen.

- Files the task touches (Read)
- Related code paths (Grep + Read)
- For large changes — use an Explore agent

## Step 3: Section template

```markdown
---

## N. [Short, specific title]

### Context
1-3 sentences: what, why, what problem.

### Na. [Subtask — specific change]

**File:** `path/to/file.ext` line ~N

```[language]
// BEFORE:
old code

// AFTER:
new code
```

### Nb. [Subtask 2]
...

### Validation
- [ ] Test scenario 1
- [ ] Test scenario 2
- [ ] Edge case
```

Key rules:
- Show before/after code, not prose descriptions
- If subtask depends on another: "Order: FIRST section X"
- Don't implement — write a spec that Ralph's agent can follow
- Don't leave unknowns — ask the user or mark as out of scope

## Step 4: Append

Use `Edit` on `tasks/TODO.md`:
- `old_string` = last line of existing content
- `new_string` = that line + separator + new section

**Always re-read the file end before editing** — it may have changed.

## Step 5: Summary

- Section number and title
- 1-3 bullets: key points
- Dependencies on other sections if any

## Archival

If TODO.md > 800 lines: move `~~N. Title~~ DONE` sections to `tasks/TODO_ARCHIVE.md`.
