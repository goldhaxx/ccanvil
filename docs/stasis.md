# Stasis

> Feature: session-2026-04-25-bts-164-substrate-ship
> Kind: session
> Last updated: 1777145000
> Session objective: ship BTS-160 mktemp fix as a small opener; then ship BTS-164 Linear API substrate (Path A scope) so /recall + /radar stop reporting fossil idea-counts. Capture what couldn't ship as follow-up tickets.

## Accomplished

- **BTS-160 shipped (PR #73, merged).** Skill prose fix in `.claude/commands/permissions-review.md` — three `mktemp /tmp/foo.XXXXXX.json` invocations replaced with BSD-portable `mktemp -t <prefix>` form. Hoisted `$DECISIONS` tmpfile creation into Step 1 (per code-reviewer WARN). Linear BTS-160 → Done via the still-MCP path (last ship before BTS-164 migrated this).
- **BTS-164 shipped (PR #74, merged).** Linear API substrate landed: `linear-query.sh` wrapper (curl + jq + `LINEAR_API_KEY` auth) with subcommands viewer, list-issues, get-issue, list-states, list-labels, save-issue (create + update + transition). New `http` resolver mechanism in `operations.sh`. Migrated verbs: `idea.count`, `ticket.transition`, `ticket.get`. Skills updated for /spec, /activate, /land, /idea triage outcomes — all now use the `eval $(jq -r .invocation.command)` dispatcher pattern. 1140/1140 tests green; **39 net-new tests** across `linear-query.bats` (25), `operations-resolve-http.bats` (8), `idea-count-resolver.bats` (6); 3 existing test files migrated from mcp-shape to http-shape. Live verified end-to-end against real Linear.
- **The user-visible /recall + /radar fix is live.** Before: `idea-count` reported fossil counts from April 9–23 local log. After: returns current Linear state (1 triage / 15 backlog / 1 icebox / 2 canceled / 2 duplicate). Closes the recurring misinformation that motivated BTS-164.
- **Dogfood-close at the system level.** BTS-164 closed itself — first thing the substrate did after merging was use itself to mark itself Done. Same pattern as BTS-149's last-action self-application but at the substrate-replaces-MCP level.
- **Captured BTS-165** (provider-onboarding workflow — `/onboard linear` for credential discovery + validation + caching IDs) and **BTS-166** (Phase 2 Linear API migration for `/idea` capture/list/triage walkthrough; design open question on shell-quoting strategy for dynamic content).
- **/idea triage drained** earlier in the session: 14 promoted to Backlog with priorities, BTS-163 deferred to Icebox; remaining drain count for BTS-163 activation: 21 → ~22 with BTS-165 + BTS-166 added back.
- **Code review caught 3 WARNs**, all addressed before merge: symlink in test fixture (forgot the `feedback_no_symlinks` rule — replaced with `cp`), fragile `$?` capture in `_post_graphql` (now `local rc=$?`), and unsafe `$PRIORITY`/`$TARGET_ID` append in skill prose example (now `jq @sh`-quoted). Security audit: PASS, no findings.

## Current State

- **Branch:** `main` at `ee7a772`, in sync with origin/main.
- **Tests:** **1140 / 1140 green** via `bats-report.sh --parallel`.
- **Uncommitted changes:** none.
- **Build status:** clean.
- **Active spec:** none — between features.
- **Permissions audit:** danger=0, promote-review.total=0.
- **Specs archive:** 71 Complete (was 69 at session start; +bts-160, +bts-164).
- **Linear:** 22 ahead of BTS-163's drain gate (15 Backlog + 7 in pre-existing Backlog state, plus BTS-165, BTS-166 in Triage).

## Blocked On

- Nothing.
- Note: BTS-163 (release primitive) remains Icebox-deferred until backlog drains to 0 in Triage + Backlog. Drain count: 22 (high; not actionable this session).

## Next Steps

1. **BTS-156** — Gate `rm -rf` in guard-destructive.sh. Most acute outstanding security gap. Urgent priority. ~30 min.
2. **BTS-155** — guard-workspace `find -exec/-delete`. Urgent. Child of BTS-158.
3. **BTS-157** — `sort -o` writer flag. Urgent. Child of BTS-158.
4. **BTS-158** — workspace-fence umbrella ticket (consolidates 153/155/157). Urgent.
5. **BTS-153** — `cat` outside `~/projects`. High. Child of BTS-158.
6. **BTS-151** — `git commit -m` false-positive in guard-workspace (we hit it twice this session — known friction). High.
7. **BTS-159 / BTS-161** — `/permissions-review` substrate codification. Medium.
8. **BTS-162** — `/idea --parent` and capture-from-context. Medium.
9. **BTS-152 / BTS-150 / BTS-154** — classifier + audit-allowlist refinements. Medium / Low.
10. **BTS-166** — Phase 2 Linear API migration (the deferred /idea capture/list/triage paths). High (but design open question to settle first).
11. **BTS-165** — provider-onboarding workflow. Triage; promote when ready to ship publicly.
12. **Tech stack distribution** — roadmap "Up Next #1".

## Context Notes

- **Mechanism naming locked at Option A: `http`.** Three options surveyed (transport-shaped, capability-shaped, provider-shaped). Picked `http` because it's the right level — concrete enough that callers act on it without a separate dispatch step, abstract enough that "Linear" stays in the existing `provider` field. Future GitHub/Notion integrations also fit `http`. The capability-shaped (`read-remote`/`write-remote`) and provider-shaped (`linear`/`github`) alternatives both add a layer without removing one.
- **Path A scoping was load-bearing.** Original spec AC-4 promised migration of all 7 verbs (`idea.add`, `idea.list`, `idea.triage`, `idea.promote/defer/dismiss/merge`, `ticket.transition`, `ticket.get`, `backlog.list`). After digging in, surfaced honestly: full migration would require parallel /idea skill prose updates with shell-quoting decisions for dynamic content (title/description) — 3+ hours additional work. User picked Option A: ship dispatcher-pattern migration (ticket.transition + ticket.get) in v1, defer /idea capture/list/triage to BTS-166. Spec AC-4 + Out-of-Scope updated honestly to reflect actual scope. **Pattern: when implementing reveals over-scoped AC, scope down + capture follow-up — better than half-finishing.**
- **Linear API client design.** The wrapper accepts caller-provided IDs only (no name lookups). Resolver pre-resolves names from cached config (team_id, project_id, label_ids in `.claude/ccanvil.local.json`). Future operators need their own values — BTS-165's onboarding flow will discover and cache them. For ad-hoc CLI use, name-based flags can be added later as a follow-up.
- **Stub-endpoint pattern.** `hub/tests/fixtures/linear-stub.sh` shadows `curl` with a bash function (`export -f curl`) that captures invocation args to a side-channel file and echoes a canned response. Reusable across all wrapper subcommand tests. `LINEAR_QUERY_ENDPOINT` env override points production calls at the stub. Worked cleanly across 25 wrapper tests.
- **BSD bash parameter-expansion bug.** `local variables="${2:-{}}"` parses as `${2:-{` followed by literal `}` — yields `{}` when arg unset, but appends a stray `}` when arg is set. Caused jq `--argjson` failures in `_post_graphql`. Fixed with explicit empty-check (`local v="${2:-}"; [[ -z "$v" ]] && v='{}'`). Worth remembering — bash parameter expansion reads to first `}`, period.
- **Cron lock file friction (recurring).** Last session's stasis flagged "Cron-job durability verification" as a Determinism Review candidate (single observation: `durable: true` echoed "Session-only"). This session: confirmed durability is silently ignored AND the lock file (`.claude/scheduled_tasks.lock`) persisted as an untracked artifact, blocking `/activate`'s clean-worktree precheck. Two-observation pattern now → ticket-worthy (see Determinism Review).

## Determinism Review

- **operations_reviewed:** ~50 (full-session — spec/plan/activate/implement/review/PR/land × 2 features, plus skill prose updates and tests).
- **candidates_found:** 2.

- **NEW: Cron-machinery cleanup.** Confirmed two-observation pattern. The CronCreate `durable: true` flag is silently ignored on one-shot tasks (cron job didn't persist; verified `.claude/scheduled_tasks.json` doesn't exist). Worse: the runtime lock file `.claude/scheduled_tasks.lock` DID persist, isn't gitignored, and contaminates downstream tooling — blocked `/activate`'s clean-worktree precheck this session, requiring manual `rm` mid-flow. Capture as a real ticket: (a) gitignore `.claude/scheduled_tasks*` (b) document or fix the durability gap on one-shots (c) consider whether scheduled-task state should live somewhere other than `.claude/`. Impact: medium (recurring friction; affects every session where cron is used). **Action: ticket-worthy in next session.**
- **NEW: Symlink-rule violation (caught by reviewer).** I added `ln -s` in a bats test fixture despite the `feedback_no_symlinks` memory. Reviewer caught it; fixed in commit `00cba3a`. Consider whether the auto-memory rule needs a more aggressive surfacing mechanism — relying on me-remembering-during-write is unreliable when working fast. Could be a pre-commit grep that flags `ln -s` outside known-safe paths, or a bats-lint rule. Impact: low (caught by review; would have been merged with the symlink if review skipped). **Action: idea-capture for a `bats-lint` extension that catches `ln -s` in test files.**

## Cross-Session Patterns

- **CONFIRMED RECURRING (now a real pattern): Cron-machinery durability gap + lock-file leak.** Last stasis flagged "Cron-job durability verification" as single-observation. This session confirmed: durability is silently ignored AND the lock file leaks. Two observations → ticket-worthy. Listed in Determinism Review above; will be captured in the next session.
- **NEW: Spec scope honest-update at PR time.** When mid-implementation reveals an AC was over-promised, scope down + capture follow-up cleanly. Did this for BTS-164 AC-4 (Path A scope; Phase 2 → BTS-166). Healthy pattern — better than partial completion or skipped tests. Worth memorizing as a workflow heuristic.
- **CONFIRMED: dogfood-close cultural invariant.** Cumulative count: ~30+ now. BTS-164 closed itself via the substrate it shipped — most explicit instance yet of the system using its own output to complete itself.
- **CONFIRMED: legacy-refs-scan stays clean** (0 matches). BTS-132 mechanism continues to hold.
- **CONFIRMED: classifier-semantics gap family still at 2 tickets** (BTS-150 + BTS-154). Below the 4-5 threshold for structural cleanup. Watching.

## Security Review

- This session added: 1 new script (`linear-query.sh` — uses `LINEAR_API_KEY` from env, never logged or committed), 1 test fixture (`linear-stub.sh`), 3 new bats files, modifications to skill prose and resolver. Plus gitignored `ccanvil.local.json` updates with team_id/project_id/label_ids — workspace-specific, never committed.
- `security-audit.sh --files-only` run as part of /review: PASS, no secrets/PII/dangerous-files findings.
- `LINEAR_API_KEY` is sourced from `.env` (gitignored) at use time; never written to logs or committed.
- Verdict: **PASS**.

## Memory Candidates

- **Mechanism naming heuristic — pick the level concrete enough to act on without a separate dispatch step.** When taxonomizing resolver output (or any layered abstraction), the right level is the one where consumers can act on the value without needing another lookup. `http` over `read-remote` because consumers need the actual transport; `http` over `linear` because the transport is reusable across providers. Worth a feedback memory.
- **BTS-164 substrate is shipped (Path A) — `/recall` + `/radar` now read live Linear state.** Update `project_linear_api_substrate.md` memory (created last session) to reflect: substrate is live; Phase 2 (idea.add/list/triage) deferred to BTS-166. Mark BTS-164 as shipped.
- **Path A scoping pattern.** When implementation reveals over-scoped AC, scope down + capture follow-up cleanly. Spec AC-4 was over-promised; mid-implementation I reduced scope to dispatcher-pattern migration only, captured Phase 2 as BTS-166, updated the spec honestly. Worth a feedback memory: "If an AC turns out larger than the session can support, prefer scope-down + follow-up ticket over partial completion."
- **No external references discovered this session that aren't already memorialized.**

Memories to save in this stasis: yes — three above (mechanism-naming, substrate-update, scope-down pattern).

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
