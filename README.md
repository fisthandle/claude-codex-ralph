# Ralph

Autonomous AI coding loop. Reads tasks from `TODO.md`, dispatches an AI agent
to implement them one by one, commits, and loops. Ralph syncs with remote at
the session level.

## How it works

```
tasks/TODO.md ──► ralph picks first open task
                      │
                      ▼
                  codex agent (full-auto)
                  implements, tests, audits
                      │
                      ▼
                  git commit
                      │
                      ▼
                  sleep, then loop ◄──┐
                      │               │
                      └───────────────┘
```

Each iteration:
1. Ralph reads `tasks/TODO.md` in your project repo
2. Picks the first task not marked as DONE
3. Dispatches a [Codex](https://github.com/openai/codex) agent with full-auto permissions
4. Agent implements the task end-to-end, runs tests, and commits
5. Ralph detects completion, waits, then starts next iteration
6. No tasks left? Ralph pushes pending commits, then idles and polls periodically

## Requirements

- [Codex CLI](https://github.com/openai/codex) in your `PATH`
- A git repository
- Bash 4+

## Installation

```bash
git clone https://github.com/example/ralph.git
ln -s "$(cd ralph && pwd)/ralph" ~/bin/ralph
```

Or just add the ralph directory to your `PATH`.

### Claude Code skill (optional)

Ralph comes with a `todo` skill for [Claude Code](https://claude.ai/claude-code)
that helps you write well-structured tasks. To install:

```bash
cp -r ralph/skills/todo ~/.claude/skills/todo
```

Then in Claude Code, use `/todo` followed by a task description. The skill
analyzes your codebase and writes a detailed implementation spec directly into
`tasks/TODO.md` — ready for Ralph to pick up.

### PHP skills pack (optional)

Ralph also ships a PHP implementation workflow:

- `php-context` -> analyze scope and dependencies
- `php-implement` -> implement scoped changes
- `php-validation` -> run tests and measure test time
- `php-gatekeeper` -> final security/quality/commit gate

Install all:

```bash
cp -r ralph/skills/php-context ~/.claude/skills/php-context
cp -r ralph/skills/php-implement ~/.claude/skills/php-implement
cp -r ralph/skills/php-validation ~/.claude/skills/php-validation
cp -r ralph/skills/php-gatekeeper ~/.claude/skills/php-gatekeeper
```

## Usage

```bash
cd your-project-repo
ralph run              # start the loop
ralph stop             # toggle stop file (set/remove tasks/agent.stop)
ralph safe-stop        # toggle safe-stop (set/remove tasks/agent.safe-stop)
ralph restart <pid>    # reload a running process
ralph help             # show help
```

## Configuration

All configuration is via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `RALPH_LANG` | `pl` | Language: `pl`, `en` |
| `RALPH_MODE` | `loop` | Mode: `loop` (keep going), `single` (one task then stop) |
| `MODEL` | `gpt-5.3-codex` | AI model name passed to codex |
| `REASONING` | `auto` | Reasoning mode: `auto`, `none`, `minimal`, `low`, `medium`, `high`, `xhigh` |
| `SLEEP_SECONDS` | `10` | Pause between runs (seconds) |
| `IDLE_SLEEP_SECONDS` | `100` | Pause when no tasks found |
| `ERROR_SLEEP_SECONDS` | `300` | Pause after a failed run |
| `TODO_MIN_LINES_FOR_MODEL` | `10` | If `tasks/TODO.md` has fewer lines, skip model run and stay in idle polling mode |
| `RALPH_HOME` | *(auto-detected)* | Ralph installation directory |
| `RALPH_VERBOSE` | `0` | Set to `1` to show agent output live |
| `RALPH_INLINE_CLAUDE` | `0` | Set to `1` to inline full `CLAUDE.md` files into each prompt |
| `RALPH_WT_MAX_LINES` | `40` | Max `git status --short` lines appended to each prompt |
| `RALPH_GIT_SYNC_ON_START` | `1` | Set to `0` to skip one-time `git pull --rebase` at session start |
| `RALPH_GIT_PUSH_ON_IDLE` | `1` | Set to `0` to disable auto-push of pending commits on idle/stop |
| `STUCK_TIMEOUT_SECONDS` | `1800` | Timeout for a single agent attempt (`timeout` command) |
| `STUCK_KILL_GRACE_SECONDS` | `20` | Grace period before hard kill after timeout |
| `MAX_RETRIES_ON_FAILURE` | `1` | Retry count for retryable failures (`infra_network`, `stuck`) |
| `BACKOFF_MULTIPLIER` | `2` | Multiplier for retry backoff |
| `RUN_BUDGET_WINDOW_SECONDS` | `3600` | Run budget window size in seconds |
| `MAX_RUNS_PER_WINDOW` | `30` | Maximum runs allowed in one budget window |
| `RALPH_TODO_MAINTENANCE_MODE` | `idle` | TODO maintenance mode: `off`, `idle`, `periodic` |
| `RALPH_TODO_MAINTENANCE_EVERY` | `10` | Run interval for maintenance in `periodic` mode |
| `RALPH_FAIL_ON_TODO_DUPLICATES` | `0` | Set to `1` to fail-fast when duplicate open TODO sections are detected |
| `BASE_PROMPT_FILE` | `prompts/{lang}.md` | Override agent prompt file |

Example:

```bash
RALPH_LANG=en MODEL=o3 ralph run
```

Reasoning policy:

- `REASONING=auto` (default) selects:
  - `medium` by default,
  - `high` for migration/security/cross-cutting tasks,
  - `xhigh` only after 2 repeated infra failures,
  - `low` for docs/admin-only tasks.
- If you set `REASONING=none|minimal|low|medium|high|xhigh`, Ralph does not override it.

Examples:

```bash
REASONING=auto ralph run
REASONING=high ralph run
```

Subagent policy:

- Subagent rules are centralized in `ralph/CLAUDE.md` (`subag=auto`).
- Wrapper policy:
  - do not force subagents for simple 1-2 file fixes,
  - use subagents for audits/multi-file research/repeated infra diagnosis,
  - max 2 subagents, timeout 240s, max 1 retry,
  - fallback to local execution if subagent is unavailable.

Runtime observability:

- Every run prints a compact reason tag:
  - `reason=auto(medium)` for auto selection,
  - `reason=high` (or another fixed level) for manual override.
- `tasks/logs/runs/*/meta.txt` includes:
  - `reasoning_requested`, `reasoning_selected`, `reasoning_reason`,
  - `failure_class`, `retry_count`, `stuck_timeout_hit`,
  - `policy_violation`, `policy_reason`, `protocol_violation`, `protocol_reason`,
  - `todo_duplicates_count`, `todo_duplicates_warning`, `todo_duplicates_fail_on_detect`,
  - `context_hash`, `prompt_hash`, `prompt_drift`, `drift_reason`,
  - `phase_prepare_seconds`, `phase_agent_seconds`, `phase_policy_seconds`, `phase_maintenance_seconds`, `phase_finalize_seconds`,
  - `maintenance_mode`, `maintenance_ran`, `maintenance_seconds`, `maintenance_sections_moved`,
  - `test_seconds`, `duration_seconds`.
- `scripts/report_runs.sh` daily JSON includes medians for:
  - `median_phase_prepare_seconds`,
  - `median_phase_agent_seconds`,
  - `median_phase_policy_seconds`,
  - `median_phase_maintenance_seconds`,
  - `median_phase_finalize_seconds`.

TODO maintenance modes:

- `off`: wrapper does not run TODO maintenance.
- `idle` (default): wrapper runs maintenance only when the agent reports `NO TASKS`.
- `periodic`: wrapper runs maintenance every `RALPH_TODO_MAINTENANCE_EVERY` runs.

## Prompt Context Order

For each `ralph run` iteration, context files are loaded in this order:

1. `$HOME/.claude/CLAUDE.md` (optional, user-global)
2. `$RALPH_HOME/CLAUDE.md` (Ralph central policy)
3. `<project-root>/CLAUDE.md` (project-specific policy)
4. `prompts/{lang}.md` (runtime loop prompt)

If `RALPH_INLINE_CLAUDE=1`, Ralph inlines these files directly into `prompt.txt`.
Otherwise, it lists them under "Runtime context files".

## Eval Harness

- Run benchmark scenarios:

```bash
benchmarks/run_eval.sh
```

- Compare against baseline gate:

```bash
benchmarks/compare.sh benchmarks/baseline.json tasks/logs/benchmarks/<run>.json
```

- Generate daily run report:

```bash
scripts/report_runs.sh --date "$(date +%F)"
```

See details: `docs/benchmarks.md`.

## File structure

| File | Purpose |
|------|---------|
| `ralph` | Main script — loop, PID management, logging |
| `prompts/pl.md` | Agent prompt (Polish) |
| `prompts/en.md` | Agent prompt (English) |
| `archive_todo.sh` | Utility: archive completed sections from TODO.md |
| `benchmarks/*` | Eval harness and baseline gate |
| `scripts/check_todo_duplicates.sh` | Detect duplicate open TODO sections by normalized title+content |
| `scripts/report_runs.sh` | Aggregate run telemetry into daily JSON report |
| `scripts/validate_commit_policy.sh` | Post-run commit policy check |
| `scripts/validate_run_protocol.sh` | Post-run protocol check (`napkin-first`, `spawn_agent` announcement) |
| `skills/todo/SKILL.md` | Claude Code skill for writing structured tasks |
| `skills/php-*/SKILL.md` | PHP implementation workflow skills |

## TODO.md format

Ralph expects `tasks/TODO.md` (created automatically if missing) with numbered sections:

```markdown
# TODO

## 1. Add user authentication
Implement login/logout with session tokens.

## 2. Fix pagination bug
The /api/items endpoint returns wrong page count.
```

When the agent completes a task, it marks the section as DONE:

```markdown
## ~~1. Add user authentication~~ DONE (2026-02-12 14:30:00)
```

DONE sections are moved to `tasks/TODO_ARCHIVE.md` by wrapper maintenance
according to `RALPH_TODO_MAINTENANCE_MODE`.

### Subsections

Tasks can have lettered subsections. Ralph treats them as a single unit:

```markdown
## 3. Refactor database layer
### 3a. Extract connection pool
### 3b. Add retry logic
### 3c. Update tests
```

All open letters are completed in one session before marking section 3 as DONE.

## Runtime files

Ralph creates these in your project repo (add `tasks/` to `.gitignore`):

```
tasks/
  TODO.md              # task list
  DONE.md              # completion log
  TODO_ARCHIVE.md      # archived DONE sections
  agent.stop           # touch to stop the loop
  agent.safe-stop      # touch to request safe-stop
  agent.restart        # used by ralph restart
  logs/
    ralph.pid          # PID lock file
    run_budget_state.json # persisted run budget state
    reports/
      YYYY-MM-DD.json  # aggregated daily report
    latest -> runs/... # symlink to latest run
    runs/
      20260212-143000-1/
        stdout.log     # agent output
        prompt.txt     # prompt sent to agent
        policy_check.log # commit policy diagnostics
        protocol_check.log # protocol diagnostics (`napkin-first`, subagent announcements)
        meta.txt       # run metadata (reasoning, failure class, policy/protocol status, drift, retries, test_seconds, duration_seconds)
```

## License

[MIT](LICENSE)
