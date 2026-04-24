# Implementation Plan: ticket.transition operation verb

> Feature: bts-128-ticket-transition
> Work: linear:BTS-128
> Created: 1776992519
> Spec hash: 65b0d666
> Based on: docs/spec.md

## Objective

Add a provider-neutral `ticket.transition <id> <role>` verb to `operations.sh` that resolves a role → state-UUID lookup + pre-stitches a ready-to-dispatch Linear `save_issue` payload, collapsing the recurring manual UUID-paste pattern into a single deterministic call.

## Sequence

Six phases, 12 TDD steps. Each step is one red-green-refactor commit. Tests first; no implementation without a failing test on the prior line.

### Phase 1 — Operation registration + argument parsing

#### Step 1: Register `ticket.transition` as a valid operation (AC-1)
- **Test:** New bats file `hub/tests/ticket-transition.bats` asserting `operations.sh resolve ticket.transition BTS-1 backlog` does NOT fail with `ERROR: unknown operation`. Start the test expecting success status.
- **Implement:** Add `ticket.transition` to the `is_valid_operation` switch in `operations.sh` (line 28-43).
- **Files:** `hub/tests/ticket-transition.bats` (new), `.ccanvil/scripts/operations.sh` (modified).
- **Verify:** `bats hub/tests/ticket-transition.bats` first test passes; all prior tests still green.

#### Step 2: Extend arg parser to consume a second positional (AC-8)
- **Test:** Add assertion that after parsing `resolve ticket.transition BTS-1 backlog`, the second arg `backlog` is captured as a new `OP_ARG2` variable (observable via JSON output once the resolver is wired). Also add a regression test that an existing single-arg operation (e.g., `backlog.get BTS-42`) still produces its existing JSON shape.
- **Implement:** Duplicate the single-arg parse block (lines 84-86) to optionally consume a second positional into `OP_ARG2`. Initialize `OP_ARG2=""` at top. Do NOT change the single-arg semantics of existing operations.
- **Files:** `.ccanvil/scripts/operations.sh` (modified).
- **Verify:** `bats hub/tests/ticket-transition.bats` parser test green; full suite still passes (no regression to single-arg operations).

### Phase 2 — Happy-path resolver

#### Step 3: Resolver emits Linear MCP payload for `backlog` role (AC-2)
- **Test:** `hub/tests/ticket-transition.bats` — fixture writes a Linear-configured `.claude/ccanvil.json` with `state_ids.backlog` populated. `operations.sh resolve ticket.transition BTS-1 backlog` must emit JSON with `.provider == "linear"`, `.mechanism == "mcp"`, `.invocation.tool == "mcp__claude_ai_Linear__save_issue"`, `.invocation.params.id == "BTS-1"`, `.invocation.params.stateId` matching the fixture's backlog UUID.
- **Implement:** Add `ticket.transition)` case to `linear_mcp_adapter` (after existing idea.* cases, ~line 617). Use the existing `linear_state_id` helper to look up the role. Emit `params: {id: $id, stateId: $state_id}` via `jq -n --arg id ... --arg state_id ... --arg tool ...`.
- **Files:** `.ccanvil/scripts/operations.sh` (modified), `hub/tests/ticket-transition.bats` (modified).
- **Verify:** AC-2 test green.

#### Step 4: Resolver supports all six roles including `done` (AC-3)
- **Test:** Parameterize the happy-path test across all six roles — `triage`, `backlog`, `icebox`, `canceled`, `duplicate`, `done`. Each asserts the resolved `.stateId` matches the fixture's corresponding UUID. The `done` assertion uses a test-fixture UUID since no production config has `done` yet.
- **Implement:** No code change expected — the generic `linear_state_id "$provider_config" "$role"` call already handles any role name. This test validates that.
- **Files:** `hub/tests/ticket-transition.bats` (modified).
- **Verify:** All six role assertions pass against the test fixture.

