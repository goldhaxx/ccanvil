Push project customizations to the scaffold hub for review.

## Pre-checks

1. Run `./scripts/scaffold-sync.sh status` to get current state.
2. Read `.claude/scaffold.lock` to get the scaffold source path.
3. Check if the scaffold repo has uncommitted changes: `git -C <scaffold_source> status --porcelain`. If dirty, STOP and warn the user.

## Identify candidates

Gather files that could be pushed:
- **MODIFIED** files — scaffold-origin files with local changes
- **LOCAL** files — project-only files not in scaffold
- If the user specified a file argument, only process that file.

## For each candidate

1. Read the file content.
2. If it's a MODIFIED scaffold file, show the diff between scaffold version and local version.
3. If it's a LOCAL file, show the full content.
4. Classify the change:
   - **Generalizable** — useful across projects (new rule, improved workflow, better agent prompt, new command, new skill, utility script)
   - **Project-specific** — references project names, specific APIs, domain logic, tech stack details
5. Present the classification and rationale to the user.
6. Ask the user to approve, skip, or edit before pushing.

## Apply approved pushes

For each approved file:
1. Copy the file to the scaffold at the corresponding path: `cp <project_file> <scaffold_source>/<file>`
2. For MODIFIED files where only parts are generalizable: read the scaffold version, apply only the generalizable changes, show the result to the user for approval.
3. Update the lockfile:
   - For LOCAL → PROMOTED: `./scripts/scaffold-sync.sh lock-update <file> status promoted` and update `scaffold_hash`
   - For MODIFIED → clean: update `scaffold_hash` to match new scaffold version
4. Log to changelog: `./scripts/scaffold-sync.sh changelog "push from <project_name>"` and `changelog-detail "ADDED/MODIFIED <file> — <description>"`
5. Log locally: `./scripts/scaffold-sync.sh log "push to scaffold"` and `log-detail "PROMOTED/UPDATED <file>"`

## Finalize

1. Commit in the scaffold repo: `git -C <scaffold_source> add -A && git commit -m "chore(scaffold): upstream <description>"`
2. Update scaffold version in lockfile: `./scripts/scaffold-sync.sh lock-set-version <new_commit>`
3. Summarize what was pushed.

## Rules
- NEVER push project-specific content (tech stack, project names, API endpoints, domain logic).
- NEVER overwrite scaffold files wholesale with a project-specific version. Extract only generalizable changes.
- ALWAYS show the user what will be written to the scaffold before committing.
- The scaffold's CLAUDE.md is NEVER pushed to — it has `[Project Name]` placeholders that must be preserved.
