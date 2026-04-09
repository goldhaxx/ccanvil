# Feature: Idea capture and roadmap foundation

> Feature: idea-capture
> Created: 1775757518
> Status: In Progress

## Summary

Near-zero-friction idea capture that prevents good ideas from being lost during focused work. A `/idea` skill logs thoughts in one line, a triage process connects them to the roadmap, and a `docs/roadmap.md` template establishes the strategic layer that ccanvil currently lacks.

## Job To Be Done

**When** I have an idea mid-session and don't want to lose it or interrupt my current flow,
**I want** to capture it in one command and get back to work,
**So that** ideas are never lost and can be evaluated against the project's strategic direction at a natural break point.

## Acceptance Criteria

### Idea capture — `/idea` skill

- [ ] **AC-1:** `/idea <text>` appends an entry to `docs/ideas.md` with timestamp, text, and status `new`. Returns confirmation and immediately resumes current work — no follow-up questions, no triage, no interruption.
- [ ] **AC-2:** `docs-check.sh idea-add "<text>"` is the deterministic script backing `/idea`. It appends a structured line to `docs/ideas.md`, creating the file if it doesn't exist.
- [ ] **AC-3:** Each idea entry is a markdown list item: `- [ ] <ISO-date>: <text> <!-- status:new -->`.
- [ ] **AC-4:** `docs-check.sh idea-list [--status <status>]` outputs ideas as JSON: `[{date, text, status, line}]`. Default: all ideas. `--status new` filters to untriaged.
- [ ] **AC-5:** `docs-check.sh idea-count` outputs `{total, new, triaged, promoted, dismissed}` — used by `/radar` for summary metrics.

### Idea triage — `/idea triage`

- [ ] **AC-6:** `/idea triage` reads all `new` ideas from `docs/ideas.md`, reads `docs/roadmap.md` for strategic context, reads the Linear backlog (via operations.sh), and for each idea recommends one of: `promote` (create Linear ticket + spec), `merge` (overlaps existing ticket), `park` (add to roadmap horizon), `dismiss` (not aligned).
- [ ] **AC-7:** Triage presents recommendations as a table and asks for approval before executing. The user can accept, reject, or modify each recommendation.
- [ ] **AC-8:** When an idea is promoted, its status changes to `promoted` and the checkbox is checked. When dismissed, status changes to `dismissed` and checkbox is checked. When merged, status changes to `merged:<ticket-id>` and checkbox is checked.
- [ ] **AC-9:** `docs-check.sh idea-update <line-number> <status>` is the deterministic script for updating idea status.

### Roadmap template

- [ ] **AC-10:** `.ccanvil/templates/roadmap.md` provides the roadmap structure: Vision, Goals, Active Theme, Up Next, Horizon.
- [ ] **AC-11:** `/init` copies `roadmap.md` to `docs/roadmap.md` (skip if exists, same as other docs templates).
- [ ] **AC-12:** The roadmap template includes guidance comments explaining each section's purpose and update cadence.

### Integration

- [ ] **AC-13:** `/catchup` reports untriaged idea count: `"Ideas: N untriaged"` (if docs/ideas.md exists and has new items).
- [ ] **AC-14:** `docs-check.sh recommend` includes idea triage as a recommended action when untriaged count > 3.

### Tests

- [ ] **AC-15:** All existing tests pass (394+).
- [ ] **AC-16:** New tests: idea-add creates file and appends, idea-add to existing file, idea-list outputs JSON, idea-list with status filter, idea-count returns correct totals, idea-update changes status.

## Affected Files

| File | Change |
|------|--------|
| `preset/.ccanvil/scripts/docs-check.sh` | Add `cmd_idea_add`, `cmd_idea_list`, `cmd_idea_count`, `cmd_idea_update` |
| `preset/.claude/skills/idea/SKILL.md` | New — `/idea` skill |
| `preset/.ccanvil/templates/roadmap.md` | New — roadmap template |
| `preset/.claude/commands/catchup.md` | Add idea count to output |
| `hub/tests/docs-check.bats` or new test file | New tests for idea commands |
| `global-commands/init.md` | Add roadmap.md to docs setup step |

## Dependencies

- **Requires:** None — this is foundational

## Out of Scope

- Automatic promotion to Linear (triage recommends, user approves)
- AI-generated idea summaries or categorization during capture
- Idea voting or prioritization scoring

## Implementation Notes

- `idea-add` is append-only — never modifies existing entries. This makes it safe to call from any context.
- The `<!-- status:new -->` HTML comment keeps the status machine-readable without cluttering the visual markdown.
- `idea-list` parses the markdown with regex — fragile but adequate for a structured format we control.
- Triage is a skill (Claude reasoning), not a script. The script provides data, Claude provides judgment.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
