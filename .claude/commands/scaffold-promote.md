Promote a local-only file to the scaffold hub.

This is a shortcut for `/scaffold-push` targeting a single file. Use when you've created a new rule, command, agent, skill, or template that should be shared across all projects.

## Steps

1. The user provides a file path (relative to project root) as an argument, e.g., `/scaffold-promote .claude/rules/my-new-rule.md`
2. Read `.claude/scaffold.lock` and verify the file's status is `local-only`. If it's already `clean` or `promoted`, inform the user — nothing to do.
3. Read the file content. Verify it doesn't contain project-specific references (project names, specific APIs, hardcoded paths). If it does, warn the user and suggest editing first.
4. Show the file content and ask the user to confirm promotion.
5. Copy the file to the scaffold: `cp <file> <scaffold_source>/<file>`
6. Update lockfile: run `./scripts/scaffold-sync.sh lock-update <file> status promoted` and `./scripts/scaffold-sync.sh lock-update <file> scaffold_hash <hash>`
7. Log: `./scripts/scaffold-sync.sh changelog "promote from <project>"` and `./scripts/scaffold-sync.sh changelog-detail "ADDED <file> — <brief description>"`
8. Log locally: `./scripts/scaffold-sync.sh log "promote to scaffold"` and `./scripts/scaffold-sync.sh log-detail "PROMOTED <file>"`
9. Commit in scaffold repo: `git -C <scaffold_source> add -A && git commit -m "chore(scaffold): add <filename> from <project>"`
10. Update scaffold version: `./scripts/scaffold-sync.sh lock-set-version <new_commit>`
11. Confirm to the user what was promoted.
