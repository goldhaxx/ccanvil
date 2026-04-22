# Migrating to the Linear-backed `/idea` system

This guide walks a downstream node through adopting the ccanvil idea pipeline. Before the migration, `/idea` captures lived in a tracked `docs/ideas.md` and every capture eventually pressured a direct-to-main commit. After:

- Captures route through `.ccanvil/scripts/operations.sh` to one of two providers: a local gitignored JSONL log, or Linear Triage via MCP.
- `/idea` never touches git — no commits, no branches.
- On Linear-configured nodes, `.ccanvil/ideas.log` becomes an archive-only record of pre-migration entries; new captures flow straight to Linear.

## Quick path: `idea-upgrade` (one command)

For most nodes this is all you need:

```bash
/ccanvil-pull
bash .ccanvil/scripts/docs-check.sh idea-upgrade \
  --provider linear \
  --team "<Linear team name>" \
  --project "<Linear project name>" \
  --from-legacy
```

What it does, in one commit:

- Writes `.claude/ccanvil.local.json` with the provider config.
- Adds `.ccanvil/ideas.log`, `.ccanvil/ideas-pending.log`, and `docs/ideas.md` to `.gitignore`.
- If `docs/ideas.md` is tracked, parses each entry, generates a concise title via `title-from-body` (uses the local `claude` CLI when present, deterministic fallback otherwise), writes JSONL to `.ccanvil/ideas.log`, and `git rm`s the source file.
- Prepends a `# ARCHIVE: read-only after <date>` header to `.ccanvil/ideas.log` (Linear only), so the log's archive-only role is self-documenting.

Flag quick-reference:

| Flag | Purpose |
|------|---------|
| `--provider local`  | Gitignored JSONL at `.ccanvil/ideas.log`. Zero network, zero config. |
| `--provider linear` | Routes captures to Linear Triage via MCP. Requires `--team` and `--project`. |
| `--from-legacy`     | Migrate an existing tracked `docs/ideas.md`. Safe to include even when no legacy file exists. |
| `--create-project`  | Emit a `save_project` intent on stdout (Linear only); the /idea skill layer dispatches it via MCP. |
| `--dry-run`         | Print the plan without making changes. Combines with any flag. |

Idempotent — re-running with the same provider is a no-op (`Already upgraded`).

### Linear-only: custom statuses

Statuses in Linear are team-scoped. If your node routes to the same team as the hub (Blocktech Solutions / BTS), the `Idea` and `Icebox` statuses already exist — nothing to do.

Otherwise, create both statuses manually in the Linear UI (MCP doesn't expose status creation yet):

1. Open **Team Settings → <your team> → Issue statuses & automations**.
2. Click **+** in the **Backlog** category. Name it `Idea`. Save.
3. Repeat: click **+** in the **Backlog** category. Name it `Icebox`. Save.

### Smoke-test

```
/idea test capture via the new flow
```

- **Local**: confirm a new line appeared in `.ccanvil/ideas.log`.
- **Linear**: confirm a new issue appeared in Linear Triage with status `Idea` and label `idea`.

If Linear is configured but a capture falls through to `.ccanvil/ideas-pending.log`, the MCP call failed (usually auth expiry). Fix the MCP connection and run `/idea sync` to drain the pending entries.

## Manual alternative

When you need fine-grained control — e.g., migrating without committing, or wiring up a node that requires bespoke steps — the original 4-step path still works. `idea-upgrade` is a wrapper around it.

1. **Pull the update**: `/ccanvil-pull`.
2. **Configure the provider**:
   ```bash
   bash .ccanvil/scripts/docs-check.sh idea-setup --provider local
   # or:
   bash .ccanvil/scripts/docs-check.sh idea-setup --provider linear --team T --project P
   ```
3. **Migrate legacy entries** (only if `docs/ideas.md` is tracked):
   ```bash
   bash .ccanvil/scripts/docs-check.sh idea-migrate
   ```
   Idempotent — exits 0 with `Nothing to migrate` if the file is absent.
4. **Commit the change**:
   ```bash
   git add .claude/ccanvil.local.json .gitignore docs/ideas.md
   git commit -m "chore(idea-migration): ..."
   ```

The manual path doesn't auto-generate titles for migrated entries (title = body), doesn't add the archive header, and requires two commits to land cleanly. Prefer `idea-upgrade` unless one of those matters.

## Troubleshooting

**`/idea` exits with "missing Linear config"** — `routing.idea = "linear"` is set but `providers.linear.{project, team}` is missing. Re-run `idea-upgrade --provider linear --team ... --project ...`.

**Broadcast prints a "docs/ideas.md still tracked" hint for the node** — that node hasn't run `idea-upgrade --from-legacy` yet. Each node migrates itself; `broadcast` only surfaces the need.

**Statuses don't exist in the target Linear team** — see step "Linear-only: custom statuses" above. `save_issue` will reject the capture until the statuses exist.

**Want to change providers later?** Re-run `idea-upgrade` with different flags. Provider-change (local → linear or vice versa) is NOT idempotent — the upgrade proceeds and creates a new commit.

**`idea-add` refuses with "Linear-configured" on a Linear node** — that's defense-in-depth. Captures on Linear-configured nodes must go through `/idea` so they route to Linear. The local log is archive-only.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
