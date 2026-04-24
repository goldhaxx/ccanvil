# Stasis

> Feature: session-2026-04-24-bts-122-ship
> Kind: session
> Last updated: 1777050618
> Session objective: Ship BTS-122 (lifecycle gate audit) — fetch-before-compare + behind detection + offline fallback in cmd_activate, new cmd_pr_guard for /pr finalization, cmd_land offline hardening. Dogfood by self-closing BTS-122 via its own primitives.

## Accomplished

- **Shipped PR #49 (`6913644`)** — `claude/feat/bts-122-lifecycle-gate-audit`. 8 commits on branch: activate → plan → 5 TDD phase commits → code-review fix → lifecycle cleanup. Full suite **883/883 bats green** (+19 from 864 baseline: 13 in new `hub/tests/lifecycle-gate-audit.bats`, 6 extensions in `hub/tests/activate-push-guard.bats`). Clean squash-merge + FF `land`. One pre-existing test renamed (AC-18 halt-message assertion now checks `--force-sync` instead of legacy `--force-local-ahead`), everything else unchanged.
- **BTS-122 closed via the primitives it shipped** — `pr-guard` dogfood-passed on its own ship's `/pr` pre-flight before merge, then `docs-check.sh land` emitted `AUTO-CLOSE: {"provider":"linear","id":"BTS-122","role":"done"}` → `/land` dispatched `save_issue` → Linear transitioned to `Done` (`completedAt: 2026-04-24T17:09:22Z`). **Third consecutive dogfood-close**: BTS-128 → BTS-119 → BTS-122. Pattern now culturally baked in — every ship that adds a primitive closes the driving ticket using that primitive.
- **Two new `docs-check.sh` subcommands** (`cmd_sync_check`, `cmd_pr_guard`):
  - `sync-check <repo-root>` — fetches `origin/main` with 5s timeout, compares local main. Exit 0 synced / 1 ahead / 2 behind / 0 no-op (no origin, no ref, fetch failed with `WARN:`). Graceful-degradation pattern matches BTS-119 posture.
  - `pr-guard` — runs on feature branch, detects when `origin/main` has moved past HEAD. Halts with `rebase|merge` remediation. Wired into `.claude/commands/pr.md` step 3.
- **`cmd_activate` refactored**: inline ahead-check → `cmd_sync_check` call. New `--force-sync` canonical flag; `--force-local-ahead` kept as silent legacy alias with union bypass semantics. New guard halts if target branch already exists locally (resume-or-delete remediation). `set -euo pipefail` + `|| sc_rc=$?` pattern for clean exit-code capture — validated under review.
- **`cmd_land` offline-hardened**: fetch failure → `WARN: offline — skipping origin fetch and reset. Local main left at current HEAD.` + skip the `reset --hard`. Prevents silent reset-to-stale-ref when origin is unreachable.
- **Code review gate caught 4 WARN + 2 NIT (reviewer spotted 2 WARN + 2 NIT; I had one judgment-call refactor of my own — extracting helpers vs. inline)**:
  - W1 fixed (commit `521f084`): AC-8 tests used `$output` (merged) instead of `$stderr`. Fragile — if stdout ever leaks, `head -1` picks wrong line. Switched to `run --separate-stderr` + `$stderr` + added `bats_require_minimum_version 1.5.0` to silence BW02.
  - W2 fixed (commit `521f084`): `/pr` step numbering `3a` was unconventional. Merged into step 3 as a compound step.
  - N1/N2 skipped: blank-line assertion in `_assert_error_format` (low risk), lowSpeedLimit=1 comment (minor polish).
- **Command-reference guide** gained 2 new rows (`sync-check`, `pr-guard`) + updated `activate` row to document `--force-sync`, new guards, and pre-flight order.
- **No plan-hash rebase needed this session** — first session in 3 without it. The WARN fixes touched bats tests + skill prose, not the spec. Pattern: plan-hash rebase happens only when a code-review WARN forces a spec-text edit.

## Current State

- **Branch:** `main` at `6913644`, synced with origin.
- **Tests:** 883/883 bats green at PR HEAD (post-merge on main: not re-run, squash was FF-equivalent).
- **Uncommitted changes:** none (working tree clean post-`/land`).
- **Build status:** clean.
- **Context budget:** HEALTHY, no warnings (ceiling 8000 tokens).
- **Permissions audit:** 20 DANGER + 167 UNREVIEWED (unchanged from prior session — no new MCP permissions triggered).
- **Specs archive:** 46 complete (was 45); no active/ready/in-progress specs.
- **Linear state:** BTS-122 `Done` with `completedAt: 2026-04-24T17:09:22Z`; PR #49 auto-attached by Linear's GitHub integration (branch substring match `claude/feat/bts-122-lifecycle-gate-audit`). Linear Triage inbox at 0. Backlog still has 14 items.

