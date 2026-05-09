# Stasis: session-2026-05-09-bts-387-ratify-and-ship

> Feature: session-2026-05-09-bts-387-ratify-and-ship
> Kind: session
> Last updated: 1778362000
> Session: 36
> Boundary: 2026-05-09T13:30:20-07:00

## Accomplished

Resumed from session 35's BTS-383 ship and ratified PR #171 (BTS-387) in a single arc, validating the BTS-383 substrate via direct dogfood:

* **PR #171 (BTS-387) — SHIPPED** at 2026-05-09 \~13:50 PT. Squash-merged as `e742582`, branch deleted, BTS-387 → Done in Linear (auto-close fired via /ship).
* **Atomization ratified end-to-end:** 4 rules atomized (`tdd`, `provider-integration`, `evidence-required-for-captures`, `background-task-discipline`); 4 Tier-2 reference docs created under `docs/research/`. Net **-3898 tokens** (12080 → 8182, 151% → 102% of 8000 budget). All 4 per-rule atom thresholds (AC-1–4) passed; AC-7 (manifest validate clean) and AC-8 (≤9000 budget) passed.
* **One blocker fixed:** session 33's pause-state failure shape (`caller-not-found` on `bats-lint.sh:bats-lint`) was diagnosed in **\~3 min** via the new BTS-383 `--json failures[]` envelope vs the **\~30 min** grep-140-files approach session 33 attempted. Single-line fix (`573de2f`): retargeted `bats-lint.sh`'s manifest `caller:` from `.claude/rules/tdd.md` → `docs/research/tdd-foundations.md` (mirroring the atomization relocation). 1 failure cleared + 3 cascaded `setup_file`-blocked tests now run.
* **Velocity discipline held — substrate-driven:** ONE full-suite at /pr time (PASS 2106/0/2106 in 6 min wall, 30s heartbeats throughout). Targeted bats post-fix: 29/0/29 in 6.3s. Zero stacked invocations, zero wait-loops, zero buffered-vs-hung confusion (heartbeats eliminated that failure mode).
* **Same-week dogfood proof:** BTS-383 substrate shipped this morning (PR #172, session 35) was used this afternoon (session 36) on the SAME failure shape session 33 burned 30 min on. Direct evidence the substrate's leverage is real, not hypothetical.

## Current State

* **Branch:** `main` (post-ship, fast-forward from squash-merge of #171).
* **Tests:** `PASS 2106 / FAIL 0 / TOTAL 2106` (\~6 min wall via `--parallel --progress`).
* **Uncommitted changes:** none.
* **Build status:** clean. PR #171 MERGED. BTS-387 closed.

## Blocked On

Nothing.

## Next Steps

Per `/radar` and the prior session 35 stasis directives:

1. **BTS-384 — rule scope tags.** Composes on top of the BTS-385/386/387 frontmatter foundation (now fully landed on main). Distribution filter for `tier`/`scope`/`stack` peer keys.
2. **BTS-204 — SSOT-Linear.** Major effort, dedicated session. Routes specs/plans/stasis to Linear ticket bodies as primary surface. Listed in Triage on Linear.
3. `/idea triage` — 6 untriaged ideas (jumped from 1 at session start; ambient captures fired during the session). Worth triaging before next feature-work session.
4. **Capture pending** — see Memory Candidates §1 + §2 below for two new project patterns worth promoting before the next feature drains into them.

## Context Notes

* **Initial** `--json` arg-shape misuse — first targeted bats run used `bats-report.sh --json /tmp/path.json hub/tests/...` thinking `--json` took a file-path arg. The `@manifest` documents `--json` as "emit structured ... to stdout"; my re-read of `--help` corrected the usage. Cost: \~4 min on the first invocation that returned `wall_ms:72` with a single `bats-gather-tests` failure (bats tried to load `/tmp/path.json` as a test file). Recoverable in 30s via reading the help banner; not a substrate gap. **Lesson:** read `--help` FIRST when invoking a substrate flag for the first time — manifests are self-documenting, but only if consumed.
* **Reciprocal-caller drift class identified.** When BTS-387 commit `08514ef` removed `depends-on: bats-lint.sh` from `tdd.md`'s manifest, it failed to also remove the *reciprocal* `caller: .claude/rules/tdd.md` declaration on `bats-lint.sh`'s manifest. The bidirectional manifest graph means atomization completes only when BOTH directions are updated. The drift validator catches this (it surfaced the `caller-not-found` DRIFT line that diagnosed today's blocker) — but at *capture* time, the atomization workflow doesn't surface the reciprocal edges to be checked. **Captured as memory candidate §2.**
* **Velocity expectation calibrated** — session 36 confirmed session 35's revised baseline: full-suite is \~6 min, NOT 30 min. The session 33 estimate was wrong; the speed gap was already closed by BTS-281/293/296 (manifest pre-warm + caller/target-body indices) before BTS-383. BTS-383's contribution is the *visibility* gap (heartbeats + per-test failure detail), not the *speed* gap.
* **Spec hashes drift across sessions** — the BTS-387 archived spec was on the BTS-387 branch only; merging main in (commit `d06d708`) brought BTS-383 substrate but no spec.md drift. The lifecycle-state stayed `implementing` throughout, validated against the active spec on the branch. /pr's `pr-cleanup` archived the spec/plan/stasis cleanly.

## Determinism Review

operations_reviewed: 18
candidates_found: 0

No candidates this session. The discipline held, and the substrate carried the workload:

* Diagnosis: BTS-383 `--json failures[]` envelope (deterministic) replaced what would have been Claude grepping 140 files (stochastic) — exactly the substrate-shaped replacement the BTS-383 ship was designed to produce.
* Test execution: ONE full-suite invocation at /pr time per the BTS-118/BTS-383 single-call discipline rule.
* Ship sequence: `/ship 171` substrate handled title-assert + merge + branch-delete + land + auto-close in one verb.

The only stochastic operations were the commit message + PR body composition, which are appropriately Claude work.

## Evidence Gaps

No evidence gaps this session.

## Manifest Coverage

194 / 194 (allowlist), drift incidents: 0 (post-fix; the bats-lint reciprocal-caller drift was the only outstanding incident at session start; cleared by `573de2f`). Info-warn count: 8 rule-tier-budget-exceeded entries (advisory only — the 150-token threshold is sub-realistic for files carrying `manifest:` blocks; AC-7 acknowledged this and the operational target of total budget ≤9000 is met at 8182).

## Cross-Session Patterns

* **Recurring pattern: full-bats-runs-during-iteration — STILL CLOSED.** Session 33 violated this 5+ times. Session 35 ran 1 full-suite at /pr time. Session 36 ran 1 full-suite at /pr time. Two consecutive sessions with the discipline holding — the substrate (`--progress` + `--json failures[]`) and the rule (`background-task-discipline.md`) are working in concert.
* **Recurring pattern: substrate-collision-mid-PR — DID NOT recur this session.** Session 33 had 3 collisions across BTS-385/386/387; session 35 had 1 (`--progress` × `--parallel` regression). Session 36: zero. The BTS-387 ratification was a clean substrate-driven path with no architectural surprises — the only change was the reciprocal-caller fix, which is a discrete bug-fix, not a mid-PR rethink.
* **New pattern: same-week substrate dogfood validation.** BTS-383 substrate shipped session 35 was used in session 36 on the SAME failure-shape that drove its origin. Each shipped substrate primitive should expect a dogfood test within \~7 days; structurally validates whether the substrate solves the named problem. Captured as memory candidate §1.
* **No legacy-refs drift** (legacy-refs-scan: empty).

## Security Review

PASS — no secret/PII patterns committed this session. Single substrate-line fix (`bats-lint.sh:22`) plus lifecycle archive transitions. No `.env`, no credentials, no API keys.

## Memory Candidates

* **Project pattern:** `project_bts_387_atomization_complete` — BTS-387 SHIPPED 2026-05-09 PR #171. Total context atomization (BTS-385/386/387 cumulative): 12080 → 8182 tokens, -3898 net, 151% → 102% of 8000 budget. Layer 0/1 atomization thesis validated: hub auto-load context structurally fits within the soft ceiling. Future per-rule trims constrained by `manifest:` block weight (\~280-400 tokens floor per rule-file).
* **Project pattern:** `project_substrate_dogfood_within_one_week_validates_thesis` — BTS-383 (shipped session 35) was directly consumed in session 36 to ratify BTS-387. The 30-min → 3-min diagnosis-time delta on the same failure shape proves the substrate's leverage is real. Generalizable: when shipping infrastructure, expect a dogfood test within \~7 days; if the test doesn't materialize, the substrate may be solving a hypothetical problem.
* **Feedback (validated):** `feedback_remove_reciprocal_manifest_edges_during_atomization` — when an atomization removes a `depends-on:` edge from a rule's manifest (because the operational detail moved to a Tier-2 reference doc), ALSO update the reciprocal `caller:` declaration on the dependency to point to the new location (or remove if no other caller). The bidirectional manifest graph drifts otherwise. BTS-387 commit `08514ef` (session 33) missed this; BTS-387 commit `573de2f` (session 36) cleaned it up — at the cost of one cascaded test-blocker. Apply on every atomization that moves operational detail across files.
* **Reference:** `reference_bats_report_json_emits_to_stdout_not_path_arg` — `bats-report.sh --json` emits the JSON envelope to stdout (no path arg). Pipe to a file with shell redirect: `bash bats-report.sh --json --parallel hub/tests/foo.bats > /tmp/out.json`. The `@manifest` documents this; misreading it costs \~4 min on a wasted bats invocation that loads the path arg as a test file.