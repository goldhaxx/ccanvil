# Feature: Hub/Node Guide Inheritance

> Created: 2026-03-20
> Status: Draft

## Summary

GUIDE.md and SCAFFOLD_FRAMEWORK.md should propagate to downstream projects through the sync system, but with different inheritance behaviors. SCAFFOLD_FRAMEWORK.md is immutable reference material — identical everywhere. GUIDE.md has a hub base layer that syncs downward, plus a node-specific layer that stays local. Hub guide updates always flow to nodes; node-specific content never flows back to the hub.

## Job To Be Done

**When** I initialize or pull updates into a downstream project,
**I want to** have an accurate, project-specific guide that includes both the scaffold-wide documentation and my project's unique commands/rules/workflows,
**So that** anyone working in this project understands the full system — both the shared scaffold and the local customizations.

## Acceptance Criteria

- [ ] **AC-1:** When `/init` creates a new project, both `SCAFFOLD_FRAMEWORK.md` and `GUIDE.md` are copied and tracked in the lockfile.
- [ ] **AC-2:** `SCAFFOLD_FRAMEWORK.md` is tracked as `clean` and auto-updated on pull, same as any other scaffold file. It is never node-specific.
- [ ] **AC-3:** `GUIDE.md` in a node project has two distinct sections: a hub-managed section (synced from scaffold) and a node-specific section (local additions). The boundary is marked by a clear delimiter.
- [ ] **AC-4:** When `/scaffold-pull` runs and the hub's GUIDE.md has changed, the hub-managed section is updated while the node-specific section is preserved intact.
- [ ] **AC-5:** When `/scaffold-push` or `/scaffold-promote` evaluates GUIDE.md, it never pushes node-specific content to the hub. The node section is classified as project-specific by default.
- [ ] **AC-6:** When the `/plan` command adds a GUIDE.md update step (because scaffold structure changed), it updates both the hub section AND the node section if the change is node-relevant (e.g., a new local command was added).
- [ ] **AC-7:** The node-specific section of GUIDE.md documents local commands, rules, agents, skills, and workflows that exist only in that project.

## Affected Files

| File | Change |
|------|--------|
| `scripts/scaffold-sync.sh` | Modified — add GUIDE.md and SCAFFOLD_FRAMEWORK.md to tracked patterns, add merge logic for GUIDE.md hub/node sections |
| `.claude/commands/scaffold-pull.md` | Modified — add special handling for GUIDE.md section-based merge |
| `.claude/commands/plan.md` | Modified — node-specific GUIDE.md section awareness |
| `global-commands/init.md` | Modified — copy both files, generate initial node section in GUIDE.md |
| `GUIDE.md` | Modified — add hub section delimiter marking the boundary |
| `.claude/agents/scaffold-differ.md` | Modified — always classify GUIDE.md node section as project-specific |

## Dependencies

- **Requires:** Scaffold sync system (complete), GUIDE.md (complete), SCAFFOLD_FRAMEWORK.md (complete)
- **Blocked by:** Nothing

## Out of Scope

- Automatic generation of node-specific GUIDE.md content from scanning local files (that's a future enhancement — for now the node section is manually maintained or updated by `/plan`)
- Merging node GUIDE.md content back into the hub GUIDE.md (explicitly blocked)
- Versioning SCAFFOLD_FRAMEWORK.md separately from the scaffold (it uses the same commit-based versioning)

## Implementation Notes

- The hub/node boundary in GUIDE.md should use a clear, grep-able delimiter like `<!-- NODE-SPECIFIC-START -->` / `<!-- NODE-SPECIFIC-END -->` so the sync script can reliably split the file for section-based merging.
- `scaffold-sync.sh` needs a new merge mode for GUIDE.md: replace everything above the delimiter with the hub version, preserve everything below.
- SCAFFOLD_FRAMEWORK.md is simpler — treat it like any tracked file (clean/modified/etc). The protection rule in code-quality.md already prevents modification.
- Both files should be added to the `TRACKED_PATTERNS` array in scaffold-sync.sh as top-level `*.md` patterns would be too broad. Track them explicitly by name.
