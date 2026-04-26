# Feature: permissions-audit entry-context substrate

> Feature: bts-161-entry-context-substrate
> Work: linear:BTS-161
> Created: 1777166389
> Status: Complete

## Summary

Add an `entry-context` subcommand to `.ccanvil/scripts/permissions-audit.sh` that returns the deterministic per-row presentation context as JSON. Replaces the per-row by-hand 6-line render Claude does in `/permissions-review` (read each row's permission, source, pattern, hook gate, origin) with one substrate call. Sibling of BTS-159 (decision-append, the write side) — this ticket handles the read side.

Per the BTS-161 ticket and stasis guidance: ship the deterministic spine (file/permission/pattern/origin) first. Heuristic hook scan (matched_hooks) is in scope; manifest path is out.

## Job To Be Done

**When** `/permissions-review` walks pending rows,
**I want to** call one substrate command per row to get the deterministic context (file, permission, pattern, hooks, origin commit),
**So that** Claude renders only the judgment-heavy "net effect" prose, cutting per-row tool calls from ~5-8 to ~2-3.

## Acceptance Criteria

- [ ] **AC-1:** `permissions-audit.sh entry-context "<permission>" --json` exits 0 and prints a JSON object with keys: `permission`, `source_files`, `matched_pattern`, `matched_hooks`, `introduced_in`. The `permission` field equals the input verbatim.
- [ ] **AC-2:** For a permission present in `.claude/settings.json`, `source_files` is `[".claude/settings.json"]`. For one present only in `.claude/settings.local.json`, it is `[".claude/settings.local.json"]`. For one in both, it lists both, sorted.
- [ ] **AC-3:** For a DANGER-classified permission (e.g., `Bash(chmod:*)`), `matched_pattern` matches the same `check_danger`-derived value the existing `cmd_check` JSON already returns for that entry.
- [ ] **AC-4:** For a permission whose leading verb appears in a hook file (e.g., `Bash(chmod:*)` → `guard-destructive.sh`, `guard-workspace.sh`), `matched_hooks` is a non-empty array of objects each with keys `path` and `lines` (1-based line range as `[start, end]` covering the matched block — minimally `[N, N]` for a single line). For a permission with no leading-verb match (e.g., `Bash(echo:*)`), `matched_hooks` is `[]`.
- [ ] **AC-5:** `introduced_in` is an object with keys `commit` (short SHA) and `subject` (commit subject line) sourced from the first commit (oldest by author date) that introduced the permission string into either settings file. When the permission is not in any settings file or the introduction commit cannot be determined, the field is `null`.
- [ ] **AC-6:** `entry-context` accepts the permission as a positional arg. When the arg is missing, exit 2 with a non-empty stderr error message and no stdout. When `--json` is omitted, also default to JSON output (the script has no text-mode for this subcommand).
- [ ] **AC-7:** When the permission is not present in any settings file, exit 0 with `source_files: []`, `matched_pattern: null`, and `introduced_in: null` — `matched_hooks` still populated by leading-verb scan since hook gating is independent of settings presence. (Out-of-scope warning: callers shouldn't ask for a permission that isn't tracked, but the command must not crash.)
- [ ] **AC-8:** Round-trip: `entry-context` for a permission returned by `cmd_check` produces a `matched_pattern` field that equals the matched_pattern field in the corresponding `cmd_check` entry. Drift-guard test asserts contract stability.
- [ ] **AC-9:** `/permissions-review` skill prose updated: the DANGER walkthrough (step 4) calls `entry-context --json` once per row before prompting and includes `matched_hooks[].path` in the prompt. A drift-guard bats test asserts `.claude/commands/permissions-review.md` contains the substring `entry-context`.
- [ ] **AC-10:** Edge: when the hooks dir is missing (downstream node without `.claude/hooks/`), `matched_hooks` is `[]` rather than failing.

## Affected Files

| File | Change |
|------|--------|
| `.ccanvil/scripts/permissions-audit.sh` | Add `cmd_entry_context` + dispatch case + leading-verb regex helper |
| `hub/tests/permissions-audit-entry-context.bats` | New test file (10 ACs) |
| `.claude/commands/permissions-review.md` | Update DANGER walkthrough to call `entry-context` per row |
| `.ccanvil/guide/command-reference.md` | Document the new subcommand (one-line entry) |

## Dependencies

- **Requires:** BTS-159 (`decision-append` substrate) — already shipped. `entry-context` and `decision-append` are read/write siblings; the skill prose update touches both call sites in the same flow.
- **Blocked by:** none.

## Out of Scope

- **Manifest path (Path A from the ticket).** Heuristic scan only; no `hub/manifests/hooks.json`. Future ticket if precision matters more than freshness.
- **Net-effect prose composition.** Claude continues to compose the human-readable summary; the substrate provides only the structural inputs.
- **Caching.** `entry-context` is invoked per row; with 16-row walks the wall-time is irrelevant.
- **Non-Bash permissions (`Read(...)`, `Write(...)`, etc.).** Same `cmd_check` scope (Bash-only). Other permission shapes return `matched_hooks: []` and `matched_pattern: null` without error.

## Implementation Notes

- Follow the same shape as `cmd_promote_review` (BTS-144): typed flag parser, JSON-only output via `jq -n --arg`/`--argjson`, exit codes 0/2 only.
- Heuristic hook scan: extract leading verb from `Bash(<verb>...)` (strip `<env=val>` prefix, take first word, drop `:*`). `grep -nE` the verb in `.claude/hooks/*.sh`; collect `(path, line)` matches; coalesce contiguous lines into ranges. Skip if the dir is missing.
- `introduced_in` lookup: `git log --diff-filter=A --follow --pretty=format:%H%x09%s -- <settings-file>` is too coarse; instead `git log -S '<permission>' --reverse --pretty=format:%h%x09%s -- .claude/settings.json .claude/settings.local.json | head -1` returns the first commit that introduced the string. Quote with `printf '%s' "$perm" | jq -R .` to safely embed in `git log -S` (the literal string flag — no regex meaning).
- `cmd_check`'s `matched_pattern` derivation lives in `check_danger` (line ~271). `cmd_entry_context` calls the same helper to guarantee AC-8 contract stability.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
