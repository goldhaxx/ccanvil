# Stasis

> Feature: session-2026-04-25-autonomy-batch-ship
> Kind: session
> Last updated: 1777082008
> Session objective: Ship the autonomy-first triple — BTS-142 (permissions rewrite) → BTS-146 (workspace fence) → BTS-145 (auto-push-main). Each layered on the prior to deliver "maximum motion inside the workspace, hard boundary at the edge." Plus full discovery on Cloudflare-WAF behavior for Linear MCP and capture of two follow-on tickets.

## Accomplished

- **3 features shipped end-to-end** plus 4 ideas captured (BTS-143/144/146 → Triage; BTS-147 captured stasis-time after a self-discovered hook bug). All three ships compose into a coherent autonomy-first design: the first opens the surface, the second fences it, the third removes the friction.
  - **PR #65 / BTS-142** — autonomy-first permissions rewrite. `settings.json` rewritten with 125 broad command-namespace wildcards (`Bash(git:*)`, `Bash(gh:*)`, `Bash(bash:*)`, `Bash(rm:*)`, `Bash(chmod:*)`, `mcp__claude_ai_Linear__*`, etc.) trusting the hook layer as the safety floor. `settings.local.json` reset to `{permissions:{allow:[]}}` (gitignored, per-node) — by design becomes the staging area for "always allow" approvals → periodic promotion review. Deny list: 12 entries, only catastrophic system-level ops. Extended `guard-destructive.sh` with chmod-destructive patterns (777/666/000). 11 new bats cases. Net audit shift: 199 entries → 137; 28 DANGER → 16 (all intentional broad wildcards).
  - **PR #66 / BTS-146** — guard-workspace hook. New PreToolUse hook `.claude/hooks/guard-workspace.sh` that blocks file-mutation verbs (rm/cp/mv/chmod/chown/bash) when any absolute or tilde-prefixed path argument falls outside `$HOME/projects/` or whitelisted system temp dirs. Bypass via `ALLOW_OUTSIDE_WORKSPACE=1`. 16 new bats cases. Self-validated immediately at stasis-time when a false-positive on bare `/` token surfaced — captured as BTS-147 follow-on.
  - **PR #67 / BTS-145** — `cmd_activate` auto-push-main. When sync-check returns AHEAD AND current branch is `main`, auto-push origin main before activating. 7 new bats cases plus AC-18 update to use `--no-auto-push` (preserves halt-path test contract). Eliminates the third-consecutive-stasis recurring friction (11 redundant pushes across 3 sessions).
- **21 consecutive dogfood-closes** as of session end: 18 from prior session + BTS-142, BTS-146, BTS-145. Cultural invariant maintained.
- **Test suite grew 1024 → 1058** (+34 across 3 ships: 11 chmod-destructive + 16 guard-workspace + 7 activate-auto-push). Full suite green.
- **4 ideas captured.** BTS-143 (DANGER override via REVIEWED log rationale), BTS-144 (promote-review tooling for settings.local.json delta), BTS-146 (later promoted to ship), BTS-147 (guard-workspace false-positive on bare `/` token). All Triage.

## Current State

