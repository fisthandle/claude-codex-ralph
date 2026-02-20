---
name: php-gatekeeper
description: Final PHP diff gate before commit - security, quality, policy, and commit readiness checks.
version: 1.0.0
---

# php-gatekeeper

Use this skill as final gate before commit.

## Trigger

- Implementation and validation are complete.
- Preparing final commit for the current task.

## Checklist

1. Security review:
   - auth/session checks unchanged or intentionally updated,
   - no obvious injection/XSS/CSRF regressions,
   - no secret leakage.
2. Quality review:
   - no dead code introduced,
   - naming/style consistent with project,
   - scope limited to current task.
3. Policy review:
   - no `tasks/*` runtime artifacts staged,
   - commit message concise,
   - unrelated files excluded.

## Deliverable

- `commit_ready=yes|no`
- Findings (if any) with file paths.
- If `no`, explicit fix list before commit.
