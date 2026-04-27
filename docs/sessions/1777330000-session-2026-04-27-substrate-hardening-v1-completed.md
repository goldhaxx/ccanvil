# Stasis

> Feature: session-2026-04-27-substrate-hardening-v1-completed
> Kind: session
> Last updated: 1777330000
> Session: 7
> Boundary: 2026-04-27T13:17:12-07:00
> Session objective: complete the substrate-hardening-v1 release (BTS-229) by finishing the 5 remaining children — BTS-210, BTS-202, BTS-230, BTS-203, BTS-205 — and resolve the BTS-163 / BTS-231 architectural overlap.

## Accomplished

* **BTS-229 substrate-hardening-v1 release: 10/10 SHIPPED.** Five back-to-back ships this session completed the release:
  * **BTS-210** (PR #120) — guard-workspace tolerates trailing prose punctuation on slash-command tokens (`/stasis).`, `/idea,`, etc.). Single regex change extending the BTS-173 allowlist match.
  * **BTS-202** (PR #121) — guard-destructive rm-rf detection scoped to combined flag clusters (`-rf`, `-fr`) OR dual long-form (`--recursive --force`). Eliminates the `jq -r ... ; rm -f` false-positive class. Trade-off: split short-form `rm -r -f` no longer caught (per ticket recommendation C).
  * **BTS-230** (PR #122) — archive-stasis routing-aware. On Linear-routed nodes, reads stasis content via `cmd_artifact_read` instead of erroring on missing `docs/stasis.md`. Live verified end-to-end during this stasis write itself.
  * **BTS-203** (PR #123) — evidence-scan-session per-candidate `get-issue` fetch. Closes the BTS-201 protocol's load-bearing gap — `idea.list` doesn't return description, so every bug-shape ticket reported false-positive missing-anchors. Now fetches body per candidate, with `LINEAR_QUERY_OVERRIDE` env for tests.
  * **BTS-205** (PR #124) — dual-capture resilience. Two failure modes closed: (1) local-routed `/stasis` no longer skips dual-capture (mechanism-aware case dispatch); (2) `cmd_idea_pending_append` writes to `.ccanvil/dual-capture-emergency.log` as last-resort dead-letter when its primary log is unwritable.
* **BTS-229 parent ticket closed** with retrospective comment (`4aaa2c71-42c4-4abb-bf7b-cc692464b481`) capturing cadence, surprise discoveries, and the BTS-163 ramp decision posture.
* **BTS-231 → BTS-163 consolidation.** Specced BTS-231 (--also-close switch); architectural conversation surfaced the broader "delivery primitive" concept; posted matured architecture as a comment on BTS-163 (id `9ddbd44e-6e29-4c1b-97f1-c38e7eeac461`); marked BTS-231 as Duplicate of BTS-163 via the dogfooded BTS-228 substrate; deleted the orphan spec file; disabled the 2026-05-11 drainage routine `trig_01VAjaAbt8S9r4v5RkLYo1cT`.
* **Initial misorder caught and reverted.** Started speccing BTS-163 (release primitive) before BTS-229 was complete; operator pushed back ("aren't we still in the middle of shipping BTS-229?"); reverted BTS-163 to Icebox, deleted spec file, pivoted to BTS-229 cleanup.
* **Three follow-up tickets captured** — BTS-232 (/recall carry-forward determinism candidates), BTS-233 (/idea sync replay for emergency log), BTS-234 (FIX: guard-workspace blocks `/recall's` apostrophe-s tokens after quote-strip — bug-shape with full BTS-201 evidence anchors, hit twice this session).

## Current State

* **Branch:** `main`, fast-forwarded to `origin/main`. Working tree clean.
* **Tests:** **1787 / 1787 passing** (1712 baseline + 75 new across the 8 ships across two sessions, of which 38 new this session: 17 BTS-210, 17 BTS-202 + 3 BTS-156 contract updates, 4 BTS-230, 6 BTS-203, 6 BTS-205).
* **Uncommitted changes:** none.
* **Build status:** clean.

## Blocked On

Nothing.

## Next Steps

1. **BTS-163 spec when ready.** The architectural sketch for the delivery primitive lives on BTS-163 as a comment with three candidate substrate shapes (local file / Linear Document / Linear ticket parent-child). The BTS-229 retrospective explicitly framed ramp-or-not decision: lightweight pattern (parent + label + parentId) carried this release, but BTS-231's `--also-close` friction is real — a delivery primitive that auto-derives close lists from manifest membership would close the gap without recurring to NLP (rejected per `feedback_no_provider_nlp_coupling`). When operator wants to ramp: `/spec BTS-163`. Multi-ship initiative — likely 4-5 ships.
2. **BTS-234 (apostrophe-s tolerance) — small immediate ship.** Same shape as BTS-210; the proposed fix is removing the `tr -d "'"` apostrophe-strip from `guard-workspace.sh`. \~30 minutes to ship including bats + verification.
3. **BTS-232 + BTS-233 (read-side resilience for dual-capture).** Co-shippable; both extend the `/recall` and `/idea sync` skills to read from emergency-log + carry-forward. \~1hr each, complementary to BTS-205.
4. **Linear backlog drainage status:** 13 Backlog (was 17 at start; 4 closed this session). Triage queue: 3 untriaged ideas (BTS-232/233/234 just captured). Run `/idea triage` next session if direction shifts.
5. **2026-05-11 BTS-163 drainage routine** is disabled — answer was preempted by today's conversation. Don't re-enable.

## Context Notes

* **5-ship cadence inside a release was tractable** because the substrate was fully mature. BTS-128/164/166/167/204/213/216/217 all in place — each ship was an apply-pattern, not a substrate-build. Context budget held throughout (didn't approach a /stasis-mid-release threshold). The `feedback_backlog_annihilation_validated` memory's "4+ ship soft limit" is substrate-dependent; mature-substrate releases can exceed it safely.
* **Operator-driven scope discipline** caught a real misorder. Started speccing BTS-163 (architectural / multi-ship) before BTS-229's tactical 4 children were done. Operator pushback was correct — finish open releases before opening new architectural work. Captured into memory.
* **BTS-203's** `LINEAR_QUERY_OVERRIDE` env-var pattern is now established. Same-shape pattern as `LINEAR_QUERY_ENDPOINT` (which already existed for the GraphQL endpoint override). Future substrate calls that dispatch to subprocesses should consider this pattern for testability.
* **BTS-234 surfaced naturally during BTS-230's commit.** The BTS-210 fix (BTS-173 punct-tolerance) doesn't help with apostrophe-s because the apostrophe is stripped BEFORE the regex match. Shows that BTS-210 closes one class of friction; the apostrophe-s class is a separate fix. Two `ALLOW_OUTSIDE_WORKSPACE=1` bypasses needed during the session.
* **BTS-228 dogfood reuse:** BTS-231 → Duplicate of BTS-163 transition used `linear-query.sh save-issue --duplicate-of`, which is the substrate that was JUST shipped in session 6. End-to-end dogfood validation that the duplicate-relation fix lands correctly.
* **Hypothesis-titled bug-capture pattern continues:** none this session. The titles for BTS-202/210/230 all matched their actual root causes. The protocol catches drift cleanly when present (BTS-227 was the last instance).

## Determinism Review

* **operations_reviewed:** \~50 (5 ship cycles × \~10 ops each: spec write + dispatch, activate + override, plan write, bats write + run, code edit + run, suite run, commit, push, pr-cleanup, gh title + ready + merge, land + auto-close)
* **candidates_found:** 1
* `pr-cleanup` → `gh pr edit --title` → `gh pr ready` → `gh pr merge`: this 4-step ship-finalization sequence is identical for every ship and could be wrapped in a `ship-finalize.sh` macro that takes the PR number and the desired title. The current per-ship invocation requires Claude to re-derive the title and re-emit the four `gh` commands; deterministic. The substrate already has `bash .ccanvil/scripts/docs-check.sh assert-pr-title` — extending that to a full `pr-finalize-and-merge` verb would close the gap. Impact: medium — every ship pays the cost.

## Evidence Gaps

No evidence gaps this session.

## Cross-Session Patterns

* **CONFIRMED RECURRING (session 4, 5, 6, 7): dogfood-surfaces-substrate-bugs-that-bats-stubs-miss.** This session: BTS-228 substrate (just shipped) was used for BTS-231 → BTS-163 dedup transition; the dogfood confirmed the substrate works end-to-end for legitimate operational use, not just the recovery case from session 6. Pattern remains the strongest evidence basis for the substrate-fix release model.
* **CONFIRMED RECURRING (session 6, 7):** `guard-workspace` false-positives across slash-command prose tokens. BTS-210 closed one class (trailing punct); BTS-234 captured another (apostrophe-s after quote-strip). Each instance ramps a real ship.
* **CONFIRMED RECURRING (sessions 5, 6, 7): substrate-fix paired with data-recovery.** BTS-228 in session 6 fixed the IssueRelation API AND recovered a lost relation. This session's BTS-231 → BTS-163 duplicate transition used the same substrate for genuine intent, not just smoke-test. Substrate maturity = substrate is now USED, not just verified.
* **NEW (session 7): scope-discipline pushback within autonomous mode.** Auto mode explicitly tells the agent "execute autonomously, minimize interruptions" — but the operator caught a scope misorder (BTS-163 spec before BTS-229 finish). The lesson: autonomous execution does NOT mean "skip the WIP-limit check on what's in flight." Explicit "finish them all" directive scoped to a defined set; pivoting to a different unfinished set requires operator alignment.
* **No legacy-refs or audit-session findings beyond expected.** audit-session reported 5 patterns (4 git-C, 1 jq) — these are the deterministic substrate calls the ship cycles make (resolver dispatches, jq filters). False-positive on the audit; the patterns are the deterministic-by-design machinery.

## Security Review

* All 5 ships were substrate-only changes (bash hooks + skill prose). No new auth surfaces.
* BTS-203's `LINEAR_QUERY_OVERRIDE` env is a TEST-only override; production path still uses `$(dirname "$0")/linear-query.sh`. No leak.
* BTS-205's emergency log writes to `.ccanvil/dual-capture-emergency.log` (gitignored — same patterns as ideas-pending.log family). No secrets in entries.
* BTS-228 substrate exercised against real Linear API for the BTS-231 transition; uses LINEAR_API_KEY from `.env` (gitignored). No key leakage.
* All new bats tests use stub patterns or local fixtures (no live API in CI).
* **Verdict: PASS.**

## Memory Candidates

* **NEW MEMORY:** `feedback_finish_open_release_before_new_architectural_work` — when an in-flight release has remaining children, finish it before opening new architectural specs (even when operator authorizes a directive like "Finish them all" — the directive scoped to the open release, not a permission to start new multi-ship initiatives). Surfaced from this session's BTS-163 spec misorder. **Save as feedback memory.**
* **REINFORCE:** `feedback_lightweight_pattern_dogfoods_substrate_design` — the BTS-229 retrospective explicitly noted the lightweight pattern (parent ticket + label + parentId children) carried the release without any of BTS-163's substrate code. Strong evidence the lightweight form may be sufficient until friction surfaces. Already a memory; this session is its second confirming dogfood.
* **REINFORCE:** `feedback_dogfood_probe_as_thesis_test` — BTS-228 substrate used for legitimate operational transition (BTS-231 → BTS-163 duplicate), validating substrate maturity beyond the original recovery probe in session 6.
* **No new external references** this session.