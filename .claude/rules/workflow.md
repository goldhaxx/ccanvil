# Workflow and Context Management Rules

## Feature Lifecycle

| Step | What happens | Command |
|------|-------------|---------|
| **Spec** | Acceptance criteria in `docs/specs/<id>.md` | `/spec` |
| **Activate** | Branch + draft PR + copy spec to `docs/spec.md` | `docs-check.sh activate <id>` |
| **Plan** | Implementation plan in `docs/plan.md` | `/plan` |
| **Implement** | TDD: red → green → refactor → commit | Manual |
| **Complete** | Mark Complete, remove lifecycle docs, PR ready | `docs-check.sh complete <id>` |
| **Merge** | Squash merge to main | `gh pr merge --squash` |
| **Land** | Switch to main, sync, delete branch | `docs-check.sh land` |

Main is protected — PreToolUse hook blocks direct commits to main/master.

## Strategic Awareness
- `/radar` — project briefing at session start or between features
- `/idea <text>` — quick capture; triage via `/idea triage`
- `docs/roadmap.md` — strategic source of truth; update when direction changes

## Session Discipline
- One objective per session. State it at the start.
- End with: one-line summary → explicit next action → `/compact`.
- After ~30 min of complex work, suggest checkpointing.

## Context Preservation
- On "checkpoint," use `.ccanvil/templates/checkpoint.md` format. Include Feature ID, epoch, plan hash.
- Plan before checkpoint if no plan exists.
- Determinism review mandatory at checkpoint — follow `self-review.md`.
- Resume after reset: read `docs/checkpoint.md` first.

## Hub Sync
- Classify new preset files at creation: "project-specific or hub-tracked?"
- When preset structure changes, update relevant `.ccanvil/guide/` file.

## Error Recovery
- After 2 failed attempts, STOP. Checkpoint and suggest alternatives.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
