---
name: php-implement
description: Implement PHP feature/fix/refactor using a file-by-file plan and minimal safe diff.
version: 1.0.0
---

# php-implement

Use this skill to execute PHP code changes after scope is known.

## Trigger

- Feature, bugfix, refactor, migration task for PHP code.
- `php-context` already produced a scoped file map.

## Workflow

1. Build a minimal diff plan:
   - file list and order,
   - expected behavior change per file.
2. Implement in small coherent steps:
   - update production code,
   - update/extend tests next to changed behavior.
3. Keep changes local:
   - no broad unrelated refactors,
   - no runtime artifact edits.
4. Prepare commit-ready output:
   - list changed files,
   - short rationale for non-obvious decisions.

## Guardrails

- Preserve backward compatibility unless task explicitly requires breaking change.
- For security-sensitive paths, prefer explicit checks and fail-safe defaults.
- For migrations, include rollback/compatibility consideration.

## Deliverable

- Applied code changes aligned with scope.
- Updated tests.
- Handoff for `php-validation`.
