# Feature: Unified lifecycle-state primitive

> Feature: bts-20-lifecycle-state-primitive
> Work: linear:BTS-20
> Created: 1777243739
> Status: In Progress

## Summary

The implicit lifecycle state machine — Draft → Activated → Plan → Implement → PR → Land → Session-wrap — lives today in skill prose and a partially-overlapping pair of `docs-check.sh` commands (`validate` + `recommend`). Each consumer (skills `/recall`, `/plan`, `/pr`, `/stasis`, `/spec`) re-parses validate output independently. This ship introduces a unified `lifecycle-state` substrate primitive that emits a structured envelope `{state, legal_next_actions[], blockers[], suggestions[]}` consumed via one resolver call. The transition graph lives as data in `.ccanvil/templates/lifecycle-graph.json` instead of scattered prose.

This is **Session-1** of a multi-session ship: primitive design + transition-graph data + `/recall` migration as the proof-point consumer. Session-2/3 migrate `/plan`, `/pr`, `/stasis`. Sessions are explicitly bounded so each lands as a complete substrate ship.

## Job To Be Done

**When** any skill (or future scheduled-agent) needs to know the current lifecycle state and what the legal next actions are,
**I want to** call one substrate primitive that returns a complete machine-readable envelope,
**So that** state-parse logic stops being duplicated across skill prose, transitions are codified as data not narrative, and future skills inherit the gates by construction.

## Acceptance Criteria

- [ ] **AC-1:** `bash .ccanvil/scripts/docs-check.sh lifecycle-state --project-dir .` exits 0 on a clean repo and emits valid JSON matching `{state: string, legal_next_actions: [{action, command, reason}], blockers: [string], suggestions: [string]}`. Drift-guard greps the cmd dispatcher and runs the command on a fixture repo.
- [ ] **AC-2:** `.ccanvil/templates/lifecycle-graph.json` exists, parses as JSON, and contains keys `states[]` and `edges[]`. Each state has `{id, description}`. Each edge has `{from, to, action, guard?, command?}`. Drift-guard validates schema with `jq -e`.
- [ ] **AC-3:** The graph covers (at minimum) the canonical lifecycle states: `no-active-spec`, `spec-drafted`, `spec-activated`, `plan-written`, `implementing`, `pr-open`, `pr-merged`, `session-wrap`. Drift-guard `jq -e '[.states[].id] | contains(["no-active-spec","spec-activated","plan-written"])'`.
- [ ] **AC-4:** Given the current repo (no spec, no plan, session-stasis present, post-compact marker fresh), `lifecycle-state` returns `state == "session-wrap"` with at least one `legal_next_actions` entry whose `action` references `/radar` or `activate`. Drift-guard runs against a constructed fixture.
- [ ] **AC-5:** Given an active spec on a feature branch with no plan, `lifecycle-state` returns `state == "spec-activated"` and `legal_next_actions[]` includes `/plan`. Drift-guard runs against a fixture.
- [ ] **AC-6:** When validate returns `stale-plan` or `mismatched`, `lifecycle-state` surfaces it under `blockers[]` with the validate detail strings. `legal_next_actions[]` is empty (or only contains the recovery action). Drift-guard fixture.
- [ ] **AC-7:** `.claude/skills/recall/SKILL.md` consumes `lifecycle-state` (single call) instead of separate `validate` + `recommend` calls. Drift-guard greps for `lifecycle-state` and asserts `validate` + `recommend` are NOT also invoked side-by-side at recall's top.
- [ ] **AC-8:** Recall's briefing surfaces the new envelope: shows current `state`, lists `legal_next_actions[]` (titles + commands), and includes blockers when present. Drift-guard greps recall prose for the literal phrase `legal next actions`.
- [ ] **AC-9:** Edge: when `lifecycle-state` is invoked outside a git repo or in a non-ccanvil project, exit code is 2 with a JSON error envelope `{error: "...", state: "uninitialized"}`. Drift-guard runs against `/tmp` fixture.
- [ ] **AC-10:** Tests land in `hub/tests/lifecycle-state.bats` with ≥9 cases (one per AC-1..AC-9) plus drift-guards for the recall migration in `hub/tests/recall-skill.bats` (or new `recall-lifecycle-migration.bats` if no recall test file exists).

## Affected Files

| File | Change |
|------|--------|
| `.ccanvil/scripts/docs-check.sh` | New `cmd_lifecycle_state` function + dispatcher entry |
| `.ccanvil/templates/lifecycle-graph.json` | New transition-graph data file |
| `.claude/skills/recall/SKILL.md` | Replace separate validate + recommend with single `lifecycle-state` consumption |
| `hub/tests/lifecycle-state.bats` | New — primitive shape + transition-graph + AC fixtures |
| `hub/tests/recall-skill.bats` (or new file) | Drift-guards for recall migration |
| `.ccanvil/guide/command-reference.md` | Document `lifecycle-state` subcommand |
| `.ccanvil/guide/session-management.md` | Reference the unified primitive in skill orchestration prose |

## Dependencies

- **Requires:** Existing `cmd_validate`, `cmd_recommend`, `cmd_status` (already shipped). `last-compact-ts` marker (BTS-113). `cmd_idea_count` (existing).
- **Blocked by:** None.

## Out of Scope

- **Migrating `/plan`, `/pr`, `/stasis`, `/spec`.** Session-2/3 work — each migration is its own ship with its own drift-guards.
- **Pre-flight gap audit.** Stasis flagged "does plan block if no spec? does activate block on dirty tree? does idea-triage warn on just-captured ideas?" — separate ticket; this ship only codifies what's already enforced, doesn't add new gates.
- **Always-on orchestrator service.** Original BTS-20 scope; deferred (launchd `claude -p` pattern is sufficient).
- **Multi-agent / multi-terminal coordination.** Original BTS-20 scope; not at single-user scale.
- **Cross-node lifecycle coordination.** Lives in `ccanvil-sync.sh`, not the engine.
- **Refactoring `cmd_validate` or `cmd_recommend` internals.** The new primitive consumes their output; it does NOT subsume them. They remain callable for backwards-compat.

## Implementation Notes

- The shape `{state, legal_next_actions[], blockers[], suggestions[]}` is richer than `recommend`'s `{next_action, reason}` — recommend is a single-action emitter; lifecycle-state is the full state envelope. Recommend stays callable; can later be reimplemented as a thin wrapper, but not in this ship.
- The transition-graph JSON shape follows the substrate-data convention (see `.ccanvil/templates/scaffold.json` for the canonical pattern: `{states: [...], edges: [...]}`).
- For AC-4/AC-5/AC-6 fixtures: use the `BATS_TMPDIR`-based fixture pattern from `hub/tests/evidence-scan-session.bats` (constructs a temporary docs/ tree, invokes the cmd, asserts the JSON shape).
- `/recall` migration shape: replace steps 0a + 0b (currently two separate cmd calls) with one `lifecycle-state` call. The briefing render then walks `legal_next_actions[]` and `blockers[]` from the envelope. Keep all other recall data-gathering steps unchanged — this ship is scoped to the state-parse delta, not a recall rewrite.
- Drift-guard pattern follows BTS-200 / BTS-201 — bats tests grep skill prose for required structural elements + execute the substrate primitive against fixtures.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