#### Step 5: Populate `done` UUID in production config (AC-4)
- **Test:** Smoke test — from the project root, `operations.sh resolve ticket.transition BTS-130 done` emits JSON with `.invocation.params.stateId == "bc6aa160-258d-4eae-b3b5-a2575732a188"`. This uses the REAL project config (not a test fixture) and confirms the config edit landed.
- **Implement:** Edit `.claude/ccanvil.local.json` to add `"done": "bc6aa160-258d-4eae-b3b5-a2575732a188"` to the `state_ids` block. Preserve trailing-comma hygiene.
- **Files:** `.claude/ccanvil.local.json` (modified).
- **Verify:** Smoke-test command produces the expected stateId; full bats suite still green.

### Phase 3 — Error paths

#### Step 6: Unknown role rejected with vocabulary listing (AC-7)
- **Test:** `operations.sh resolve ticket.transition BTS-1 nonsense` exits non-zero; stderr contains "unknown role" plus an enumerated list of valid roles (`triage`, `backlog`, `icebox`, `canceled`, `duplicate`, `done`).
- **Implement:** In the `ticket.transition)` adapter branch, validate role against a local allowlist BEFORE the `linear_state_id` lookup. Emit the error + exit 1 on mismatch.
- **Files:** `.ccanvil/scripts/operations.sh` (modified), `hub/tests/ticket-transition.bats` (modified).
- **Verify:** AC-7 test green.

#### Step 7: Missing args produce distinct errors (AC-6)
- **Test:** Two tests — (a) `resolve ticket.transition` (no args) exits non-zero with "id required"; (b) `resolve ticket.transition BTS-1` (no role) exits non-zero with "role required". Error messages must be distinct.
- **Implement:** At the start of the `ticket.transition)` branch, check `$op_args` (id) for empty-string → emit "id required" error + exit 1. Check `$OP_ARG2` (role) for empty-string → emit "role required" error + exit 1. Route `OP_ARG2` through to the adapter (pass as additional function arg or via env).
- **Files:** `.ccanvil/scripts/operations.sh` (modified), `hub/tests/ticket-transition.bats` (modified).
- **Verify:** Both AC-6 sub-tests green.

