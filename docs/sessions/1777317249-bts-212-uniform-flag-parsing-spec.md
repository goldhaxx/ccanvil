# Feature: Uniform flag parsing across `docs-check.sh` subcommands

> Feature: bts-212-uniform-flag-parsing
> Work: linear:BTS-212
> Created: 1777315706
> Status: In Progress

## Summary

`.ccanvil/scripts/docs-check.sh` exposes 49 subcommands, but their argument-handling is inconsistent. Some declare a `--project-dir <path>` flag (e.g. `cmd_session_info`, `cmd_artifact_read`); some accept it via positional arg only (e.g. `cmd_radar_gather` reads `$1`); some silently swallow unknown flags via `*) shift ;;`. The first two patterns interact badly: when a skill mechanically passes `--project-dir .` (the documented pattern in `recall`, `stasis`, `idea` skills) to a positional-only subcommand, the flag string is taken as the positional, then `dirname --project-dir` aborts with `dirname: illegal option -- -`. The error is cryptic — it surfaces from a tool the caller never invoked, not from the substrate that owns the contract.

This feature makes flag parsing uniform across the project-tree-aware subcommand family: every such subcommand accepts `--project-dir <path>` via an explicit arg loop, and every such arg loop emits a clean `usage` + exit 2 on unknown flags. A drift-guard bats test enumerates the canonicalized set and locks the contract in.

Closes BTS-218 (radar-gather specific manifestation) as a side effect of the canonicalization.

## Job To Be Done

**When** I'm authoring or refactoring a skill that calls a `docs-check.sh` subcommand,
**I want to** mechanically pass `--project-dir <path>` to any project-tree-aware subcommand without per-subcommand guesswork, and get a clean substrate-level error for typos,
**So that** skill prose stays uniform across primitives and substrate failures surface from the substrate, not from `dirname` / `jq` / etc.

## Acceptance Criteria

Each criterion is independently testable. Binary pass/fail.

- [ ] **AC-1:** `bash .ccanvil/scripts/docs-check.sh radar-gather --project-dir <fixture>` succeeds (exit 0) and emits the same JSON shape as the bare `radar-gather` invocation against the same project. (Closes BTS-218.)
- [ ] **AC-2:** Every project-tree-aware subcommand (defined in AC-5) accepts `--project-dir <path>` and resolves it to the same effective project root that the legacy positional-arg form resolved to (when applicable). Backwards-compatible: existing positional-arg call sites continue to work unchanged.
- [ ] **AC-3:** Every project-tree-aware subcommand emits a clean usage error and exits 2 when given an unknown flag. Reproducer: `bash .ccanvil/scripts/docs-check.sh <subcommand> --bogus-flag-xyz` produces stderr matching `^Usage:` (case-sensitive) and exit code is exactly 2 — no `dirname:` / `jq:` / other downstream-tool error message in stderr.
- [ ] **AC-4:** A new bats test in `hub/tests/docs-check-flags.bats` enumerates the project-tree-aware subcommand set and asserts (a) `--project-dir <fixture>` succeeds OR returns a clean usage error if the subcommand requires additional positional args, (b) `--bogus-flag-xyz` emits `^Usage:` to stderr and exits 2. The test fails if a new project-tree-aware subcommand is added without inheriting the contract.
- [ ] **AC-5:** The "project-tree-aware" subcommand set is enumerated explicitly in a single source-of-truth: a constant array near the top of `docs-check.sh` (e.g. `PROJECT_TREE_SUBCOMMANDS=(status validate ...)`) consumed by the drift-guard bats test via parsing. Pure-utility subcommands (e.g. `extract-work`, `title-from-body`, `idea-template-body`, `idea-pending-validate`, `auto-close-emit`, `auto-transition-emit`, `derive-pr-title`, `config-get`) are explicitly excluded and the test does not assert flag-handling on them.
- [ ] **AC-6:** Full bats suite remains green: `bash .ccanvil/scripts/bats-report.sh --parallel` reports `PASS: <count>, FAIL: 0, TOTAL: <count>` with `<count>` ≥ 1712 (current baseline).

## Affected Files

| File | Change |
| -- | -- |
| `.ccanvil/scripts/docs-check.sh` | Add arg-loops + `--project-dir` support + strict unknown-flag handling to \~30 project-tree-aware `cmd_*` functions. Add `PROJECT_TREE_SUBCOMMANDS` source-of-truth constant. |
| `hub/tests/docs-check-flags.bats` | New bats file with the drift-guard contract test (AC-4). |
| `hub/tests/fixtures/` | Reuse existing fixtures where possible; add a minimal project-tree fixture if no existing one is suitable. |

## Dependencies

* **Requires:** None — purely substrate-internal refactor.
* **Blocked by:** None.

## Out of Scope

* Migrating to a real CLI parsing library (getopts, argparse-bash, etc.). Each subcommand keeps its own local arg loop; only the unknown-flag handling and `--project-dir` inclusion are uniform.
* Refactoring subcommand structure / consolidating overlapping verbs.
* Per-subcommand help-text completeness — `Usage: <subcommand> ...` is sufficient for AC-3.
* Adding `--project-dir` to pure-utility subcommands (those that operate on stdin/stdout only). Explicitly excluded per AC-5.
* Skill prose updates to standardize `--project-dir .` usage across all skill files. (Skills already pass it where supported; this spec makes it work everywhere it should work, but doesn't rewrite skill prose.)

## Implementation Notes

* **Pattern to follow** for the arg loop: same shape as `cmd_session_info` (line \~257 of `docs-check.sh`), but replace the silent `*) shift ;;` with `*) echo "Usage: docs-check.sh <subcommand-name> [--project-dir <path>] [<positional>...]" >&2; exit 2 ;;`.
* **Backwards compat** is critical. Many existing call sites invoke `cmd_radar_gather "$DEFAULT_DOCS_DIR"` or `cmd_idea_count "$project_dir"` positionally. The arg loop must accept positional args after consuming flags — keep `local docs_dir="${1:-$DEFAULT_DOCS_DIR}"` semantics where they exist; the flag-parsing loop precedes them and skips on the first non-flag token.
* `PROJECT_TREE_SUBCOMMANDS` array is the single source of truth. Define it once near the top of the script (or in a dedicated section). The drift-guard bats test reads the array via `awk` (same pattern as the BTS-217 `_normalize_feature_to_ticket` test) and iterates it.
* **No new helper function** for arg parsing — the LOC overhead per cmd is small (\~5 lines), and a generic helper would have to handle every positional shape across 30+ cmds. Keep parsing local; standardize only the unknown-flag handling and the `--project-dir` token.
* **Test isolation**: the drift-guard test must run in `$BATS_TEST_TMPDIR` (lesson from BTS-217's stasis-recall.bats fix) so it doesn't depend on hub routing config.
* **Bash 3.2 portability** required (macOS `/bin/bash`). No `${var^^}`, no associative arrays in the source-of-truth constant. Use a plain bash array.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
