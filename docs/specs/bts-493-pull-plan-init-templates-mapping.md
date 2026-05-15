# Feature: pull-plan / pull-auto / pull-apply resolve INIT_GITHUB_TEMPLATES path mappings

> Feature: bts-493-pull-plan-init-templates-mapping
> Work: linear:BTS-493
> Created: 1778871058
> Subject: pull-plan / pull-auto / pull-apply resolve INIT_GITHUB_TEMPLATES path
> Status: Complete

## Summary

`cmd_pull_plan`, `cmd_pull_auto`, and `cmd_pull_apply` in `.ccanvil/scripts/ccanvil-sync.sh` all assume the lockfile-entry key matches the hub-relative path (`hub_file="$hub_source/$file"`). That assumption breaks for entries registered via `INIT_GITHUB_TEMPLATES` — lockfile key is the destination path (`.github/workflows/ccanvil-checks.yml`) while hub stores the file at the template path (`.ccanvil/templates/github/workflows/ccanvil-checks.yml`). Today the visible symptom is `pull-plan` emitting `action: "removed"` on every node that received the BTS-488 fleet heal. Latent symptoms: `pull-auto` would copy from a non-existent path and `pull-apply take-hub` dies with `Hub file not found`. This spec adds one bash-3.2-safe helper to resolve the inverse mapping and routes all three call sites through it, restoring the intended `clean` / `auto-update` classification and unblocking the BTS-488 ship's distribution goal.

## Job To Be Done

**When** I run `ccanvil-sync.sh pull-plan` (or `pull-auto`, or `pull-apply`) on a node whose lockfile contains an `INIT_GITHUB_TEMPLATES`-mapped entry,
**I want to** see the entry classified against its hub template source (not its destination path),
**So that** hub updates to `ccanvil-checks.yml` (and any future template-mapped file) auto-update fleet-wide via the canonical pull path, with no false `removed` prompts.

## Acceptance Criteria

- [ ] **AC-1:** New helper `_resolve_hub_relpath_for_lockfile_key <key>` returns the template path (e.g. `.ccanvil/templates/github/workflows/ccanvil-checks.yml`) for any of the 5 `INIT_GITHUB_TEMPLATES` destination paths, and passes through unchanged for non-template keys.
- [ ] **AC-2:** `cmd_pull_plan` on a fixture node whose lockfile has `.github/workflows/ccanvil-checks.yml` with hub_hash matching the hub template emits NO entry for that file (clean, hub_changed=false) — never `removed`.
- [ ] **AC-3:** `cmd_pull_plan` on the same fixture after the hub template hash changes (and local is clean) emits exactly one entry `{action: "auto-update"}` for that file — never `removed`, never `new`, never `conflict`.
- [ ] **AC-4:** `cmd_pull_auto` on the AC-3 fixture copies the hub template into `.github/workflows/ccanvil-checks.yml` and updates the lockfile entry's `hub_hash` and `local_hash` to the new value with `status: "clean"`.
- [ ] **AC-5:** `cmd_pull_apply <dest-path> take-hub` succeeds for a template-mapped entry — no `Hub file not found` die; the destination file becomes byte-identical to the hub template; lockfile reflects clean.
- [ ] **AC-6:** Regression guard: `cmd_pull_plan` on a fixture with a non-template entry (e.g. `.claude/rules/tdd.md`) classifies it identically before and after the change (clean / auto-update / conflict based on hashes, no spurious actions).
- [ ] **AC-7:** Helper is bash-3.2 compatible — no `declare -A` / `local -A` (verified by running tests under `/bin/bash` on a 3.2.57 system).
- [ ] **AC-8:** Error path: when the lockfile entry's hub-template source file is genuinely absent from hub (e.g. operator deleted `.ccanvil/templates/github/workflows/ccanvil-checks.yml`), `cmd_pull_plan` STILL emits `action: "removed"` for that entry. The fix preserves the "removed" semantics for actual removals; it only fixes mis-routing of present files.
- [ ] **AC-9:** Module-manifest registration: the new helper carries a `@manifest` block with `purpose`, `input`, `output`, at least one `caller` (cmd_pull_plan), and `failure-mode: passthrough-for-non-template-key`. `cmd_pull_plan`, `cmd_pull_auto`, `cmd_pull_apply` manifests gain `depends-on: _resolve_hub_relpath_for_lockfile_key`. `manifest-allowlist.txt` includes the new entry.
- [ ] **AC-10:** Full bats suite green; manifest validate clean (drift 0).

## Affected Files

| File | Change |
|------|--------|
| `.ccanvil/scripts/ccanvil-sync.sh` | Modified: new helper + three call-site rewrites at lines ~1998, ~2011, ~2157, ~2253 |
| `.ccanvil/manifest-allowlist.txt` | Modified: add `_resolve_hub_relpath_for_lockfile_key` entry |
| `hub/tests/pull-plan-init-templates-mapping.bats` | New: fixture + 8 tests covering AC-2..AC-8 |

## Dependencies

- **Requires:** `INIT_GITHUB_TEMPLATES` array (ccanvil-sync.sh:62-68, present today) and `cmd_heal_ci_workflows` (BTS-488, shipped) — both prerequisites are in main.
- **Blocked by:** Nothing.

## Out of Scope

- BTS-489 (init-time lockfile registration gap for github templates) — orthogonal upstream bug; BTS-488's heal currently papers over it for `ccanvil-checks.yml` only. Whether to extend lockfile registration to all INIT_GITHUB_TEMPLATES entries at init time is BTS-489's concern, not this one.
- BTS-490 (hub-level credential `.gitignore` defaults) — unrelated.
- Forward fleet heal — every node already has the correct lockfile entry from BTS-488; this fix is forward-compat. No re-broadcast required after merge.
- `cmd_init`'s classify-file walk for INIT_GITHUB_TEMPLATES (lines 839-846) — uses `classify_file "$hub_file" "$dst"` with explicit hub_file from `github_tpl_root`; not affected by this bug.

## Implementation Notes

- **Helper shape (bash 3.2 safe):**
  ```bash
  _resolve_hub_relpath_for_lockfile_key() {
    local key="$1"
    local mapping
    for mapping in "${INIT_GITHUB_TEMPLATES[@]}"; do
      if [[ "${mapping##*:}" == "$key" ]]; then
        echo ".ccanvil/templates/github/${mapping%%:*}"
        return 0
      fi
    done
    echo "$key"
  }
  ```
- **Call-site refactor pattern:** replace `local hub_file="$hub_source/$file"` with `local hub_file="$hub_source/$(_resolve_hub_relpath_for_lockfile_key "$file")"` at the three identified sites (cmd_pull_plan:1998, cmd_pull_auto:2157, cmd_pull_apply:2253). The line-2011 `file_hash "$hub_file"` already consumes the resolved variable — no change needed there.
- **Test fixture:** mimic the unifi-toolbox shape — tmpdir hub with `.ccanvil/templates/github/workflows/ccanvil-checks.yml` populated, tmpdir node with `.ccanvil/ccanvil.lock` containing the entry `.github/workflows/ccanvil-checks.yml` mapped to `origin:hub, hub_hash:<H>, local_hash:<H>, status:clean`. Run pull-plan; assert empty plan (clean). Mutate hub template content; re-run; assert single `auto-update` entry.
- **Bash 3.2 verification:** the project already runs CI on bash 3.2.57(1) (per `bash --version` on this host). No new assertion needed; the existing CI surface covers it.
- **Live-API risk:** none — pure filesystem and lockfile mutations.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
