# Feature: Per-Test Timing Observability

> Feature: bts-137-per-test-timing-observability
> Work: linear:BTS-137
> Created: 1777068865
> Status: In Progress

## Summary

BTS-118 shipped parallel bats and cut wall-time 76% — broad-brush. Next-layer optimization (fixture consolidation, rewriting slow tests) needs per-test timing to prioritize. Extend `bats-report.sh` with `--timings` (emit sorted per-test timing table) and `--slow-top N` (show N slowest) flags. bats-core's `-T/--timing` flag emits `ok N <name> in Nms` — parse and aggregate. JSON mode gains a `timings: [{test, ms}]` array.

## Acceptance Criteria

- [ ] **AC-1:** `bats-report.sh --timings` runs the suite with `bats -T`, parses per-test timings from the output, and emits a sorted table (slowest first) with columns: `ms | test name`. Default existing output (tail + PASS/FAIL/TOTAL) is preserved before the table.
- [ ] **AC-2:** `bats-report.sh --slow-top N` runs with `-T`, emits only the N slowest tests (N = positive integer). Rest of output unchanged.
- [ ] **AC-3:** `bats-report.sh --slow-top 0` emits zero timing rows but exits 0. `--slow-top <non-integer>` exits 2 with ERROR.
- [ ] **AC-4:** `bats-report.sh --json --timings` includes `timings: [{test: "<name>", ms: <int>}]` in JSON output, sorted slowest-first. Backward compat: JSON without `--timings` omits the `timings` key (or emits empty array).
- [ ] **AC-5:** `--timings` combines with `--parallel`. Parallel mode passes `-T` through too.
- [ ] **AC-6:** When a test fails (bats emits `not ok N <name> in Nms`), timing is still captured for that failing test.
- [ ] **AC-7:** 5+ new bats cases exercising flags + edge cases (empty output, malformed `-T` lines gracefully skipped, top-0, top-all).
- [ ] **AC-8:** `.ccanvil/guide/command-reference.md` + `.claude/rules/tdd.md` (Running the suite section) document the new flags.

## Affected Files

| File | Change |
|------|--------|
| `.ccanvil/scripts/bats-report.sh` | Modified — add --timings, --slow-top flags + parsing |
| `hub/tests/bats-report.bats` | Modified — 5+ new cases |
| `.ccanvil/guide/command-reference.md` | Modified — flag docs |
| `.claude/rules/tdd.md` | Modified — Running the suite section updated |

## Out of Scope

- Durable history (`.ccanvil/state/bats-timings.jsonl`) — can be a follow-up.
- /stasis integration auto-surfacing "Slowest tests" — follow-up.
- Per-file timing aggregation — follow-up.

## Implementation Notes

- bats emits `ok N <test name> in <ms>ms` (and `not ok N ... in <ms>ms`) when `-T` is passed.
- Parse: `grep -E '^(ok|not ok) [0-9]+ .* in [0-9]+ms$' | sed -E 's/^(ok|not ok) [0-9]+ (.+) in ([0-9]+)ms$/\3\t\2/'` → tab-separated `ms<TAB>name`, then `sort -rn`.
- For JSON: same parse, then `jq -Rn` to build array.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
