Demote a scaffold-managed file to local-only override.

Use when you've customized a scaffold file for this project and want to prevent future `/scaffold-pull` from auto-updating it. The file stays in place — only the lockfile metadata changes.

## Steps

1. The user provides a file path as an argument, e.g., `/scaffold-demote .claude/rules/workflow.md`
2. Read `.claude/scaffold.lock` and verify the file's status is `clean`. If it's already `modified` or `local-only`, inform the user — it's already effectively demoted.
3. Confirm with the user: "This will mark `<file>` as a local override. Future scaffold pulls will show diffs instead of auto-updating. Proceed?"
4. Update lockfile: `./scripts/scaffold-sync.sh lock-update <file> status modified`
5. Log locally: `./scripts/scaffold-sync.sh log "demote"` and `./scripts/scaffold-sync.sh log-detail "DEMOTED <file> — marked as local override"`
6. Confirm to the user. Mention they can re-sync by running `/scaffold-pull` and choosing "Take scaffold" for this file.
