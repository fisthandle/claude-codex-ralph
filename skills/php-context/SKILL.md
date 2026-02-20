---
name: php-context
description: Analyze PHP task scope before implementation - map files, dependencies, risks, and proposed change boundary.
version: 1.0.0
---

# php-context

Use this skill before editing PHP code.

## Trigger

- Task touches PHP (`*.php`, framework routes, migrations, DI config).
- Request asks for impact analysis, debugging map, or safe scope definition.

## Workflow

1. Identify the first open task and collect only relevant sections.
2. Map related files:
   - entrypoints (routes/controllers/commands),
   - services/repositories/events/jobs,
   - schema/migrations touched by the flow.
3. Build dependency and impact notes:
   - data flow in/out,
   - side effects and coupling points,
   - security and performance hotspots.
4. Propose implementation boundary:
   - in-scope files,
   - explicitly out-of-scope files,
   - validation targets.

## Deliverable

- Short scope summary.
- File map with rationale.
- Risk list (security, regression, migration risk).
- Recommended next step (`php-implement`).
