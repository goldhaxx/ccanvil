# Stasis

> Feature: session-2026-04-27-substrate-hardening-v1-three-ships
> Kind: session
> Last updated: 1777320591
> Session: 6
> Boundary: 2026-04-27T11:34:27-07:00
> Session objective: complete Ship 2 + Ship 3 of the substrate-hardening-v1 release (BTS-229) — both with /spec→/plan→/pr→/land cycles end-to-end against the SSOT-Linear flow.

## Accomplished

* **Ship 1 (BTS-212 + BTS-218 closed) — uniform flag parsing across** `docs-check.sh`. Added `PROJECT_TREE_SUBCOMMANDS` source-of-truth array (41 subcommands) and patched every cmd to accept `--project-dir <path>` + emit `Usage: ... + exit 2` on unknown flags. Bidirectional drift-guard in `hub/tests/docs-check-flags.bats`. PR #117 squash `dffcfea`.
* **Ship 2 (BTS-219 + BTS-227 closed) — live-API diagnostic surfacing + safe JSON pipe.** Added `_classify_linear_failure` helper to `docs-check.sh` mapping captured stderr to `auth-missing` / `not-found` / `network-error` / `parse-error`. `cmd_artifact_read`'s linear branch now emits structured WARN + retry recipe. Replaced `echo "$VAR" | jq` with `jq <<< "$VAR"` in drift-watchdog skill (4 sites). Re-framed BTS-227 mid-flight: NOT a `linear-query.sh` encoder bug (JSON output is valid) — bug is shell-dependent (zsh's `echo` interprets `\n`). PR #118 squash `f4db28d`.
  * **Latent bug found** during BTS-219 implementation: `var=$(failing_cmd); rc=$?` pattern was killed by `set -e` before the failure branch ran. Restructured to `if var=$(...); then rc=0; else rc=$?; fi`.
* **Ship 3 (BTS-228 closed) — IssueRelation API separation.** Added `linear-query.sh create-relation` primitive wrapping `issueRelationCreate` (supports `duplicate`/`blocks`/`related`). Removed broken `duplicateOf` field from `IssueUpdateInput` in `cmd_save_issue`; dispatches `create-relation` as a follow-up after successful state transition. WARN-on-failure preserves state-transition outcome when relation half fails. PR #119 squash `81f2eab`.
  * **Live-API smoke recovered the lost BTS-226→BTS-197 duplicateOf relation** from the original triage merge. BTS-227 cleanup couldn't fix it because the substrate was broken; this ship fixed the substrate AND landed the recovery as the live-API gate validation.
* **Captured BTS-231** ("Decide: /land multi-ticket close — ccanvil-owned dispatch, not Linear auto-link") with three candidate shapes for design discussion. Surfaced from BTS-218's manual transition at /land time — Linear's GitHub auto-link could close referenced tickets but the operator deliberately keeps that integration OFF for provider-neutrality.
* **New memory:** `feedback_workflow_logic_lives_in_ccanvil` — workflow dispatch (transitions, multi-ticket closes, state changes) lives in ccanvil substrate; 3rd-party integrations (Linear GitHub auto-link, Notion sync, etc.) stay OFF deliberately for provider-neutrality + no hidden dependencies.
* **Substrate-hardening-v1 release: 5/10 children Done** (BTS-212, 218, 219, 227, 228). Remaining: BTS-202, 203, 205, 210, 230. Drainage check fires 2026-05-11.

## Current State

* **Branch:** `main`, fast-forwarded to `origin/main`, working tree clean.
* **Tests:** **1737 / 1737 passing** (1715 baseline + 22 new across 3 ships: 3 BTS-212 drift-guard blocks covering \~120 cmd × shape iterations, 7 BTS-219 WARN classifier tests, 4 BTS-227 JSON-pipe-safety tests, 11 BTS-228 IssueRelation tests + state lock).
* **Uncommitted changes:** none.
* **Build status:** clean.

## Blocked On

Nothing.

## Next Steps

