---
manifest:
  id: ccanvil-push
  purpose: Push project customizations back to the hub for review — script handles deterministic copy/hash/lockfile/git mechanics; Claude's role is limited to classifying each candidate as generalizable (hub-worthy) or project-specific (skip). Spawns the ccanvil-differ sub-agent for the classification step.
  routes-by: /ccanvil-push
  input:
    - "no positional args (synthesizes from local diffs vs lockfile)"
    - "optional: <file-path> (push only that file)"
  output:
    - "side-effect: hub branch updated, hub PR opened, lockfile bumped on the project side"
  depends-on:
    - ccanvil-sync.sh
  side-effect:
    - copies-files-to-hub
    - opens-hub-pr
    - mutates-lockfile
  failure-mode:
    - "no-candidates | exit=0 | visible=stdout-message | mitigation=no-action-needed"
    - "all-project-specific | exit=0 | visible=skip-list-without-hub-pr | mitigation=use-/ccanvil-promote-on-individual-files"
  contract:
    - judgment-only-on-classification
    - never-pushes-without-confirmation
  anchor:
    - BTS-256 (manifest seed)
---

Push project customizations to the hub for review.

All deterministic operations (copy, hash, lockfile, git commit, logging) are handled by the script. Claude's role is LIMITED to: classifying changes as generalizable vs project-specific.

## Step 1: Pre-check and identify candidates (deterministic)

```bash
./.ccanvil/scripts/ccanvil-sync.sh pre-check
./.ccanvil/scripts/ccanvil-sync.sh push-candidates
```

If the user specified a file: `./.ccanvil/scripts/ccanvil-sync.sh push-candidates <file>`

Read the JSON output: array of `{file, status, has_diff}` objects.

## Step 2: For each candidate (JUDGMENT CALL)

1. Read the file content.
2. If `has_diff` is true, show the diff: `./.ccanvil/scripts/ccanvil-sync.sh diff <file>`
3. **Classify the change** — this is Claude's judgment call:
   - **Generalizable** — useful across projects (new rule, improved workflow, better agent prompt, utility script)
   - **Project-specific** — references project names, specific APIs, domain logic, tech stack details
   - **Mixed** — extract generalizable parts
4. Present the classification and rationale to the user.
5. User approves, skips, or edits.

## Step 3: Apply approved pushes (deterministic)

For each approved file:
```bash
./.ccanvil/scripts/ccanvil-sync.sh push-apply <file> "<brief description>"
```

For mixed files where only parts are generalizable: read the hub version, apply only the generalizable changes to a temp file, show the user for approval, then push the temp file content.

## Step 4: Finalize (deterministic)

```bash
./.ccanvil/scripts/ccanvil-sync.sh push-finalize "chore(ccanvil): upstream <description>"
```

Report what was pushed.

## Rules
- NEVER run `cp`, `jq`, `lock-update`, or `git -C` manually. Use compound commands.
- NEVER push project-specific content (tech stack, project names, API endpoints, domain logic).
- NEVER push the CLAUDE.md node section (above the delimiter).
- ALWAYS show the user what will be written to the hub before committing.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
