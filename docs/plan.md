# Implementation Plan: Permissions Security Audit

> Feature: permissions-audit
> Created: 1774230545
> Spec hash: 36e70665
> Based on: docs/spec.md

## Objective

Build a deterministic permissions audit script that classifies every Bash permission entry as DANGER/UNREVIEWED/REVIEWED, with a tracked decision log for rationale.

## Sequence

### Step 1: Script skeleton + entry parsing (AC-1 partial)
- **Test:** `permissions-audit.sh check` with a fixture `settings.json` containing 3 allow entries outputs valid JSON with `entries` array, each having `permission`, `source`, `status` fields, plus `danger`, `unreviewed`, `reviewed` counts.
- **Implement:** Create `scripts/permissions-audit.sh` following `security-audit.sh` structure — `set -euo pipefail`, argument dispatch (`check` subcommand), parse `permissions.allow[]` and `permissions.deny[]` via jq, assemble JSON output.
- **Files:** `scripts/permissions-audit.sh`, `tests/permissions-audit.bats`
- **Verify:** `bats tests/permissions-audit.bats`

### Step 2: Parse both settings files + deduplication (AC-1 complete, AC-10)
- **Test:** Fixture with entries in both `settings.json` and `settings.local.json`. Same entry in both → one entry with `"source": ["settings.json", "settings.local.json"]`. Unique entries report their single source. Missing `settings.local.json` → no error, only `settings.json` parsed.
- **Implement:** Add `settings.local.json` parsing. Merge by permission string, collecting sources into arrays. Count unique entries for totals.
- **Files:** `scripts/permissions-audit.sh`, `tests/permissions-audit.bats`
- **Verify:** `bats tests/permissions-audit.bats`

### Step 3: Dangerous pattern detection (AC-3)
- **Test:** Fixture with entries matching each dangerous pattern category: broad wildcard (`echo:*`), compound operator (`cmd;cmd`), env-prefix (`VAR=val cmd`), redirect (`> file`), `find -exec`, loop primitives (`for `, `done`), file mutation (`git branch -D`), arbitrary execution (`xargs -I`). All classified as `DANGER`.
- **Implement:** Add `DANGER_PATTERNS` array with regex/substring patterns. Classify each entry against patterns before log lookup. DANGER status includes which pattern matched.
- **Files:** `scripts/permissions-audit.sh`, `tests/permissions-audit.bats`
- **Verify:** `bats tests/permissions-audit.bats`

### Step 4: Log-based status classification (AC-4, AC-6)
- **Test:** Fixture log with: (a) fully-reviewed entry (all fields non-empty, non-TODO) → REVIEWED; (b) stub entry (rationale: "TODO") → UNREVIEWED; (c) entry not in log → UNREVIEWED. Log follows schema: `{"entries": {"<permission>": {"risk", "rationale", "efficiency_justification", "reviewer", "reviewed_epoch"}}}`.
- **Implement:** Read `.claude/permissions-log.json`, look up each non-DANGER entry by exact key match, check all required fields are present, non-empty, and non-"TODO".
- **Files:** `scripts/permissions-audit.sh`, `tests/permissions-audit.bats`
- **Verify:** `bats tests/permissions-audit.bats`

### Step 5: Exit codes (AC-2)
- **Test:** Three fixture scenarios: (a) all REVIEWED, no DANGER → exit 0; (b) UNREVIEWED exists, no DANGER → exit 1; (c) DANGER exists (even with some REVIEWED) → exit 2.
- **Implement:** Exit code logic after classification: DANGER present → 2; else UNREVIEWED present → 1; else → 0.
- **Files:** `scripts/permissions-audit.sh`, `tests/permissions-audit.bats`
- **Verify:** `bats tests/permissions-audit.bats`

### Step 6: Error handling — missing and invalid log (AC-8, AC-9)
- **Test:** (a) No log file → all entries UNREVIEWED, exit 1, stderr contains "NOTE: permissions-log.json not found — run permissions-audit.sh init". (b) Invalid JSON log → stderr "ERROR: permissions-log.json is not valid JSON", exit 2.
- **Implement:** Add log file existence check with stderr note. Add `jq empty` validation before parsing. Invalid JSON exits 2 immediately.
- **Files:** `scripts/permissions-audit.sh`, `tests/permissions-audit.bats`
- **Verify:** `bats tests/permissions-audit.bats`

### Step 7: Text output mode (AC-5)
- **Test:** `check --text` outputs grouped report: DANGER first (with matched pattern name), then UNREVIEWED, then REVIEWED. REVIEWED suppressed unless `--verbose` also passed.
- **Implement:** Add `--text` and `--verbose` flags. Group and format entries by status category.
- **Files:** `scripts/permissions-audit.sh`, `tests/permissions-audit.bats`
- **Verify:** `bats tests/permissions-audit.bats`

### Step 8: Init command (AC-7)
- **Test:** (a) `init` with no existing log → creates log with all current entries as stubs (risk: "", rationale: "TODO"). (b) `init` with existing reviewed entries → preserves them, adds stubs for new entries only. (c) `init` twice → idempotent, no reviewed data lost.
- **Implement:** Add `init` subcommand. Read both settings files, diff against existing log, create/merge stubs. Use jq for merge.
- **Files:** `scripts/permissions-audit.sh`, `tests/permissions-audit.bats`
- **Verify:** `bats tests/permissions-audit.bats`

### Step 9: Scaffold-audit integration (AC-11)
- **Test:** N/A (command file, not scriptable). Manual review.
- **Implement:** Add a "Permissions" step to `.claude/commands/scaffold-audit.md`: run `permissions-audit.sh check`, if exit non-zero include danger/unreviewed counts and all DANGER permission strings in the audit report.
- **Files:** `.claude/commands/scaffold-audit.md`
- **Verify:** Read command file, confirm step is present and correct.

### Step 10: Documentation + settings update
- **Test:** N/A (documentation). Full suite run for regression.
- **Implement:** Add `permissions-audit.sh` commands to CLAUDE.md commands block. Add to GUIDE.md utility commands table. Add `Bash(scripts/permissions-audit.sh:*)` to settings.json allow list.
- **Files:** `CLAUDE.md`, `GUIDE.md`, `.claude/settings.json`
- **Verify:** `bash -n scripts/permissions-audit.sh`, `bats tests/` (full suite)

## Risks

- **Pattern false positives:** Entries like `Bash(bash -n scripts/foo.sh)` contain "bash" but aren't dangerous — the pattern must match `bash:*` (broad wildcard), not `bash -n` (specific syntax check). Need careful regex boundaries.
- **jq pipeline complexity:** Multiple jq merges for dedup + log lookup. Mitigation: keep each jq expression simple and tested independently.
- **settings.local.json absence:** Won't exist in downstream nodes or fresh clones. Script must skip gracefully — already planned in Step 2.
- **Real settings validation:** Must test against the actual `settings.json` + `settings.local.json` to catch pattern edge cases before shipping. Run against real files as a final sanity check.

## Definition of Done

- [ ] All 11 acceptance criteria from spec pass
- [ ] All existing tests still pass (222 + new)
- [ ] No syntax errors (`bash -n scripts/permissions-audit.sh`)
- [ ] Code reviewed (run /review)
- [ ] GUIDE.md and CLAUDE.md updated
- [ ] Linear issue ZWR-11 status updated
