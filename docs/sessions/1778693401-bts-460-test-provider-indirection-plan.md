# Implementation Plan: Test-provider indirection: /pr dispatcher reads node config

> Feature: bts-460-test-provider-indirection
> Work: linear:BTS-460
> Created: 1778688000
> Spec hash: 3992af0f
> Based on: docs/spec.md

## Objective

Introduce `cmd_test_suite_run` in `docs-check.sh` that reads node-local config (`test-provider` with `stacks[0]` fallback, default `bats`) and dispatches to the right test runner; migrate `/pr` skill Step 2 to invoke the dispatcher; document the "describe behavior, not tooling" pattern in `.ccanvil/guide/configuration.md`.

## Sequence

Each step is one TDD red-green-refactor cycle. Slices ordered smallest-error-path first; later steps build on the seam established by earlier ones.

### Step 1: AC-3 error path — unimplemented provider

* **Test:** Add `hub/tests/test-suite-run.bats` with one @test asserting `docs-check.sh test-suite-run --project-dir <tmpdir>` exits 2 and stderr matches `ERROR: test-provider 'pytest' dispatcher not yet implemented` when `<tmpdir>/.claude/ccanvil.json` contains `{"test-provider":"pytest"}`. Run — should fail with "unknown verb" (cmd doesn't exist yet).
* **Implement:** Add `cmd_test_suite_run` function skeleton with `--project-dir` flag parsing + jq read of `.["test-provider"] // .stacks[0] // "bats"` from `.claude/ccanvil.json` + case statement: `bats` branch is `echo "TODO" >&2; exit 1` placeholder; default branch is `echo "ERROR: test-provider '$p' dispatcher not yet implemented — see BTS-460-followup" >&2; exit 2` with inline `# @failure-mode: unimplemented-provider` marker. Add `test-suite-run` to `PROJECT_TREE_SUBCOMMANDS` and to the main case-statement dispatch (alongside `lifecycle-state`).
* **Files:** `hub/tests/test-suite-run.bats` (new), `.ccanvil/scripts/docs-check.sh` (new function + dispatch line + array entry).
* **Verify:** Run `bats hub/tests/test-suite-run.bats` — single test passes.

### Step 2: AC-1 config resolution paths

* **Test:** Extend `test-suite-run.bats` with three more @tests:
  1. Missing `.claude/ccanvil.json` (or no `test-provider`/`stacks` keys) → resolver defaults to `bats`; assert behavior via the override (set in step 3, but for now assert stderr distinguishes from unimplemented-provider error — bats path returns `TODO` placeholder exit 1, not exit 2).
  2. `{"stacks":["bats"]}` without `test-provider` → resolves to bats.
  3. `--project-dir` flag points the resolver at the supplied path; default `.` if omitted; unknown flag exits 2 with stderr Usage.
* **Implement:** Refine the resolver: `local provider; provider=$(jq -r '.["test-provider"] // .stacks[0] // "bats"' "$config" 2>/dev/null || echo bats)`. Handle missing config file gracefully (default `bats`). Add unknown-flag failure-mode marker.
* **Files:** `hub/tests/test-suite-run.bats`, `.ccanvil/scripts/docs-check.sh`.
* **Verify:** All 4 @tests pass.

### Step 3: AC-2 + AC-7 bats provider dispatch (the actual work)

* **Test:** Replace the step-1 placeholder bats branch with: stub `BATS_REPORT_OVERRIDE=/tmp/stub.sh` where stub echoes its argv and exits 0; assert dispatcher's stdout matches `--parallel --progress` followed by any positional args; assert exit 0; assert positional `--json` is forwarded.
* **Implement:** Replace placeholder with: `local runner="${BATS_REPORT_OVERRIDE:-$script_dir/bats-report.sh}"; exec bash "$runner" "$@"` (after stripping `--project-dir <p>`). The dispatcher MUST forward all remaining args verbatim. Test verifies single-process exec (no extra wrappers).
* **Files:** `hub/tests/test-suite-run.bats`, `.ccanvil/scripts/docs-check.sh`.
* **Verify:** All @tests pass; total 5–6 @tests covering AC-1/2/3/7/8.

### Step 4: AC-6 module manifest

* **Test:** Run `bash .ccanvil/scripts/module-manifest.sh validate --json` — assert exit 0 and zero drift entries that name `cmd_test_suite_run`.
* **Implement:** Add `# @manifest` block above `cmd_test_suite_run` with: `id: cmd_test_suite_run`; `purpose:` (one-line); `input: --project-dir <path>; positional args forwarded to runner; env BATS_REPORT_OVERRIDE (test-injection)`; `output: stdout: runner's stdout; stderr: runner's stderr; exit: runner's exit (bats path) or 2 (unimplemented)`; `caller: skill:/pr` (verify reachable from `.claude/commands/pr.md` after step 5); `depends-on: jq`; `depends-on: bats-report.sh`; `side-effect: spawns-test-runner`; `failure-mode: unimplemented-provider | exit=2 | visible=stderr-error`; `failure-mode: unknown-flag | exit=2 | visible=stderr-Usage`; `contract: provider-resolution-order-test-provider-then-stacks0-then-bats`; `anchor: BTS-460`. Add `.ccanvil/scripts/docs-check.sh:cmd_test_suite_run` to `.ccanvil/manifest-allowlist.txt`.
* **Files:** `.ccanvil/scripts/docs-check.sh` (manifest block + inline markers at die-sites), `.ccanvil/manifest-allowlist.txt`.
* **Verify:** `module-manifest.sh validate` exits 0; coverage increments 194 → 195.

### Step 5: AC-4 skill migration

* **Test:** `grep -F 'docs-check.sh test-suite-run' .claude/commands/pr.md` exits 0; `grep -F 'bash .ccanvil/scripts/bats-report.sh --parallel --progress' .claude/commands/pr.md` exits 1 (text removed); the BTS-118/BTS-383 explanatory text is preserved (grep for "single-invocation discipline" and "30s-idle heartbeat"). Add this as a bats test under `hub/tests/test-suite-run.bats` or a new doc-drift bats file.
* **Implement:** Edit `.claude/commands/pr.md` Step 2: replace the hardcoded `bats-report.sh` invocation with `bash .ccanvil/scripts/docs-check.sh test-suite-run --project-dir . --parallel --progress`. Update the leading manifest's `depends-on` if it lists `bats-report.sh`. Keep the parenthetical BTS-118 + BTS-383 explanatory text intact (point it at the dispatcher instead).
* **Files:** `.claude/commands/pr.md`.
* **Verify:** Doc-drift bats assertions pass; `module-manifest.sh validate` still exits 0 (caller of `cmd_test_suite_run` is now grep-resolvable from pr.md).

### Step 6: AC-5 configuration guide

* **Test:** `grep -F 'Hub describes behavior, node describes implementation' .ccanvil/guide/configuration.md` exits 0; section content mentions `test-provider`, `test-suite-run`, and the followup inventory (`tdd.md`, `pr.md`, `stasis/SKILL.md`). Add as bats assertions.
* **Implement:** Append a new section to `.ccanvil/guide/configuration.md` (between the existing `stacks:` section and `<!-- NODE-SPECIFIC-START -->`). Content: pattern statement, worked example showing rule→config→dispatcher chain, inventory of remaining leak sites as captured follow-up work.
* **Files:** `.ccanvil/guide/configuration.md`.
* **Verify:** Bats assertions pass; section under \~25 lines.

### Step 7: Full-suite gate

* **Test:** `bash .ccanvil/scripts/bats-report.sh --parallel --progress` (NOT via the new dispatcher yet — direct, so we can spot any regression the new code introduced).
* **Implement:** N/A — this is the regression gate. Fix any failure before proceeding to /pr.
* **Verify:** Existing 2259 + new \~7 = \~2266 tests, all green.

### Step 8: In-session dogfood — exercise dispatcher under /pr's real path

* **Test:** Manually invoke `bash .ccanvil/scripts/docs-check.sh test-suite-run --project-dir . --parallel --progress` from CLI (no override) on the hub. Verify it produces identical output shape to the direct `bats-report.sh` invocation in step 7.
* **Implement:** N/A — pure validation.
* **Verify:** Same pass/fail counts; same timing envelope; same exit code. Confirms AC-7 regression criterion under real execution (not just stubbed bats test).

## Risks

* **Manifest scaffold-tier rule-tier-budget noise**: Adding a new manifest field set could nudge some rule-vocab-leak counts. Mitigation: the new manifest declares `bats-report.sh` as `depends-on:`, which is the allowed shape — leak-detector only fires on rule files, not script manifests. Verify after step 4.
* **Caller resolution failure under manifest validate**: If `.claude/commands/pr.md`'s edited invocation doesn't grep-match `docs-check.sh test-suite-run` (e.g., backticks or line-wrap mid-token), the manifest's `caller:` declaration fails. Mitigation: explicit literal string in pr.md; verify via `grep -F` in step 5's tests.
* **Argv forwarding subtlety**: [bats-report.sh](<http://bats-report.sh>) accepts `--parallel`, `--progress`, `--json`, `--timings`, `--slow-top N`, plus pass-through args. Mitigation: dispatcher uses `exec bash "$runner" "$@"` after stripping its own flags — no per-arg whitelisting needed.
* **Live-API gate (BTS-171)**: NOT APPLICABLE — this ship has no live-API contract. All test seams are env-var stubs (`BATS_REPORT_OVERRIDE`). No live network call to validate.

## Definition of Done

- [ ] All 8 acceptance criteria from spec pass
- [ ] All existing tests still pass (2259+ green)
- [ ] `module-manifest.sh validate` exits 0; coverage 194 → 195
- [ ] No type/lint errors
- [ ] Code reviewed (run `/review` — note: AC-4/AC-5 are pure-prose; AC-1/2/3/6/8 are code/test; per `feedback_skip_review_on_trivial_diffs`, /review is warranted because substrate logic changes)
- [ ] In-session dogfood (step 8) confirms hub-on-itself execution is identical to today

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
