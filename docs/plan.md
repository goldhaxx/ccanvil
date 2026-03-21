# Implementation Plan: Hub/Node Document Inheritance

> Created: 2026-03-20
> Based on: docs/spec.md

## Objective

Make GUIDE.md, CLAUDE.md, and SCAFFOLD_FRAMEWORK.md propagate to downstream projects through the sync system — SCAFFOLD_FRAMEWORK.md as a standard tracked file, GUIDE.md and CLAUDE.md with section-based merge that preserves node-specific content while syncing hub-managed methodology.

## Sequence

### Step 1: Restructure hub CLAUDE.md with delimiter
- **Implement:** Add `<!-- NODE-SPECIFIC-START -->` delimiter to CLAUDE.md in the hub. The top half (above delimiter) becomes the node-specific zone: project name, description, tech stack, commands, architecture. The bottom half (below a `<!-- HUB-MANAGED-START -->` marker at the very top) contains: workflow, conventions, reference documents, do not. Restructure so the hub-managed content is at the bottom after the delimiter, and the node-specific project identity content is at the top.
- **Files:** `CLAUDE.md`
- **Verify:** CLAUDE.md still under 80 lines. Delimiter present. Hub sections (Workflow, Conventions, Reference Documents, Do Not) are below it. Node sections (name, tech stack, commands, architecture) are above it.

### Step 2: Add delimiter to hub GUIDE.md
- **Implement:** Append `<!-- NODE-SPECIFIC-START -->` delimiter and a starter node section template to the end of GUIDE.md. The hub version's node section contains placeholder text explaining what goes there.
- **Files:** `GUIDE.md`
- **Verify:** Delimiter is present, file still renders correctly in markdown preview.

### Step 3: Track GUIDE.md, CLAUDE.md, and SCAFFOLD_FRAMEWORK.md in scaffold-sync.sh
- **Implement:** Add explicit named file entries to `TRACKED_PATTERNS` in scaffold-sync.sh: `"GUIDE.md"`, `"CLAUDE.md"`, `"SCAFFOLD_FRAMEWORK.md"`. Remove CLAUDE.md from the "NOT tracked" list in the plan documentation — it is now tracked.
- **Files:** `scripts/scaffold-sync.sh`
- **Verify:** `./scripts/scaffold-sync.sh scan` lists all three files.

### Step 4: Add `section-merge` subcommand to scaffold-sync.sh
- **Implement:** New subcommand `scaffold-sync.sh section-merge <scaffold-file> <local-file>` that:
  1. Looks for `<!-- NODE-SPECIFIC-START -->` in both files
  2. Takes everything ABOVE the delimiter from the scaffold version (hub-managed content)
  3. Takes everything FROM the delimiter onward from the local version (node-specific content)
  4. Concatenates and writes to stdout
  5. If local has no delimiter, outputs scaffold content above delimiter + delimiter + full local content (graceful first-time handling)
  6. If scaffold has no delimiter, falls back to standard diff (not a section-merge file)
- **Files:** `scripts/scaffold-sync.sh`
- **Verify:** Test with pairs of files. Confirm hub content replaced, node content preserved. Confirm graceful fallback when delimiter missing from local.

### Step 5: Update /scaffold-pull to use section-merge for delimited files
- **Implement:** Add a rule to the pull command: when processing a file that contains `<!-- NODE-SPECIFIC-START -->` in the scaffold version, use `section-merge` instead of the standard four-option conflict flow. This applies to both GUIDE.md and CLAUDE.md (and any future delimited files). Present the merged result to the user for approval before writing. If the file is clean (no local node content yet), auto-update as normal.
- **Files:** `.claude/commands/scaffold-pull.md`
- **Verify:** Trace the pull flow for both GUIDE.md and CLAUDE.md. Hub content updates while node content is preserved.

### Step 6: Update scaffold-differ to classify node sections as project-specific
- **Implement:** Add a rule to the scaffold-differ agent: for any file with `<!-- NODE-SPECIFIC-START -->`, everything below the delimiter is always classified as project-specific. This covers GUIDE.md, CLAUDE.md, and any future delimited files generically.
- **Files:** `.claude/agents/scaffold-differ.md`
- **Verify:** Read the updated instructions and confirm the generic delimiter-aware classification logic.

