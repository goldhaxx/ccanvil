# Plan: cmd_session_info jq-fork reduction

> Feature: bts-207-cmd-session-info-jq-fork-reduction
> Created: 1777341806
> Spec hash: 1d8142e5

## Strategy

Replace 5-fork pattern (jq -e validity + 3 field reads + jq -n assembly) with single-fork pattern using `--rawfile` + `try/fromjson` for valid AND corrupt cases. Missing-file case needs its own jq -n fork (no file to read). Result: ≤1 jq fork in all 3 boundary states (valid, corrupt, missing).

## TDD

1. RED: write fork-counter test that wraps jq via PATH-shadow, asserts ≤1 fork in 3 boundary states.
2. GREEN: rewrite `cmd_session_info` boundary-read with `--rawfile` + `try/catch`.
3. Suite: 1842 → 1847 (+5 new tests).

## Files

- `.ccanvil/scripts/docs-check.sh` — `cmd_session_info` boundary-read collapse.
- `hub/tests/session-info-jq-forks.bats` — 5 new tests with PATH-shadow counted-jq.

## Risks

- `--rawfile` requires the file to exist. Mitigation: explicit `[[ -f ]]` check before the jq call.
- `try/catch` syntax requires jq ≥1.6 (we use 1.7+). Pre-1.6 environments unsupported, same as elsewhere in the substrate.
