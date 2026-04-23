# Implementation Plan: idea.add routes Linear captures to Triage via stateId

> Feature: idea-add-triage-routing
> Created: 1776968877
> Spec hash: f3fa3e8f
> Based on: docs/spec.md

## Objective

Apply the conditional-stateId-merge pattern from `idea.promote/defer/dismiss/merge` to the `idea.add` Linear resolver so captures land in Triage instead of Backlog.

## Sequence

Each step is one red-green-refactor cycle. All tests run via `bats hub/tests/<file>.bats -f "<filter>"` with output captured to `/tmp/bats.out` (single invocation, no `| tail` chaining).

### Step 1: AC-1 — stateId emitted when state_ids.triage configured

- **Test:** New bats test in `hub/tests/idea-triage-native.bats`, modeled on "Step 2: idea.triage resolve includes state_ids.triage as params.stateId" at line 102. Uses `_linear_config_with_state_ids` fixture; asserts `.invocation.params.stateId == "aaaaaaaa-0000-0000-0000-000000000001"`.
- **Implement:** Modify `.ccanvil/scripts/operations.sh:365-376` — `idea.add` Linear resolver. Add `local triage_state_id; triage_state_id=$(linear_state_id "$provider_config" "triage")`. Merge stateId into params via `+` object-merge guarded by `if $state_id != ""`.
- **Files:** `.ccanvil/scripts/operations.sh` (resolver), `hub/tests/idea-triage-native.bats` (new test).
- **Verify:** `bats hub/tests/idea-triage-native.bats -f "idea.add.*stateId"` passes (red → green).

### Step 2: AC-3 — stateId omitted when state_ids absent

- **Test:** New bats test using `_linear_config_no_state_ids` fixture; assert `.invocation.params | has("stateId") | not`. Mirrors "Step 5: Linear idea.promote omits stateId when state_ids absent" at line 427.
- **Implement:** No code change needed — conditional merge from Step 1 already handles this. Test confirms.
- **Files:** `hub/tests/idea-triage-native.bats`.
- **Verify:** Test passes on first run (green without red) because Step 1's conditional merge already guards.

### Step 3: AC-5 — stateId omitted when empty string

- **Test:** New bats test — write config where `state_ids.triage = ""`; assert `.invocation.params | has("stateId") | not`.
- **Implement:** No code change — `if $state_id != ""` already covers empty string. Test prevents regression.
- **Files:** `hub/tests/idea-triage-native.bats`.
- **Verify:** Test passes without red.

### Step 4: AC-2 + AC-4 — params contract (existing fields + no `state` name)

- **Test:** Extend Step 1 test to assert `.invocation.params.project`, `.invocation.params.team`, `.invocation.params.labels[0] == "idea"` are still present AND `.invocation.params | has("state") | not`. Confirms stateId is additive and name-based dispatch stays forbidden.
- **Implement:** None if assertions already pass.
- **Files:** `hub/tests/idea-triage-native.bats`.
- **Verify:** Extended test passes.

### Step 5: Update superseded AC-15 test

- **Test:** `hub/tests/ideas-to-linear.bats:113` — the existing "AC-15: idea.add with Linear routing" test. Without `state_ids` in `_linear_config` fixture, stateId should be absent (per AC-3). Keep existing `has("state") | not` assertion. Add `has("stateId") | not` assertion to document the before-migration behavior. Comment the test as superseded by Step 1.
- **Implement:** No code change.
- **Files:** `hub/tests/ideas-to-linear.bats`.
- **Verify:** Existing test file still green.

### Step 6: Refactor — update stale comments + skill doc

- **Test:** No new test.
- **Implement:** 
  - Update comment at `.ccanvil/scripts/operations.sh:367-371` — drop "Linear routes API-created issues to the team's native Triage intake surface automatically" (falsified); replace with "Explicit stateId dispatch targets Triage when state_ids.triage is configured; falls through to team default when unconfigured (backward-compat)."
  - Update `/idea` SKILL.md at `.claude/skills/idea/SKILL.md:48` — the "**no `state` param** — Linear auto-routes..." note. Replace with: "The resolver injects `stateId` from `state_ids.triage` when configured; otherwise the capture falls through to the team's default state."
  - Update `.ccanvil/guide/command-reference.md` if it references the auto-routing claim (grep to confirm).
- **Files:** `.ccanvil/scripts/operations.sh`, `.claude/skills/idea/SKILL.md`, `.ccanvil/guide/command-reference.md` (if hit by grep).
- **Verify:** `grep -r "auto-route\|auto-routes" .ccanvil/ .claude/skills/` returns zero hits.

### Step 7: Full test suite

- **Test:** `bats hub/tests/ > /tmp/bats.out 2>&1; grep -cE '^(ok|not ok)' /tmp/bats.out; grep -cE '^not ok' /tmp/bats.out`.
- **Implement:** Fix any regressions surfaced.
- **Verify:** All tests green (not ok count == 0); total count ≥ prior baseline of 804.

### Step 8: Live smoke test (dogfood)

- **Test:** None — manual MCP probe.
- **Implement:** Run `bash .ccanvil/scripts/operations.sh resolve idea.add --project-dir .` on this branch; confirm `.invocation.params.stateId == "53b10a02-ce3c-4990-aebc-e105c7229a37"` (the configured triage UUID from `.claude/ccanvil.local.json:11`). Capture a live idea via `/idea <smoke test>`; confirm Linear returns `statusType: "triage"` and the issue appears in the Triage inbox. Transition the smoke-test issue to Canceled after verification.
- **Files:** None modified.
- **Verify:** Live capture lands in Triage on first try. If Backlog, debug and iterate.

### Step 9: Commit + review

- **Test:** None.
- **Implement:** Stage all changes. Commit on the feature branch with message `feat(idea-add-triage-routing): route captures to Triage via stateId`. Run `/review` and address findings.
- **Files:** All modified files from prior steps.
- **Verify:** Clean working tree; review passes with no CRITICAL findings.

## Risks

- **Risk:** `jq -n` object-merge syntax differs subtly between macOS (bsd jq) and Linux. Mitigation: use the same `+` pattern proven in `idea.promote` at line 439 — already cross-platform tested.
- **Risk:** Additive stateId could conflict with a future Linear MCP change that treats `stateId` on create differently than on update. Mitigation: AC-6 locks the skill dispatch to the resolver shape; if Linear changes semantics, the test suite flags immediately.
- **Risk:** Smoke test in Step 8 creates Linear noise. Mitigation: prefix capture with "SMOKE TEST:" and transition to Canceled immediately after verification. Alternatively, use a throwaway text like "smoke-BTS-121" for clarity.
- **Risk:** Any stasis/commit pollution from session boundaries during this flow. Mitigation: pre-activate guard already cleared (main pushed to origin); commits land cleanly on feature branch.

## Definition of Done

- [ ] All 6 acceptance criteria from spec pass (covered across Steps 1-6).
- [ ] All existing tests still pass (Step 7 — full suite green).
- [ ] Live smoke test confirms Triage routing (Step 8).
- [ ] Stale "auto-routes" comments eliminated (Step 6 — grep clean).
- [ ] Code reviewed via `/review` with no CRITICAL findings (Step 9).

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
