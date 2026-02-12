# Przygotowanie Ralph do open source — plan implementacji

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Cel:** Przygotować repo Ralph do publicznego wydania — wyczyścić prywatne ścieżki, usunąć legacy pliki, dodać i18n (pl/en), README/LICENSE/.gitignore, wypuścić jako świeży initial commit.

**Architektura:** Struktura plików po zmianach:

```
ralph/
  ralph              # główny skrypt (bash)
  prompts/
    pl.md            # prompt PL (domyślny)
    en.md            # prompt EN
  archive_todo.sh    # utility do archiwizacji DONE sekcji
  README.md          # dokumentacja (EN)
  LICENSE            # MIT
  .gitignore
```

**Stack:** Bash, Git

---

### Task 1: Usunięcie zbędnych plików

**Pliki:**
- Usuń: `ralph.sh` (stary entry point, zastąpiony przez `ralph`)
- Usuń: `agent_watchdog.sh` (stary watchdog, wchłonięty przez `ralph`)
- Usuń: `AGENT_WATCHDOG.md` (docs starego watchdoga)
- Usuń: `CLAUDE.md` (zawiera tylko prywatny claude-mem context)
- Usuń: `PETLA_CONTINUOUS.md` (overlay continuous — zbędny)
- Usuń: `.claude/` (napkin i inne lokalne dane)

**Krok 1: Usuń pliki**

```bash
rm -f ralph.sh agent_watchdog.sh AGENT_WATCHDOG.md CLAUDE.md PETLA_CONTINUOUS.md
rm -rf .claude
```

**Krok 2: Weryfikacja**

Oczekiwane: zostają `ralph`, `PETLA.md`, `archive_todo.sh`, `docs/`, `.git/`

---

### Task 2: Przeniesienie PETLA.md do prompts/ i tłumaczenie na EN

**Pliki:**
- Przenieś: `PETLA.md` → `prompts/pl.md`
- Utwórz: `prompts/en.md` (tłumaczenie)

**Krok 1: Przenieś**

```bash
mkdir -p prompts
mv PETLA.md prompts/pl.md
```

**Krok 2: Utwórz prompts/en.md**

Pełne tłumaczenie `prompts/pl.md` na angielski. Zachowaj identyczną strukturę
(nagłówek, blok text, algorytm 0-9, politykę blokad, definicję gotowe).

Kluczowe tłumaczenia:
- "PETLA" → brak tłumaczenia nazwy, opis: "single-task prompt for autonomous agent"
- "JEDNO ZADANIE" → "SINGLE TASK"
- "BRAK ZADAŃ" → "NO TASKS" (**ważne** — ralph grep-uje tę frazę w logach)
- "tasks/TODO.md" → bez zmian (ścieżki zostają)
- "CLAUDE.md" → bez zmian (referencje do pliku projektu docelowego)
- "DONE" token → bez zmian (format nagłówka sekcji)

**UWAGA:** W `prompts/en.md` fraza "NO TASKS" musi być dokładnie taka sama
jak pattern w `ralph` (patrz Task 3, grep regex update).

---

### Task 3: Edycja `ralph` — RALPH_HOME, i18n, drop continuous

**Pliki:**
- Modyfikuj: `ralph`

#### 3a: Portable auto-detect RALPH_HOME (linia 8)

Zamień:
```bash
RALPH_HOME="${RALPH_HOME:-$HOME/STUFF/hidden_files/ralph}"
```
na:
```bash
_script_dir() {
  local src="${BASH_SOURCE[0]}"
  while [ -L "$src" ]; do
    local dir
    dir="$(cd -P "$(dirname "$src")" && pwd)"
    src="$(readlink "$src")"
    [[ "$src" != /* ]] && src="$dir/$src"
  done
  cd -P "$(dirname "$src")" && pwd
}
RALPH_HOME="${RALPH_HOME:-$(_script_dir)}"
```

Dlaczego nie `readlink -f`: macOS BSD nie ma `-f`. Ten loop rozwiązuje symlinki
przenośnie.

#### 3b: Dodaj RALPH_LANG i i18n komunikatów

Po bloku zmiennych konfiguracyjnych (po linii ~24), dodaj:

```bash
RALPH_LANG="${RALPH_LANG:-pl}"
BASE_PROMPT_FILE="${BASE_PROMPT_FILE:-$RALPH_HOME/prompts/${RALPH_LANG}.md}"
```

I zamień istniejącą linię:
```bash
BASE_PROMPT_FILE="${BASE_PROMPT_FILE:-$RALPH_HOME/PETLA.md}"
```

Następnie dodaj blok i18n z komunikatami. Treść poniżej:

