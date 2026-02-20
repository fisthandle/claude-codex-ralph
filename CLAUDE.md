# CLAUDE.md - Ralph (central policy)

This file defines global runtime policy for `ralph run`.
It is loaded by Ralph and supplements project-level instructions.

## Scope and Priorities

- Execute exactly one TODO task per run.
- Fix blocking errors first.
- If the same infra failure signature appears twice in a row, prioritize infra/test-runner diagnosis.

## Subagents (`subag=auto`)

- Default: do not spawn subagents.
- Use subagents when they reduce risk or time:
  - analysis, audit, or multi-file research,
  - cross-cutting regression diagnosis,
  - infra blocker diagnosis after 2 repeated failure signatures.
- Do not use subagents for simple implementation work:
  - small RED/GREEN loops,
  - fixes touching 1-2 files,
  - local rename/refactor.

### Subagent Limits

- Max 2 subagents in parallel per run.
- Each subagent must have a narrow goal and explicit artifact:
  - findings list, risk checklist, or diff plan.
- Timeout: 240s per subagent.
- Retry: max 1 per subagent.
- Fallback: if subagent is unavailable, continue locally without blocking the run.

### Results Integration

- Main agent owns final decisions and implementation.
- Subagent results must be locally verified before applying.
- Before commit: run project-required tests and self-audit the diff.

## Reasoning Policy

Ralph wrapper supports `REASONING=auto` and maps to allowed levels:
`none|minimal|low|medium|high|xhigh`.

### Selection Rules

- Default: `medium`.
- `high`:
  - cross-cutting migrations (routing/bootstrap/auth/db schema),
  - security-sensitive flows,
  - complex multi-file bugfixes.
- `xhigh`:
  - only when the same infra failure repeats 2 times in a row.

### Override

- If user explicitly sets `REASONING=none|minimal|low|medium|high|xhigh`,
  wrapper must not override it.

## Run Telemetry

In `tasks/logs/runs/*/meta.txt`, write:

- `reasoning_requested=<input value>`
- `reasoning_selected=<final level>`
- `reasoning_reason=<short reason>`
- `test_seconds=<value>`
- `duration_seconds=<value>`

## Execution Guardrails

- Do not stop after first failure; attempt repair and validate.
- Commit only the current task scope.
- Never commit runtime artifacts (`tasks/logs`, stop files, etc.).
- If project policy conflicts with central policy:
  - security and test integrity take precedence,
  - document decision in DONE entry for the run.
