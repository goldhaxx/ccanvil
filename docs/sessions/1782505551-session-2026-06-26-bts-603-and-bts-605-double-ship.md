# Stasis: session-2026-06-26-bts-603-and-bts-605-double-ship

> Feature: session-2026-06-26-bts-603-and-bts-605-double-ship
> Kind: session
> Last updated: 1782505551
> Session: 85
> Boundary: 2026-06-26T13:25:51-07:00
> Session objective: Ship BTS-603 (consolidate .claude/settings.json, spec activated on prior cold-start) THEN ship BTS-605 (broadcast unblock — user goal-locked mid-session). Two complete feature ships back-to-back from main → main, plus 4 follow-up tickets captured along the way.

## Accomplished

* **BTS-603 SHIPPED** — PR #198 (squash-merged as `6feb189` on main). Trimmed `.claude/settings.json` by 19 entries (1604 → 1465 tokens):
  * 9 shell control-flow keywords removed (AC-5).
  * 2 `./`-prefixed Bash path duplicates collapsed to canonical form (AC-6).
  * 8 operator-personal MCP wildcards + `Read(//Users/...)` moved to `settings.local.json` (AC-7, gitignored).
  * Project-shared MCPs retained: `Linear` (substrate-reachable) + `Mermaid_Chart` (AC-8).
  * New drift-guard `hub/tests/settings-consolidation.bats` (19 tests) pinning AC-3/4/5/6/7/8/11.
  * **Spec amendment (2026-06-25):** AC-1 narrowed ≥600 → ≥130 tokens (math: 19 removals only deliver ~139). AC-2 deferred — settings.json alone CAN'T move total below 90% (rules-files dominate at 71% of ceiling). Real lever captured as **BTS-666** (rules-file consolidation).
  * **Reviewer hardening (in-commit, not follow-up):** AC-4 for-loops → jq exhaustive-check, gitignored skip clauses, AC-7 ONLY-this-set exclusivity test added (19th).
