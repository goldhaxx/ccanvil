Pull updates from the scaffold hub into this project.

## Pre-checks

1. Run `./scripts/scaffold-sync.sh status` to get current state.
2. Read `.claude/scaffold.lock` to get the scaffold source path and version.
3. Check if the scaffold repo has uncommitted changes: `git -C <scaffold_source> status --porcelain`. If dirty, STOP and warn the user.

## Pull workflow

For each tracked file, compare the scaffold's current version against the lockfile's `scaffold_hash`:

### Auto-update (scaffold changed, local is clean)
- Copy the scaffold version to the project
- Update the lockfile: `./scripts/scaffold-sync.sh lock-update <file> scaffold_hash <new_hash>` and `lock-update <file> local_hash <new_hash>`
- Log: `./scripts/scaffold-sync.sh log-detail "AUTO-UPDATED <file>"`

### Conflict (scaffold changed, local is modified)
Present the user with:
```
CONFLICT: <file>
  Both scaffold and local have changes since last sync.
```
Show the diff between scaffold and local versions.
Offer four options:
1. **Keep local** — skip this update
2. **Take scaffold** — overwrite local with scaffold version
3. **Merge** — read both versions, propose a combined version, show it to the user for approval before writing
4. **Show full diff** — display side-by-side before deciding

Log the resolution: `SKIPPED`, `OVERWRITTEN`, or `MERGED`

### New in scaffold (file exists in scaffold but not in project/lockfile)
Show the file's purpose and first few lines. Ask the user to accept or skip.
If accepted:
- Copy to project
- Add lockfile entry: `./scripts/scaffold-sync.sh lock-add <file> scaffold <hash> <hash> clean`
- Log: `ADDED <file>`

### Removed from scaffold (file in lockfile but gone from scaffold)
Ask the user: keep locally or delete?
Log: `KEPT <file>` or `DELETED <file>`

## Finalize

1. Update scaffold version in lockfile: `./scripts/scaffold-sync.sh lock-set-version <current_scaffold_commit>`
2. Write the sync log header: `./scripts/scaffold-sync.sh log "pull from scaffold @ <version>"`
3. Summarize what happened: N auto-updated, N conflicts resolved, N new files added, N skipped.

## Rules
- NEVER auto-update a file whose local hash differs from the lockfile's local_hash — that means it was locally modified.
- ALWAYS show the user what will change before writing.
- For merge conflicts, Claude proposes the merge but the user must approve before it's written.