- **Branch:** `main` at `8974e7e` (post-BTS-145 merge, FF'd via `/land`).
- **Tests:** **1058 / 1058 green** via `bats-report.sh --parallel`.
- **Uncommitted changes:** `.claude/settings.local.json` only — the gitignored per-node staging file accumulated 2 entries during this stasis when bash hook prompts fired (the BTS-147 false-positive workaround). Won't appear in any PR.
- **Build status:** clean.
- **Context budget:** WARNING at **81.3%** (6502/8000) — climbed from 74.9%. Increase is from BTS-142's enlarged `settings.json` (125 allow + 12 deny entries vs the prior 60 entries). Trade-off accepted: more permissions in the always-loaded file is the cost of the autonomy-first design.
- **Permissions audit:** **18 DANGER + 121 UNREVIEWED + 0 REVIEWED** (was 16 / 121 / 0 post-BTS-142). +2 DANGER from settings.local.json's auto-allow entries (env-prefix `ALLOW_OUTSIDE_WORKSPACE=1` form trips the env-prefix DANGER pattern — exactly what BTS-143 will resolve via deliberate REVIEWED rationales).
- **Specs archive:** **64 Complete** (was 61 entering session; +3: 142, 146, 145). Linear backlog: ~6 items remaining, plus 4 newly Triaged this session.

## Blocked On

- Nothing. Working tree clean, tests green, all three ships landed cleanly.

## Next Steps

1. **Triage BTS-147** (guard-workspace bare-`/` false-positive). One-line fix to the hook's `case` glob (`/*)` → `/?*)`) plus a regression bats case. Cheap, immediately useful, dogfood-relevant.
2. **Triage BTS-143** (REVIEWED log rationale should override DANGER). Pairs with BTS-144 as the deliberate-review system. Together they unlock the "0 DANGER by design" outcome via rationale-writing.
3. **Triage BTS-144** (promote-review tooling for settings.local.json delta). Now actually testable — settings.local.json has its first organic entries (the 2 ALLOW_OUTSIDE_WORKSPACE bypasses), so promote-review has something to surface.
4. **BTS-115** (determinism candidates → captured as ideas, not memories). This session was a partial dogfood — 4 ideas captured mid-session, not journaled to memory. Codify in skill prose.
5. **BTS-125** (Linear save_issue markdown truncation) — P4 finisher; needs reproduction.
6. **BTS-72** (`/merge` for local-only repos) — bigger scope; activate when ready.
7. **BTS-116** (broadcast-resolve-auto algorithmic conflict resolution) — judgment-call work.
8. **BTS-22** (Docs directory strategy) — research-level horizon item.

## Context Notes

- **The autonomy-first triple is a coherent design, not three independent tickets.** Each ship answers a specific objection that the prior ship's broadness creates: BTS-142 makes Claude fast (broad allow), BTS-146 makes Claude safe (workspace fence), BTS-145 makes Claude smooth (no manual push step). Together: "max motion inside the workspace, hard boundary at the edge." Future autonomy work should think in this triad — what surface? what fence? what friction?
- **Cloudflare WAF blocks Linear MCP `save_issue` bodies containing literal shell-injection patterns.** Confirmed twice this session. Captured as `reference_linear_mcp_waf.md` memory. Workaround pattern: write full content to `/tmp/<id>-design.md`, paste manually via Linear web UI (different ruleset, accepts the content). Verified working — BTS-146 ticket has full 4166-char design after manual paste.
- **The stasis-time guard-workspace bug is the cleanest dogfood case yet.** I shipped BTS-146, then immediately the very next session's stasis data-gathering tripped its own hook on a literal `/` in a jq format string. Filed as BTS-147 within minutes. Validates that real usage finds bugs the test suite missed.
- **Anthropic API "Overloaded" interruption.** Mid-session, my response cut off after "Going. Writing the spec first." with no continuation. Zach reported the API error from his terminal; I had no visibility into the error. Recovery is just retry — but a useful operational note: API failures during multi-step shipping flows are transient and don't corrupt state. The spec/branch/PR I was about to create were unaffected.
- **Always-allow → settings.local.json is now organically populated.** First time settings.local.json has accumulated entries since the BTS-142 wipe. Two entries from the `ALLOW_OUTSIDE_WORKSPACE=1 bash ...` workaround. This is the first concrete data point for BTS-144's promote-review tooling design — those entries are clearly DELETE candidates (one-shot bypass for a now-fixed bug), not promote-to-hub material.

## Determinism Review

- **operations_reviewed:** ~50 (across 3 ships + 4 idea captures + 1 stasis bug discovery)
- **candidates_found:** 1 NEW + 1 RESOLVED + 1 carryover trending down
- **NEW: guard-workspace hook tokenization is too eager.** Bare `/` token (zero-info standalone slash) trips the absolute-path check. **Captured as BTS-147** — Triage. Impact: medium (hits anytime jq format strings or shell regex use literal `/`), but trivially fixable (one glob change `/*)` → `/?*)`).
- **RESOLVED via ship: redundant `git push origin main` per spec-on-main commit.** This was a 2-stasis recurring candidate. Shipped as BTS-145 this session. Auto-push fires when on main + AHEAD. Will be dogfooded next session.
- **CARRYOVER trending down: audit-session test-fixture noise.** 49 findings last session, 14 this session. Source is bats fixture code (`git -C` calls in test setup). The test-fixture noise floor would zero out if `cmd_audit_session` skipped `hub/tests/*.bats` the way it skips `.ccanvil/scripts/*.sh`. Worth a small ticket if the noise re-amplifies.

## Cross-Session Patterns

- **RESOLVED: redundant `git push origin main`.** Was prior stasis's #2 next-step. Shipped this session as BTS-145.
- **RECURRING (trending down): audit-session noise.** 49 → 14. Allowlist-extension fix would zero it.
- **NEW (resolved within session): guard-workspace fence missing the bare-`/` exclusion.** Discovered → captured → on the docket.
- **VALIDATED: same-session capture→ship loop (3rd time).** BTS-141 last session, BTS-145 this session promoted from carryover ticket. Pattern is robust.
- **VALIDATED: dogfood-close cultural invariant.** 18 → 21 consecutive ships closing their driving Linear ticket via the primitive being added. 33% growth in one session.
- **CONFIRMED: legacy-refs-scan stays clean** with `--respect-allowlist` — 0 matches this session, 0 last session. BTS-132 mechanism holds.
- **NEW: Cloudflare WAF blocks Linear MCP body content matching shell-injection patterns.** Memory captured (`reference_linear_mcp_waf.md`). Workaround: paste via web UI. Will recur on any security/hook ticket; the workaround pattern is now documented.
- **NEW: context budget climbed 74.9% → 81.3%** entering WARNING territory more deeply. BTS-142's `settings.json` rewrite is the cause (60 → 125 allow entries). Trade-off accepted; if it starts hitting CRITICAL, options are to move static parts to on-demand or leverage BTS-143 to mark broad wildcards REVIEWED so they collapse visually.

## Security Review

- No secrets, tokens, PII, or credentials introduced this session. All work was permission-list edits, hook code, and test fixtures.
- BTS-142 rewrote `settings.json` — review confirmed no over-broad denies removed and no privileged operations added without intentional design.
- BTS-146 introduced a path-scoped fence — defensive code, narrows risk surface.
- BTS-145 introduced an auto-push call — only fires on main with explicit AHEAD detection AND `auto_push=true` (default). Bypass paths (`--no-auto-push`, `--force-sync`) preserve user control.
- The two `ALLOW_OUTSIDE_WORKSPACE=1 bash ...` entries in settings.local.json are a workaround for the BTS-147 false-positive — they'll evaporate when BTS-147 ships.
- Verdict: **PASS**.

## Memory Candidates

- **Autonomy-first design philosophy (feedback)** — Zach's stated direction: "I am building this tool for myself. I am building it to work the way that I want it." Implications: (1) prefer broad allow lists fenced by hooks over narrow-allow per-prompt friction; (2) "I care less about [security] and more about speed and productivity" within reasonable safety floors; (3) a forced systematic review system (settings.local.json staging → promote-review → settings.json) is the long-term safety mechanism. **Worth a feedback memory** for future tone calibration on safety-vs-speed tradeoffs.
- **Hook → fence → friction-removal triad** — three-layer pattern for autonomy work: open the surface, fence the boundary, remove the friction. Validated through BTS-142 + BTS-146 + BTS-145 as a coherent design. Future autonomy proposals should think in this triad. **Worth a project memory** as a design pattern.
- **Manual-paste workaround for Linear MCP WAF blocks** (already memorialized in `reference_linear_mcp_waf.md` last session — no update needed; pattern reconfirmed by BTS-146 capture).
- **Anthropic API can return "Overloaded" mid-response** — operational note, not novel. Skip memorializing.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
