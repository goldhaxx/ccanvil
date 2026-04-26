# Implementation Plan: drift-watchdog-launchd-install wrapper

> Feature: bts-199-launchd-install-wrapper
> Work: linear:BTS-199
> Created: 1777237400
> Spec hash: 5e074dd4
> Based on: docs/spec.md

## Objective

Wrap the four-step launchd install recipe into one idempotent `ccanvil-sync.sh drift-watchdog-launchd-install [--reload]` subcommand with stub-driven bats coverage.

## Sequence

### Step 1: Test harness with stub launchctl + plutil
- **Test:** `hub/tests/drift-watchdog-launchd-install.bats` — write tests AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-7 using `setup()` that creates `$BATS_TEST_TMPDIR/bin/{launchctl,plutil}` stubs and prepends to PATH. Stubs read env vars (`STUB_LAUNCHCTL_PRINT_OUT`, `STUB_LAUNCHCTL_LOAD_RC`, etc.) to control behavior per test.
- **Implement:** Tests will fail because `cmd_drift_watchdog_launchd_install` doesn't exist yet. RED.
- **Files:** `hub/tests/drift-watchdog-launchd-install.bats`.
- **Verify:** Tests fail with "unknown subcommand" or similar.

### Step 2: Implement cmd_drift_watchdog_launchd_install
- **Test:** Same file from Step 1.
- **Implement:** Add `cmd_drift_watchdog_launchd_install` to `.ccanvil/scripts/ccanvil-sync.sh` after `cmd_drift_watchdog_launchd_print`. Wire dispatcher entry. Function: parse `--reload` flag, generate plist via internal call, lint with `plutil` (or warn-skip), optional unload, copy to `~/Library/LaunchAgents/...`, `launchctl load -w`, verify with `launchctl print`, emit JSON. Handle each error path per AC-5/6/7.
- **Files:** `.ccanvil/scripts/ccanvil-sync.sh`.
- **Verify:** All bats cases pass.

### Step 3: Update drift-watchdog SKILL with one-liner reference
- **Test:** Add drift-guard test to `hub/tests/drift-watchdog-skill.bats` asserting SKILL.md mentions `drift-watchdog-launchd-install`.
- **Implement:** Update `.claude/skills/drift-watchdog/SKILL.md` operator-workflow section to use the one-liner.
- **Files:** `.claude/skills/drift-watchdog/SKILL.md`, `hub/tests/drift-watchdog-skill.bats`.
- **Verify:** Drift-guard passes.

### Step 4: Update command-reference.md
- **Implement:** Add `ccanvil-sync.sh drift-watchdog-launchd-install [--reload]` row to the Drift Watchdog section of `.ccanvil/guide/command-reference.md`.
- **Files:** `.ccanvil/guide/command-reference.md`.
- **Verify:** Visual review.

## Risks

- **Stub fragility.** The `launchctl` and `plutil` stubs need to be prepended to PATH BEFORE bats invokes the script. Mitigation: use `setup()` to write stubs to `$BATS_TEST_TMPDIR/bin` and `export PATH=...` in the same hook; pattern proven in similar fixtures.
- **macOS-only.** `plutil` is macOS-specific. Linux nodes don't have launchd anyway, so the subcommand is only invoked on macOS — but the WARN-skip path means the subcommand wouldn't completely fail on a Linux box if exercised (lint skipped, but copy + load would fail later — that's acceptable, not a regression).

## Definition of Done

- [ ] All 10 acceptance criteria from spec pass
- [ ] All existing tests still pass
- [ ] Code reviewed (run `/review`) — substrate code; not a trivial diff
