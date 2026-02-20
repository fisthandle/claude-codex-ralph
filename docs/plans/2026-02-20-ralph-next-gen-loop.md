# Ralph Next-Gen Loop — plan implementacji

> **Cel:** Zbudować stabilny, mierzalny i skalowalny system pętli agentskiej dla repo PHP, z centralną polityką, ewaluacją i pakietem skilli implementatora.

## 1) Ustalenia (interview -> decyzje bez TBD)

### 1.1 Co rozwiązujemy
- Zmniejszamy koszt "kręcenia się" agenta (powtarzalne failure, brak postępu, dryf promptu).
- Ujednolicamy standard wykonania dla zespołu (szczególnie PHP) bez kopiowania zasad do każdego projektu.
- Dokładamy obserwowalność i ewaluację, żeby zmiany w promptach/heurystykach były mierzalne.

### 1.2 Kto korzysta
- Operator pętli (`ralph run`) i maintainerzy narzędzia.
- Implementatorzy PHP korzystający ze skilli i gotowego workflow.

### 1.3 Poza zakresem (na teraz)
- Brak GUI/dashboardu webowego.
- Brak zewnętrznej bazy metryk (zostajemy przy plikach + skryptach raportujących).

### 1.4 Decyzje
- Wrapper pozostaje źródłem prawdy dla runtime policy (prompt + telemetry + retry).
- Repo-agnostyczna policy zostaje w `ralph/CLAUDE.md`, projektowe wyjątki w `<project>/CLAUDE.md`.
- Każda zmiana pętli musi przejść eval harness przed rolloutem.

---

## 2) Architektura docelowa

### 2.1 Warstwy
1. Orchestrator: `ralph` (pętla, retry, budżety, klasyfikacja failure, commit guard).
2. Policy layer: `$HOME/.claude/CLAUDE.md` -> `ralph/CLAUDE.md` -> `<project>/CLAUDE.md` -> `prompts/{lang}.md`.
3. Telemetry layer: `tasks/logs/runs/*/meta.txt` + raporty agregujące.
4. Eval layer: zestaw benchmarków/regresji pętli + porównanie do baseline.
5. Skills layer: pakiet skilli ogólnych + pakiet PHP implementatora.

### 2.2 Kluczowe sygnały jakości
- `failure_class`, `retry_count`, `stuck_timeout_hit`, `policy_violation`, `reasoning_selected`, `duration_seconds`, `test_seconds`.
- Stabilność: spadek powtarzalnych failure i krótszy czas do zielonego runu.
- Agregacja telemetryki: `scripts/report_runs.sh` (nowy) buduje dzienny raport `tasks/logs/reports/YYYY-MM-DD.json`.

---

## 3) Roadmapa wdrożenia

## 3.1 P0 — Stabilność i bezpieczeństwo pętli (MVP)

### Task P0.1: Stuck detector + watchdog timeout
- Pliki: `ralph`, `README.md`
- Dodaj env:
  - `STUCK_TIMEOUT_SECONDS` (domyślnie 1800)
  - `STUCK_KILL_GRACE_SECONDS` (domyślnie 20)
- Zachowanie:
  - run przekraczający timeout kończy się kontrolowanie,
  - `meta.txt` dostaje `failure_class=stuck` i `stuck_timeout_hit=1`.

### Task P0.2: Safe-stop semantics
- Pliki: `ralph`, `README.md`
- Dodaj rozróżnienie:
  - `agent.stop` = zatrzymaj po bieżącym runie,
  - `agent.safe-stop` = wymuś zakończenie przy wykrytym ryzyku/policy violation.
- `meta.txt`: `stop_reason=` oraz `stopped_by=`.
- Priorytet sygnałów:
  - watchdog timeout -> `stopped_by=watchdog`, `stop_reason=stuck_timeout`,
  - safe-stop file -> `stopped_by=operator`, `stop_reason=safe_stop`.

### Task P0.3: Taksonomia failure w runtime
- Pliki: `ralph`, `README.md`
- Klasy minimalne:
  - `infra_network`, `test_failure`, `lint_failure`, `policy_violation`, `stuck`, `unknown`.
- `meta.txt` ma zawsze `failure_class=` (także dla sukcesu: `none`).

**DoD P0**
- Nie ma runów wiszących bez klasyfikacji.
- Każdy run ma `failure_class` i `reasoning_*` w `meta.txt`.

## 3.2 P1 — Adaptacyjna niezawodność

### Task P1.1: Retry/backoff
- Pliki: `ralph`, `README.md`
- Dodaj env:
  - `MAX_RETRIES_ON_FAILURE` (domyślnie 1)
  - `BACKOFF_MULTIPLIER` (domyślnie 2)
- Retry tylko dla klas retryowalnych (`infra_network`, `stuck`).

### Task P1.2: Run budget / rate limiting
- Pliki: `ralph`, `README.md`
- Dodaj env:
  - `RUN_BUDGET_WINDOW_SECONDS` (np. 3600)
  - `MAX_RUNS_PER_WINDOW` (np. 30)
- Po przekroczeniu budżetu pętla przechodzi w controlled cooldown.
- Stan budżetu zapisuj w `tasks/logs/run_budget_state.json`, żeby restart procesu nie resetował limitu.

### Task P1.3: Prompt drift fingerprinting
- Pliki: `ralph`, `README.md`
- Zapisuj hashy kontekstu/promptu w `meta.txt`:
  - `context_hash=`, `prompt_hash=`, `prompt_drift=0|1`.
- Gdy `prompt_drift=1`, dopisz `drift_reason=context_changed|prompt_changed` i log warning w stdout.