#### Step 8: Unconfigured role fails loud (AC-5)
- **Test:** Fixture config with `state_ids` block that is missing the `done` key. `resolve ticket.transition BTS-1 done` exits non-zero; stderr names both `done` and the config path.
- **Implement:** After the `linear_state_id` lookup, if the result is empty, emit "role 'X' not configured in <config-path>:state_ids" + exit 1. (Existing idea mutations silently fall through to name-based dispatch on empty state_id; here we fail loud because the wrapper's contract is UUID-only.)
- **Files:** `.ccanvil/scripts/operations.sh` (modified), `hub/tests/ticket-transition.bats` (modified).
- **Verify:** AC-5 test green.

#### Step 9: Local provider returns unsupported (AC-9)
- **Test:** Fixture with no `.claude/ccanvil.json` (local-provider default). `resolve ticket.transition BTS-1 backlog` exits non-zero with "provider local does not support ticket.transition".
- **Implement:** Add `ticket.transition)` case to `local_adapter` that unconditionally emits the unsupported error + exit 1. This makes the capability gap explicit instead of a confusing fall-through.
- **Files:** `.ccanvil/scripts/operations.sh` (modified), `hub/tests/ticket-transition.bats` (modified).
- **Verify:** AC-9 test green.

### Phase 4 — /idea skill refactor (AC-10)

#### Step 10: Refactor /idea skill dispatches to use `ticket.transition`
- **Test:** The skill is prose-driven, not unit-testable. Instead, verify by (a) reading through the updated SKILL.md for internal consistency — each of triage/defer/dismiss/merge sections now points to `ticket.transition` with the right role, and (b) running an end-to-end smoke test: set up a test fixture idea in a scratch directory, invoke the updated skill flow, confirm the state transitions happen.
- **Implement:** Edit `.claude/skills/idea/SKILL.md`:
  - In the Triage dispatch rubric table, replace each "Linear dispatch" entry that hand-assembles `save_issue { id, stateId: <params.stateId> }` with `operations.sh resolve ticket.transition <id> <role>` → then dispatch the returned resolution.
  - Promote keeps priority in the dispatch (priority is not part of ticket.transition — the caller adds it alongside the returned stateId).
  - Merge keeps `duplicateOf` in the dispatch (same reasoning — ticket.transition provides the stateId, caller adds the duplicate link).
  - Keep the existing fallback-to-pending-log behavior — that remains in the skill.
- **Files:** `.claude/skills/idea/SKILL.md` (modified).
- **Verify:** Skill prose passes a self-consistency read; BTS-131-135 migrations earlier in this session demonstrate the triage flow works end-to-end (no regression expected since the underlying MCP call is the same).

### Phase 5 — Documentation (AC-11)

#### Step 11: Document `ticket.transition` in command-reference.md
- **Test:** `grep -q 'ticket.transition' .ccanvil/guide/command-reference.md` returns 0.
- **Implement:** Add a row for `ticket.transition` to the operations verb table (near the existing `work.resolve` entry). Add a short paragraph with the arg shape, the six supported roles, and one example invocation (`operations.sh resolve ticket.transition BTS-128 done`).
- **Files:** `.ccanvil/guide/command-reference.md` (modified).
- **Verify:** Grep test passes; read-through for clarity.

### Phase 6 — Regression

#### Step 12: Full bats suite green (AC-12)
- **Test:** `bats hub/tests/` produces 836+ ok, 0 not ok.
- **Implement:** No code change; if any test fails, bisect and fix the regression.
- **Verify:** Total count ≥ 842 (836 baseline + 6 new). Zero failures.

## Risks

- **Arg-parser change could regress single-arg operations.** Mitigation: Step 2's regression test explicitly covers an existing single-arg operation (`backlog.get BTS-42`) emitting unchanged JSON. If any existing bats test references operations-with-args, run those tests before and after Step 2.
- **`OP_ARG2` plumbing through adapters.** The adapter functions currently take `op`, `provider_config`, `op_args` — adding a second arg means threading a new parameter through `local_adapter`, `linear_mcp_adapter`, and `external_adapter`. Mitigation: pass `OP_ARG2` as a 4th positional to the adapter functions, default to empty string. Keeps ordering clean; no existing callers break because bash positional args past the declared ones are harmless.
- **`done` role unconfigured on downstream nodes.** Fucina and luxlook don't have `done` in their state_ids. Mitigation: AC-5 (unconfigured role → loud error) ensures downstream users get a clear actionable error message rather than a silent Linear server 400. Document the config migration path in Step 11's doc update.
- **`/idea` skill refactor introduces prose drift.** The skill's triage table is dense; reordering could muddy the existing agentic contract. Mitigation: change the dispatch column only, keep the outcome/verb columns untouched. Diff review in the code-review gate will catch drift.
- **Test fixture state_ids need to be independent from production.** The ticket-transition bats fixture must stand up its OWN `.claude/ccanvil.json` with a known `state_ids` block, not read the project's `ccanvil.local.json`. Mitigation: follow the same fixture pattern used in `work-resolve.bats` and `validate-work-alignment.bats` (per-test `PROJECT` directory with its own config).

## Definition of Done

- [ ] All 12 acceptance criteria from `docs/spec.md` pass
- [ ] Full bats suite green (≥ 842 tests, 0 failures)
- [ ] No regressions in existing single-arg operation tests
- [ ] Code reviewed (run `/review` — WARN fixes pre-merge per BTS-130 precedent)
- [ ] `.ccanvil/guide/command-reference.md` documents the new verb
- [ ] Smoke test: `operations.sh resolve ticket.transition BTS-128 done` against the real project config emits the correct Blocktech Done UUID

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
