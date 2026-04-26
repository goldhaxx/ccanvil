# Stasis

> Feature: session-2026-04-26-backlog-annihilation-batch-4
> Kind: session
> Last updated: 1777182558
> Session objective: post-/compact continuation of backlog annihilation. Started with stasis-recall claiming "P3=0, P4=0" — Zach corrected that the idea-labeled subset is not the backlog. Real backlog had 4 scaffold-labeled tickets; this session shipped 5 (one was a Part 1 already in flight, four new) plus two captures-then-ships in same session.

## Accomplished

**Five substrate ships:**

- **BTS-162 Part 1 (P3, PR #93).** `/idea --parent <ref>` flag for capture-time parentId. Covered both Linear (http via `linear-query.sh save-issue --parent-id`) and local (JSONL `parent_id` field) providers + pending-log enqueue/replay. /review surfaced 3 CONCERNs — all addressed before commit (Sync-replay drop, Step-3b local pass-through, validation parity). 15 bats. Part 2 deferred (depends on session-context plumbing).
- **BTS-125 (P4, PR #94, scope-down on reveal).** Original ticket framed as "MCP save_issue silently truncates nested markdown" — incident from 2026-04-23. Live repro on 2026-04-26 (test ticket BTS-174, both http + MCP routes) showed catastrophic truncation **no longer reproduces** (Linear server-side fixed). A residual cosmetic mutation persists: list-item leading bold whose content STARTS with a backticked code-span gets stripped on save. Documented avoidance shapes in `/idea` SKILL.md Safe-markdown section. Round-trip-validation wrapper + pre-send linter (original proposals) deemed overinvestment. 5 drift-guard bats. Pure-prose ship.
- **BTS-173 (P3, PR #95, mid-implementation scope-down).** Workspace-fence `/word` exemption for slash-command names. First-attempt regex `^/[a-zA-Z][a-zA-Z0-9_-]{0,29}$` correctly exempted `/idea` BUT also `/etc`, `/var`, `/a` — broke BTS-155 AC-10 + BTS-147 AC-6. Real system paths and slash-command names are **syntactically identical**; pure-syntactic disambiguation impossible. Pivoted mid-impl to filesystem-rooted allowlist: read `.claude/commands/*.md` + `.claude/skills/*/`, exempt only single-segment tokens whose basename matches. 13 bats including explicit `/etc` collision regression-guard. Captured during the session BEFORE shipping.
- **BTS-172 (P3, PR #96, scope-down).** /idea capture flags for templated body sections (Part 2 of BTS-162). Original framing called for `capture-from-context` subcommand with auto-detection of active skill name + cross-session family. Auto-detection requires session-context plumbing that doesn't exist yet; pivoted to explicit-flag form (`--source-skill`, `--context`, `--family`). New deterministic substrate `docs-check.sh idea-template-body` owns templating; skill prose is thin (flag forwarding). Bare `/idea <text>` unchanged. 14 bats. Captured during session BEFORE shipping (so it materialized as same-session ship, not deferred backlog).
- **BTS-72 (P3, PR #97, /review caught BLOCKING).** Local-only repo lifecycle adapter via new `detect-repo-type` substrate. Both `cmd_land` and `/pr` branch on `{type: github|other-remote|local}`. Local-only path performs in-place `git merge --no-ff` instead of GitHub PR flow. /review surfaced **2 BLOCKING + 3 CONCERN + 2 NIT** — all addressed: BLOCKING-2 was a real merge-state corruption bug (failed merge would leave user on main with lingering `MERGE_HEAD`; now `git merge --abort` + return to feature branch). CONCERN-1 was a real false-positive risk (host extraction now uses regex on URL, not substring on full URL — `gitlab.com:user/github.com-mirror.git` would have classified as github before). 16 bats including `git init` fixture pattern (new for ccanvil's bats — most used synthetic dirs). Doc'd AC-5 honest gap: AUTO-CLOSE marker doesn't fire on already-on-main local-only path because branch recovery requires `gh`.

**Two new captures (no ships, deferred backlog):**

- None this session — every capture became a same-session ship (BTS-172 / BTS-173).

**Day combined ledger across all sessions: 17 ships** (8 morning + 4 afternoon + 5 this batch). All of priority-3 + priority-4 in the actual backlog cleared except BTS-22 (P3 Docs directory strategy), BTS-20 + BTS-21 (P4 needs-research, framed as "genuinely future work").

## Current State

- **Branch:** `main` at `16cc5b5`, in sync with origin/main.
- **Tests:** **1413 / 1413 green** via `bats-report.sh --parallel`.
- **Uncommitted changes:** none.
- **Build status:** clean.
- **Active spec:** none — between features.
- **Permissions audit:** `danger=0`, `promote-review.total=0`. Clean.
- **Linear backlog (verified — by direct `mcp__claude_ai_Linear__list_issues --state Backlog`, NOT via `idea.list`):**
  - **BTS-22** (P3) — Docs directory strategy (multi-file specs/plans/checkpoints). Substrate change. Meatier.
  - **BTS-20** (P4) — Workflow engine / deterministic state machine. `needs-research`, framed as genuinely future work.
  - **BTS-21** (P4) — GitHub Agentic Workflows (gh-aw) integration. `needs-research`, framed as genuinely future work.
- **Untriaged ideas:** 0.
- **Context budget:** Session at ~36% used (per /context). Auto-compact buffer untouched.

## Blocked On

- Nothing. Five clean ships across the post-compact session; cadence held through substrate maturity.

## Next Steps

1. **BTS-22** — Docs directory strategy. Substrate-foundational (multi-file specs/plans/checkpoints, splitting today's monolithic `docs/spec.md` into directory). Bigger design space than today's ships; deserves its own session with fresh context.

2. **After BTS-22 ships, drop to P4** — both remaining (BTS-20, BTS-21) are explicitly `needs-research`. Either re-evaluate priority (icebox candidates?) or do the research and let it inform the backlog.

3. **Re-evaluate icebox.** Two icebox tickets (BTS-163 release primitive, BTS-165 provider-onboarding) are stale-by-cadence (60+ day re-eval). Worth a `/idea review-icebox` pass to confirm or promote.

4. **Optional: Address the new determinism finding** (see Determinism Review). The `/idea list` view filtered by `label=idea` hid 4 scaffold-labeled backlog tickets from my "what's left" reasoning earlier this session. A small fix to /recall (use `backlog.list` not `idea.list` for the canonical "remaining work" view) prevents recurrence.

## Context Notes

- **The "view-vs-truth" determinism error.** /recall + my session reasoning treated `idea.list` (Linear filter `label=idea`) as canonical for "what's in the backlog." Zach pushed back ("there are 4 items in the backlog, wdym zero") — and they were right. Four `scaffold`-labeled tickets in Backlog state were invisible to the idea-filtered view. Lesson: a filtered listing is not the truth; the truth is queryable via `mcp__claude_ai_Linear__list_issues --state Backlog` without label filter, OR via the existing `operations.sh resolve backlog.list` which doesn't carry the idea label by default. /radar's "Up Next" section also surfaces full backlog. The fix is at the recall/radar layer — use the broader query so Claude doesn't reason from a partial view that looks complete.

- **Scope-down on reveal validated 4× in single session.** Memory `feedback_scope_down_on_reveal.md` had 1-2 prior occurrences. This session: BTS-125 (catastrophic truncation moot, scope to safe-markdown rule), BTS-173 (regex too broad, pivot to allowlist mid-impl), BTS-172 (subcommand framing dropped, scope to flags), BTS-72 (Out-of-Scope captured 4 follow-ups during spec). Pattern is now load-bearing; the memory is well-validated.

- **Live-API discipline held under fire (BTS-125).** Plan didn't flag a live-API risk explicitly, but the spec required validating "is this still reproducible at all?" before shipping any wrapper. Live repro via test ticket BTS-174 — exactly the discipline BTS-171 codified — surfaced that the entire ticket scope was stale. ~5-minute live test prevented building a wrapper for a non-existent failure mode. Memory + rule continue to validate.

- **Substrate compounding (5×).** BTS-72's local-only path uses BTS-128/164's `cmd_auto_close_emit`. BTS-173's allowlist reads BTS-115's commands+skills directories. BTS-172 leans on BTS-162 Part 1's `--parent` extraction pattern. BTS-125's drift-guards mirror BTS-171's pattern. Each ship makes the next one cheaper and lower-risk.

- **/review continues to pay for itself.** 4 substrate-touching ships ran /review (BTS-162 Part 1, BTS-72; BTS-173 + BTS-172 + BTS-125 self-judged sufficient). BTS-72's pass surfaced **a real BLOCKING bug** (merge-state corruption on conflict) and **a real CONCERN** (substring-match false-positive on `github.com` in repo path). Without /review, both would have shipped. The skip-/review-on-pure-prose rule (BTS-125 prose-only diff) continues to be the right cut.

- **Two captures-then-ships in same session.** BTS-172 and BTS-173 were captured during this session AND shipped during this session. The original ticket BTS-162 had Part 2 framed as "deferred to follow-up" — but Part 2's friction was friction encountered in the very next ship's repro flow, so deferring would've been pointless. Captured + shipped > captured + waited. The `--parent` flag (BTS-162 Part 1) was used to file BTS-172 as a child, dogfooding the just-shipped feature.

## Determinism Review

- **operations_reviewed:** ~28 (5 ticket lifecycles × ~5 lifecycle ops, plus /idea triage dispatches, /review dispatches, security audit, full-suite runs, the live-API repro on BTS-174, plus the determinism-finding investigation on backlog visibility).

- **candidates_found:** 1.

- **idea.list-view-treated-as-backlog-truth.** Claude reasoned from `bash .ccanvil/scripts/operations.sh resolve idea.list ...` (filtered to `label=idea`) as the canonical backlog view, missing four scaffold-labeled tickets. The deterministic fix is at the **/recall and /radar skill prose** layer: when reporting "what's in the backlog," use `bash .ccanvil/scripts/operations.sh resolve backlog.list ...` (no label filter) OR `mcp__claude_ai_Linear__list_issues --state Backlog --project ccanvil` (no label filter). Impact: medium — affects Claude's "what should I work on next?" reasoning, which is high-leverage. Substrate already exists (`backlog.list` resolver); the fix is skill-prose pointing the consumers at the right one. Worth a small ship.

## Cross-Session Patterns

- **CONFIRMED RECURRING: scope-down on reveal.** Validated 4× this session (BTS-125 truncation moot, BTS-173 regex→allowlist mid-impl, BTS-172 subcommand→flags, BTS-72 four out-of-scope follow-ups captured during spec). Memory `feedback_scope_down_on_reveal.md` was at 1-2 prior; now thoroughly empirical. Continues to compound: as substrate matures, each new ticket reveals more "actually we don't need that" boundaries.

- **CONFIRMED RECURRING: /review-finds-real-defects on substrate work.** Sister of last session's pattern. BTS-72's pass: **2 BLOCKING + 3 CONCERN + 2 NIT.** BLOCKING-2 (merge-state corruption on conflict) was a real bug — merge fail left user on main with `MERGE_HEAD`, next /land call would fast-forward instead of finishing the merge. CONCERN-1 (substring-match false-positive on `github.com` in path) was a real wrong-classification risk. Three sessions in a row now: substrate diffs always surface something /review-worthy.

- **CONFIRMED RECURRING: live-validate plan-flagged risks.** BTS-125 was the prototype case — live repro via test ticket BTS-174 collapsed the entire scope. The discipline BTS-171 codified continues to compound.

- **CONFIRMED RECURRING: substrate compounding.** Each ship used 2-3 prior substrates. Validated 5× this session.

- **NEW PATTERN: filtered-view-treated-as-canonical.** This is the determinism finding — Claude assumed `idea.list` = backlog. Memorialize as `feedback_verify_view_vs_truth.md` if it recurs. Worth saving even on first occurrence because the failure mode is silent (Claude doesn't realize the view is filtered).

- **CONFIRMED CLOSED: workspace-fence false-positives.** BTS-169 closed pure-slash; BTS-173 closed single-segment-slashword. Both via filesystem-rooted allowlist for the latter. The fence is now narrow enough that prose-handling flows don't hit it on slash-command names. Captured `/):` punctuation case as deferred (out-of-scope of BTS-173).

- **CONFIRMED: legacy-refs-scan stays clean** (0 matches with allowlist). BTS-132 mechanism continues to hold.

- **CONFIRMED: dogfood-close cultural invariant.** All 5 ships auto-closed on land via BTS-128/164 substrate.

## Security Review

- **Five ships.** No new external attack surface introduced.
- BTS-162 Part 1: `--parent` flag passes refs verbatim through to `linear-query.sh save-issue --parent-id`; quoted via `jq -Rr @sh` against shell-injection. Validated non-empty + no-whitespace at script + skill layers.
- BTS-125: pure-prose + drift-guard tests; zero attack surface.
- BTS-173: workspace-fence ALLOWLIST is filesystem-read-only on `.claude/commands/*.md` + `.claude/skills/*/`. Cached per hook invocation. Reading a directory listing for classification doesn't expand the fence's blast radius.
- BTS-172: `cmd_idea_template_body` is pure string composition via `jq` substitution. No shell expansion of user input. Validated non-empty + no-whitespace at the substrate boundary.
- BTS-72: `cmd_detect_repo_type` is read-only `git rev-parse` + `git remote get-url`. `cmd_land` local-only path performs `git merge --no-ff` (standard git op, no shell injection surface). On conflict: `git merge --abort` cleanup before exit.
- `security-audit.sh --files-only`: PASS.
- Verdict: **PASS**.

## Memory Candidates

- **REINFORCE existing memory: scope-down on reveal.** Validated 4× this session in a single stretch — that's empirically near-decisive. Existing memory `feedback_scope_down_on_reveal.md` is correct; no update needed beyond the empirical strength.
- **REINFORCE existing memory: live-validate plan-flagged risks.** BTS-125 collapsed entire ticket scope via 5-min live repro. Memory + BTS-171 substrate continue to compound.
- **NEW MEMORY: filtered-view-treated-as-canonical.** Determinism finding from this session — Claude treated `idea.list` (label-filtered) as canonical backlog and reported "P3=0, P4=0" when actually 2 P3 + 2 P4 tickets were sitting in Backlog. Worth saving as `feedback_verify_view_vs_truth.md` — when a script returns a filtered listing, surface the filter explicitly OR query the broader source before reasoning from the count. Recurrence hasn't happened yet but the silent-failure mode justifies pre-emptive capture.
- **NEW MEMORY (low-confidence): captures-then-same-session-ships are productive.** BTS-172 + BTS-173 were captured AND shipped in the same session. Both built on substrate that surfaced the friction. The cost of "capture, then defer, then re-context next session" is real; when the friction is recurring AND the substrate is in hand, ship in the same flow. One-occurrence — wait for a second before promoting. (Note: this is essentially the same insight as `feedback_investigation_ship_when_actionable` from last stasis. Cross-link rather than duplicate.)

Memories to save in this stasis: **one new memory.** `feedback_verify_view_vs_truth.md` — Claude must verify the filter scope of any listing call before treating its output as canonical truth.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
