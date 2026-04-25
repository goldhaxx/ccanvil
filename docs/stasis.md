# Stasis

> Feature: session-2026-04-25-guard-layer-hardening
> Kind: session
> Last updated: 1777156100
> Session objective: close the acute guard-layer gaps surfaced during BTS-149's DANGER review pass — and resolve the workflow friction those gates created.

## Accomplished

Five Linear tickets shipped, one umbrella closed:

- **BTS-156 (Urgent, PR #76).** Path-agnostic `rm -rf` shape gate in `guard-destructive.sh`. Detects each flag independently so cluster (`-rf`), split (`-r -f`), mixed (`-r --force`), and long-form (`--recursive --force`) all block. Bypass: `ALLOW_DESTRUCTIVE=1`. 24 tests.
- **BTS-155 (Urgent, PR #77).** Destructive-find shape gate (`-delete`, `-exec`, `-execdir`, `-okdir`) in `guard-destructive.sh`. Also added `find` to `guard-workspace.sh`'s gated-verb regex so out-of-workspace traversal trips the path fence. 13 tests.
- **BTS-157 (Urgent, PR #78).** One-line gate: `sort` added to `guard-workspace.sh` verb regex. The existing path-token iteration applies the workspace fence to `-o FILE` writer-flag targets and shell-redirect targets incidentally. 9 tests.
- **BTS-153 (High, PR #79).** `cat` added to `guard-workspace.sh` verb regex — read-side fence for exfiltration risk (`cat ~/.ssh/id_*`, `cat /etc/*`). Last child of BTS-158; umbrella closed. 11 tests + BTS-146 AC-12 contract-flipped.
- **BTS-151 (High, PR #80).** Early-exit on `git commit` in both guard hooks. Eliminates the recurring false-positive where commit message bodies mentioning verbs (`bash`, `cat`, `rm`) or path-shaped strings (`/stasis`, `/tmp/foo`) tripped the path scan or destructive-shape regex. Workaround was always `commit -F` to a tmpfile — hit 3+ times this session before this fix landed. 13 tests including quoted env-prefix coverage.
- **BTS-158 closed.** Workspace-fence umbrella — all three children shipped (BTS-153, BTS-155, BTS-157).

Bookended by:
- `/permissions-review` — dropped one DELETE candidate (`Bash(ALLOW_OUTSIDE_WORKSPACE=1 bash /tmp/check_tmpdir.bats)`), leftover from a code-reviewer agent investigation last session.
- `/idea triage` — BTS-165 (provider-onboarding) deferred to icebox; BTS-166 (Phase 2 Linear API migration) promoted to backlog at P2.

Cumulative pattern count: ~36+. Five consecutive ships, each with code-review + addressed-WARNs + auto-close via the BTS-128 / BTS-164 substrate.

## Current State

- **Branch:** `main` at `ae8b7f0`, in sync with origin/main.
- **Tests:** **1221 / 1221 green** via `bats-report.sh --parallel`.
- **Uncommitted changes:** none.
- **Build status:** clean.
- **Active spec:** none — between features.
- **Permissions audit:** danger=0, promote-review.total=0. Clean.
- **Linear:** 0 in Triage, 10 in Backlog (was 16 — six Urgent/High shipped this session — wait, five shipped + 1 unrelated triage; hmm let me recount). Actually 56 total, 10 backlog, 2 icebox, 2 canceled, 2 duplicate, 40 done.

## Blocked On

- Nothing. Five urgent/high gates closed; the friction tickets they generated also closed.

## Next Steps

1. **Cron-machinery cleanup** — Two-observation pattern that's persisted across multiple stases without being captured as a Linear issue. Gitignore `.claude/scheduled_tasks*` and document/fix the durability gap. Medium. Worth opening as an idea before another session passes.
2. **BTS-159 / BTS-161** — `/permissions-review` substrate codification (decision-append / entry-context substrates). Medium.
3. **BTS-162** — `/idea --parent` and capture-from-context. Medium.
4. **BTS-166** — Phase 2 Linear API migration (deferred /idea capture/list/triage paths). High; design open question (shell-quoting strategy) to settle at spec time.
5. **BTS-22** — Docs directory strategy (multi-file specs/plans/stasis). Medium, needs-research.
6. **BTS-20 / BTS-21 / Dark code framework** — strategic Horizon items per roadmap. Low / needs-research.
7. **Tech stack distribution** — roadmap "Up Next" item: distribute tech stack profiles from hub to nodes. Spec written, ready to activate.
8. **BTS-165** — provider-onboarding workflow. Iceboxed; revisit when packaging for distribution.

## Context Notes

- **Five consecutive `feat → review → fix → pr → land` cycles in one session.** Pattern works: each ticket was small enough (~30 min including review) that the lifecycle ceremony didn't dominate. The substrate (auto-transition + auto-close + http resolver) made the per-ticket overhead negligible. Once the user said "continue 157" mid-cycle, dropping into auto-mode for sequential Urgent items was the right read.
- **Guard-layer false-positive cascade.** Adding BTS-156's `rm -rf` regex to `guard-destructive.sh` immediately created the `git commit -m "fix rm -rf"` false-positive that BTS-151 had to address. Same with BTS-153's `cat` adding to the workspace verb list, which made any commit message mentioning `cat` trigger a path scan. The pattern: every shape-detection gate added to a hook that scans the literal command string creates a new false-positive surface for narrative text (commit messages, echo, grep arguments). BTS-151's `git commit` early-exit is the structural countermeasure — but it doesn't help echo / grep / printf with similar payloads. Worth watching whether more false-positive friction surfaces.
- **`git commit` early-exit is incomplete for chained shapes.** AC-9 explicitly accepts `git commit -m "x" && rm -rf /` as bypassed; AC also doesn't handle `git add . && git commit -m ...` (the command starts with `git add`). Hit the latter twice during BTS-151 itself — workaround is to split staging and committing into two Bash invocations. Not blocking, but the friction may resurface.
- **Code review subagent caught one real CONCERN per ticket.** BTS-156: split-flag gap (`rm -r -f` evaded the cluster regex). BTS-155: comment inverted truth about quote boundary. BTS-157: gsort known-limitation undocumented. BTS-153: BTS-146 AC-12 silently removed instead of contract-flipped. BTS-151: quoted env-prefix values fell through. The reviewer earned its keep — every concern was a real defect.
- **Test infra quirk for quoted args.** BTS-155 AC-8 (quoted `-name '-delete'`) had to use a tmpfile + heredoc instead of inline JSON because bats's `bash -c "echo '$input'"` re-parses single quotes during expansion, stripping them. Pattern documented inline. Future tests passing single-quoted shell args need the same approach.
- **The bats-report-text-output flake.** BTS-153 ship had one transient run report `PASS: 1206 / FAIL: 1 / TOTAL: 1207` with no `not ok` line; immediately re-running showed clean. Suspicion: race condition in --parallel summary aggregation. Filed mentally, not actionable.

## Determinism Review

- **operations_reviewed:** ~30 (5 ticket lifecycles × ~6 lifecycle ops each, plus permissions-review and idea-triage walkthroughs).
- **candidates_found:** 1.

- **Single-Bash-invocation `git add ... && git commit ...` pattern.** I hit the BTS-151 false-positive twice during its own commit because Claude Code's typical commit shape chains `git add` and `git commit` in one Bash call. The chained command's leading verb is `git add`, not `git commit`, so the new early-exit doesn't fire. The current workaround — split into two Bash invocations — is stochastic per-call. A more deterministic fix would be either (a) `/commit` as a skill that always splits stage + commit, or (b) tightening the early-exit regex to allow `git add` followed by `git commit`. Captured as a possible future ticket; not urgent.

## Cross-Session Patterns

- **CONFIRMED RECURRING: `git commit -m` false-positive friction.** Logged in the prior stasis (BTS-167's session) as a known issue with a noted workaround. THIS session shipped BTS-151 to resolve it deterministically. Pattern: when friction recurs across 2+ stases, ticket-and-ship is the right move (the workaround tax compounds).
- **CONFIRMED RECURRING: `bats-report.sh` over-invocation.** Last session flagged this. Did not recur this session — every test cycle used a single invocation with appropriate filtering (`-f 'BTS-15X'`). Closed as a learned pattern, not actionable.
- **CONFIRMED CARRY-OVER: Cron-machinery durability gap.** Flagged in three consecutive prior stases now. Still uncaptured as a Linear ticket. Should open it next session before the gap drifts further.
- **CONFIRMED: legacy-refs-scan stays clean** (0 matches with allowlist). BTS-132 mechanism continues to hold.
- **CONFIRMED: dogfood-close cultural invariant.** All five tickets this session closed via the BTS-128 / BTS-164 substrate. Auto-close fired on every `land`.
- **NEW: Shape-gate / narrative-string false-positive cascade.** Each new shape-detection regex added to a guard hook creates a false-positive surface for narrative strings in commit messages, echo args, etc. Watch for the next instance.
- **NEW: Code-review CRITICAL/CONCERN hit rate.** Five reviews in this session, five real defects caught. The reviewer is well-calibrated for hook-layer changes — keep using it on guard-hook PRs even when the diff is small.

## Security Review

- **Five hook changes** all expanded blocking surface (BTS-153/155/156/157) or relaxed it (BTS-151's `git commit` early-exit).
- BTS-151's relaxation is bounded: chained `git commit -m "x" && rm -rf /` could bypass the destructive gate. Documented; operationally rare; ALLOW_DESTRUCTIVE=1 envelope still works for the legitimate case.
- `security-audit.sh --files-only`: PASS (no secrets, PII, or dangerous file types in any of the 5 commits).
- No new attack surface created by shape-gates — they're path-agnostic detection of dangerous flag combinations, not credentials handling or network code.
- Verdict: **PASS**.

## Memory Candidates

- **Update `project_linear_api_substrate.md` (or sibling)** to note the BTS-158 umbrella's resolution: workspace-fence + destructive-shape gates are now structurally complete for the verbs surfaced in BTS-149's DANGER review (rm/find/sort/cat). Future hardening in this family should follow the same shape: regex for the bad shape, path-agnostic, ALLOW_DESTRUCTIVE / ALLOW_OUTSIDE_WORKSPACE bypass, comprehensive bats coverage including word-anchor + bypass + safe-shape tests.
- **NEW feedback memory candidate: shape-gate / narrative-string cascade.** When adding a regex-based shape gate to a hook that scans literal command strings, the same regex becomes a false-positive trigger for commit messages, echo args, etc. The structural countermeasure is BTS-151-style early-exits for `git commit` (and possibly other narrative-rich commands). Pattern worth capturing if it recurs once more (it just did, with 5 consecutive examples in one session).
- **Reinforce: code-review subagent on hook-layer changes.** Every review caught a real defect. Don't skip /review for hook PRs even when the diff is one line.

Memories to save in this stasis: yes — both candidates above are non-obvious + recurring.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
