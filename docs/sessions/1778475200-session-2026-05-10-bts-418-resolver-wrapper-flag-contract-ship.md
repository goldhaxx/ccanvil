# Stasis: session-2026-05-10-bts-418-resolver-wrapper-flag-contract-ship

> Feature: session-2026-05-10-bts-418-resolver-wrapper-flag-contract-ship
> Kind: session
> Last updated: 1778475200
> Session: 43
> Boundary: 2026-05-10T21:02:16-07:00
> Session objective: Pick up BTS-418 spec-to-ship arc — companion to BTS-419 (closes BTS-407-shape regression class)

## Accomplished

Session 43 — BTS-418 spec to /spec --review critic to activate to plan to 9-step TDD to review to PR to ship, end-to-end in one turn. Pair-ship with BTS-419 (session 42) now structurally closes the BTS-407-shape regression class.

* **BTS-418 SHIPPED** (PR #179, merge `c2d65f8`). Added a static-analysis bats fixture in `hub/tests/operations-drift-guard.bats` that, for every http-mechanism resolver verb in `linear_mcp_adapter`, statically verifies every emitted `--<flag>` is accepted by the target `linear-query.sh` subcommand's case-arm parser. 4 inline bats helpers (`_emitted_flags`, `_wrapper_accepted_flags`, `_target_wrapper_subcmd`, `_check_flag_contract` + envelope variant). 27 new bats covering all 7 ACs. Catches BTS-407-shape regressions at merge time before they ship to downstream nodes.
* **/spec --review critic-mode dogfood — first non-trivial run, caught a real ambiguity.** The critic agent flagged AC-3's "maximal-config fixture" as undefined for non-idea-class verbs (ticket.get, spec.read/write, plan.read/write, stasis.read/write). Fix: enumerated the Maximal-Config Fixture definition in Implementation Notes — single fixture `_with_linear_routing_and_project_id` covers ALL listed verbs because (a) idea-class verbs emit ALL conditional flags under full config, (b) transition-class is fixed positional + `--id` + `--state`, (c) document-class has NO conditional flags. Spec re-dispatched, validate → status: ok. Critic-mode prevented a spec-to-implementation interpretation drift that would have surfaced as test-coverage uncertainty mid-implementation.
* **Plan resolved the 3 architectural open questions** at plan time (not spec time, per session 42's pattern). Option 1 (inline bats helpers) over Option 2 (shared substrate script) — chosen for lightest-weight + zero-new-substrate; promote to Option 2 only if `/review` or `/ccanvil-audit` calls for the same check from outside bats. One `@test` per verb (mirrors BTS-419 Step 7/8). Hub-only fixture (BTS-419's runtime self-consistency defends downstream nodes; this static check defends the hub at merge time).
* `awk -v` regex interpolation gotcha caught + fixed in first iteration. Initial `_wrapper_accepted_flags` used `awk -v fn="^${fn_name}\\(\\) \\{" '$0 ~ fn,/^}/'` to range-match cmd_function bodies. Failed silently because awk's `-v` escape-processing on `\(` is unspecified across awk implementations. Fixed by using string-equality on the literal opener line: `awk -v opener="${fn_name}() {" '$0 == opener { p=1 } p { print } p && $0 == "}" { p=0 }'`. Stable across BSD-awk and gawk. Failure pattern was diagnostic: Step 2b failed → cascade to all live-resolve tests → fixed at the root.
* **Code-reviewer surfaced 2 forward-looking WARN findings** — addressed as code comments (commit `8fcfab6`): (W1) documented `--flag=value` form is out of scope + stdin-sentinel `-` is correctly non-matched; (W2) noted the column-0 `}` range-close is structurally fragile if a future `cmd_` body adds a nested helper/here-doc closing at column 0 — `declare -f` after sourcing is the robust alternative.

## Current State

* **Branch:** `main` (clean, fast-forward through `c2d65f8`).
* **Tests:** 2215 / 2216 from the parallel full-suite run mid-/pr. The 1 failure is a pre-existing parallel-execution flake in `hub/tests/module-manifest-query-helpers.bats:46` (`query: --by-side-effect surfaces matched primitives`) — confirmed 8/8 pass when that file is run serially. Targeted post-implementation sweep: `hub/tests/operations*.bats` 122/122 GREEN. BTS-418 fixture alone: 53/53 (26 BTS-419 carry-forward + 27 new BTS-418).
* **Uncommitted changes:** none.
* **Build status:** clean. PR #179 merged + branch deleted + BTS-418 auto-closed to Done. Manifest 194/194 drift 0.

## Blocked On

Nothing.

## Next Steps

1. **BTS-314 (P2)** — Onboarding theme cluster opener: Linear-config audit + heal pass for the 3 drifted nodes (inbox-toolbox + microsoft365-toolbox config divergences flagged 2026-05-06). Roadmap-aligned. With BTS-419/BTS-418 closing the resolver-correctness substrate, the next theme is downstream-node correctness.
2. **BTS-417 (P3)** — Layer 3 ramp prose tuning — 3 small edits from BTS-317 audit. Cache-warm cadence-eligible.
3. **Investigate module-manifest-query-helpers parallel flake.** Today: capture as a triage ticket. The test passes serially but fails \~1× per parallel run. Suspect race with another test that calls `cmd_index` (which writes `manifests.json`) concurrently. Low-priority but worth a deterministic fix to stop polluting `/pr` test reports.
4. **BTS-204 — SSOT-Linear** (Triage, major effort, dedicated session). Still ambient strategic work.

## Context Notes

* **Pair-ship complete.** BTS-419 + BTS-418 together structurally close the BTS-407 regression class. The two guards enforce adjacent contracts: BTS-419 = resolver self-consistency (config → emitted flags); BTS-418 = resolver-emit → wrapper-accept flag-set acceptance. Future BTS-407-shape regressions are now caught at merge time (BTS-418) AND at runtime on stale downstream nodes (BTS-419) — both directions.
* **Critic-mode validates spec at the right granularity.** The validator's `missing-given-when-then` flag was an INFO-level smoke detector; the critic-mode agent caught a real semantic ambiguity (undefined "maximal config") that validate-spec couldn't see. Session 43 anchor: run critic-mode after validate-spec for non-trivial specs. The two checks are complementary, not redundant.
* **Maximal-Config-Fixture definition is a substrate-fitness signal.** When a spec's coverage claim ("all verbs covered by one fixture") requires arguing why the fixture is exhaustive across verb classes, that argument belongs in the spec, not in the implementer's head. Inline the audit (idea-class / transition-class / document-class) in Implementation Notes so the next session reads the substrate fit directly.
* **awk** `-v` regex escape behavior is unspecified. Don't rely on `awk -v fn="literal-with-backslash-escapes" '$0 ~ fn'` for portable scripts. Use string-equality with `==` and a literal-text variable instead. BSD-awk vs gawk vs nawk diverge on `-v`'s backslash-processing semantics. Anchored in W1's helper implementation; would have surfaced in a downstream node with a different awk if not caught here.
* **Code-reviewer false-positive defense holds (session 42 carryover).** Empirically verified before applying any fix; this session no false positives (both WARNs were genuine forward-looking concerns, addressed as code comments without functional change). The discipline saves cycles on legitimate corrections too — the agent's findings are still useful even when they don't require code edits.

## Determinism Review

operations_reviewed: 14
candidates_found: 0

No candidates this session.

The architecture-by-the-book outcome (again — session 42 pattern): the fixture itself replaced what would have been a stochastic "code review catches resolver-wrapper flag drift" pattern with deterministic shell parsing. Critic-mode + validate-spec replaced what would have been a stochastic "did the spec capture coverage rigorously" judgment with structured per-class enumeration. No emergent stochastic ops fell out of the implementation.

## Evidence Gaps

No evidence gaps this session.

## Manifest Coverage

194 / 194 (allowlist), drift incidents: 0. Status: ok. Unchanged from session 42.

## Cross-Session Patterns

* **Recurring (positive, now 6+ sessions): one-turn-spec-to-ship cadence at substrate maturity.** Session 42 shipped BTS-419 in one turn; session 43 shipped BTS-418 in one turn. Both followed identical shape: spec → critic → activate → plan → TDD → review → /pr → /ship. Cadence works when (a) substrate is mature enough that the spec writes itself off existing primitives, and (b) the ticket is structurally adjacent to a recent ship (BTS-418 reused BTS-419's fixture file + helpers). Pair-tickets with this shape will continue to be one-turn-eligible.
* **NEW (this session): /spec --review (critic mode) is a high-value pre-activate gate.** First non-trivial usage caught a real spec-coverage ambiguity that would have surfaced as implementer-uncertainty mid-implementation. Cost: one agent invocation + one spec edit + re-dispatch. Benefit: zero mid-implementation drift, zero half-built then-discarded test fixtures. Adopt as standard pre-activate gate for tickets with ≥3 ACs OR explicit "Implementation Notes options" sections.
* **Recurring (positive, holding): review catches real failure-mode drift even when manifest validate is clean.** Session 42's BTS-419 W2 finding (cmd_resolve manifest missing the new exit-path declaration). Session 43's W1+W2 findings are forward-looking, not drift — different shape but same value pattern. Manifest validate is the structural floor; code-reviewer is the semantic ceiling.
* **NEW (this session): bats parallel-execution flakes are real and worth a dedicated fix.** 1/2216 flake (`module-manifest-query-helpers.bats:46`) is environmental, but it shows up consistently enough in `/pr` runs that it noisified this session's test report. Capture as a triage ticket on next /idea triage pass.
* **No legacy-refs drift** (legacy-refs-scan: 0 matches).
* **No audit-session findings** (`audit-session --since c2d65f8`: 0 findings — empty diff against the just-merged commit).

## Security Review

PASS — no secret/PII patterns introduced this session. Diff content is bats + spec/plan markdown only; new helpers parse JSON envelopes and shell strings, no env-variable reads, no file writes outside the bats temp tree. Security audit baseline noise (17 pre-existing findings in session archives + spec markdown for BTS-394/395/72) unchanged.

## Memory Candidates

* **Feedback (validated):** `feedback_critic_mode_catches_coverage_ambiguity` — for specs with ≥3 ACs OR explicit "Implementation Notes options" sections, run `/spec --review` BEFORE /activate. Critic-mode catches semantic ambiguity (undefined "maximal config", under-defined coverage claims) that validate-spec's structural floor cannot see. Session 43 anchor: BTS-418 AC-3 maximal-config ambiguity caught + fixed pre-activate. (Companion to existing `feedback_critic_mode_finds_real_findings_on_validated_specs` — refines the trigger heuristic.)
* **Feedback (validated):** `feedback_awk_v_regex_interpolation_unportable` — `awk -v var="regex-with-backslash-escapes" '$0 ~ var'` is non-portable across awk implementations; backslash-escape processing in `-v` is unspecified. Use `awk -v var="literal-string" '$0 == var'` for stable matching. Anchored in BTS-418 `_wrapper_accepted_flags` implementation.
* **Feedback (validated):** `feedback_pair_ship_shape_makes_one_turn_cadence_feasible` — when shipping the second of a pair of structurally-adjacent tickets, the first ship's fixture/substrate is the leverage. BTS-418 reused BTS-419's `_with_*` config helpers + sourceability guards + file location. One-turn ship was possible because the substrate was already laid down. Recognize pair-shape at /spec time and budget accordingly.
* **Project:** `project_bts_407_regression_class_closed` — BTS-419 (session 42, PR #178) + BTS-418 (session 43, PR #179) together close the BTS-407-shape resolver-correctness regression class. Forward: resolver flag-set changes are caught at merge time (BTS-418 static check) AND at runtime on stale nodes (BTS-419 self-consistency check). Both directions defended.
* **Reference:** `reference_module_manifest_query_helpers_parallel_flake` — `hub/tests/module-manifest-query-helpers.bats:46` (`query: --by-side-effect surfaces matched primitives`) exhibits a parallel-execution flake; passes 8/8 serially. Suspect race with concurrent `cmd_index` writes. Triage ticket pending.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->