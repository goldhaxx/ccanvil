---
name: spec
description: "Write a feature specification with acceptance criteria. The first step after deciding to act on an idea."
---

# Spec Skill

Write a specification for the feature described in the arguments. Every spec requires a **work reference** — a provider-namespaced identifier (`BTS-130` on a Linear node, `idea-29` on a local node) that links the spec to its source-of-truth across Linear / GitHub / etc.

## Usage

- `/spec <work-ref> <description>` — write a spec with an explicit work reference
- `/spec idea <num> [description]` — write a spec from an existing idea (the idea UID serves as the work ref)
- `/spec BTS-130 <description>` — Linear-provider shorthand (resolves to `linear:BTS-130`)

A work ref is one of:

- A bare provider-native identifier (e.g., `BTS-130`, `PROJ-42`, `idea-29`) — resolved via the configured provider routing
- An explicit `<provider>:<id>` prefix (e.g., `linear:BTS-130`, `local:idea-29`) — overrides routing

## Steps

1. **Read the template:** Read `.ccanvil/templates/spec.md` for the specification format.

2. **Resolve the work reference:** Run `bash .ccanvil/scripts/operations.sh resolve work.resolve "<arg1>" --project-dir .` on the first user argument. Capture the resolved JSON (`{provider, id, slug, url}`).
   - If the command exits non-zero OR the first argument looks like a description rather than a ticket-key format, **STOP** and tell the user: `/spec requires a work reference. Examples: /spec BTS-130 "describe the feature", /spec idea 29, /spec linear:BTS-130 "...". Run /idea <text> first to capture the work if it doesn't exist yet.`

3. **Check state:** Run `bash .ccanvil/scripts/docs-check.sh validate` — if there's already an active spec on this branch, warn and ask before proceeding.

4. **If `idea <num>` mode:** The work ref is the idea's UID. Run `bash .ccanvil/scripts/docs-check.sh idea-list` to get the idea body and use it as the feature description.

5. **Explore the codebase:** Search for relevant files, patterns, and existing tests that relate to this feature. Read the 3-5 most relevant files.

6. **Derive the `feature_id`:** Use `<slug>-<kebab-name>` where `<slug>` comes from the resolved work ref's `slug` field and `<kebab-name>` is a kebab-case description of the feature. Example: work ref `BTS-130` + "Add cool thing" → `bts-130-add-cool-thing`. The slug prefix is required — it propagates into the filename and the branch name (via `activate`) so Linear's GitHub integration auto-link fires.

7. **Write the spec** to `docs/specs/<feature_id>.md` following the template format:
   - Every acceptance criterion must be independently testable (binary pass/fail)
   - Use Given/When/Then format for complex criteria
   - Include at least one error/edge case criterion
   - Reference specific files and patterns from the codebase
   - Keep under 100 lines
   - Set metadata: `> Feature: <feature_id>`, `> Work: <provider>:<id>`, `> Created: <epoch>` (via `date +%s`), `> Status: Draft`

8. **If from an idea:** Run `bash .ccanvil/scripts/docs-check.sh idea-update <num> promoted`

9. **Report:** Display the spec summary and suggest next step: "Spec written to `docs/specs/<feature_id>.md`. When ready, run `docs-check.sh activate <feature_id>` to create a branch and begin work."

## Rules

- Do NOT create a branch or activate the spec. That happens separately via `activate`.
- Do NOT write a plan. That comes after activation via `/plan`.
- Do NOT implement anything. Spec only.
- The spec goes in `docs/specs/<feature_id>.md`, NOT `docs/spec.md`. The `activate` command copies it to the active location.
- The work ref is REQUIRED. Unresolvable refs halt the skill with a clear error. Legacy specs without `Work:` are grandfathered by the validator — enforcement happens at creation time, not retroactively.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
