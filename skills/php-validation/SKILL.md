---
name: php-validation
description: Run PHP validation pipeline (fast -> broad), measure test time, and report final test status.
version: 1.0.0
---

# php-validation

Use this skill after implementation, before final audit/commit.

## Trigger

- Code changes finished and ready for verification.

## Workflow

1. Start with fastest relevant checks:
   - targeted/unit tests for changed modules,
   - static checks if required by project.
2. Expand scope only when needed:
   - smoke/e2e for cross-cutting/API/auth/security changes,
   - full suite when targeted checks are insufficient.
3. Track wall-clock time for all test commands.
4. Emit compact result:
   - pass/fail summary,
   - key failing signal if not green,
   - `RALPH_TEST_SECONDS=<integer>`.

## Deliverable

- Validation summary with command list.
- Measured total test time.
- Clear PASS/FAIL status for handoff to `php-gatekeeper`.
