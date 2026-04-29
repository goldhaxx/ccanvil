---
manifest:
  id: security-audit
  purpose: Scan the repository for PII, secrets, and sensitive information that should not be in a public repo. Wraps the deterministic security-audit.sh substrate (full mode — files + history). Reports findings as CRITICAL / WARN / INFO; recommends remediation or allowlist entry.
  routes-by: /security-audit
  input:
    - "no positional args"
  output:
    - "stdout: findings table with severity / category / location / detail"
  depends-on:
    - security-audit.sh
  side-effect:
    - reads-only-no-mutations
  failure-mode:
    - "findings-detected | exit=1 | visible=stdout-findings-table | mitigation=remediate-or-allowlist-with-rationale"
  contract:
    - read-only
    - deterministic-no-claude-judgment
  anchor:
    - BTS-256 (manifest seed)
---

Scan this repository for PII, secrets, and sensitive information that should not be in a public repo.

This is a fully deterministic operation. No Claude judgment needed for the scan itself.

## Step 1: Run the audit (deterministic)

```bash
bash .ccanvil/scripts/security-audit.sh
```

This checks:
- **Secrets**: API tokens (GitHub, OpenAI, AWS, Slack), Bearer tokens
- **PII**: Absolute home paths with OS username (`/Users/<name>/`, `/home/<name>/`)
- **Emails**: Personal email addresses in tracked files (excludes noreply)
- **Dangerous files**: `.env`, `.pem`, `.key`, SSH keys, credential files tracked in git
- **Git history**: PII and secrets in commit messages and diffs

## Step 2: Report results

If PASS (exit 0): Report clean status.

If findings detected (exit 1): Present each finding with severity, category, location, and detail. Recommend specific fixes:

| Severity | Action |
|----------|--------|
| CRITICAL | Must fix before pushing. Secrets need rotation, files need removal from git history. |
| HIGH | Must fix before publishing. PII needs scrubbing, may require history rewrite. |
| MEDIUM | Should fix. Personal emails should use noreply format. |
| LOW | Informational. Review and decide. |

For findings in git history, suggest `git filter-branch` or `git filter-repo` to rewrite.

## Step 3: Targeted re-scan (if fixes applied)

After fixes, re-run with `--files-only` to verify tracked files are clean:
```bash
bash .ccanvil/scripts/security-audit.sh --files-only
```

## Rules
- NEVER dismiss a CRITICAL finding. Secrets must be rotated even after removal.
- NEVER suggest `.gitignore` as a fix for already-tracked files — the file is already in history.
- For PII in paths, the fix is `get_hub_source_display()` pattern (store `~/` not absolute).

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
