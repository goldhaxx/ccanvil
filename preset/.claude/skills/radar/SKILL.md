---
name: radar
description: Comprehensive project briefing — connects tactical work to strategic roadmap across all time horizons.
---

Scan the project's current state across all time horizons and produce a strategic briefing.

## Data gathering (deterministic)

1. Run: `bash .ccanvil/scripts/docs-check.sh radar-gather`
2. Run: `bash .ccanvil/scripts/operations.sh exec backlog.list` (if available — gracefully skip if not)
3. Read `docs/roadmap.md` (if it exists)

## Briefing (synthesis)

Using the gathered data, produce a structured briefing with these sections:

### Shipped
Recently completed features (from `completed_recent`). For each, one line: what it was and which roadmap goal it served. If no roadmap exists, just list completions.

### In Flight
Current work: active spec name, branch, what's being built, estimated progress based on git activity. If no active spec, say so.

### Up Next
The next 2-3 priorities. Source from: roadmap "Up Next" section, Ready specs in backlog, or untriaged ideas that align with the active theme. Recommend what to start after current work completes.

### Horizon
Longer-term items from roadmap "Horizon" section and backlog tickets that aren't immediately actionable. Brief — just names and one-line context.

### Ideas
If there are untriaged ideas (ideas.new > 0), list them and note any that connect to current themes. Suggest running `/idea triage` if count > 3.

### Health
- Context budget status (run `bash .ccanvil/scripts/context-budget.sh check --text` if available)
- Test count trend (if known from recent commits)
- Theme drift: does current work align with the roadmap's active theme? If not, flag it.

## Close with a recommendation

End with ONE clear recommended action:
- If in the middle of a feature: "Continue current work on <feature>."
- If between features: "Start <next priority> — run `docs-check.sh activate <id>`."
- If ideas are piling up: "Triage ideas first — run `/idea triage`."
- If roadmap is stale or missing: "Update `docs/roadmap.md` to reflect current direction."

## Rules

- `/radar` is read-only. It never modifies files, creates commits, or starts work.
- Keep the briefing concise — aim for one screen of output.
- If data is missing (no roadmap, no ideas, no backlog), adapt gracefully — show what's available.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
