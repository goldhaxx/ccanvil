# Stasis

> Feature: session-2026-04-27-ssot-linear-validation-and-bts-216
> Kind: session
> Last updated: 1777272000
> Session: 2
> Boundary: 2026-04-26T22:30:00-07:00
> Session objective: continue SSOT-Linear cleanup arc (BTS-213 then BTS-214). Operator dogfood probe surfaced a substrate contract bug; pivoted to BTS-216 inline. End state: SSOT-Linear flow proven end-to-end against the live API for the first time.

## Accomplished

- **Shipped 3 PRs end-to-end:** BTS-213 (`/spec` + `cmd_activate` route-aware Linear dispatch — PR #113), BTS-214 (`_complete_archive_linear` 6→5 API call refactor + zombie-trash fix — PR #114), BTS-216 (RFC 4122 v4 UUID fix — PR #115). All squash-merged, all → Done in Linear, all auto-closed via `/land` AUTO-CLOSE marker.
- **Discovered + fixed a 3-PR-deep contract bug.** BTS-204's stasis claimed live-validation, but the cited test UUIDs (`36eb3962…`, `bcef1f0a…`) were Linear-ASSIGNED outputs — `--create-with-id` was never round-tripped. Operator-driven dogfood test ("add a Document to BTS-215") triggered the discovery: `resolve-document-id` produced UUID-shaped strings whose version + variant nibbles violate RFC 4122. Linear's `class-validator` `isUuid('4')` rejected every call with `"id must be a UUID"`. The bug had silently shipped through BTS-204 → BTS-213 → BTS-214 because stub tests pass on any GraphQL body shape.
- **Hand-crafted live-API control test surfaced the v4-only constraint.** Constructed `aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee` (v4) → accepted; same UUID with `5ccc` (v5) → rejected. Linear validates ONLY UUID v4. Substrate fix forces version nibble to `4` and variant nibble to `8` after the SHA-256 slice. Determinism preserved.
- **End-to-end substrate round-trip verified post-fix:** `cmd_artifact_write --kind spec --feature BTS-215 --project-dir <linear-routed-fx>` created Document `dafdcb22-6c83-4651-8c04-44def92e6967`, parented to BTS-215 issue, retrieved via `get-document`, trashed via `trash-document`. The full BTS-204/213/214 chain now actually works against api.linear.app.
- **/review found 5 issues across 3 ships, all addressed inline:** BTS-213 WARN-1 (missing `--project-dir` propagation in `cmd_artifact_write`), WARN-2 (failure-semantic divergence between SKILL and `cmd_activate`), INFO-1 (cross-cwd dispatch test gap); BTS-214 WARN-1 (zombie-trash: empty-content Documents stayed alive in Linear), WARN-2 (silent truncation ceiling at `--limit 50`), INFO (untested get-issue failure path). Each landed in the same PR with a "why this matters" rationale per `feedback_review_findings_need_why_it_matters`.
- **Captured BTS-217 as session-end carry-forward** in Linear Triage. Operator-driven config flip (no code) — adds `routing.{spec,plan,stasis}=linear` to `.claude/ccanvil.local.json`. Substrate is proven; this ticket is the dogfood-on-hub validation step.

## Current State

- **Branch:** `main` (post-merge, fast-forwarded to origin/main)
- **Tests:** **1707 / 1707 passing** (1681 baseline → +26 SSOT-Linear drift-guards across the 3 ships)
- **Uncommitted changes:** none
- **Build status:** clean

## Blocked On

Nothing.

## Next Steps

1. **`/idea triage`** — clear BTS-217 from Triage (operator-decided: flip routing on hub or stage on downstream first?).
2. **Pick the next ship.** Up Next options:
   - **BTS-217** — flip routing on hub. Dogfood the full SSOT-Linear flow; closes the BTS-204 arc loop.
   - **BTS-211** — `operations.sh exec` doesn't dispatch http-mechanism (single-file substrate fix from prior /radar).
   - **BTS-202** — `guard-destructive` jq-raw + rm-force false-positive (single-file).
   - **BTS-215** — `docs-check.sh` usage-string out of sync (one-line).
3. **Verify the dogfood.** Once BTS-217 routing is flipped, the next-shipped feature's spec/plan/stasis Documents should appear in Linear under their parent issue's Documents tab. If anything misroutes, BTS-216-class symptoms will surface immediately.

## Context Notes

- **Session arc was 4 ships** (BTS-213 → BTS-214 → unplanned BTS-216 mid-session → BTS-217 capture). Mid-session pivot: operator probed the substrate with a direct dogfood test ("add a doc to BTS-215") that revealed the v4-validator contract bug. We had been shipping live since BTS-204 against a non-functional substrate.
- **The dogfood probe was the thesis test.** Stub tests gave 1681 → 1707 green across BTS-204/213/214. Live API gave 0 successful end-to-end round-trips. Operator's "I'm watching, why no Documents?" was the first time the actual contract was checked. Live-validation discipline (`feedback_live_activation_hardening`) had been articulated but not enforced as a hard gate; this session demonstrates why it must be.
- **Routing flip is gated on operator decision, not substrate readiness.** The hub still has only `routing.idea=linear`; spec/plan/stasis default to `local`. Substrate is proven. BTS-217 captures the flip work + caveats (PR body embed contract change, downstream-node opt-in semantics, no `/ccanvil-pull` propagation of routing).
- **/review pattern continues to compound value.** 5 inline fixes across this session (versus deferred-as-followup) saved at least 2 separate /pr cycles. The "why this matters" articulation discipline — surfaced by the memory written 2 sessions ago — is now habitual; every WARN/INFO carried operational-cost framing.
- **Linear's UUID validator quirk (v4-only).** `class-validator` `isUuid('4')` is configured in Linear's Document mutation. Worth a memory: when generating UUIDs for Linear, the value must be v4-shaped (version nibble `4`, variant nibble `8/9/a/b`); v3 and v5 are rejected with `"id must be a UUID"` regardless of structural validity. Discovered via hand-crafted control test on 2026-04-27. Likely applies to any Linear API field that takes a caller-supplied UUID; verify before the next such substrate.

## Determinism Review

- **operations_reviewed:** ~50 (3 ships × ~5-7 phases each + /review captures × 3 + dogfood probe + BTS-216 capture + spec/plan/activate × 3 + pr-cleanup × 3 + push × 3 + merge × 3 + /land × 3 + AUTO-CLOSE dispatch × 3 + BTS-217 capture)
- **candidates_found:** 0
- No candidates this session. All non-deterministic surfaces caught — the BTS-216 contract bug was a substrate defect, not a stochastic-Claude-operation flag. The fix shipped as deterministic substrate (forced nibbles in `resolve-document-id`). The 3 audit-session findings (`shasum`, `jq`) are inside bats test fixtures, not Claude reasoning that should become a script.

## Evidence Gaps

The substrate primitive `evidence-scan-session` reports 3 gaps (BTS-205, BTS-209, BTS-210) — **all three are the same false positives carried forward from prior sessions**. Cause: BTS-203 substrate gap. The `idea.list` resolver doesn't include `description` in its output shape, so the evidence scan can't see the four anchors that ARE present in each ticket body. Will resolve when BTS-203 ships.

**No real evidence gaps this session.**

## Cross-Session Patterns

- **CONFIRMED RECURRING (6+ sessions): substrate gap surfaces ONLY at dogfood / live execution.** This session's BTS-216 contract bug is the most expensive instance to date — a 3-PR-deep regression that bats stubs couldn't catch. Prior sessions: BTS-204 Phase 1 `actor`/`actorIds` (caught Phase 1 because that ship's plan flagged live-API risk; this session shipped without that gate). The pattern is now durable enough to be a hard rule, not just a memory: live-validation against the real API contract MUST happen for any new substrate that bridges external systems, even when stubs pass.

- **CONFIRMED RECURRING (3+ sessions): BTS-204 stasis falsely claimed end-to-end live-validation.** The original session-stasis cited `36eb3962…` and `bcef1f0a…` as proof, but those were Linear-ASSIGNED, never derived. This session is the empirical correction — re-titled the BTS-204 live-validation claim from "verified" to "stub-validated only." Worth surfacing in BTS-204 archive (`docs/sessions/1777267442-session-2026-04-27-bts-204-ssot-linear-ship.md`) as an addendum if anyone re-reads it.

- **CONFIRMED RECURRING (5+ sessions): operator-driven articulation discipline.** Every /review finding this session carried "why this matters" rationale — both inline-fixed and captured-as-followup. Now habitual contract.

- **CONFIRMED RECURRING (3+ sessions): scope-up on reveal.** BTS-216 was scope-up: mid-BTS-214-completion, dogfood probe surfaced a substrate-spanning bug; pivoted to capture + fix inline rather than defer. Same cost-curve as scope-down decisions — fast, explicit, both directions.

- **NEW (negative): BTS-204's "live-validated" stasis claim.** Now flagged. Future-self reading prior stasis archives must verify any "live-validated" claim by inspecting the actual artifacts (commit hashes, doc UUIDs, command outputs) rather than trusting the assertion.

- **NEW (positive): operator-as-live-API-canary.** When the operator visually probes the system ("I'm watching, why X?"), treat it as a thesis test. This session, that probe caught a 3-PR-deep bug. Not a pattern to seek (operator visibility is the limited resource), but worth biasing toward: when there's a way to surface running state to the operator cheaply, do it.

- **No recurring legacy-refs.** `legacy-refs-scan` returned `[]`.

## Security Review

- BTS-213 / BTS-214 / BTS-216 substrate: all bash + GraphQL via existing http machinery (BTS-164). No new auth surfaces. Linear API key reused.
- BTS-216 fix changes only the deterministic UUID derivation — no security boundary affected.
- Live-test artifacts: created + trashed 3 test Documents during this session (`f1de9a42-…`, `aaaaaaaa-…b-4ccc-…`, `dfc384b1-4da9-4a42-…`, `dafdcb22-6c83-4651-…`). All trashed via `trash-document` returning `{"success": true}`.
- One v5-version test Document (`aaaaaaaa-bbbb-5ccc-…`) was rejected at validation and never created.
- No secrets in commits; `.env` referenced only via `set -a; source .env; set +a` for local live-tests.
- **Verdict: PASS.**

## Memory Candidates

- **NEW MEMORY: `feedback_linear_validates_uuid_v4_only`** — Linear's API rejects caller-supplied UUIDs that aren't v4-shaped. Verified via hand-crafted control: `aaaaaaaa-bbbb-4ccc-8ddd-…` accepted, `5ccc` rejected with `"id must be a UUID"`. When generating UUIDs for any Linear input field, force version nibble `4` and variant nibble `8/9/a/b`. v5 (name-based, SHA-1) is structurally valid per RFC 4122 but Linear's `class-validator` `isUuid('4')` config rejects it. Save.

- **NEW MEMORY: `feedback_dogfood_probe_as_thesis_test`** — When the operator visibly probes the substrate ("show me X working"), it's a live thesis test that catches what stubs miss. This session's BTS-216 was caught by a single dogfood request; the bug had shipped 3 PRs deep before. Generalizes: when designing substrate that bridges external systems, prefer surfacing running state to the operator cheaply — operator visibility is a free oracle. Save.

- **REINFORCE: `feedback_live_activation_hardening`** — substrate gaps surface only at dogfood. BTS-216 is the most expensive instance to date (3-PR-deep regression). Now 6+ sessions running and elevating from "memory" to "should be a hard rule in `tdd.md`": any new substrate that bridges an external system MUST round-trip a real call before merge, not just stub coverage. Already saved; this session is the strongest data point yet.

- **REINFORCE: `feedback_research_before_architectural_commit`** — BTS-204 was the canonical case (research-first changed the architecture). BTS-216 is the inverse-failure case (no research about Linear's UUID validator → 3 ships shipped a contract bug). Same pattern; live-validation is the catch-all.

- **NEW REFERENCE (in code, not memory):** Linear ccanvil project_id is `0c5fec47-fa1c-4e2c-9e0a-4b4dc0fc05d6`. BTS-217 captures it in the routing-flip recipe. Worth knowing for any future substrate work that needs project-parented Documents.

Memories to save: **two new** (`feedback_linear_validates_uuid_v4_only`, `feedback_dogfood_probe_as_thesis_test`). Two reinforced.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
