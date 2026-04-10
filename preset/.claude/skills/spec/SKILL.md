---
name: spec
description: "Write a feature specification with acceptance criteria. The first step after deciding to act on an idea."
---

# Spec Skill

Write a specification for the feature described in the arguments.

## Usage

- `/spec <description>` — write a spec from a feature description
- `/spec idea <num>` — write a spec from an existing idea (by idea number)

## Steps

1. **Read the template:** Read `.ccanvil/templates/spec.md` for the specification format.
2. **Check state:** Run `bash .ccanvil/scripts/docs-check.sh validate` — if there's already an active spec on this branch, warn and ask before proceeding.
3. **If `idea <num>` mode:** Run `bash .ccanvil/scripts/docs-check.sh idea-list` to get the idea text. Use that as the feature description.
4. **Explore the codebase:** Search for relevant files, patterns, and existing tests that relate to this feature. Read the 3-5 most relevant files.
5. **Derive the `feature_id`:** Create a kebab-case slug from the feature name (e.g., "Spec Skill" → `spec-skill`).
6. **Write the spec** to `docs/specs/<feature_id>.md` following the template format exactly:
   - Every acceptance criterion must be independently testable (binary pass/fail)
   - Use Given/When/Then format for complex criteria
   - Include at least one error/edge case criterion
   - Reference specific files and patterns from the codebase
   - Keep under 100 lines
   - Set metadata: `> Feature: <feature_id>`, `> Created: <epoch>` (via `date +%s`), `> Status: Draft`
7. **If from an idea:** Run `bash .ccanvil/scripts/docs-check.sh idea-update <num> promoted`
8. **Report:** Display the spec summary and suggest next step: "Spec written to `docs/specs/<id>.md`. When ready, run `docs-check.sh activate <id>` to create a branch and begin work."

## Rules

- Do NOT create a branch or activate the spec. That happens separately via `activate`.
- Do NOT write a plan. That comes after activation via `/plan`.
- Do NOT implement anything. Spec only.
- The spec goes in `docs/specs/<id>.md`, NOT `docs/spec.md`. The `activate` command copies it to the active location.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
