# Stasis

> Feature: session-2026-04-24-bts-119-ship
> Kind: session
> Last updated: 1777045931
> Session objective: Ship BTS-119 (auto-close linked Linear issue on PR merge) — the sibling ship to BTS-128 that closes the remaining manual Linear state-transition step. Dogfood by self-closing BTS-119 via the `/land` skill it ships.

## Accomplished

- **Shipped PR #48 (`86e26bc`)** — `bts-119-auto-close-linear-on-merge`. 5 commits on branch: activate → Phases 1-2 helpers → Phases 3-5 skill+docs+tests → code-review fix commit → lifecycle cleanup. Full suite **864/864 bats green** (+14 from 850 baseline via `hub/tests/auto-close-linear-on-merge.bats`). Clean squash-merge + FF `land`. No regressions — not one pre-existing test needed updating this time (unlike BTS-128's `idea-triage-native.bats` update).
- **BTS-119 closed via `/land`'s first real invocation** — `docs-check.sh land` emitted `AUTO-CLOSE: {"provider":"linear","id":"BTS-119","role":"done"}` → `ticket.transition BTS-119 done` resolved to `save_issue` payload → MCP call flipped Linear to `Done` with `completedAt: 2026-04-24T15:49:05Z`. Second consecutive dogfood close; pattern now robust. This ship also completes the full "post-merge cleanup" loop: spec archive auto-Completes (BTS-114, shipped), feature branch deleted (`cmd_land`), Linear issue auto-Dones (BTS-119, this session). No manual state flips anywhere.
- **Two deterministic shell helpers in `docs-check.sh`:**
  - `cmd_extract_work <spec-file>` — reads `> Work:` metadata, emits `{"provider","id"}` JSON. Empty stdout + exit 0 for legacy specs (BTS-119's grandfather rule for AC-5). Malformed `Work:` values treated as legacy too.
  - `cmd_auto_close_emit <branch> [docs-dir]` — maps branch + Work → `AUTO-CLOSE: {...}` marker (linear) or named skip log (local/unknown provider/non-claude branch). Pure logic, zero git side effects. Integrated into `cmd_land` after the existing post-merge safety net.
- **New `/land` slash command** — wraps `docs-check.sh land`, greps stdout for the AUTO-CLOSE marker, resolves `ticket.transition <id> done` via `operations.sh`, dispatches MCP `save_issue`, falls back to `.ccanvil/ideas-pending.log` with `op:"ticket.transition"` on MCP failure. `/pr` docs updated to point post-merge users at `/land` (running `docs-check.sh land` directly still works but skips the auto-close).
- **`/idea sync` dispatch table extended** for `op:"ticket.transition"` entries — re-resolves via `operations.sh` and dispatches `save_issue`. Idempotent on Linear's side so replay is safe. Shape-agnostic `cmd_idea_sync` needed no script changes; two new bats tests lock in the list + ack paths for the new entry shape.
- **Code review gate caught 4 WARN + 5 NIT, all addressed pre-merge** (commit `e06cf13`):
  - W1 documented: `gh pr merge --delete-branch` switches to main before `/land` runs, tripping `cmd_land`'s "already on main" early return. Workaround (run `/land` before `gh`) + followup hook noted in `land.md` Rules. Future ship candidate: parse squash-commit subject to recover feature-id on that path.
  - W2 fixed: `land.md` Rule 1 was wrong about `/idea sync` replay for direct-script users — nothing gets queued in that path. Corrected.
  - W3 fixed: renamed AC-2 test label to "(foundation)" to match scoping language.
  - W4 fixed: spec AC-9 text rewritten — implementation uses branch-name regex (reusing safety-net parser), not commit-message parsing as the original spec said.
  - N3/N4/N5 fixed: inline comment cleanup, missing `status` assert in AC-4 test, unquoted vars in `bash -c` subshells (hardening for TMPDIR with spaces).
- **Plan-hash rebased mid-flow** — mid-TDD spec edit for W4 → `> Spec hash:` stale → one-line update to `plan.md`. Second session in a row this came up; now a well-known pattern.
- **Command-reference guide extended** with `/land`, `extract-work`, `auto-close-emit` rows. AUTO-CLOSE marker contract documented on `cmd_land`'s entry.

## Current State

- **Branch:** `main` at `86e26bc`, synced with origin.
- **Tests:** 864/864 bats green at PR HEAD (post-merge on main: not re-run, squash was FF-equivalent).
- **Uncommitted changes:** none (working tree clean post-`/land`).
- **Build status:** clean.
- **Context budget:** 5188 / 8000 tokens = 64.8% (HEALTHY — unchanged from prior two sessions).
- **Permissions audit:** 20 DANGER + 167 UNREVIEWED (was 166; +1 from a newly-used Linear MCP permission this session — not sensitive, content-neutral save_issue).
- **Specs archive:** 45 complete (was 44); no active/ready/in-progress specs.
- **Linear state:** BTS-119 `Done` with `completedAt: 2026-04-24T15:49:05Z` and PR #48 auto-attached by Linear's GitHub integration (branch substring match `claude/feat/bts-119-auto-close-linear-on-merge`). Linear Triage inbox still at 0.

## Blocked On

- Nothing.

## Next Steps

1. **Ship BTS-122** (pre-activate guard audit) — 10 enumerated gaps in the ticket. BTS-119 is now done; BTS-122 is next in priority order per last stasis. Good focused session scope.
2. **Ship BTS-127 + BTS-118** (bats assertion-leak family) — codify the combined-`jq -e 'a and b'` pattern across the existing 864-test suite. The new `auto-close-linear-on-merge.bats` uses it already; rest of the suite predates it. One bundled ship.
3. **Ship BTS-129** (`ticket.find-by-title` wrapper) — sibling of BTS-128 in the deterministic-wrapper family. Needed as a primitive for BTS-123. Third dogfood-close candidate (would complete the trilogy after BTS-128 and BTS-119).
4. **Ship BTS-123** (pending-log fallback integrity) — correctness bug in the MCP-down replay path. Waits on BTS-129 for idempotent replay semantics. Sibling family with BTS-119's new `op:"ticket.transition"` queue.
5. **Ship BTS-131-135** (ccanvil tooling correctness bundle) — 5 small correctness/determinism items. BTS-131 (bats double-run → one-shot reporter) unlocks a session-wide efficiency win; BTS-134/135 are sub-30-min each.
6. **Ship BTS-125** (Linear save_issue markdown truncation codification) — P4 nice-to-have. Ship when a session wants a small finisher.
7. **Longer horizon:** BTS-113 (stale recommend after stasis+compact+recall). The stale "/compact to wrap session" recommendation I saw this session at `/recall` is a live example — evidence for the ticket.

## Context Notes

- **Dogfood close pattern now culturally established** — BTS-128 (last session) + BTS-119 (this session) both self-closed via their own primitives. Pattern: ship the wrapper → use the wrapper's first real invocation to close the driving ticket. Validates happy path + marks the determinism candidate resolved in one motion. BTS-129 (sibling wrapper) is the natural third trial.
- **Extracted helper vs inline emission** — the plan initially prescribed inlining the AUTO-CLOSE emit inside `cmd_land`'s regex block. Mid-Phase 2 I judged that extracting `cmd_auto_close_emit` as a separate subcommand made testing tractable (no git setup needed — just crafted branch names + fixture specs). The inline call from `cmd_land` preserves the high-level intent. Lesson for future refactors: push git-side-effect-free decision logic out of integrated flows so bats can exercise every skip path. No plan-hash rebase needed — plan text still broadly accurate.
- **AUTO-CLOSE marker protocol** — `AUTO-CLOSE: {json}` on stdout is the script→skill handoff contract. Line-prefix + single-line JSON + `^AUTO-CLOSE: ` grep anchor. The prefix is unique in `cmd_land`'s output (verified in code review). This pattern could generalize to other script→skill intent handoffs.
- **Known `gh pr merge --delete-branch` gap** — documented in `land.md` Rules, flagged as future-ship candidate. The fix is to parse the squash-commit subject when `cmd_land` is already on main; ~30 min of work. Priority depends on how often Zach uses the `--delete-branch` flag. This session I used `--squash` (without `--delete-branch`) specifically to test the happy path — worth verifying whether that was circumstantial or an implicit workflow preference.
- **Mid-TDD spec edit workflow** — second session in a row the code-review WARN-fix edit to `docs/spec.md` invalidated the plan hash. The fix is one line to `plan.md`, but the friction adds up. Candidate for a micro-script: `docs-check.sh rebase-plan-hash` that reads `status` and writes the new hash in place. Conditional candidate — ship if it recurs again.
- **TaskCreate discipline** — used task list for the first time this session (12 TDD steps). Low overhead, high visibility into progress. Worth doing routinely for features with >4 phases; pointless for smaller scope.

## Determinism Review

- **operations_reviewed:** 24
- **candidates_found:** 1 resolved recurring + 0 new
- **RESOLVED (recurring):** **Manual Linear state transitions post-merge** — prior stasis (BTS-128 session) flagged this as the remaining manual Linear step after BTS-128 shipped. BTS-119 closes the loop: `/land` dispatches `ticket.transition` deterministically. First live use this session (BTS-119 → Done) required zero manual UUID handling. No manual save_issue calls anywhere in the land flow.
- **No new candidates this session.** Every operation in the TDD cycle routed through deterministic script calls (`docs-check.sh`, `operations.sh`, `bats`, `jq`, `git`, `gh`). Stochastic surface stayed appropriately scoped to spec/plan writing, test drafting, and code-review synthesis. Audit-session flagged one `jq` pattern in the new bats file — false positive (assertion expression, not a stochastic op).

## Cross-Session Patterns

- **RESOLVED: BTS-119 manual Linear transition** — prior stasis flagged it as the remaining manual state-flip step. **Fix shipped in this PR.** The `/land` wrapper's first live use closed BTS-119 itself. Next session should NOT need to transition Linear issues manually post-merge.
- **RESOLVED (2nd consecutive): BTS-128 manual UUID paste** — did not recur. The `ticket.transition` primitive is now the default path for every state transition across `/idea`, `/land`, and future flows.
- **RESOLVED (3rd consecutive): BTS-120 session-stasis trap** — activate on fresh main worked without the `git rm docs/stasis.md` workaround. Kind: session discriminator holding firm across three shipped features.
- **RECURRING (2x): Plan-hash rebase after mid-TDD spec edit** — pattern appeared in BTS-128 session AND BTS-119 session. Both times for a code-review WARN-fix that touched the spec. Becoming predictable enough to warrant a deterministic wrapper if it recurs once more. See Memory Candidates.
- **Legacy-refs-scan: 11 matches total** — 3 hub-owned (`command-reference.md`, `session-management.md` x2, `docs-check.sh`), 8 node-specific (`foundations.md` x2, `.ccanvil/ideas.log` x4 pre-existing captures). Unchanged from prior sessions. Hub-owned resolve on next `/ccanvil-pull` on downstream nodes.
- **Audit-session since `fcd0803`: 1 pattern (false positive)** — a `jq` match in the new bats file, but it's a test assertion expression, not a stochastic operation. Clean session signal otherwise.

## Security Review

- `security-audit.sh --files-only` run during `/review`: **PASS** — no secrets, PII, emails in non-example files, or dangerous file types.
- The `AUTO-CLOSE:` marker contains only a ticket ID + state constant — no sensitive data. Verified that every code path that writes the marker uses `jq -cn` (structured, no interpolation injection).
- The `cmd_auto_close_emit` role-allowlist check in `ticket.transition` (pre-existing from BTS-128) keeps the MCP dispatch surface tight — unknown roles fail loud before hitting the resolver.
- No new secrets/tokens/keys introduced. All MCP calls this session went through pre-approved Linear permissions.

## Memory Candidates

- **Dogfood-close pattern is now cultural** (project) — two consecutive sessions (BTS-128, BTS-119) shipped wrappers that closed their own driving tickets via their own first live invocation. Expected end-of-ship behavior in this repo going forward, not coincidence. BTS-129 is the natural third trial to confirm the pattern fully.
- **Plan-hash rebase friction recurring** (project/conditional) — spec edits mid-TDD (typically for code-review WARN fixes) invalidate the plan's `> Spec hash:`. One-line manual fix but now hit twice in a row. If it recurs a third time, ship a `docs-check.sh rebase-plan-hash` subcommand (conditional candidate).
- **`gh pr merge --delete-branch` skips auto-close** (project/reference) — known gap documented in `land.md` Rules. Future fix: parse squash-commit subject on `cmd_land`'s "already on main" early-return path to recover feature-id. Priority depends on how often this flag is used in practice; this session I intentionally used `--squash` without `--delete-branch` to exercise the happy path.
- **AUTO-CLOSE marker protocol** (project) — `AUTO-CLOSE: {json}` + single-line + `^AUTO-CLOSE: ` grep anchor pattern worked cleanly as a script→skill intent handoff. Generalizable for future features where a shell script needs to signal a skill to do an MCP-side dispatch. Worth capturing as a reusable contract name.
- **Refactor mid-TDD is OK if intent preserved** (feedback/project) — extracted `cmd_auto_close_emit` as a helper instead of inlining per the plan's original Phase 2 prescription. The extraction made the decision tree testable with zero git setup. No plan-hash rebase was needed because the plan's Step 5 description ("extend cmd_land") remained broadly accurate. Judgment call validated by passing bats + passing review.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
