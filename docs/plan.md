# Plan: operations.sh exec dispatches http-mechanism commands

> Feature: bts-211-operations-exec-http-dispatch
> Created: 1777342155
> Spec hash: 1d8142e5

## Strategy

Replace `cmd_exec`'s bash-only `if/else` with a `case` matching `bash|http) eval` and `*) echo envelope`. Test via stubbed linear-query.sh in a project_dir + cwd-relative resolution.

## TDD

1. RED: 4 tests — AC-3 bash regression, AC-2 http main, AC-4 mcp regression (source-grep), drift.
2. GREEN: 5-line case-branch swap.
3. AC-5 live-API: `operations.sh exec backlog.list | jq -r '.[].id'` prints BTS keys.
4. Suite: 1847 → 1851.

## Files

- `.ccanvil/scripts/operations.sh` — `cmd_exec` case/branch.
- `hub/tests/operations-exec-http.bats` — 4 tests.

## Risks

- mcp branch correctness preserved by `*) echo` — tests source-grep the script for the echo line.
- AC-3 bash test exits 1 due to a pre-existing pipefail issue in cmd_idea_count_local on empty logs. Test asserts on output shape only (not exit code). Documented inline; not in scope.
