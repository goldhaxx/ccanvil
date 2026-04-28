# Plan: canonical hook failure recording

> Feature: bts-209-hook-failure-recording
> Created: 1777343134
> Spec hash: 1d8142e5

## Strategy

1. New helper `.claude/hooks/_lib/record-failure.sh` — sourceable function `_hook_record_failure <hook> <step> <message>` that appends one JSONL line to `.ccanvil/state/hook-failures.log`.
2. `post-compact-marker.sh` migrates from set-euo-pipefail to canonical pattern (per-step guards, helper sourced).
3. `session-boundary.sh` adds `_hook_record_failure` calls on every WARN path.
4. Bats: AC-1 helper shape, AC-2 hook exits 0 on success, AC-6 hook exits 0 on failure (state dir read-only), AC-3 session-boundary records non-integer counter, drift refs in all three files.

## TDD: RED → GREEN

- RED: 6/8 fail (helper missing, post-compact set-e propagates, drift refs missing).
- GREEN: implement helper + migrate hooks.
- Suite: 1858 → 1866.

## Files

- `.claude/hooks/_lib/record-failure.sh` (new)
- `.claude/hooks/post-compact-marker.sh` (migrated)
- `.claude/hooks/session-boundary.sh` (record-failure calls added)
- `hub/tests/hook-failure-recording.bats` (8 tests)

## Risks

- Helper failures (jq missing, log write fails) are silently swallowed at the helper level — best-effort. Caller already emitted to stderr (loud), so the failure isn't invisible. Acceptable trade.
- Source path uses `$CLAUDE_PROJECT_DIR` resolution. If unset (rare, pre-init), falls back to `pwd`. No-op fallback function ensures the hook still runs even if helper is missing.
