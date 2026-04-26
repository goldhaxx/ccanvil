# Implementation Plan: Unified lifecycle-state primitive

> Feature: bts-20-lifecycle-state-primitive
> Work: linear:BTS-20
> Created: 1777243800
> Spec hash: 5e1fb823
> Based on: docs/spec.md

## Objective

Ship `docs-check.sh lifecycle-state` (a structured-envelope primitive over `validate` + `recommend` + git state) plus the codified `lifecycle-graph.json`, then migrate `/recall` onto it as the proof-point consumer.

## Sequence

### Step 1: Codify the transition graph as data

- **Test:** `hub/tests/lifecycle-state.bats` — assert `.ccanvil/templates/lifecycle-graph.json` parses, has `states[]` and `edges[]`, every state has `{id, description}`, every edge has `{from, to, action}`, and the canonical state IDs from AC-3 are present.
- **Implement:** Write `.ccanvil/templates/lifecycle-graph.json`. States: `no-active-spec`, `spec-drafted`, `spec-activated`, `plan-written`, `implementing`, `pr-open`, `pr-merged`, `session-wrap`, `blocked`. Edges link states with `{action, command, guard}` where guard is a free-text predicate name (e.g., `branch-on-claude-prefix`, `validate-aligned`, `stasis-fresh-vs-compact-marker`). Keep guards as descriptive strings — Session-1 doesn't execute predicates programmatically; codifying them as data is the goal.
- **Files:** `.ccanvil/templates/lifecycle-graph.json` (new); `hub/tests/lifecycle-state.bats` (new with AC-2, AC-3 tests).
- **Verify:** `bash .ccanvil/scripts/bats-report.sh -f 'lifecycle-state'` shows AC-2, AC-3 green; nothing else changed.

### Step 2: Implement `cmd_lifecycle_state` clean-state path (AC-1)

- **Test:** `hub/tests/lifecycle-state.bats` AC-1 — invoke `bash .ccanvil/scripts/docs-check.sh lifecycle-state --project-dir <fixture>`, assert exit 0 + valid JSON shape `{state, legal_next_actions[], blockers[], suggestions[]}`. Fixture is a temp dir initialized with no docs.
- **Implement:** Add `cmd_lifecycle_state` to `.ccanvil/scripts/docs-check.sh`. Reads `cmd_validate` output + git branch + active-spec presence. Maps to a state ID. For Step 2, only handle the `no-active-spec` / `no docs` case. Build the envelope. Add dispatcher entry: `lifecycle-state) cmd_lifecycle_state "$@" ;;`.
- **Files:** `.ccanvil/scripts/docs-check.sh` (modified — new function + dispatcher).
- **Verify:** AC-1 test passes; existing tests still pass.

### Step 3: Map validate results to lifecycle states (AC-4, AC-5, AC-6)

- **Test:** Three new bats cases in `lifecycle-state.bats`:
  - AC-4 fixture: no spec, no plan, session-stasis present, fresh post-compact marker → `state == "session-wrap"`, `legal_next_actions[]` non-empty.
  - AC-5 fixture: active spec on feature branch, no plan → `state == "spec-activated"`, `legal_next_actions[]` includes `/plan`.
  - AC-6 fixture: stale-plan validate result → `blockers[]` carries the validate detail strings; `legal_next_actions[]` only contains the recovery action.
- **Implement:** Extend `cmd_lifecycle_state` to walk validate result + spec/plan/stasis exists + session-vs-feature stasis kind + branch name + last-compact-ts marker. Emit the right state. For each state, derive `legal_next_actions[]` from the transition graph (read the JSON, filter edges by `from == state`).
- **Files:** `.ccanvil/scripts/docs-check.sh` (modified — flesh out the state mapping + transition-graph consumption).
- **Verify:** AC-4, AC-5, AC-6 tests pass.

### Step 4: Edge case — uninitialized repo (AC-9)

- **Test:** AC-9 in `lifecycle-state.bats` — `cd /tmp && bash <abs-path>/docs-check.sh lifecycle-state --project-dir .` exits 2 with `{error, state: "uninitialized"}`.
- **Implement:** Detect missing `.ccanvil/scripts/` (or non-git repo) and emit the error envelope with exit 2.
- **Files:** `.ccanvil/scripts/docs-check.sh`.
- **Verify:** AC-9 passes; full bats green.

### Step 5: Migrate `/recall` onto the new primitive (AC-7, AC-8)

- **Test:** New `hub/tests/recall-skill.bats` — drift-guards: skill mentions `lifecycle-state`; does NOT invoke `validate` and `recommend` separately at top of data-gathering; mentions `legal next actions` (literal phrase) in the briefing prose.
- **Implement:** Edit `.claude/skills/recall/SKILL.md`. Replace steps 0a + 0b with a single `lifecycle-state` invocation. Update the briefing-render prose to walk `state`, `legal_next_actions[]`, `blockers[]` from the envelope. Keep all other steps (1-10) unchanged.
- **Files:** `.claude/skills/recall/SKILL.md` (modified); `hub/tests/recall-skill.bats` (new).
- **Verify:** AC-7, AC-8 tests pass. Run `/recall`-equivalent dry-run by calling `bash .ccanvil/scripts/docs-check.sh lifecycle-state --project-dir .` from this repo — confirm the envelope renders cleanly.

### Step 6: Live-API validation gate

The primitive is local-deterministic; no live-API calls. Skip — no contract risk to verify.

### Step 7: Documentation update

- **Implement:**
  - `.ccanvil/guide/command-reference.md` — add `lifecycle-state` row to the `docs-check.sh` subcommand table.
  - `.ccanvil/guide/session-management.md` — note the unified primitive in skill-orchestration prose.
- **Files:** Both files modified.
- **Verify:** Drift-guards (if any) for guide files still pass; full bats green.

### Step 8: Final verification

- Run `bash .ccanvil/scripts/bats-report.sh --parallel`. Expected: prior count + ≥10 (one per AC) + recall-migration drift-guards. All green.
- Confirm no uncommitted changes outside the planned files.

## Risks

- **Transition-graph completeness drift.** AC-3 only enforces a minimum-set; the actual graph could be incomplete and still pass tests. Mitigation: list every legal transition observed in skill prose during Step 1; when in doubt, add the edge.
- **Recall-skill prose drift between SKILL.md and tests.** The new drift-guards will fail any future SKILL.md edit that drops `lifecycle-state` consumption — that's intentional and correct.
- **`cmd_validate` semantics already cover most of the logic.** Risk of duplication if `lifecycle-state` re-implements validate's checks. Mitigation: lifecycle-state CONSUMES `cmd_validate` output, never re-derives it. Validate stays the source of truth for alignment; lifecycle-state composes alignment + git state + transition graph into the envelope.
- **Session creep — temptation to also migrate `/plan` or `/pr` "while I'm in here."** Out-of-scope per spec. If the migration shape proves clean, capture follow-up tickets for Session-2; do NOT bundle.

## Definition of Done

- [ ] All 10 acceptance criteria from spec pass
- [ ] All existing tests still pass (1575 baseline + new tests)
- [ ] No bash lint errors (`bash -n`)
- [ ] Code reviewed (run /review)

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