* **BTS-605 SHIPPED** — PR #200 (squash-merged as `06fbf53` on main). `ccanvil-sync.sh broadcast` no longer false-positive-blocks the fleet:
  * `cmd_pre_check` ignores `??` (untracked) lines — Codex CLI artifacts (`.agents/`, `.codex/`, `AGENTS.md`) no longer block (AC-1).
  * Bootstrap-before-dirty reorder so broadcast self-heals stale node scripts (AC-3).
  * `cmd_broadcast` invokes the HUB's pre-check (not node's local copy) — fleet upgrades in one operator action.
  * New `cmd_registry_prune_stale` substrate verb — pruned 50 stale `tmp.*` registry entries (kept 19 real nodes) in this PR (AC-12).
  * `cmd_broadcast` filters stale BEFORE iteration; emits one `STALE: N entries skipped` summary instead of per-stale headers (AC-5).
  * Dry-run skip on post-bootstrap re-check (dry-run can't commit; re-check would always fail on uncommitted bootstrap state).
  * New drift-guard `hub/tests/broadcast-pre-check-untracked.bats` (7 tests).
  * **Spec amendment (2026-06-26):** scope-up-on-reveal — live AC-6 verification showed nodes' OLD pre-check still blocked first broadcast. Expanded scope: broadcast uses HUB's pre-check, OoS "self-healing fleet without operator action" item now IN scope and delivered.
* **4 follow-up tickets captured:**
  * **BTS-666 (Triage)** — rules-file consolidation for context budget (from BTS-603 spec amendment).
  * **BTS-667 (Triage)** — diff-vs-manifest substrate: walk new fn definitions inside diff hunks (substrate bug surfaced + workaround in BTS-605).
  * **BTS-668 (Triage)** — dry-run summary counters: bootstrap-pending nodes invisible (reviewer C-4).
  * **BTS-669 (Triage)** — `cmd_registry_prune_stale`: replace per-entry jq fork with single-jq slurp at scale (reviewer C-5).

## Current State

* **Branch:** `main` (3 commits ahead of session-start: 6feb189, 06fbf53, plus prior 925a76c).
* **Tests:** 2495 / 0 PASS (full suite, BTS-605 pre-merge gate).
* **Uncommitted changes:** none.
* **Build status:** clean. Manifest 205 / 205, drift 0 (Layer 2 + Layer 3 both clean).
* **Linear:** BTS-603 Done, BTS-605 Done; 4 new Triage entries (BTS-666/667/668/669).
* **Triage queue:** 20 items (was 16 at cold-start; 4 BTS-666-669 added this session).
* **Backlog:** 87.
* **Context budget:** still CRITICAL post-BTS-603 (settings.json trimmed but rules-files dominate). BTS-666 is the next real lever.

## Blocked On

Nothing.

## Next Steps

1. `/idea triage` — drain the 20 Triage items (4 are this session's substrate-fix follow-ups; the rest accumulated since 2026-06-01).
2. **BTS-666 (rules-file consolidation)** is the next big-leverage ship — settled per BTS-603 spec amendment as the actual fix for CRITICAL context budget. Substantive (architectural-adjacent); plan a /spec session.
3. **BTS-667 (substrate fix)** — small, mechanical. Sequence: AFTER BTS-666 or any other ship that adds a new function (the workaround in BTS-605 sufficed; substrate fix is hardening, not blocking).
4. **BTS-668 + BTS-669** — quality-of-life follow-ups from BTS-605 reviewer. Combine into one ship if convenient; both touch cmd_broadcast or cmd_registry_prune_stale.

## Context Notes

* **Goal-lock workflow validated.** `/goal ship BTS-605` set a Stop hook that drove the BTS-605 ship from spec → activate → impl → review → pr → ship without intermediate prompts. Worked cleanly.
* **Scope-up-on-reveal pattern, second consecutive ship.** BTS-603 scoped DOWN at impl time (AC-1 ≥600 → ≥130). BTS-605 scoped UP at impl time (broadcast uses HUB pre-check; OoS clause superseded). Both honestly amended in spec, follow-ups captured. Pattern memory: scope adjustments are sometimes the spec acting AS the working substrate.
* **Manifest substrate's xfuncname bug** surfaced during BTS-605 reviewer-driven fixes. The substrate attributes inline `# @side-effect:`/`@caller:` markers via git's xfuncname header — when a new function is added in a hunk whose header points BACKWARD to the existing function (because git xfuncname walks UP from added lines), the new function's markers get false-attributed. BTS-605 workaround: omit the conditional-write side-effect declaration and document it in `purpose`. BTS-667 captures the substrate fix.
* `# @manifest` **block parser is strict.** Lines must be `# <key>: <value>` with no narrative. NOTE comments inside the block silently close it, causing missing-required-key drift on subsequent declarations. Always put NOTE blocks OUTSIDE/ABOVE the `# @manifest` marker.
* **Live broadcast --dry-run runs leave bootstrap artifacts on every downstream node.** The bootstrap `cp` and lockfile update fire regardless of dry-run; only the commit is gated. So repeated dry-runs leave each node with uncommitted `M .ccanvil/scripts/ccanvil-sync.sh` + `M .ccanvil/ccanvil.lock`. Not a BTS-605 bug (it was pre-existing); a real broadcast would have committed those. Documented in PR body.
* **Concurrent-edit guard fired once this session** (BTS-605 activate spec dispatch). Verified empty document-history (own-caller divergence per BTS-563 pattern) before override. 7th consecutive session with the same pattern.

## Determinism Review

* **operations_reviewed:** ~50 (recall, /idea triage drain (20 → 0 + 4 new), BTS-603 final impl + reviewer hardening + commit + pr + ship + verify, /goal-driven BTS-605 spec + critic R1 + activate + impl + reviewer hardening + manifest-substrate wrestling + 3 commits + ship + 4 follow-up captures).
* **candidates_found:** 3.

**manifest-substrate-xfuncname-attribution-bug**: Claude spent ~10 substrate-investigation iterations + multiple Layer 2/3 manifest re-runs trying to resolve a substrate false-positive where inline `@side-effect:` markers in new functions get attributed to the surrounding function via git's xfuncname header. The substrate should walk new function definitions inside the hunk and update the attribution. Already captured as **BTS-667**. Impact: high (every new [ccanvil-sync.sh](<http://ccanvil-sync.sh>) / similar function addition trips this).

**pr-body-template-substrate**: Claude composed the PR body via heredoc + Python template substitution for both BTS-603 and BTS-605. A `docs-check.sh pr-body-render --feature <id>` substrate that emits the canonical PR body (summary derived from spec, test plan from ACs, embedded spec via artifact-read) would eliminate ~50 lines of hand-composition per ship. Impact: medium (saves ~5 min + reduces drift between ship bodies).

**stasis-and-ship-runtime-artifacts-cleanup**: The repeated broadcast --dry-run runs left uncommitted `M .ccanvil/scripts/ccanvil-sync.sh` on every downstream node. The substrate could detect end-of-broadcast-dry-run-state and offer a `--clean-dry-run-artifacts` recipe, OR the bootstrap could short-circuit when dry_run AND emit a `DRY-RUN: would bootstrap script@<hash> from hub` message without writing. Impact: low-medium (only matters when an operator runs multiple dry-runs in close succession, but that's the common debugging pattern).

## Evidence Gaps

* BTS-601 — Hub: guard-workspace fence false-positives on slash-delimited tokens — missing-evidence-anchors

(Note: BTS-601 is RESOLVED on Linear — closed as duplicate of BTS-602 last session. The evidence-scan substrate doesn't dedup against closed Linear state. Surfaces every session since BTS-602 shipped. Same pattern as previous stasis — captured but not actioned.)

## Manifest Coverage

205 / 205 (allowlist), drift incidents: 0.

## Cross-Session Patterns

* **concurrent-edit-guard friction RECURRED (7th consecutive session, 10× this lifecycle).** Last session (BTS-603): 4 fires. This session (BTS-603 ship + BTS-605 spec+activate): 1 fire (BTS-605 activate spec dispatch). Recurrence is monotonic; BTS-563 substrate fix is overdue.
* **legacy-refs-scan runtime-artifact false-positive RECURRED (10th consecutive session).** All matches in `.ccanvil/observability/raw-traces.jsonl` (OTel runtime, gitignored). Already-ticketed as **BTS-562**. Hub-owned, one-line fix sitting in Backlog.
* **NEW pattern: scope adjustments mid-ship validate the spec-as-working-substrate model.** BTS-603 scoped DOWN (over-optimistic token target). BTS-605 scoped UP (OoS clause superseded by live verification). Both via Spec Amendment sections + follow-up captures. Two ships in a row demonstrating: spec is not a contract to ship-or-fail; it's the document you keep honest with the implementation reality.
* **NEW pattern: manifest substrate wrestling consumed \~20% of BTS-605 ship time.** The xfuncname false-positive (BTS-667), NOTE-comment block-break, and Layer 2/3 contradictory drift all chewed up cycles. The substrate's strict line-by-line parser + git-xfuncname-based attribution is the lurking risk for any new function addition. Once BTS-667 lands, this overhead drops.
* **audit-session findings:** 27 patterns surfaced (shasum=6, cp=5, git-C=13, jq=3) — all stylistic patterns from bats fixture authoring, none are bugs.

## Security Review

**PASS.** No new secrets, credentials, or PII introduced. Both ships touched permission gates (BTS-603 trimmed `.claude/settings.json` deny array preserved 100% via AC-3 verifier; BTS-605 narrowed pre-check's dirty definition but tracked-file modifications STILL block, AC-2). Security-audit ran clean — same 21 PRE-EXISTING findings as BTS-603 session (none introduced this session).

## Memory Candidates

1. **Scope-up-on-reveal pattern (BTS-605).** When live verification reveals the spec's OoS clause leaves the user-facing goal unsatisfied, the implementer SHOULD expand scope honestly via Spec Amendment, capture the original-narrow-version as follow-up, and ship the wider version. Mirror of scope-down-on-reveal. Anchor on BTS-605 (broadcast uses HUB pre-check, supersedes OoS "self-healing fleet without operator action").
2. `# @manifest` **block parser is strict** — lines must be `# <key>: <value>`. NOTE comments inside silently close the block. Put NOTE blocks ABOVE the `# @manifest` marker or INSIDE the function body. Anchor on BTS-605 manifest wrestling.
3. **Manifest xfuncname-attribution bug** — diff-vs-manifest attributes inline `@side-effect:` / `@caller:` markers via git's xfuncname header. New functions added in hunks whose header points BACKWARD trip false-positives. Workaround: declare the side-effect via `purpose` rather than `side-effect:` key. Anchor on BTS-667.
4. **Goal-locked /goal Stop hook drove a full feature ship cleanly** (BTS-605). Validated for end-to-end-without-interrupts workflow.
5. **Live broadcast --dry-run leaves bootstrap artifacts on every downstream node.** The `cp` and lockfile update fire regardless of dry_run; only the commit is gated. After multiple dry-runs, nodes need `git checkout` to revert. Pattern memory: dry-run "preview" semantics are surface-level; substrate semantics may still mutate.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->