```bash
case "$RALPH_LANG" in
  pl)
    MSG_GIT_ONLY="To polecenie dziala tylko w repo git."
    MSG_USAGE_RESTART="blad: podaj PID. Uzycie: ralph restart <pid>"
    MSG_BAD_PID="blad: nieprawidlowy PID:"
    MSG_STOP_REMOVED="usunieto stop, mozesz ponownie ustawic powtarzajac komende"
    MSG_STOP_SET="ustawiono stop"
    MSG_RESTART_PLANNED="restart zaplanowany: przeladuje sie po biezacym runie"
    MSG_RESTART_WRONG_PID="blad: aktywny PID dla tego repo to"
    MSG_RESTART_NO_PROCESS="blad: brak aktywnego procesu ralph run w tym repo"
    MSG_ALREADY_RUNNING="blad: ralph juz dziala. Uzyj: ralph restart"
    MSG_CODEX_NOT_FOUND="codex nie znaleziony w PATH"
    MSG_PROMPT_NOT_FOUND="Prompt nie znaleziony:"
    MSG_BAD_MODE="Nieznany RALPH_MODE (dozwolone: loop, single):"
    MSG_STARTED="uruchomiono"
    MSG_STOPPED="Ralph zatrzymany."
    MSG_RUN_DONE="run zakonczony"
    MSG_IDLE="idle"
    MSG_NEEDS_DECISION="wymaga decyzji (auto-continue)"
    MSG_TASK_DONE="task wykonany"
    MSG_ERROR="blad"
    MSG_SINGLE_STOPPED="zatrzymano: tryb single"
    MSG_RESTART_RELOAD="restart: przeladowanie w tym terminalu"
    MSG_NO_TASKS_PATTERN='BRAK ZADA[ŃN]'
    ;;
  en)
    MSG_GIT_ONLY="This command only works inside a git repo."
    MSG_USAGE_RESTART="error: provide PID. Usage: ralph restart <pid>"
    MSG_BAD_PID="error: invalid PID:"
    MSG_STOP_REMOVED="stop removed, repeat command to set again"
    MSG_STOP_SET="stop set"
    MSG_RESTART_PLANNED="restart scheduled: will reload after current run"
    MSG_RESTART_WRONG_PID="error: active PID for this repo is"
    MSG_RESTART_NO_PROCESS="error: no active ralph run process in this repo"
    MSG_ALREADY_RUNNING="error: ralph already running. Use: ralph restart"
    MSG_CODEX_NOT_FOUND="codex not found in PATH"
    MSG_PROMPT_NOT_FOUND="Prompt not found:"
    MSG_BAD_MODE="Unknown RALPH_MODE (allowed: loop, single):"
    MSG_STARTED="started"
    MSG_STOPPED="Ralph stopped."
    MSG_RUN_DONE="run finished"
    MSG_IDLE="idle"
    MSG_NEEDS_DECISION="needs decision (auto-continue)"
    MSG_TASK_DONE="task completed"
    MSG_ERROR="error"
    MSG_SINGLE_STOPPED="stopped: single mode"
    MSG_RESTART_RELOAD="restart: reloading in this terminal"
    MSG_NO_TASKS_PATTERN='NO TASKS'
    ;;
  *)
    echo "Unknown RALPH_LANG: $RALPH_LANG (allowed: pl, en)" >&2
    exit 2
    ;;
esac
```

#### 3c: Zamień hardcoded stringi na MSG_* w całym skrypcie

Wszystkie `echo "..."` z polskimi komunikatami zamieniamy na odpowiednie `$MSG_*`.
Przykłady kluczowych zamian:

| Stary tekst | Nowa zmienna |
|-------------|-------------|
| `"To polecenie dziala tylko w repo git."` | `"$MSG_GIT_ONLY"` |
| `"blad: podaj PID..."` | `"$MSG_USAGE_RESTART"` |
| `"codex nie znaleziony w PATH"` | `"$MSG_CODEX_NOT_FOUND"` |
| `"Ralph zatrzymany."` | `"$MSG_STOPPED"` |
| `"uruchomiono: repo=..."` | `"$MSG_STARTED: repo=..."` |

Oraz zmień regex detekcji braku zadań:
```bash
# Stare:
if tail -n 120 "$log_file" | grep -Eq "^[[:space:]]*BRAK ZADA[ŃN][[:space:]]*$"; then
# Nowe:
if tail -n 120 "$log_file" | grep -Eq "^[[:space:]]*${MSG_NO_TASKS_PATTERN}[[:space:]]*$"; then
```

#### 3d: Usunięcie continuous mode

Usuń:
- Linię `CONTINUOUS_PROMPT_FILE=...`
- Walidację continuous w if/fi
- Blok `if [[ "$RALPH_MODE" == "continuous" ]]` w pętli

Zamień walidację RALPH_MODE:
```bash
if [[ "$RALPH_MODE" != "single" && "$RALPH_MODE" != "loop" ]]; then
  echo "$MSG_BAD_MODE $RALPH_MODE" >&2
  exit 1
fi
```

#### 3e: Aktualizuj help

```bash
  help|--help|-h)
    cat <<EOF
Usage:
  ralph run            - start agent loop
  ralph restart <pid>  - reload active process (by PID)
  ralph stop           - toggle stop (set/remove tasks/agent.stop)
  ralph help           - show this menu

Environment:
  RALPH_LANG    Language: pl (default), en
  RALPH_MODE    Mode: loop (default), single
  MODEL         AI model (default: gpt-5.3-codex)
  REASONING     Reasoning effort (default: high)
  SLEEP_SECONDS Sleep between runs (default: 10)
  RALPH_HOME    Ralph installation directory (auto-detected)
EOF
    exit 0
    ;;
```

