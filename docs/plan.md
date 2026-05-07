# Implementation Plan: provider-heal-preflight (Phase 2)

> Feature: bts-320-provider-heal-preflight
> Work: linear:BTS-320
> Created: 1778132800
> Spec hash: 3d89a8dc
> Based on: docs/spec.md

## Objective

Add `cmd_provider_heal_preflight` to `.ccanvil/scripts/docs-check.sh`. Read-only substrate that runs `ccanvil-sync.sh pull-plan` against the hub (resolved from `.ccanvil/ccanvil.lock` `.hub_source`), groups action counts, and exits 0 with PREFLIGHT-OK or non-zero with structured remediation. Bats coverage via `CCANVIL_SYNC_OVERRIDE` (new test-injection point, mirrors `LINEAR_QUERY_OVERRIDE`).

## Steps

### Step 1 — Red: bats fixtures + first failing test

Create `hub/tests/provider-heal-preflight.bats`:

- Setup: `mktemp -d` for `TMPDIR_BATS`, create `<tmp>/proj/.ccanvil/ccanvil.lock` with `{"hub_source": "<tmp>/hub-stub"}`.
- `write_sync_stub()` helper that writes `<tmp>/sync-stub.sh` branching on subcommand:
  - `pull-plan`: emits JSON array parameterized by `STUB_PLAN_JSON` env var; default = `[]` (empty plan = OK).
- AC-1 test (PREFLIGHT-OK): empty plan → exit 0, stdout contains `PREFLIGHT-OK`.

Run: `bats hub/tests/provider-heal-preflight.bats`. Confirm test FAILS (subcommand not implemented).

### Step 2 — Green: implement `cmd_provider_heal_preflight`

Add to docs-check.sh:

- Mirror `cmd_provider_resolve_ids` arg parsing (`--project-dir`, `--json`).
- Resolve hub path: `jq -r '.hub_source' <project_dir>/.ccanvil/ccanvil.lock`. Tilde-expand via `${path/#\~/$HOME}`.
- Missing lock → exit 1 with the AC-3 error.
- Run `${CCANVIL_SYNC_OVERRIDE:-$script_dir/ccanvil-sync.sh} pull-plan <hub>`. Capture stdout + exit code.
- pull-plan non-zero → exit non-zero with `WRAPPER ERROR:` prefix.
- Parse plan JSON via `jq`: `[.[] | .action] | group_by(.) | map({(.[0]): length}) | add // {}`.
- Compute total non-zero action count.
- 0 → exit 0 with `PREFLIGHT-OK: substrate aligned with hub`.
- Non-zero → exit non-zero, stderr lists each non-zero action + count + remediation recipe.
- `--json` flag: stdout structured `{status, action_counts: {auto_update, new, section_merge, conflict}, hub_path}`.

Register subcommand dispatch + add to `PROJECT_TREE_SUBCOMMANDS`.

### Step 3 — Green: ACs 2, 3, 4, 5, 6

Add bats tests:
- AC-2: stub returns plan with 3 auto-update + 2 new → exit non-zero, stderr lists both.
- AC-3: lock missing → exit 1, stderr names the missing path + remediation.
- AC-4: `--json` flag → stdout parses as JSON envelope, status="drift" when plan non-empty.
- AC-5: stub records every invocation; assert `pull-plan` called once, `pull-auto`/`pull-apply` NEVER called.
- AC-6: stub exits 1 with stderr `hub corrupt`. Substrate wraps as `WRAPPER ERROR: hub corrupt` and exits non-zero.

Refine implementation as needed.

### Step 4 — Manifest registration + drift-guard

- Add `# @manifest` block above `cmd_provider_heal_preflight` declaring purpose/input/output/depends-on/side-effect=read-only/failure-mode (uninitialized-node, wrapper-error, drift-detected)/contract (idempotent, read-only).
- Add `.ccanvil/scripts/docs-check.sh:cmd_provider_heal_preflight` to `.ccanvil/manifest-allowlist.txt`.
- Run `bash .ccanvil/scripts/module-manifest.sh validate --json` — confirm 191/191 coverage drift 0.

### Step 5 — Full bats suite verification

Run `bash .ccanvil/scripts/bats-report.sh --parallel`. Confirm 2000+ tests pass with the new test count added.

### Step 6 — Commit + ship

- Stage modified files. Commit on `claude/feat/bts-320-provider-heal-preflight`.
- Push. `/pr --skip-review`. `/ship 164`.

## Constraints

- No changes to `ccanvil-sync.sh` — Phase 2 only consumes existing pull-plan subcommand.
- Read-only — no state mutation beyond stdout/stderr writes.
- Composes with BTS-319 (provider-resolve-ids) into the future provider-heal umbrella.

## Risks

- pull-plan output shape stability — test fixtures use stubs; live pull-plan output structure verified in plan exploration (array of `{file, action, ...}` objects). Mitigation: stub matches observed shape from session 25 unifi-toolbox dogfood.
- No live-API gate needed (BTS-171) — the wrapper is a local shell script, not a network endpoint. Stubs capture the contract fully.
