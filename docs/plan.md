# Implementation Plan: provider-heal umbrella verb

> Feature: bts-326-provider-heal-umbrella
> Work: linear:BTS-326
> Created: 1778175400
> Spec hash: dd0f2ed4
> Based on: docs/spec.md

## Objective

Add `cmd_provider_heal` to docs-check.sh that fail-fast composes `cmd_provider_heal_auth` → `cmd_provider_heal_preflight` → `cmd_provider_resolve_ids`. Sibling-function dispatch (in-process). Bats coverage uses BOTH `LINEAR_QUERY_OVERRIDE` (Phase 3 + Phase 1's linear-query calls) and `CCANVIL_SYNC_OVERRIDE` (Phase 2's ccanvil-sync call) simultaneously. Manifest registered.

## Steps

### Step 1 — Red: bats fixtures + happy-path test

Create `hub/tests/provider-heal-umbrella.bats`:

- Setup: `mktemp -d`, project_dir, `FAKE_HOME`, fresh `.claude/ccanvil.local.json` with `routing.idea=linear` + `providers.linear.{team,project}` strings only (the unifi-toolbox-shape).
- `write_lq_stub()` — handles `viewer` (returns `{id:"VIEWER-1"}`), `list-teams`/`list-projects`/`list-states`/`list-labels` (returns canonical fixtures, mirror of bts-321 + bts-319 stubs).
- `write_sync_stub()` — handles `pull-plan` returning `[]` by default (clean drift). Logs every call to `$CALLS_LOG` so AC-6 can verify pull-auto/pull-apply never invoked.
- AC-1 test: all stubs at defaults, run `provider-heal`, exit 0, stdout contains `PROVIDER-HEAL-OK: auth=VIEWER-1 drift=clean ids=resolved`.

Run: `bats hub/tests/provider-heal-umbrella.bats`. Confirm test FAILS (subcommand not implemented).

### Step 2 — Green: implement `cmd_provider_heal`

Add to docs-check.sh:

- Mirror arg parsing of `cmd_provider_resolve_ids`: `--provider linear`, `--team`, `--project`, `--project-dir`, plus new `--json`.
- Invoke phases in order with stdout/stderr forwarding:

```bash
# Phase 3
auth_json=""
if (( json_out )); then
  auth_json=$(cmd_provider_heal_auth --project-dir "$project_dir" --json) || phase3_failed=1
else
  cmd_provider_heal_auth --project-dir "$project_dir" || phase3_failed=1
fi
[[ $phase3_failed ]] && _emit_envelope "auth-failed" "$auth_json" null null && return 1

# Phase 2
# similar
# Phase 1
# similar
```

Actually safer: use sub-shell isolation per phase to capture stdout into JSON on `--json` path; pass through to terminal on text path via `tee`-equivalent or direct call.

Simplest stable path: always invoke each phase function directly (text mode), capture exit. On `--json`, do a SECOND invocation per phase with `--json` and capture stdout. The second invocation is idempotent; cost is negligible (each phase is local script work + one stubbed network call). Cleaner than dual-mode capture.

Register subcommand dispatch + add `provider-heal` to `PROJECT_TREE_SUBCOMMANDS`.

### Step 3 — Green: ACs 2, 3, 4, 5, 6

Add bats tests:
- AC-2: stub auth with no key (unset LINEAR_API_KEY + no .env files) → exit non-zero, stderr contains "LINEAR_API_KEY not found", and `$CALLS_LOG` shows pull-plan was NEVER called.
- AC-3: auth ok, drift stub returns non-empty plan → exit non-zero, stderr contains "DRIFT DETECTED", resolve-ids was NOT called (verify by absence of list-teams in lq calls log).
- AC-4: auth + drift ok, but `STUB_TEAMS_JSON='[]'` so resolve-ids halts on missing team → exit non-zero with that error.
- AC-5: --json envelope shape on each path. Phase that didn't run is `null`.
- AC-6: drift detected → assert pull-auto/pull-apply NEVER called via `$CALLS_LOG`.

### Step 4 — Manifest + drift-guard

Add `# @manifest` block + body markers (`# @side-effect: writes-ccanvil-local-json-on-success-only`). Register in allowlist. Validate 193/193 drift 0.

### Step 5 — Full bats suite verification

`bash .ccanvil/scripts/bats-report.sh --parallel`. Confirm 2022+ tests pass.

### Step 6 — Commit + ship

- Stage modified files. Commit.
- Push. /pr --skip-review. /ship 166.

## Constraints

- No changes to BTS-319/320/321 primitives — umbrella composes them as-is.
- Sibling-function calls in-process (avoid subprocess overhead). Each phase is already its own function in docs-check.sh.

## Risks

- Capturing `--json` output from a sibling function while ALSO writing to actual stdout requires careful FD handling. Mitigation: invoke each phase twice (once text mode, once JSON mode) or use a tmpfile capture pattern.
- bats stub composition with TWO override env vars simultaneously (LINEAR_QUERY_OVERRIDE + CCANVIL_SYNC_OVERRIDE) may surface edge cases. Mitigation: reuse the proven stub patterns from bts-319/320/321 individually.
- No live-API gate (BTS-171) needed — composition is pure shell logic; stubs cover the contract.
