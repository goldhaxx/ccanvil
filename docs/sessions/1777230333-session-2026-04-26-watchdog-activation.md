# Stasis

> Feature: session-2026-04-26-watchdog-activation
> Kind: session
> Last updated: 1777230333
> Session objective: Drain the actionable backlog post-/recall — ship the BTS-182 word-boundary follow-up, then refresh BTS-21 (gh-aw research item) with substrate-fit analysis, pivot to a local Claude Code-native scheduled agent, and dogfood-validate the watchdog end-to-end on this machine.

## Accomplished

**Two substrate ships + a complete substrate-fit-driven pivot + live activation of a new ccanvil shape (scheduled agent).**

- **BTS-182 (PR #105).** Word-boundary truncation in `cmd_derive_pr_title`. Walk backward up to 8 chars from the 80-char cap to nearest space/hyphen, drop the boundary char, fall back to hard cut when no boundary in lookback. 8 new ACs + 1 fixture rewrite + 1 allowlist line (`docs/sessions/` exempt — pre-existing AC-29 regression on main, surfaced at full-suite-run, fixed in scope per `feedback_scope_up_on_live_api_reveal`). 1503 → 1512 tests, +9 net at PR time. Live dogfood: PR #105's own title cut at "80 chars" word boundary instead of mid-word. /review skipped per `feedback_skip_review_on_trivial_diffs`.

- **BTS-21 (PR #106).** Drift-watchdog substrate + skill + sub-agent. **Two refreshes today** of the original gh-aw framing per `feedback_refresh_old_tickets_before_shipping`: (1) narrowed gh-aw scope to a single drift-watchdog pilot, then (2) pivoted to local Claude Code-native scheduled agent after substrate-fit re-analysis showed gh-aw's only unique advantage (off-laptop runs) doesn't matter at single-user scale and ccanvil already has the local primitives (`claude -p`, `Agent(isolation: worktree)`, etc.). Three new `ccanvil-sync.sh` subcommands (`drift-watchdog-list`, `drift-watchdog-preflight`, `drift-watchdog-launchd-print`), one new skill (`/drift-watchdog`), one new sub-agent (`drift-analyst`, haiku). 27 new tests at PR time → 1503 → 1530.

- **Live activation hot-fixes (3 commits on main).** First kickstart of the watchdog surfaced three substrate gaps the bats fixtures couldn't catch:
  1. **launchd PATH:** `bash -lc` did NOT pick up the operator's profile under launchd → `bash: claude: command not found` (exit 127). Fix: embed operator's current PATH in `EnvironmentVariables` at print time.
  2. **Haiku hallucination:** parent model `--model haiku` produced a one-line "Drift-watchdog complete" summary without actually firing creates. Fixed by switching parent to sonnet (later opus 4.7 per operator preference) + adding "CRITICAL EXECUTION CONTRACT" preamble + per-step `echo` statements in SKILL.md.
  3. **Labels syntax:** SKILL.md had `--label drift-watchdog` (singular). linear-query.sh uses `--labels` (plural, comma-separated, last-write-wins). Fix: `--labels 'idea,drift-watchdog'` to override resolver default while keeping idea label.
  Also: created `drift-watchdog` workspace label in Linear (one-time operator setup); added `.ccanvil/drift-watchdog.{log,err}` to `.gitignore`.

- **End-to-end dogfood validated.** Watchdog fired clean: 7 Linear issues created (BTS-191..197, one per drifted node — all 7 nodes 119 commits behind on the same 37 tracked paths). Re-fired immediately to verify idempotency: 0 new issues created. Issues are findable via `linear-query.sh list-issues --label drift-watchdog`.

- **BTS-183 captured to Triage.** Strategic-level idea — full http-or-MCP cohesion review for Linear (and all future) provider integrations. Captures the picture that ccanvil's daily-driver Linear verbs are 100% on http (BTS-164/166/167) but `operations.sh` still carries dead-code MCP branches (`idea.promote/defer/dismiss/merge`, `backlog.get`, `ticket.find-by-title` — only test references, no live skill callers). Proposes codifying http-canonical as a rule.

- **BTS-198 captured to Triage.** `guard-destructive.sh` jq dict-literal false-positive — the watchdog ran into it on first fire and worked around by switching to Python. WILL fire every Monday until fixed; surfaces at every drift-watchdog run.

- **Watchdog parent model: opus 4.7 + $5 budget cap (operator preference).** Final config: `claude --model claude-opus-4-7 -p "/drift-watchdog" --max-budget-usd 5.00`. Sub-agent stays on haiku (synthesis is haiku-territory).

## Current State

- **Branch:** `main` at `d7916d2`, in sync with `origin/main`.
- **Tests:** **1531 / 1531 green** (was 1496 at session start; +35 net: 9 BTS-182 + 27 BTS-21 incl. one PATH-fix test added post-merge).
- **Uncommitted changes:** none.
- **Build status:** clean.
- **Active spec:** none — between features.
- **Permissions audit:** `danger=0`, `promote-review.total=0`. Clean.
- **launchd watchdog:** loaded at `~/Library/LaunchAgents/com.ccanvil.drift-watchdog.plist`, state `not running`, runs=2, next fire Monday 2026-04-27 09:13 local. Configured: opus 4.7, $5 budget cap.
- **Linear backlog (canonical via `backlog.list`):**
  - **BTS-20** (P4) — Workflow engine / deterministic state machine (QuantumBlack pattern). `needs-research`. **Operator marked as priority for next session.**
  - **BTS-191..197** — drift-watchdog issues, all in Triage (created today by the live watchdog fire). 119 commits behind hub, 37 paths drifted, uniform across nodes.
- **Linear Triage queue:** 9 untriaged total — 7 watchdog-created (BTS-191..197) + BTS-183 (provider-integration) + BTS-198 (guard-destructive false positive).
- **Context budget:** 373.9k / 1M tokens (37%) per `/context`. Comfortable; cadence-driven boundary.

## Blocked On

- Nothing. Three clean ships + complete pivot + activation, cadence held, watchdog is live.

## Next Steps

**Operator-flagged priority for next session: BTS-20 (workflow engine / deterministic state machine).**

Recommended next-session sequence:

1. **`/recall`** to orient.
2. **`/idea triage`** — **9 items** in queue need attention. Probably batch the 7 drift-watchdog tickets together (they all describe the same drift state — 7 nodes × `ccanvil-pull` recommended; could close as a batch with one composite "all 7 nodes pulled" comment, or individually after each pull). BTS-183 and BTS-198 are independent.
3. **BTS-20 substrate-fit refresh.** Like BTS-22 and BTS-21 today, BTS-20 is an old (~5 weeks) `needs-research` ticket. Per `feedback_refresh_old_tickets_before_shipping`: read the original framing, survey what has shipped that touches state-machine / workflow surface, propose 2-3 refresh options before drafting the spec. The QuantumBlack-pattern reference may or may not still be the right north star.
4. **Optional: address BTS-198** in same session if BTS-20 work doesn't fill it. Small substrate fix — guard-destructive false-positive, ~30 min audit + fix + drift-guard test.

## Context Notes

- **The pivot story is the lesson of the session.** The user asked me to "deeply research gh-aw" before deciding. The research surfaced that gh-aw is real and growing (Next → main org migration, weekly releases, 4374 stars, Home Assistant / CNCF / Carvana adopters). But ccanvil's substrate is local-first by design, and gh-aw's only unique value (off-laptop scheduled runs) didn't address any observed pain. The user's pushback ("is there any way to do this without gh-aw?") was the prompt to reconsider — and Claude Code's own primitives (`claude -p`, `CronCreate`, `Agent isolation: worktree`) made local execution strictly better for single-user reality. **This is the model: when an old ticket meets a new substrate, the original framing usually needs to be discarded, not implemented.**

- **The `CronCreate` discovery is critical for future scheduled-agent work.** Pre-flight smoke-tests revealed CronCreate is **session-bound, fires only when an idle Claude REPL is open, and auto-expires after 7 days** — perfect for intra-session "remind me in 30 min" but wrong for any weekly recurring job. The substrate that DOES work for scheduled launchd-style work is OS-level (launchd, systemd timers, system cron) invoking `claude -p "/<skill>"`. This pattern is now proven end-to-end in ccanvil. Any future scheduled agent should follow the same shape.

- **Haiku is too thin to faithfully orchestrate a multi-step skill.** First watchdog kickstart with `claude --model haiku` produced a one-line "complete" log without actually executing the create commands. Pure agent hallucination — the model READ the skill body and DESCRIBED what it would do without running it. Sonnet executed faithfully. Opus 4.7 is now the operator-chosen parent model; haiku stays for the leaf-node synthesis sub-agent (which gets explicit input + asks for explicit output, so hallucination has nowhere to hide).

- **Substrate compounding hit a new height.** BTS-181's `derive-pr-title` (last session) auto-fired clean on PR #105 and PR #106's titles AT activate time. Three substrate ships in one day have observably reduced the friction of subsequent ships in measurable ways: title cosmetics, idempotent issue creation, scheduled agent shape. Each successive substrate primitive shrank the next ship's surface area.

- **The watchdog's first dogfood revealed a real pain it would address.** All 7 registered downstream nodes are 119 commits behind on the same 37 tracked paths. Drift detection has been "I'll get to it" for weeks. The watchdog converts that into 7 Triage tickets. This is exactly the substrate fit the spec articulated — not invented pain. The idempotency contract holds: re-fire produced 0 new issues.

- **The `--labels` plural / single-write-wins semantic is a real linear-query.sh contract that future skills must respect.** Any skill that builds on the resolver-eval pattern AND wants additional labels has to override the resolver's default with a comma-joined string (e.g. `--labels 'idea,drift-watchdog'`). Captured in BTS-198's family — should be documented somewhere durable (likely in the http-canonicalization rule under BTS-183).

## Determinism Review

- **operations_reviewed:** ~22 (3 spec/plan/TDD cycles × ~5 lifecycle ops each, plus /idea triage, /idea capture × 2, full-suite runs × 5, manual `gh pr edit` on PR #105, manual `launchctl` operations × 4, manual hot-fix commits on main × 4, MCP label create × 1, two-commit /stasis flow).

- **candidates_found:** 2.

- **launchd-plist-install-flow.** Claude manually ran `launchctl unload` + `cp` + `launchctl load -w` + `launchctl kickstart -k` 4 separate times during activation hot-fixes. Each time reformulated the same idempotent reinstall sequence by hand. Should be: a `ccanvil-sync.sh drift-watchdog-launchd-install [--reload]` subcommand that wraps the install + reload + verify-loaded steps in one atomic call. Impact: medium — saves 4-5 lines per hot-fix iteration, makes the "operator workflow" prose in the spec a one-liner instead of a multi-step recipe.

- **watchdog-self-verification.** The skill's only self-check is the idempotency listing. There's no end-of-run verification that the actual creates landed. First fire would have failed silently (haiku claimed success without firing) if I hadn't manually checked Linear afterward. Should be: per-create verification — after `linear-query.sh save-issue` returns an ID, immediately `linear-query.sh get-issue $ID` to confirm presence and label. If verification fails, treat the create as failed and write to pending log. Impact: medium — prevents a class of bugs where the skill thinks it succeeded but didn't.

## Cross-Session Patterns

- **CONFIRMED RECURRING (positive — completion sweep, 5 sessions running):** the "capture-during-stasis → ship-next-session" cycle held again. Prior stasis (`09162f6`) flagged `derive-pr-title-word-boundary` as the only candidate; this session shipped it as BTS-182 in ~30 minutes. The cycle is now empirically robust at substrate-tier candidates; 5/5 sessions running. Today's stasis flags TWO candidates (launchd-plist-install-flow, watchdog-self-verification) — both substrate-tier, both small ships, both will have shipped before next session if pattern holds.

- **CONFIRMED RECURRING: substrate compounding accelerating.** Three ships in one session today (BTS-182 + BTS-21 + watchdog activation hot-fixes), with each ship leveraging primitives from prior ships in this session and prior sessions. BTS-181's `derive-pr-title` fired correctly on both new PRs without intervention; BTS-178's `assert-pr-title` no-op'd correctly per its trust-user-edits semantics; BTS-22's `archive-stasis` will fire on this stasis. Each substrate ship reduces friction for the NEXT substrate ship.

- **CONFIRMED RECURRING: skip-/review-on-trivial-diffs validates cleanly.** BTS-182 skipped /review (substrate primitive + drift-guards). No defects post-merge. 5+ sessions running.

- **CONFIRMED RECURRING: refresh-old-tickets-before-shipping.** TWO refreshes today on the same ticket (BTS-21 gh-aw → drift-watchdog pilot → local launchd-driven Claude Code agent). Both refreshes saved meaningful effort — the original gh-aw framing would have been a multi-session ship building against an unstable preview substrate; the launchd framing was 1 session and uses ccanvil's own substrate.

- **NEW (positive): substrate-driven-pivot.** When a ticket's original framing meets a substrate that didn't exist when the ticket was filed, the right move is to discard the framing and re-derive from current primitives — not "implement the original spec." BTS-21's gh-aw → launchd pivot is the canonical example. Generalizable: **substrate-fit-check should explicitly enumerate available primitives at refresh time and ask "what's the minimal use of these that solves the kernel of the original concern?"** Capture as memory candidate.

- **NEW (positive): live-activation-driven-hardening.** The 3 hot-fixes during watchdog activation (PATH, model+budget, labels) each surfaced a substrate gap that no fixture caught. The pattern: substrate that orchestrates external systems (launchd, haiku, linear-query.sh's CLI flags) needs LIVE smoke-tests before declaring done. The bats suite caught everything that's testable in isolation; nothing it tested fired when the substrate hit the real world. **Generalizable: any substrate that bridges two systems needs an explicit live-validation step in the implementation plan, not just at /pr time.** Capture as memory candidate.

- **No recurring legacy-refs.** legacy-refs-scan returns empty.

- **No recurring audit-session findings.** Today's audit-session shows `git -C` patterns in the new bats file — those are intentional (drift-guards bounding test fixtures). False positive; not a real candidate.

## Security Review

- **Three ships + activation.** New external surface introduced by the launchd entry.
- BTS-182: pure refactor + truncation logic in shell. No new auth surface.
- BTS-21: file-write to `~/Library/LaunchAgents/` (operator-mediated via `drift-watchdog-launchd-print`). The watchdog process executes `claude -p` with a $5 budget cap, communicates outbound to Anthropic API + Linear API, writes to `.ccanvil/drift-watchdog.{log,err}` (gitignored). `drift-watchdog-list` is read-only (drift-guard test enforces). `drift-watchdog-preflight` is read-only.
- Activation: copied .plist to `~/Library/LaunchAgents/` (outside workspace; ALLOW_OUTSIDE_WORKSPACE=1 used as documented). `launchctl load -w`. No write to system-wide directories. PATH embedded in .plist captures the operator's machine-local PATH at print time — that PATH is in `git status` clean territory (it's a runtime artifact of the operator's machine, not committable).
- All Linear creates went through the http substrate (no MCP indirection from the watchdog).
- No new credentials introduced; existing `.env` is gitignored, no leakage.
- Verdict: **PASS**.

## Memory Candidates

- **NEW MEMORY: substrate-driven-pivot.** When refreshing an old ticket whose framing predates current substrate, explicitly enumerate the primitives that exist NOW and re-derive the minimum that solves the kernel of the original concern. Don't implement the original spec verbatim — re-spec around current shape. Worked on BTS-21 (gh-aw was the original framing → became local launchd-driven Claude Code agent because `claude -p` + `CronCreate` + Agent worktree-isolation make the local solution strictly better). Without the pivot, the spec would have built against an unstable preview substrate (gh-aw).

- **NEW MEMORY: live-activation-driven-hardening.** Substrate that bridges two systems (launchd + claude + linear-query.sh's CLI flags in this case) needs LIVE smoke-tests at activation, not just bats. Three real failures fired during BTS-21 activation that no fixture caught: (1) launchd's PATH stripped Homebrew, (2) haiku hallucinated success without firing, (3) `--label` vs `--labels` syntax mismatch. Each was a 1-2 line fix once surfaced live. Generalizable: implementation plans for substrate that talks to external systems should include a "live-activation smoke-test" step that exercises the full chain end-to-end before declaring done.

- **REINFORCE: feedback_refresh_old_tickets_before_shipping is high-leverage AND can refresh twice.** Two refreshes on BTS-21 today (gh-aw → pilot → local). Each refresh saved meaningful effort. The first refresh (narrowed scope) would have shipped a workable but suboptimal solution (gh-aw drift-watchdog). The second refresh (substrate-driven-pivot) shipped the right solution. Don't assume the first refresh is the final answer when more substrate-fit context becomes available.

- **REINFORCE: feedback_dogfood_substrate_on_own_session_pr (and on the operator's own machine).** BTS-21 was dogfooded against the live registry (7 real downstream nodes). The dogfood surfaced 3 substrate gaps that bats would never catch. Confirms the rule: substrate that bridges to external systems must be tested against the real external system before /pr.

- **CONFIRMED REFERENCE: BTS-191..197 are the watchdog's first real output.** Future debugging may need to reference these IDs as the first generation of drift-watchdog issues. They're identified by `[idea,drift-watchdog]` label pair.

Memories to save: **two new memories** (`feedback_substrate_driven_pivot`, `feedback_live_activation_hardening`), plus reinforce existing.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
