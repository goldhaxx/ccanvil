# Plan: hook timing instrumentation primitive

> Feature: bts-208-hook-timing-instrumentation
> Created: 1777343476
> Spec hash: 1d8142e5

## Strategy

Build atop BTS-209's `_lib/record-failure.sh`. Add three helpers to the same file: `_timer_start` (epoch-ms with macOS fallback), `_timer_duration_ms`, `_timer_emit`. Wrap both telemetry hooks with `_t_start=$(_timer_start)` at top + `_timer_emit "hook" <name> "$(_timer_duration_ms "$_t_start")"` before exit.

Helper path resolves relative to `BASH_SOURCE[0]` (not `CLAUDE_PROJECT_DIR`) so test fixtures and weird cwds don't break sourcing.

## TDD

- RED: 8 tests; 5 fail pre-fix (helpers missing, log not written, drift refs missing).
- GREEN: helpers added, hooks wrapped, helper path uses BASH_SOURCE.
- Suite: 1866 → 1874.

## Files

- `.claude/hooks/_lib/record-failure.sh` — adds 3 timer helpers (~50 lines).
- `.claude/hooks/post-compact-marker.sh` — `_t_start` + final `_timer_emit`.
- `.claude/hooks/session-boundary.sh` — `_t_start` + final `_timer_emit`.
- `hub/tests/hook-timing-instrumentation.bats` — 8 tests.

## Risks

- macOS BSD date doesn't support `%3N`; fallback chain (python3 → seconds*1000) documented in code. Sub-second timings round to 0 on python3-less macOS but the timestamp itself is monotonic. Acceptable.
- HELPER path resolution via BASH_SOURCE depends on bash semantics for sourced-from scripts; tested in setup.