1. **Substrate-hardening-v1 remaining ships** (5 left): BTS-202 (guard-destructive false-positive on jq raw-flag + rm force-flag combo), BTS-203 (Determinism: evidence-scan-session needs description-fetch), BTS-205 (Determinism: silent-failure-of-BTS-115-dual-capture), BTS-210 (guard-workspace false-positive on slash-command prose tokens — triggered repeatedly this session, real friction), BTS-230 (archive-stasis not routing-aware). None overlap; each is a standalone ship.
2. **BTS-231 design decision** before implementation. Three candidate shapes drafted (PR-body parsing / structured `## Closes (additional)` / explicit `--also-close` flag). Operator picks; implementation is small once decided.
3. **5/11 drainage agent fires** — its recommendation should now reflect BTS-229's progress (5/10 done). If the remaining 5 ship cleanly, BTS-163 collapses to "document the lightweight pattern + add a `release` label." If new friction surfaces, BTS-163 ramps with concrete motivation. Update routine prompt before then if scope shifts.
4. **Triage queue:** 2 untriaged ideas (low). Run `/idea triage` if desired; not blocking.

## Context Notes

* **Three-ship cadence violated the "avoid 4+ tickets-per-session" guideline** from the prior stasis. Substrate maturity (after BTS-217's normalize helper + the SSOT-Linear flow) genuinely DID enable the cadence — every ship rode existing BTS-128/164/166/213 substrate. Context budget at 45% / 1M after Ship 3, plenty of headroom. The guideline holds in spirit (pause between ships) but the absolute count threshold is substrate-dependent. New observation: a 3-ship session inside a release is sustainable when each ship is self-contained and substrate is mature.
* **BTS-227 re-framing pattern.** The ticket title hypothesized a `linear-query.sh` encoder bug (`recommend root-cause fix at the encoder`). Investigation showed the JSON encoder is correct; the bug is shell-dependent — zsh's `echo` builtin interprets `\n` in arguments, breaking JSON when captured into a bash variable. Spec body documented the re-framing; ticket title kept (still describes the symptom). This is exactly the BTS-201 evidence-required-for-captures lesson surfacing again — hypothesis-titles can shift work toward fix-shaped tickets that don't match reality. Current spec/stasis discipline catches this at investigation time; future-self with the BTS-201 protocol won't repeat the diagnostic mistake.
* **The provider-neutrality principle now has BOTH a positive claim AND a negative claim.** Positive: every external-system action must be reachable from ccanvil programmatically (`feedback_agentic_agency_first`). Negative: even when a 3rd-party can do the action automatically, ccanvil OWNS the dispatch (`feedback_workflow_logic_lives_in_ccanvil`). Both anchored on Linear-side workflow features the operator deliberately keeps OFF. Together: ccanvil substrate is the single source of truth for workflow control flow.
* **Live-API smoke as substrate-fix verification.** Ship 3's smoke test wasn't synthetic — it recovered an actual lost relation (BTS-226→BTS-197) from a prior triage that the broken substrate couldn't complete. Pattern: when fixing a substrate bug that produced silent data loss, structure the smoke test to also REPAIR one instance of the loss. Two birds, one validation cycle.
* `cmd_artifact_read` had a latent `set -e` interaction: `var=$(failing_cmd); rc=$?` is killed by `set -e` before reaching the failure branch. The WARN block I'd written would never have fired without the `if/then/else` restructure. Worth a substrate-wide audit if other `var=$(...); rc=$?` patterns exist that weren't catching errors silently.
* `guard-workspace.sh` triggered \~3× this session on commit-message narrative tokens (`/bin/bash`, `/spec` etc.). BTS-210 already tracks; severity bumped via repeated triggers. Each `ALLOW_OUTSIDE_WORKSPACE=1` bypass is friction.

## Determinism Review

* **operations_reviewed:** \~80 (Ship 1: arg-loop patches × 35 cmds + bats writing + 2 commits; Ship 2: classifier helper + WARN block + 4 skill prose edits + 2 bats + 4 commits; Ship 3: cmd_create_relation + save-issue refactor + 1 bats + live-API smoke + 1 commit; plus /pr/land cycles × 3, BTS-231 capture, memory write, [MEMORY.md](<http://MEMORY.md>) update).
* **candidates_found:** 1
* `set -e` interaction with `var=$(failing_cmd); rc=$?`: discovered when `cmd_artifact_read`'s WARN block didn't fire. The `; rc=$?` follow-up is killed by `set -e` because the assignment exit propagates. Fix: `if var=$(...); then rc=0; else rc=$?; fi`. Substrate-wide grep candidate: any other `var=$(.*); rc=\$?` patterns that may be silently swallowing failures. Should be a deterministic pre-flight via a bats lint similar to `bats-lint.sh`. Impact: medium — silent error-swallowing in substrate is a classic-class bug.

## Evidence Gaps

No evidence gaps this session.

## Cross-Session Patterns

* **CONFIRMED RECURRING (8+ sessions, load-bearing): dogfood surfaces substrate bugs that bats stubs miss.** BTS-219 surfaced the `set -e` latent bug. BTS-227 surfaced the shell-portability gap. BTS-228 surfaced the IssueRelation API separation that the substrate had been silently swallowing for weeks. Each ship carried its own one-off discovery. Pattern remains the strongest single-evidence basis for the substrate-fix release model.
* **CONFIRMED RECURRING (3+ sessions): hypothesis-titled bug captures that need re-framing at investigation time.** BTS-198 (almost shipped a regex carve-out for a phantom rule), BTS-227 (proposed an encoder fix when the bug was shell-dependent). The BTS-201 evidence protocol catches at capture time; the spec/plan loop catches at investigation time. Two-layer defense; both layers fired this session for BTS-227.
* **NEW: substrate fix + data recovery as a paired ship pattern.** BTS-228 fixed the IssueRelation API separation AND used the live-API gate to recover the lost BTS-226→BTS-197 relation. Future substrate-fix ships that addressed silent data loss should structure the live-API smoke to recover one concrete instance — turns the validation step into a dual-purpose action.
* **CONFIRMED RECURRING (3+ sessions):** `guard-workspace.sh` false-positive on slash-command prose tokens (BTS-210). Triggered \~3× this session in commit messages. Each requires `ALLOW_OUTSIDE_WORKSPACE=1`. Ramping to a real ship-priority candidate.
* **No legacy-refs or audit-session findings.** Substrate clean (the one audit-session "jq" pattern hit is the new `json-pipe-safety.bats` test deliberately demonstrating the safe pattern — false positive).

## Security Review

* Ship 1 (BTS-212 substrate): bash arg parsing. No new auth surfaces.
* Ship 2 (BTS-219): WARN classifier reads captured stderr (file written by cmd, deleted after). No leak surface; the WARN messages are about classification, not about the API key value itself.
* Ship 2 (BTS-227): skill prose change only. No code execution change in production paths.
* Ship 3 (BTS-228): new GraphQL mutation wrapper. Auth via `_require_api_key`; same pattern as existing subcommands. No secrets in commits, no LINEAR_API_KEY in prose.
* Live-API smoke: used real LINEAR_API_KEY from `.env` (gitignored). The `--issue` and `--related` UUIDs in the BTS-228 commit message are issue UUIDs (not credentials).
* All new bats tests use stub patterns (no live API in CI).
* **Verdict: PASS.**

## Memory Candidates

* **REINFORCE:** `feedback_dogfood_probe_as_thesis_test` — the BTS-228 live-API smoke was an operator-class probe (recover the lost relation as the verification). Pattern compounds: when fixing data-loss-class substrate bugs, design the smoke to repair one instance of the loss.
* **NEW MEMORY (subtle):** `feedback_set_e_kills_rc_capture` — `var=$(failing_cmd); rc=$?` is broken under `set -euo pipefail`. The assignment's failure exit propagates BEFORE `; rc=$?` runs. Use `if var=$(...); then rc=0; else rc=$?; fi` instead. Surfaced when cmd_artifact_read's BTS-219 WARN block didn't fire — the failure branch was being killed by set -e. Worth a substrate-wide grep audit for similar silent-error-swallowing patterns. Anchor: `cmd_artifact_read` line \~4719 of [docs-check.sh](<http://docs-check.sh>). **Save as feedback memory** — non-obvious bash interaction that future-self will hit again.
* **NEW REFERENCE: BTS-228 live-API smoke as a recovery action** — the smoke test re-ran `save-issue --id BTS-226 --state duplicate --duplicate-of <BTS-197-uuid>` against real Linear, recovering the lost duplicateOf relation that BTS-227 cleanup had to leave broken. Pattern documented in Cross-Session Patterns; not a standalone memory.
* **No new external references** this session.
