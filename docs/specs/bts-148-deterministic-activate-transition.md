# Feature: deterministic activate→in_progress transition dispatch

> Feature: bts-148-deterministic-activate-transition
> Work: linear:BTS-148
> Created: 1777084057
> Status: Draft

## Summary

`cmd_activate` (BTS-136) emits an `AUTO-TRANSITION: {provider, id, role}` stdout marker but never dispatches the Linear MCP `save_issue` call. The marker design depends on a wrapper skill consuming stdout — but no such skill exists for `activate`, so every Linear-tracked feature stays in Triage after activation. Discovered when BTS-147 itself stayed in Triage despite the activate output showing the expected marker. Fix: make the script enqueue a `ticket.transition` entry to `.ccanvil/ideas-pending.log` (deterministic backup, drained by `/idea sync`) AND add an `/activate` skill that wraps the script, parses the marker, and dispatches MCP immediately. Mirrors BTS-119's `/land` + AUTO-CLOSE precedent.

## Job To Be Done

**When** I run `bash .ccanvil/scripts/docs-check.sh activate <id>` (or `/activate <id>`) on a Linear-provider node,
**I want to** the linked Linear issue's status flip to `started` automatically,
**So that** the ticket reflects reality without me remembering to dispatch the transition manually.

## Acceptance Criteria

- [ ] **AC-1:** When `activate` succeeds on a Linear-provider node with a spec carrying `Work: linear:<ID>`, an entry of the form `{"op":"ticket.transition","args":{"id":"<ID>","role":"in_progress"},"ts":<epoch>}` is appended to `.ccanvil/ideas-pending.log`.
- [ ] **AC-2:** `/idea sync` recognizes `op: "ticket.transition"` entries, re-resolves `ticket.transition <id> <role>` via `operations.sh`, dispatches the resulting `save_issue`, and acks the entry on success.
- [ ] **AC-3:** A new `/activate <id>` skill: (a) runs `bash .ccanvil/scripts/docs-check.sh activate <id>`, (b) reads the AUTO-TRANSITION marker from script stdout, (c) resolves + dispatches `mcp__claude_ai_Linear__save_issue` with the in-progress state, (d) reports both the activate result and the transition result.
- [ ] **AC-4:** When `/activate` skill dispatches successfully, the corresponding `ideas-pending.log` entry is acked in the same flow (no double-dispatch on next sync).
- [ ] **AC-5:** When MCP dispatch fails inside `/activate`, the pending-log entry is left intact for `/idea sync` to retry.
- [ ] **AC-6:** Local-provider nodes still no-op silently (no marker, no enqueue, no skill action) — preserves BTS-119/BTS-136 Linear-only scope.
- [ ] **AC-7:** Legacy specs without `Work:` no-op silently in both the script and the skill.
- [ ] **AC-8:** Idempotency — running `activate` twice on the same spec doesn't double-enqueue (or if it does, sync handles it without error since `ticket.transition` is itself idempotent against current state).

## Affected Files

| File | Change |
|------|--------|
| `.ccanvil/scripts/docs-check.sh` | Modified — `cmd_auto_transition_emit` (line 1161) appends a `ticket.transition` entry to ideas-pending.log alongside emitting the stdout marker |
| `.ccanvil/scripts/docs-check.sh` | Modified — `cmd_idea_sync` recognizes and dispatches `op: "ticket.transition"` entries |
| `.claude/skills/activate/SKILL.md` | New — wrapper skill that runs activate, parses marker, dispatches MCP, acks entry |
| `.claude/commands/activate.md` | New — slash-command entry pointing at the skill |
| `hub/tests/idea-pending-sync.bats` | Modified — coverage for new op type |
| `hub/tests/activate-auto-transition.bats` | New — coverage for script-side enqueue |
| `.ccanvil/guide/skills.md` | Modified — document `/activate` |

## Dependencies

- **Requires:** BTS-128 `ticket.transition` resolver (exists). BTS-119 `/idea sync` dispatch loop (exists).
- **Blocked by:** Nothing.

## Out of Scope

- Renaming the `AUTO-TRANSITION:` marker to something less misleading. Document inline; defer rename to avoid downstream sync break.
- PostToolUse hook variant (option 2b in BTS-148 description). Skill + enqueue covers all known activate paths; hook adds complexity without clear gain unless we hit an ad-hoc activate path that bypasses both.
- Generalizing to other lifecycle transitions (e.g., draft→ready). This spec is in_progress only.

## Implementation Notes

- Mirror BTS-119's pattern: AUTO-CLOSE marker is consumed by `/land` skill AND `ticket.transition` entries flow through `/idea sync` for retry-on-failure. AUTO-TRANSITION needs both layers for the same robustness.
- The `cmd_activate` enqueue should happen BEFORE the marker emission so that even if the marker prose is later removed, the deterministic enqueue persists.
- `/activate` skill should handle the "already In Progress" idempotent case — Linear's API accepts state transitions to current state without error. The skill just reports the resulting state.
- Test the skill's dispatch failure path explicitly (AC-5): mock MCP failure, confirm pending-log entry is preserved and `/idea sync` drains it on retry.
- Update `.ccanvil/guide/command-reference.md` with the new `/activate` command and the `ticket.transition` op type recognized by `idea-sync`.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
