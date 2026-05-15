# Implementation Plan: pull-plan / pull-auto / pull-apply resolve INIT_GITHUB_TEMPLATES path mappings

> Feature: bts-493-pull-plan-init-templates-mapping
> Work: linear:BTS-493
> Created: 1778871221
> Spec hash: b2860684
> Based on: docs/spec.md

## Objective

Route the three sync-side consumers (`cmd_pull_plan`, `cmd_pull_auto`, `cmd_pull_apply`) through one bash-3.2-safe helper that resolves `INIT_GITHUB_TEMPLATES` destination keys to their template-source paths, restoring correct classification + copy behavior for fleet-distributed hub gates.

## Sequence

### Step 1: Helper + manifest (foundation)

* **Test:** New file `hub/tests/pull-plan-init-templates-mapping.bats`. First test: invokes `_resolve_hub_relpath_for_lockfile_key` (sourced from [ccanvil-sync.sh](<http://ccanvil-sync.sh>)) for each of the 5 INIT_GITHUB_TEMPLATES dest keys and asserts return = `.ccanvil/templates/github/<source>`. Second test: passthrough for non-template key (`.claude/rules/tdd.md` → `.claude/rules/tdd.md`). Red first (helper doesn't exist).
* **Implement:** Add `_resolve_hub_relpath_for_lockfile_key()` immediately after INIT_GITHUB_TEMPLATES array (\~line 69). Body: loop over INIT_GITHUB_TEMPLATES, match `${mapping##*:}` against `$key`, echo `.ccanvil/templates/github/${mapping%%:*}` on hit; echo `$key` on miss. Bash 3.2 safe — no associative arrays. Full `@manifest` block (purpose, input, output, caller cmd_pull_plan/cmd_pull_auto/cmd_pull_apply, failure-mode passthrough-for-non-template-key, contract bash-3.2-safe).
* **Files:** `.ccanvil/scripts/ccanvil-sync.sh` (add helper + manifest block), `hub/tests/pull-plan-init-templates-mapping.bats` (new).
* **Verify:** `bats hub/tests/pull-plan-init-templates-mapping.bats` green. AC-1, AC-7, AC-9 (helper portion).

### Step 2: cmd_pull_plan refactor + AC-2

* **Test:** Bats setup helper creates tmpdir hub with `.ccanvil/templates/github/workflows/ccanvil-checks.yml` containing `# v1`. Tmpdir node has `.ccanvil/ccanvil.lock` with entry `.github/workflows/ccanvil-checks.yml`: `origin=hub, hub_hash=<sha256 of v1>, local_hash=<same>, status=clean, sync=tracked`, and the dest file at the right path with v1 content. Pre-set `hub_source` via the lockfile's hub field. Run `ccanvil-sync.sh pull-plan`. Assert: plan is `[]` (empty) — no `removed` action emitted for the template entry. Red first (current code emits removed).
* **Implement:** In cmd_pull_plan (line \~1998), replace `local hub_file="$hub_source/$file"` with `local hub_file="$hub_source/$(_resolve_hub_relpath_for_lockfile_key "$file")"`. Line 2011 (`current_hub_h=$(file_hash "$hub_file")`) needs no change — consumes the same `$hub_file` variable.
* **Files:** `.ccanvil/scripts/ccanvil-sync.sh`, `hub/tests/pull-plan-init-templates-mapping.bats`.
* **Verify:** new test green. AC-2.

### Step 3: AC-3 (auto-update classification)

* **Test:** Extend the Step 2 fixture: mutate hub template to `# v2` (different sha). Re-run `pull-plan`. Assert: plan has exactly 1 entry; entry.action == `auto-update`; entry.file == `.github/workflows/ccanvil-checks.yml`. No `removed`/`new`/`conflict` actions for the entry.
* **Implement:** No new code — Step 2's helper integration is sufficient. Test confirms the existing classifier branches work correctly once hub_file resolves to the template path.
* **Files:** `hub/tests/pull-plan-init-templates-mapping.bats` only.
* **Verify:** new test green. AC-3.

### Step 4: cmd_pull_auto refactor + AC-4

* **Test:** Fixture from Step 3 (auto-update state). Run `ccanvil-sync.sh pull-auto`. Assert: (a) dest file content == hub template v2; (b) lockfile `.files[".github/workflows/ccanvil-checks.yml"].hub_hash` == sha256(v2); (c) `.local_hash` == sha256(v2); (d) `.status` == `clean`. Red first.
* **Implement:** In cmd_pull_auto (line \~2157), replace `local hub_file="$hub_source/$file"` with the helper-routed equivalent.
* **Files:** `.ccanvil/scripts/ccanvil-sync.sh`, `hub/tests/pull-plan-init-templates-mapping.bats`.
* **Verify:** new test green. AC-4.

### Step 5: cmd_pull_apply refactor + AC-5

* **Test:** Fixture from Step 3 (template-mapped, hub-changed state). Run `ccanvil-sync.sh pull-apply .github/workflows/ccanvil-checks.yml take-hub`. Assert: exit 0; dest file == hub template v2; lockfile `status` == `clean`, both hashes == sha256(v2); no `Hub file not found` on stderr.
* **Implement:** In cmd_pull_apply (line \~2253), replace `local hub_file="$hub_source/$file"` with the helper-routed equivalent.
* **Files:** `.ccanvil/scripts/ccanvil-sync.sh`, `hub/tests/pull-plan-init-templates-mapping.bats`.
* **Verify:** new test green. AC-5.

### Step 6: Regression guard + AC-6

* **Test:** Bats fixture with a single non-template lockfile entry — `.claude/rules/tdd.md` keyed as `origin=hub, hub_hash=<H>, local_hash=<H>, status=clean`. Tmpdir hub has the file at the same path. Run `pull-plan` → assert empty plan (clean). Mutate hub copy → re-run → assert single `auto-update` action. Mutate local too → re-run → assert single `conflict` action. Confirms passthrough doesn't perturb the dominant code path.
* **Implement:** None — the helper's passthrough branch already returns `$key` unchanged.
* **Files:** `hub/tests/pull-plan-init-templates-mapping.bats`.
* **Verify:** all three classifications green. AC-6.

### Step 7: Genuine-removal preservation + AC-8

* **Test:** Bats fixture where tmpdir hub does NOT have `.ccanvil/templates/github/workflows/ccanvil-checks.yml` (operator deleted it). Lockfile still has the entry. Run `pull-plan` → assert plan has one entry; entry.action == `removed`; entry.file == `.github/workflows/ccanvil-checks.yml`. Confirms the fix preserves removal semantics for genuine hub-side removals.
* **Implement:** None — the helper still resolves to the template path; the existing existence guard correctly fires; `removed` action emits as before. Test is a behavioral lock-in.
* **Files:** `hub/tests/pull-plan-init-templates-mapping.bats`.
* **Verify:** test green. AC-8.

### Step 8: Manifest depends-on + allowlist

* **Test:** `module-manifest.sh validate --json` — assert exit 0, drift 0 (no missing depends-on, helper allowlisted).
* **Implement:** Add `# depends-on: _resolve_hub_relpath_for_lockfile_key` to the @manifest blocks of cmd_pull_plan, cmd_pull_auto, cmd_pull_apply (alphabetical position in depends-on list). Add `.ccanvil/scripts/ccanvil-sync.sh:_resolve_hub_relpath_for_lockfile_key` to `.ccanvil/manifest-allowlist.txt` (alphabetical).
* **Files:** `.ccanvil/scripts/ccanvil-sync.sh` (3 @manifest blocks), `.ccanvil/manifest-allowlist.txt`.
* **Verify:** `bash .ccanvil/scripts/module-manifest.sh validate --json` returns drift=0. AC-9.

### Step 9: Full bats regression + AC-10

* **Test:** `bash .ccanvil/scripts/docs-check.sh test-suite-run --project-dir . --parallel --progress` (BTS-460 dispatcher; BTS-118 single-invocation; BTS-383 streaming progress). All tests green. No regression introduced anywhere else.
* **Implement:** Nothing planned — any failure here means triage what regressed (likely a node-only fixture path) and fix.
* **Files:** N/A.
* **Verify:** dispatcher exit 0, all-green summary. AC-10.

## Risks

* **Variable shadowing in helper.** `mapping` is also used in the loop at line \~839 of cmd_init. Using `local mapping` inside the helper isolates it; no risk of cross-talk.
* **Bash 3.2** `%%:*` **/** `##*:` **parameter expansion.** Both forms are POSIX-portable and bash 3.0+ supported. No `@` / `@P` / nameref usage.
* **Test fixture isolation.** Each test must `mktemp -d` its own hub + node and switch cwd carefully in teardown. Mirror the strict-mode pattern from `hub/tests/heal-ci-workflows.bats` (BTS-488) — guard teardown deletions with `if [[ -n "${VAR:-}" ]]; then ... fi` blocks not single-line short-circuits (the latter trips `set -e`).
* **Subshell pollution.** Tests source [ccanvil-sync.sh](<http://ccanvil-sync.sh>) to call the helper directly (Step 1). The script's `set -euo pipefail` will activate in the test shell — existing bats helpers handle that (see ccanvil-sync.bats).
* **Hub-source resolution.** The fixture must populate the lockfile's `hub_source` field (or the hub root must be resolvable from the test). Use the BTS-488 heal-ci-workflows.bats helper pattern (`setup_hub` + `setup_node` style).

## Definition of Done

- [ ] All 10 acceptance criteria from spec pass (run the new bats file).
- [ ] All existing tests still pass (full bats suite via dispatcher, parallel mode).
- [ ] `module-manifest.sh validate --json` returns `status: ok, drift: []`.
- [ ] No new `legacy-refs-scan` matches.
- [ ] Code reviewed (run /review) — code-reviewer + security-audit + self-review.
- [ ] Live-API gate: N/A (no external APIs touched; pure filesystem + lockfile ops).
- [ ] Manifest coverage: 196/196 → 197/197 (helper adds one entry).

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
