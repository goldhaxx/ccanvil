# Feature: Universal Delimiters for Markdown Scaffold Components

> Created: 2026-03-21
> Status: In Progress

## Summary

Every markdown file synced by the scaffold system gets a `<!-- NODE-SPECIFIC-START -->` delimiter, enabling section-merge on pull instead of full-file conflicts. This means downstream projects can customize any rule, command, agent, skill, or template without losing those customizations when the hub updates.

## Job To Be Done

**When** a downstream project customizes a scaffold markdown file (e.g., adds project-specific test commands to TDD rules),
**I want to** pull hub updates without losing my local additions,
**So that** scaffold evolution and project customization coexist without manual conflict resolution.

## Acceptance Criteria

- [x] **AC-1:** All 23 markdown scaffold files (1 skill, 3 agents, 10 commands, 5 rules, 4 templates) have a `<!-- NODE-SPECIFIC-START -->` delimiter with an empty node section below it.
- [x] **AC-2:** YAML frontmatter (in skills and agents) remains above the hub section, not split by the delimiter.
- [x] **AC-3:** `scaffold-sync.sh pull-plan` classifies these files as `section-merge` (not `conflict`) when both hub and local have changes. (Already works — pull-plan checks for delimiter via `grep -qx` on the scaffold file.)
- [x] **AC-4:** `scaffold-sync.sh section-merge` correctly merges a delimited hub file with a local file that has node-specific content below the delimiter. (Already works — existing section-merge logic handles this.)
- [x] **AC-5:** `scaffold-sync.sh section-merge` correctly handles a local file that predates the delimiter (no delimiter yet) — treats entire local content as node content. (Already works — existing fallback logic.)
- [x] **AC-6:** The delimiter line is exactly `<!-- NODE-SPECIFIC-START -->` (matches the `grep -qx` in pull-plan). Verified: no false matches in code-block examples (HTML-escaped).
- [x] **AC-7:** GUIDE.md and CLAUDE.md are unchanged (they already have their own delimiters). GUIDE.md documentation updated to reflect universal delimiters.

## Affected Files

| File | Change |
|------|--------|
| `.claude/skills/tdd/SKILL.md` | Modified — add delimiter + empty node section |
| `.claude/agents/spec-writer.md` | Modified — add delimiter + empty node section |
| `.claude/agents/code-reviewer.md` | Modified — add delimiter + empty node section |
| `.claude/agents/scaffold-differ.md` | Modified — add delimiter + empty node section |
| `.claude/commands/plan.md` | Modified — add delimiter + empty node section |
| `.claude/commands/review.md` | Modified — add delimiter + empty node section |
| `.claude/commands/catchup.md` | Modified — add delimiter + empty node section |
| `.claude/commands/scaffold-status.md` | Modified — add delimiter + empty node section |
| `.claude/commands/fix-certs.md` | Modified — add delimiter + empty node section |
| `.claude/commands/scaffold-pull.md` | Modified — add delimiter + empty node section |
| `.claude/commands/scaffold-push.md` | Modified — add delimiter + empty node section |
| `.claude/commands/scaffold-promote.md` | Modified — add delimiter + empty node section |
| `.claude/commands/scaffold-demote.md` | Modified — add delimiter + empty node section |
| `.claude/commands/scaffold-ignore.md` | Modified — add delimiter + empty node section |
| `.claude/rules/tdd.md` | Modified — add delimiter + empty node section |
| `.claude/rules/workflow.md` | Modified — add delimiter + empty node section |
| `.claude/rules/code-quality.md` | Modified — add delimiter + empty node section |
| `.claude/rules/deterministic-first.md` | Modified — add delimiter + empty node section |
| `.claude/rules/tls-troubleshooting.md` | Modified — add delimiter + empty node section |
| `docs/templates/spec.md` | Modified — add delimiter + empty node section |
| `docs/templates/plan.md` | Modified — add delimiter + empty node section |
| `docs/templates/checkpoint.md` | Modified — add delimiter + empty node section |
| `docs/templates/hooks-reference.md` | Modified — add delimiter + empty node section |
| `GUIDE.md` | Modified — document universal delimiter principle |
| `docs/checkpoint.md` | Modified — update progress |

## Dependencies

- **Requires:** Section-merge system in scaffold-sync.sh (complete)
- **Blocked by:** Nothing

## Out of Scope

- Adding delimiters to non-markdown files (scripts, JSON, hooks) — can't splice those safely
- Populating node sections with content (they start empty; downstream projects add their own)
- Updating the `/init` command to handle delimiters (already works — section-merge handles missing delimiters gracefully)
- Writing tests for scaffold-sync.sh (separate next step)

## Implementation Notes

- Delimiter block is exactly 4 lines appended to each file:
  ```
  <!-- NODE-SPECIFIC-START -->
  <!-- Add project-specific content below this line. -->
  <!-- Hub content above is updated via /scaffold-pull. -->
  ```
- For files with YAML frontmatter: delimiter goes after all hub content (at the very end), not between frontmatter and body.
- The `grep -qx` in pull-plan requires the delimiter to be on its own line with no leading/trailing whitespace.
- AC-3 through AC-5 are already satisfied by existing section-merge logic — this is purely about adding the delimiters to hub files.
