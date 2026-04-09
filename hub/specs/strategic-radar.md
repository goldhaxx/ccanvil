# Feature: Radar scan and strategic advisor

> Feature: strategic-radar
> Created: 1775757518
> Status: Complete

## Summary

A `/radar` command that provides a comprehensive project briefing — connecting recently completed work, active efforts, upcoming priorities, and untriaged ideas to the project's strategic roadmap. Backed by a strategic advisor agent that can answer questions about prioritization, alignment, and direction at any point during a session.

## Job To Be Done

**When** I start a session, finish a feature, or need to decide what to work on next,
**I want** a single command that shows me where I am across all time horizons,
**So that** every tactical decision is grounded in the project's strategic direction.

## Acceptance Criteria

### Radar data gathering (deterministic)

- [ ] **AC-1:** `docs-check.sh radar-gather` collects all radar data as JSON: recently completed specs (last 5), active spec status, idea log summary, git activity (commits in last 7 days grouped by day), context budget status, and current branch.
- [ ] **AC-2:** `radar-gather` reads `docs/roadmap.md` and includes the active theme and up-next items in the output.
- [ ] **AC-3:** `radar-gather` includes Linear backlog summary via `operations.sh exec backlog.list` if available, gracefully omitting if not.

### `/radar` skill

- [ ] **AC-4:** `/radar` calls `docs-check.sh radar-gather`, then synthesizes a structured briefing with these sections:
  - **Shipped** — recently completed features and how they connect to roadmap goals
  - **In flight** — active spec, branch, PR status, progress assessment
  - **Up next** — the next 2-3 priorities from the roadmap, with any relevant untriaged ideas
  - **Horizon** — longer-term roadmap items and backlog tickets
  - **Ideas** — untriaged idea count, any that connect to current themes
  - **Health** — context budget, test count, any drift from the active theme
- [ ] **AC-5:** `/radar` ends with a single recommended action: what to do next (continue current work, triage ideas, start next feature, update roadmap, etc.).
- [ ] **AC-6:** `/radar` can be run at any point — beginning of session, mid-session, or end of session. It reads current state without modifying anything.

### Strategic advisor agent

- [ ] **AC-7:** `.claude/agents/strategic-advisor.md` defines an agent that has read access to: `docs/roadmap.md`, `docs/ideas.md`, `docs/specs/`, active lifecycle docs, recent git history, and Linear backlog.
- [ ] **AC-8:** The agent can answer strategic questions: "Does this idea align with our goals?", "Should we prioritize X over Y?", "Are we drifting from the active theme?", "What should we focus on this week?"
- [ ] **AC-9:** The agent can recommend roadmap updates: "Based on the last 3 features shipped, the Active Theme section should be updated to reflect X."
- [ ] **AC-10:** The agent can perform idea triage when asked — same logic as `/idea triage` but conversational, with the ability to ask the user clarifying questions.
- [ ] **AC-11:** The agent explicitly avoids making changes — it reads and advises. All modifications go through existing commands (`/idea`, spec writing, roadmap editing).

### Integration

- [ ] **AC-12:** `/catchup` suggests running `/radar` when: the last radar was more than 3 sessions ago, or when the roadmap's active theme doesn't match the current branch's feature area.
- [ ] **AC-13:** The `/pr` skill includes a one-line strategic note in the PR body: "Contributes to: <active theme from roadmap>" (if roadmap exists).

### Tests

- [ ] **AC-14:** All existing tests pass (394+).
- [ ] **AC-15:** New tests: radar-gather outputs valid JSON, radar-gather includes roadmap sections, radar-gather handles missing roadmap gracefully, radar-gather handles missing ideas.md gracefully.

## Affected Files

| File | Change |
|------|--------|
| `preset/.ccanvil/scripts/docs-check.sh` | Add `cmd_radar_gather` |
| `preset/.claude/skills/radar/SKILL.md` | New — `/radar` skill |
| `preset/.claude/agents/strategic-advisor.md` | New — strategic advisor agent |
| `preset/.claude/commands/catchup.md` | Add radar suggestion logic |
| `preset/.claude/commands/pr.md` | Add strategic note to PR body |
| `hub/tests/docs-check.bats` or new test file | New tests for radar-gather |

## Dependencies

- **Requires:** idea-capture feature (docs/ideas.md, docs/roadmap.md, idea-count)

## Out of Scope

- Automated roadmap updates (agent recommends, user decides)
- Historical radar snapshots or trend analysis
- Multi-project radar (single project scope)
- Calendar or time-based scheduling ("work on X this week")

## Implementation Notes

- `radar-gather` is the deterministic data layer — it calls existing scripts (`docs-check.sh list-specs`, `idea-count`, `context-budget.sh check`) and assembles the JSON. Claude never runs `jq` or `git log` during radar — the script does it.
- The strategic advisor agent should be lightweight in its definition — most of the intelligence comes from the data it reads, not from complex instructions. The agent definition specifies WHAT to read and HOW to frame responses, not business logic.
- The agent should be invocable as a sub-agent from `/radar` for the synthesis step, but also directly by the user for ad-hoc strategic questions.
- `radar-gather` should be fast (<2s) — it's a read-only aggregation of existing data sources.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
