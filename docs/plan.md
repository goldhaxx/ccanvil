# Implementation Plan: provider-heal-auth (Phase 3)

> Feature: bts-321-provider-heal-auth
> Work: linear:BTS-321
> Created: 1778170400
> Spec hash: 247bbbe1
> Based on: docs/spec.md

## Objective

Add `cmd_provider_heal_auth` to `.ccanvil/scripts/docs-check.sh`. Read-only substrate that sources the standard `.env` chain (shell env → `<project>/.env` → `~/.env`), checks `LINEAR_API_KEY` presence, and runs `linear-query.sh viewer` as a live smoke-test. Same shape as BTS-320 (`cmd_provider_heal_preflight`).

## Steps

### Step 1 — Red: bats fixtures + first failing test

Create `hub/tests/provider-heal-auth.bats`:

- Setup: `mktemp -d` for `TMPDIR_BATS`, create `<tmp>/proj` directory + `<tmp>/fake-home` for HOME isolation. Unset `LINEAR_API_KEY` per-test. Override `HOME=$TMPDIR_BATS/fake-home` so `~/.env` lookup is sandboxed.
- `write_viewer_stub()` helper writing `<tmp>/lq-stub.sh` that branches on subcommand. `viewer` returns `{"id":"STUB-VIEWER-1","name":"Stub User"}` by default; behavior parameterized by `STUB_VIEWER_EXIT` and `STUB_VIEWER_JSON` env vars.
- AC-1 test: shell env has key + viewer succeeds → exit 0, stdout contains `AUTH-OK: viewer=STUB-VIEWER-1`.

Run: `bats hub/tests/provider-heal-auth.bats`. Confirm test FAILS (subcommand not implemented).

### Step 2 — Green: implement `cmd_provider_heal_auth`

Add to docs-check.sh:

- Mirror `cmd_provider_heal_preflight` arg parsing (`--project-dir`, `--json`).
- Source-chain logic:
  ```bash
  local key_source=""
  if [[ -n "$LINEAR_API_KEY" ]]; then
    key_source="shell-env"
  elif [[ -f "$project_dir/.env" ]]; then
    set -a; source "$project_dir/.env" 2>/dev/null; set +a
    [[ -n "$LINEAR_API_KEY" ]] && key_source="$project_dir/.env"
  fi
  if [[ -z "$LINEAR_API_KEY" ]] && [[ -f "$HOME/.env" ]]; then
    set -a; source "$HOME/.env" 2>/dev/null; set +a
    [[ -n "$LINEAR_API_KEY" ]] && key_source="$HOME/.env"
  fi
  ```
- Missing key → exit 1 with AC-3 error message (or JSON envelope when --json).
- Run viewer via `${LINEAR_QUERY_OVERRIDE:-$script_dir/linear-query.sh} viewer`. Capture stdout + stderr + exit.
- Viewer non-zero or empty `.id` → exit 1 with AC-4 error.
- Success → emit AUTH-OK or JSON envelope.

Register subcommand dispatch + add to `PROJECT_TREE_SUBCOMMANDS`.

### Step 3 — Green: ACs 2, 3, 4, 5, 6

Add bats tests:
- AC-2: project `.env` has key, shell env empty → exit 0, key_source="<project>/.env" in JSON.
- AC-3: key missing everywhere → exit non-zero, stderr names all three sources.
- AC-4: key present but stub returns `{}` (no `.id`) or exits 1 → exit non-zero, stderr has invalid-key error + WRAPPER ERROR.
- AC-5: --json shape on success and each error case (status: ok|missing-key|invalid-key|wrapper-error).
- AC-6: env isolation — bats `setup()` unsets LINEAR_API_KEY explicitly; assert it's still unset after substrate runs (since substrate runs in subprocess, this is automatic; test verifies expectation).

### Step 4 — Manifest + drift-guard

Add `# @manifest` block + `# @side-effect: read-only` body marker. Register in allowlist. Validate 192/192 drift 0.

### Step 5 — Full bats suite verification

Run `bash .ccanvil/scripts/bats-report.sh --parallel`. Confirm 2013+ tests pass.

### Step 6 — Commit + ship

- Stage modified files.
- Commit on `claude/feat/bts-321-provider-heal-auth`.
- Push (PR creation deferred to /pr — currently network-flaky on gh-cli).
- `/pr --skip-review`.
- `/ship <PR>` once draft PR is created.

## Constraints

- Read-only by contract — must NOT mutate `.env` files or write secrets anywhere.
- Composes with BTS-319 (Phase 1) + BTS-320 (Phase 2) into the future provider-heal umbrella.

## Risks

- `set -a; source <file>` can fail on malformed `.env` (e.g., spaces around `=`). Mitigation: `2>/dev/null` swallows source errors; missing key after source is treated as "not found" rather than fatal-source-error.
- Viewer endpoint failures could be transient (network blip, not a key issue). Mitigation: substrate reports the failure verbatim via WRAPPER ERROR; operator decides whether to retry vs treat as actual auth failure.
- No live-API gate needed (BTS-171) — viewer is a standard subcommand with a stable contract; stubs capture the shape fully.
