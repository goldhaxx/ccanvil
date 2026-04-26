# Feature: drift-watchdog-launchd-install wrapper

> Feature: bts-199-launchd-install-wrapper
> Work: linear:BTS-199
> Created: 1777237334
> Status: Complete

## Summary

Wrap the launchd plist install/reload/verify recipe into a single idempotent `ccanvil-sync.sh drift-watchdog-launchd-install [--reload]` subcommand. Today the four-step sequence (generate plist → lint → optional unload → cp → load → verify) is documented as operator prose and was reformulated by hand four times during BTS-21 activation (PATH hot-fix, model+budget hot-fix, labels-syntax hot-fix, plus the initial install). Captures the launchd activation flow as substrate so future scheduled-agent shapes inherit the pattern.

## Job To Be Done

**When** I'm installing or reinstalling the drift-watchdog launchd entry,
**I want** one atomic command that handles plist generation, lint, optional unload, copy, load, and verify,
**So that** I don't reformulate a multi-step recipe every iteration and never end up with half-applied state.

## Acceptance Criteria

- [ ] **AC-1:** New subcommand `cmd_drift_watchdog_launchd_install` exists in `.ccanvil/scripts/ccanvil-sync.sh` and is wired into the dispatcher as `drift-watchdog-launchd-install`. Drift-guard greps the dispatcher.
- [ ] **AC-2:** Without `--reload`: subcommand generates plist via `cmd_drift_watchdog_launchd_print`, lints with `plutil -lint` (skip if `plutil` missing — emit `WARN: plutil not available, skipping lint` and continue), copies to `~/Library/LaunchAgents/com.ccanvil.drift-watchdog.plist`, runs `launchctl load -w <plist-path>`, verifies via `launchctl print "gui/$(id -u)/com.ccanvil.drift-watchdog"`, and emits JSON `{installed: true, reloaded: false, plist_path: "...", verified: true}` on success.
- [ ] **AC-3:** With `--reload`: subcommand runs `launchctl unload <plist-path> 2>/dev/null || true` (tolerates not-yet-loaded), then proceeds with copy + load + verify as in AC-2. Emits `{installed: true, reloaded: true, plist_path: "...", verified: true}`.
- [ ] **AC-4:** Idempotency: re-running the subcommand twice in succession (without `--reload`) does NOT corrupt state — the second `load -w` returns non-zero from launchctl on duplicate, but the verify step still passes (entry is loaded). The subcommand treats verify-loaded as authoritative; load-step exit code is captured but ignored when verify succeeds. Drift-guard test simulates this via stub `launchctl`.
- [ ] **AC-5:** When verify fails (`launchctl print` exits non-zero or stdout doesn't show `state = ...`), subcommand emits `{installed: true, reloaded: <bool>, plist_path: "...", verified: false, error: "<message>"}` on stderr and exits non-zero (3).
- [ ] **AC-6:** Plist generation failure (e.g., `cmd_drift_watchdog_launchd_print` exits non-zero or emits empty stdout) exits non-zero (2) with `error: "plist-generation-failed"` — never proceeds to launchctl operations.
- [ ] **AC-7:** Edge: `plutil -lint` failure (malformed plist) exits non-zero (2) with `error: "plist-lint-failed"`. Mitigates copying broken plist into `~/Library/LaunchAgents/`.
- [ ] **AC-8:** Workspace fence: writes to `~/Library/LaunchAgents/` are outside the workspace. Subcommand documents and includes the `ALLOW_OUTSIDE_WORKSPACE=1` semantic in its caller-prose so the operator knows to invoke it accordingly. Drift-guard greps the function body for the bypass mention.
- [ ] **AC-9:** Drift-watchdog skill body (`.claude/skills/drift-watchdog/SKILL.md`) is updated to reference the new one-liner instead of the multi-step recipe in any "operator workflow" section. Drift-guard asserts SKILL.md mentions `drift-watchdog-launchd-install`.
- [ ] **AC-10:** Test file `hub/tests/drift-watchdog-launchd-install.bats` covers AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-7 using a stubbed `launchctl` and `plutil` so tests don't touch the real macOS launchd. Tests use a `BIN_OVERRIDE` env var convention to inject stubs into `PATH`.

## Affected Files

| File | Change |
|------|--------|
| `.ccanvil/scripts/ccanvil-sync.sh` | New `cmd_drift_watchdog_launchd_install` + dispatcher entry |
| `.claude/skills/drift-watchdog/SKILL.md` | Reference one-liner; remove multi-step recipe duplication |
| `hub/tests/drift-watchdog-launchd-install.bats` | New |
| `hub/tests/drift-watchdog-skill.bats` | Add drift-guard for one-liner reference (AC-9) |

## Dependencies

- **Requires:** `cmd_drift_watchdog_launchd_print` (existing — generates plist with EnvironmentVariables.PATH).
- **Blocked by:** None.

## Out of Scope

- Generic launchd-install wrapper for arbitrary plists. This is drift-watchdog-specific; future scheduled-agent shapes can clone the pattern into their own subcommand.
- `launchctl kickstart -k` (manual fire) — separate concern; not part of install. Operator runs that directly when they want to test a fire.
- `--uninstall` flow. Out of scope — operator manually runs `launchctl unload && rm` if they want to remove the agent.
- Linux/systemd equivalent. macOS launchd only.
- Re-running plutil lint after copy (lint-only operates on the source plist; post-copy lint is redundant).

## Implementation Notes

- The plist path is constant: `~/Library/LaunchAgents/com.ccanvil.drift-watchdog.plist`. Hardcoded, not parametrized — drift-watchdog-specific subcommand.
- Stub pattern: tests prepend a `BIN_OVERRIDE=$BATS_TEST_TMPDIR/bin` to `PATH` and create stub scripts that emit canned stdout + exit codes. Pattern matches `idea-pending-replay.bats` (BTS-179) which does similar substrate-stubbing.
- The `verify` step parses `launchctl print` output for `state = ` (substring match) to confirm the entry is loaded. Don't assert state value (could be `running`, `waiting`, `not running` — all "loaded" semantics).
- BTS-21 captured the canonical 4-step recipe in operator prose. This spec consolidates it; that prose can be replaced with the one-liner reference once the substrate exists.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