## Blocked On

- Nothing.

## Next Steps

1. **Ship BTS-127 + BTS-118** (bats assertion-leak family) — codify the combined-`jq -e 'a and b'` pattern across the existing 883-test suite. The new `lifecycle-gate-audit.bats` uses it already; most of the suite predates BTS-127. One bundled ship.
2. **Ship BTS-129** (`ticket.find-by-title` wrapper) — sibling of BTS-128 in the deterministic-wrapper family. Needed as a primitive for BTS-123. **Fourth dogfood-close candidate** (continues the trilogy pattern).
3. **Ship BTS-123** (pending-log fallback integrity) — correctness bug in the MCP-down replay path. Waits on BTS-129 for idempotent replay semantics. Sibling of BTS-119's new `op:"ticket.transition"` queue.
4. **Triage BTS-136** (auto-transition Linear status through full dev lifecycle) — already promoted to Backlog priority 3 this session. When ready, ship as the sibling completing the Triage/Todo/In Progress/Done state-transition quartet.
5. **Ship BTS-131-135** (ccanvil tooling correctness bundle) — 5 small items, BTS-131 (bats double-run → one-shot) is a session efficiency win.
6. **Ship BTS-125** (Linear save_issue markdown truncation codification) — P4 nice-to-have, good small finisher.
7. **Ship BTS-113** (stale recommend after stasis+compact+recall) — **observed live again this session**. `recommend` returned "/compact to wrap session" at `/recall` despite compact already having run. Evidence mounting.

## Context Notes

- **Dogfood-close pattern is now 3-for-3 and cultural.** The next wrapper ship (BTS-129) should continue the pattern by default. If it breaks, that's a signal to investigate — not a signal that "dogfood" was circumstantial.
- **`--force-sync` vs `--force-local-ahead` aliasing** — kept legacy name as a silent synonym at the arg parser (`--force-local-ahead|--force-sync) force_sync=true`). Canonical hint redirects to `--force-sync`. Not emitting a deprecation warning yet — noise tax on existing scripts. Revisit if/when docs-check.sh has a broader flag-sweep refactor.
- **`run --separate-stderr` + `$stderr` is the preferred pattern** for assertions that need to distinguish stdout from stderr in bats. Required `bats_require_minimum_version 1.5.0` at file top to silence BW02. Worth codifying as house style going forward — existing suite likely has fragile `$output` assertions that could regress the same way.
- **`_assert_error_format` helper** establishes the canonical shape for guard errors: `ERROR: <what happened>` / blank line / two-space-bullet remediation lines. Every new guard this session follows it; should extend to existing guards in a future sweep (candidate for BTS-127/118 bundle).
- **Extracted helper vs. inline emission** (2nd consecutive session) — the plan prescribed wiring sync-check inline into cmd_activate; I extracted `cmd_sync_check` as a reusable command. Judgment call made testing tractable (no activate side-effect setup needed in bats — just `sync-check` + seeded repo). Same pattern as BTS-119's `cmd_auto_close_emit` extraction. This is a reliable refactor move when a git-side-effect-heavy command has a pure-logic helper buried inside it.
- **`/pr` step numbering discipline** — the `3a` inline-insert was pushback-corrected. Going forward: insert full new steps (4, 5, ...) and renumber downstream, OR merge new requirement into the existing step. No half-measures.

## Determinism Review

- **operations_reviewed:** 28
- **candidates_found:** 0 new
- **RESOLVED (2nd consecutive):** **Manual Linear state transitions post-merge** — BTS-119 shipped the `/land` auto-close; this session validated it on a second ship (BTS-122). No manual state flips this session. Pattern is stable — unflagging as a concern.
- **RESOLVED (new):** **Manual stale-baseline detection pre-activate** — BTS-122 shipped `cmd_sync_check` with fetch + ahead/behind detection. Activate now cannot proceed from a stale main. Was previously a judgment call ("is origin ahead? should I pull first?"); now mechanical.
- **No new candidates this session.** Every operation routed through scripts (`docs-check.sh`, `operations.sh`, `gh pr merge`, `gh pr ready`, `gh pr edit`, `bats`, `jq`, `git`). Audit-session flagged 45 `git-C` matches — all in new bats test fixture code (setup/teardown scaffolding for seeded repos), false positives.

