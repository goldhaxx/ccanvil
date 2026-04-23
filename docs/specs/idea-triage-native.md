# Feature: Idea Triage — Linear-native states + agentic mutations

> Feature: idea-triage-native
> Created: 1776918080
> Status: Complete

## Summary

ccanvil's `/idea` workflow inherited a custom Linear workflow state named "Idea" that collides with Linear's own state-type system, blocking reliable programmatic state transitions (mutations silently become no-ops when the target state name collides with a type name). This feature aligns `/idea` with Linear's native Triage intake surface, codifies a deliberate five-state idea lifecycle (Triage → Backlog / Icebox / Canceled / Duplicate), makes every triage outcome fully agentic via state-ID-based mutations (no dependency on Linear UI), surfaces stale Iceboxed items for periodic re-evaluation, and migrates existing items off the deprecated custom "Idea" state.

## Job To Be Done

**When** I capture an idea mid-flow and later sit down to triage or revisit,
**I want to** promote, defer, dismiss, or merge each idea — and have deferred ideas resurface on cadence — entirely from ccanvil without touching Linear's UI,
**So that** capture-to-disposition is a zero-friction, fully agentic loop and no good ideas decay into a graveyard.

## Acceptance Criteria

Each criterion is independently testable. Binary pass/fail.

- [ ] **AC-1 — Triage-native capture.** Given the Linear provider, when `/idea <text>` runs, the created issue lands in Linear's native Triage state (type=`triage`). Given the local provider, the log entry's `status` field is `"triage"` (not `"new"`).
- [ ] **AC-2 — Triage listing.** When `/idea triage` runs, the returned list includes exactly items in Triage state (Linear) or `status: "triage"` (local). Items in Backlog, Icebox, Canceled, Duplicate, or downstream states are excluded.
- [ ] **AC-3 — Four outcomes via state ID.** When the user approves each of `promote`, `defer`, `dismiss`, `merge`, the mutation targets the state by **ID** (not name), and a re-fetch of the issue confirms the resulting state: `Backlog` (promote, with priority applied), `Icebox` (defer), `Canceled` (dismiss), `Duplicate` with `duplicateOf` set (merge). No UI interaction required.
- [ ] **AC-4 — State IDs resolved via operations.sh.** `operations.sh resolve idea.{promote,defer,dismiss,merge}` returns an invocation object whose `params.stateId` field contains the target state UUID for the Linear provider, derived from cached workspace metadata — not hardcoded in skill prose or config.
- [ ] **AC-5 — Icebox review command.** When `/idea review-icebox` runs, it lists only items in Icebox state older than 60 days (by `createdAt` for Linear, log epoch for local), with title + age + original rationale. Each item is actionable via the same four outcomes as AC-3.
- [ ] **AC-6 — Radar ambient surface.** When `/radar` runs, the `### Ideas` section reports the count of Icebox items ≥60d old; when the count is 0 the surface is silent. `radar-gather` emits a new `ideas.icebox_stale_count` field.
- [ ] **AC-7 — Legacy migration.** A one-shot `docs-check.sh idea-migrate-state` command transitions every issue currently in the deprecated custom "Idea" state to `Backlog` (preserving priorities and labels). The command is idempotent: a second run reports zero migrations.
- [ ] **AC-8 — Error: MCP failure during triage mutation.** When a state mutation fails (network, auth), the intent is appended to `.ccanvil/ideas-pending.log` (same JSONL pattern as `idea.add`), and the user sees `PENDING: <id> (<N> total pending)` instead of a raw MCP error. `/idea sync` replays these on recovery.
- [ ] **AC-9 — Edge: listings exclude terminal and deferred states.** Default `idea.list` (no filter) excludes Canceled, Duplicate, and Icebox. Explicit filters (`--status canceled`, `--status icebox`) surface them.

## Affected Files

| File | Change |
|------|--------|
| `.ccanvil/scripts/operations.sh` | Modified — add `idea.promote`, `idea.defer`, `idea.dismiss`, `idea.merge`, `idea.review-icebox` resolvers; state-ID lookup via cached workspace metadata |
| `.ccanvil/scripts/docs-check.sh` | Modified — `cmd_idea_count` / `cmd_idea_update` extend local status vocabulary; new `cmd_idea_review_icebox`; new `cmd_idea_migrate_state`; `radar-gather` emits `ideas.icebox_stale_count` |
| `.claude/ccanvil.json` | Modified — replace `idea_status` / `icebox_status` string fields with an optional `state_ids` block (populated by lookup) |
| `.claude/skills/idea/SKILL.md` | Modified — rewrite Triage section for four programmatic outcomes; new `/idea review-icebox` usage |
| `.claude/skills/radar/SKILL.md` | Modified — Ideas section surfaces Icebox-stale count |
| `.ccanvil/templates/ccanvil.json` | Modified — strip legacy state-name fields |
| `hub/tests/idea-triage-native.bats` | New — covers AC-1 through AC-9 (Linear mode via fixture, local mode end-to-end) |

## Dependencies

- **Requires:** Linear Triage feature enabled on the workspace (done this session, per Zach).
- **Requires:** Linear MCP tool `mcp__claude_ai_Linear__list_issue_statuses` for state-ID lookup.
- **Blocked by:** None.

## Out of Scope

- Linear Snooze integration (deferred; session decision).
- Auto-cancel of Icebox items older than N days (surface-only; never auto-act).
- Cross-team Triage routing rules (single-team scope).
- Priority inference (user still assigns priority on `promote`).
- Local-provider behavioral parity with Linear's "exclude Triage from default views" — the local log is a single flat JSONL, simpler model.
- Deletion of the deprecated custom "Idea" state in Linear (manual operator step; documented in migration output but not automated — Linear may block deletion of states with historical issues).

## Implementation Notes

- **Pattern:** same provider-routing architecture as existing `idea.{add,list,triage,sync}` — resolve via `operations.sh`, dispatch via MCP or local bash.
- **State IDs:** look up once per session via `list_issue_statuses(team)` and cache. Write resolved IDs into `.claude/ccanvil.local.json` under `integrations.providers.linear.state_ids` so subsequent runs skip the lookup. Keep name-based fields as fallbacks only.
- **Local-log vocabulary migration:** rename JSONL `status` values (`new → triage`, `promoted → backlog`, `parked → icebox`, `dismissed → canceled`, `merged → duplicate`) via a one-shot script. Keep a timestamped backup of the old log.
- **Linear auto-routing:** API-created issues land in Triage automatically when Triage is enabled. Do NOT pass `state` in `idea.add` save_issue calls for Linear — let Linear route.
- **60d cadence:** compute age from `createdAt` (Linear) or entry epoch (local) at query time; don't persist staleness as a field.
- **Legacy migration idempotency:** `idea-migrate-state` filters by state=`<custom-Idea-id>` pre-run; returns zero targets post-run.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