### Step 7: Update /init to copy all three files and generate initial node sections
- **Implement:** Modify `/init` to:
  1. Copy `GUIDE.md`, `CLAUDE.md`, and `SCAFFOLD_FRAMEWORK.md` to the new project
  2. For CLAUDE.md: replace `[Project Name]` and `[One-line description]` placeholders in the node section (top). Hub section (bottom) stays as-is.
  3. For GUIDE.md: scan the project for existing `.claude/` files (rules, commands, agents, skills) not from the scaffold. Generate an initial node-specific section listing what was found, or a placeholder if the project is empty.
  4. SCAFFOLD_FRAMEWORK.md: copy as-is, no modification.
  5. Lockfile generation picks up all three files via updated TRACKED_PATTERNS.
- **Files:** `global-commands/init.md`
- **Verify:** Instructions clearly describe copying all three files and generating node sections.

### Step 8: Update /plan for hub vs node GUIDE.md and CLAUDE.md awareness
- **Implement:** Refine step 7 of `/plan`: when the plan involves local-only changes (new project command/rule/agent), the update step targets the node-specific sections of both GUIDE.md and CLAUDE.md. When it's a scaffold-wide change, it targets the hub sections. Make this generic — "update the appropriate section (hub or node) of delimited files."
- **Files:** `.claude/commands/plan.md`
- **Verify:** Read the updated instructions and confirm the distinction is clear.

### Step 9: Update GUIDE.md hub section with documentation for this feature
- **Implement:** Read `GUIDE.md` and update the hub section:
  - Add SCAFFOLD_FRAMEWORK.md to the System Overview diagram as a tracked reference document
  - Add a "Document Inheritance" subsection in Scaffold Sync System explaining the delimiter convention, section-merge behavior, and which files use it
  - Update the pull flow diagram to show the section-merge path for delimited files
  - Add CLAUDE.md to the sync system architecture diagram (it was previously excluded)
  - Update command reference tables if any command behavior changed
- **Files:** `GUIDE.md`
- **Verify:** All diagrams render correctly. Guide accurately describes the new feature.

## Risks

- **Delimiter corruption:** If a user removes `<!-- NODE-SPECIFIC-START -->`, the merge fails. Mitigation: `section-merge` detects missing delimiter and falls back to appending full local content as node section.
- **CLAUDE.md 80-line budget:** The delimiter comment costs 1 line. Mitigation: the line budget is already tight at 63 lines — there's room. The delimiter enables syncing the methodology sections, which is worth 1 line.
- **Large GUIDE.md in context:** Reading GUIDE.md for updates is expensive. Mitigation: only read during the specific plan step, only when scaffold structure changed.
- **Existing projects without delimiters:** fucina's CLAUDE.md and GUIDE.md (once copied) won't have delimiters. Mitigation: `section-merge` graceful fallback treats the entire local file as node content, then adds hub content above. User reviews the result.
- **Hub content order matters for attention:** CLAUDE.md hub sections (Workflow, Do Not) are at the bottom. The U-shaped attention curve means beginning and end get most attention. Mitigation: "Do Not" is already at the end (high attention), and the Workflow summary at the boundary is reinforced by rules files.

## Definition of Done

- [ ] AC-1: `/init` copies GUIDE.md, CLAUDE.md, and SCAFFOLD_FRAMEWORK.md, all tracked in lockfile
- [ ] AC-2: SCAFFOLD_FRAMEWORK.md auto-updates on pull (standard tracked file)
- [ ] AC-3: GUIDE.md has hub section + delimiter + node section
- [ ] AC-4: CLAUDE.md has node section (top: identity) + delimiter + hub section (bottom: methodology)
- [ ] AC-5: `/scaffold-pull` uses section-merge for delimited files, preserving node content
- [ ] AC-6: `/scaffold-push` never pushes node-specific content from delimited files
- [ ] AC-7: `/plan` distinguishes hub vs node section updates
- [ ] AC-8: Node sections document local-only commands, rules, agents, skills
- [ ] AC-9: Graceful fallback when local file has no delimiter (first-time or legacy projects)
- [ ] All existing scaffold sync functionality still works
- [ ] Code reviewed (run /review)