## Cross-Session Patterns

- **RESOLVED (3rd consecutive): BTS-119 auto-close** — now works on every ship that carries a `Work: linear:<ID>` spec. BTS-128 (first), BTS-119 (second, self-closing), BTS-122 (this session). Unflag as a concern going forward.
- **RESOLVED (3rd consecutive): BTS-128 manual UUID paste** — `ticket.transition` primitive is now the default for every state transition. No UUID handling this session.
- **RESOLVED (4th consecutive): BTS-120 session-stasis trap** — activate on a main that had an unpushed stasis from the prior session hit the push-guard as expected. After `git push origin main`, activate proceeded cleanly. The guard worked as designed. Kind: session discriminator holding firm across four shipped features.
- **NOT RECURRING (streak broken): Plan-hash rebase** — 2-session streak (BTS-128, BTS-119) did NOT continue this session. Code-review WARNs hit bats tests + skill prose, not the spec. Confirms the earlier hypothesis: plan-hash rebase correlates specifically with mid-TDD spec edits, not code-review WARNs in general. Demote from "recurring" to "conditional". If it hits a 3rd time on a future ship, ship the `docs-check.sh rebase-plan-hash` micro-script.
- **RECURRING (live evidence): BTS-113 stale recommend** — `docs-check.sh recommend` returned "/compact to wrap session" during `/recall` this session. This was observed last session too. Ticket is well-supported by evidence now; prioritize when a session wants a small finisher.
- **Legacy-refs-scan:** unchanged from prior 3 sessions. Same `/catchup`, `/checkpoint`, `docs/checkpoint.md`, `stale-checkpoint` matches in hub-owned (`docs-check.sh`, `command-reference.md`, `session-management.md`, `legacy-refs-scan.bats`) and node-specific (`.ccanvil/ideas.log` historical, `.claude/settings.local.json` permission allowlist, old `docs/specs/*.md` archives). Hub-owned resolve on next `/ccanvil-pull` on downstream nodes; node-specific are frozen history.
- **Audit-session since `dd50712`: 45 `git-C` matches (all false positives)** — bats test fixture code invoking `git -C "$REPO" ...` for seeded-repo operations. Not stochastic operations Claude performed; test assertion infrastructure. Clean session signal otherwise.

## Security Review

- `security-audit.sh --files-only` run during `/review`: **PASS** — no secrets, PII, emails in non-example files, or dangerous file types.
- The `AUTO-CLOSE:` marker and all new bats fixtures contain only test data (ticket IDs, bare-repo paths, dummy email `t@t`) — no sensitive content.
- `cmd_sync_check` and `cmd_pr_guard` use `git -C "$repo_root"` consistently with quoted path expansion; no shell-injection surface on user-controlled inputs.
- No new secrets/tokens/keys introduced. All MCP calls this session went through pre-approved Linear permissions.

## Memory Candidates

- **Dogfood-close pattern now 3-for-3** (project) — BTS-128, BTS-119, BTS-122. Culturally entrenched. Expected end-of-ship behavior for any ship that introduces a primitive. If a future wrapper-ship doesn't self-close, that's a signal something's wrong.
- **`run --separate-stderr` + `bats_require_minimum_version 1.5.0`** (project) — preferred pattern for bats assertions that need to distinguish stdout from stderr. Codify as house style; existing suite has fragile `$output` assertions that should migrate in a sweep.
- **`_assert_error_format` ERROR:/blank/two-space-bullet** (project) — canonical shape for all new guard error messages in `docs-check.sh`. Should extend to existing guards in a future cleanup.
- **Plan-hash rebase pattern downgraded to "conditional"** (project/update) — prior 2-session streak was circumstantial. The real trigger is mid-TDD spec edits, not code-review WARNs in general. Update the existing memory about this friction point.
- **Extracting side-effect-free helpers from git-heavy commands is a reliable refactor move** (project/feedback) — `cmd_auto_close_emit` (BTS-119), `cmd_sync_check` (BTS-122). Pattern: when a command needs to decide something based on git state but the decision itself is pure logic, extract the decision into its own subcommand. Makes bats testing possible without git setup.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