**DoD P1**
- Powtarzane awarie nie mielą pętli bez końca.
- Widać, czy regresja zbiegła się ze zmianą promptu/policy.

## 3.3 P2 — Eval harness i gate quality

### Task P2.1: Benchmark harness
- Pliki: `benchmarks/run_eval.sh` (nowy), `docs/benchmarks.md` (nowy), `README.md`
- Uruchamia serię zadań referencyjnych i zapisuje raporty do `tasks/logs/benchmarks/*`.
- Format raportu: JSON (`run_id`, `task_id`, `success`, `failure_class`, `duration_seconds`, `test_seconds`, `retry_count`).

### Task P2.2: Baseline i porównanie regresji
- Pliki: `benchmarks/baseline.json` (nowy), `benchmarks/compare.sh` (nowy)
- Metryki: success rate, median `duration_seconds`, median `test_seconds`, retry rate.
- Twardy próg regresji:
  - success rate nie spada > 3 p.p.,
  - median duration nie rośnie > 15%,
  - retry rate nie rośnie > 20%.

### Task P2.3: Gate przed rolloutem
- Pliki: `README.md`, opcjonalnie `scripts/ci-eval.sh`
- Reguła: brak rolloutu zmian prompt/runtime bez `compare.sh` >= baseline.
- Gate jest binarny (exit code 0/1) i blokuje merge/rollout przy niespełnieniu progów.

**DoD P2**
- Każda zmiana w `ralph`/promptach ma porównanie do baseline.

## 3.4 P3 — Pakiet skilli PHP (implementator)

### Task P3.1: `skills/php-context/SKILL.md`
- Trigger: zadanie dotyka PHP i wymaga analizy impactu.
- Output: mapa plików, ryzyka, proponowany scope.

### Task P3.2: `skills/php-implement/SKILL.md`
- Trigger: implementacja feature/fix/refactor w PHP.
- Output: plan zmian po plikach + minimalny diff-plan + check przed commit.

### Task P3.3: `skills/php-validation/SKILL.md`
- Trigger: walidacja po implementacji.
- Output: zestaw testów szybkie->pełne, pomiar czasu, wynik PASS/FAIL.

### Task P3.4: `skills/php-gatekeeper/SKILL.md`
- Trigger: audyt diffu i commit.
- Output: check security/quality + status commit-ready.

### Task P3.5: Integracja skilli
- Pliki: `README.md`, `prompts/pl.md`, `prompts/en.md`
- Dodaj sekcję kolejności pracy:
  - `php-context -> php-implement -> php-validation -> php-gatekeeper`.
- Dodaj wersjonowanie skilli (`version:` w front matter) i changelog w `skills/CHANGELOG.md`.

**DoD P3**
- Zespół ma powtarzalny flow PHP od analizy do commita.

---

## 4) Kryteria akceptacji końcowej

1. Wrapper nie zawiesza się bez sygnału i klasyfikuje failure każdego runu.
2. Retry/backoff i run budget działają przewidywalnie i są widoczne w `meta.txt`.
3. `REASONING=auto` pozostaje aktywne i mierzalne (`requested/selected/reason`).
4. Istnieje eval harness z baseline i porównaniem regresji.
5. Pakiet skilli PHP jest dostępny i opisany w promptach oraz README.
6. Run budget pozostaje skuteczny po restarcie procesu (test restartowy PASS).
7. `prompt_drift=1` generuje czytelny sygnał (`drift_reason`) w logu i metadanych.
8. Eval gate jest egzekwowany (rollout blokowany przy regresji ponad próg).
9. Pilotowe repo PHP przechodzi pełny flow 4 skilli bez manualnych wyjątków.

---

## 5) Plan rolloutu (bezpieczny)

1. Wdrożenie P0 w jednej gałęzi i 2-3 dni obserwacji logów.
2. Wdrożenie P1 i porównanie jakości (przed/po) na tych samych taskach.
3. Uruchomienie P2 (baseline), dopiero potem zmiany promptów na szerszą skalę.
4. Wdrożenie P3 (skills PHP) i krótkie szkolenie zespołu na jednym repo pilotowym.
5. Po pilocie: freeze baseline v1 i dopiero wtedy rollout na kolejne projekty.

---

## 6) Checklista wykonawcza

- [ ] Dodać timeout watchdog i failure taxonomy do `ralph`.
- [ ] Dodać retry/backoff i run budget do `ralph`.
- [ ] Dodać prompt/context hash do `meta.txt`.
- [ ] Dodać `benchmarks/run_eval.sh` + `benchmarks/compare.sh`.
- [ ] Dodać `scripts/report_runs.sh` i raport dzienny JSON.
- [ ] Dodać 4 nowe skille PHP w `skills/`.
- [ ] Dodać `skills/CHANGELOG.md` i wersjonowanie front matter.
- [ ] Zaktualizować `README.md` i `prompts/{pl,en}.md`.
- [ ] Zrobić dry-run na repo pilotowym i zebrać baseline.

---

## 7) Źródła wzorców (do kalibracji)

- OpenAI Codex + praktyki operacyjne: https://openai.com/index/introducing-codex/
- OpenAI evaluation best practices: https://platform.openai.com/docs/guides/evaluation-best-practices
- OpenAI trace grading: https://platform.openai.com/docs/guides/trace-grading
- Anthropic building effective agents: https://www.anthropic.com/engineering/building-effective-agents
- OpenHands stuck detector: https://docs.openhands.dev/sdk/guides/agent-stuck-detector
- SWE-agent (architektura OSS): https://github.com/SWE-agent/SWE-agent