#### 3f: Weryfikacja

```bash
bash -n ralph
```

---

### Task 4: Dodanie .gitignore

**Pliki:**
- Utwórz: `.gitignore`

```gitignore
# Runtime state (generated per target repo, not part of ralph itself)
tasks/
*.pid
*.log

# Claude Code local state
.claude/

# Editor
*.swp
*~
```

---

### Task 5: Dodanie LICENSE (MIT)

**Pliki:**
- Utwórz: `LICENSE`

Standardowa MIT, rok 2026, autor: "Ralph Contributors".

---

### Task 6: Dodanie README.md (EN)

**Pliki:**
- Utwórz: `README.md`

Struktura:

```markdown
# Ralph

Autonomous AI coding loop. Reads tasks from `TODO.md`, dispatches an AI agent
to implement them one by one, commits, pushes, and loops.

## How it works

1. Ralph reads `tasks/TODO.md` in your project repo
2. Picks the first task not marked as DONE
3. Dispatches a Codex agent with full-auto permissions
4. Agent implements the task, runs tests, commits and pushes
5. Ralph detects completion, waits, then starts next iteration

## Requirements

- [Codex CLI](https://github.com/openai/codex) in your PATH
- A git repository with `tasks/TODO.md`
- Bash 4+

## Installation

git clone <repo-url>
ln -s "$(pwd)/ralph/ralph" ~/bin/ralph  # or anywhere in PATH

## Usage

cd your-project-repo
ralph run              # start the loop
ralph stop             # toggle stop file
ralph restart <pid>    # reload running process

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| RALPH_LANG | pl | Language: pl, en |
| RALPH_MODE | loop | Mode: loop, single |
| MODEL | gpt-5.3-codex | AI model name |
| REASONING | high | Model reasoning effort |
| SLEEP_SECONDS | 10 | Pause between runs |
| IDLE_SLEEP_SECONDS | 15 | Pause when no tasks |
| RALPH_HOME | (auto) | Ralph installation dir |
| RALPH_VERBOSE | 0 | Show agent output live |

## File structure

| File | Purpose |
|------|---------|
| `ralph` | Main script — loop, PID management, logging |
| `prompts/pl.md` | Agent prompt (Polish) |
| `prompts/en.md` | Agent prompt (English) |
| `archive_todo.sh` | Utility: archive DONE sections from TODO.md |

## TODO.md format

(opis formatu sekcji ## N. Tytuł, oznaczania DONE, podsekcji literowych)

## License

MIT
```

---

### Task 7: Nowe repo ze squashowanym commitem

**Krok 1: Przygotuj czyste repo**

```bash
rm -rf .git
git init
git add ralph prompts/pl.md prompts/en.md archive_todo.sh .gitignore LICENSE README.md
```

NIE dodajemy: `docs/plans/`, `.claude/`, ani żadnych plików spoza powyższej listy.

**Krok 2: Ustaw neutralnego autora i commituj**

```bash
git config user.name "Ralph Contributors"
git config user.email "noreply@example.com"
git commit -m "Initial release"
```

**Krok 3: Weryfikacja — brak leaków**

```bash
git grep -E "STUFF|hidden_files|domownik|cx33|pawel|losowy"
```

Oczekiwane: zero wyników. Użycie `git grep` zamiast `grep -r` — skanuje tylko
tracked files, pomija docs/plans/ i inne lokalne śmieci.

---

### Task 8: Końcowa weryfikacja

**Krok 1: Dry-run w tmpdir**

```bash
tmp=$(mktemp -d)
cd "$tmp"
git init && echo "# test" > README.md && git add . && git commit -m "init"
mkdir tasks
printf '# TODO\n\n## 1. Test task\nDo something\n' > tasks/TODO.md
```

**Krok 2: Test help (oba języki)**

```bash
RALPH_HOME=/ścieżka/do/ralph /ścieżka/do/ralph/ralph help
RALPH_LANG=en RALPH_HOME=/ścieżka/do/ralph /ścieżka/do/ralph/ralph help
```

Oczekiwane: help menu bez błędów w obu językach.

**Krok 3: Test run startup**

```bash
RALPH_VERBOSE=1 RALPH_MODE=single RALPH_HOME=/ścieżka/do/ralph \
  /ścieżka/do/ralph/ralph run 2>&1 | head -3
```

Oczekiwane: linia `started: repo=..., pid=..., mode=single` (lub PL odpowiednik).
Ctrl+C po weryfikacji.

**Krok 4: Test RALPH_LANG=en prompt loading**

```bash
RALPH_LANG=en RALPH_MODE=single RALPH_HOME=/ścieżka/do/ralph \
  /ścieżka/do/ralph/ralph run 2>&1 | head -3
```

Oczekiwane: bez błędu "Prompt not found".

**Krok 5: Cleanup**

```bash
rm -rf "$tmp"
```
