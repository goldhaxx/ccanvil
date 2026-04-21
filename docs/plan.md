# Implementation Plan: init-mature-project — safe retrofit for existing repos

> Feature: init-mature-project
> Created: 1776811115
> Spec hash: dd2071e2
> Based on: docs/spec.md

## Objective

Make `/ccanvil-init` safe on mature, partially-initialized, and already-initialized repositories by adding deterministic project-mode detection, mode-aware defaults, and an explicit idempotency path — so retrofit onto an established project like docint never clobbers custom rules, re-runs `git init`, or overwrites in-progress lifecycle docs.

## Sequence

Each step is one red-green-refactor cycle. Every step ends with the full bats suite green; legacy `init-preflight.bats` + `init-apply.bats` must stay green throughout (AC-19).

### Step 1: Project-mode detection in `init-preflight`

- **Test:** `hub/tests/init-mode-detection.bats` — five fixtures (fresh, source-no-git, mature-repo, partial-ccanvil, already-initialized) plus two edge cases (AC-24 bare git repo → source-no-git, AC-26 mature repo with no source files but real HEAD → mature-repo). Each asserts `project_mode` field in `init-preflight` JSON output. Verify detection is pure (runs twice, same result, no filesystem writes — AC-3).
- **Implement:** In `.ccanvil/scripts/ccanvil-sync.sh`, add a `detect_project_mode` helper called at the top of `cmd_init_preflight` before the classify loop. Emit `project_mode` as a top-level field alongside `plan` and `summary`. Detection rules per AC-2, with the AC-24 tiebreaker (`git log -1` exit 128 → `source-no-git`) and AC-26 override (`.git/` + HEAD → `mature-repo` regardless of source count).
- **Files:** `.ccanvil/scripts/ccanvil-sync.sh` (new `detect_project_mode`, modified `cmd_init_preflight`), `hub/tests/init-mode-detection.bats` (new), `hub/tests/fixtures/` extensions if needed.
- **Verify:** All 7 mode-detection cases pass. `init-preflight.bats` still green. `jq '.project_mode'` on real output returns one of the five strings.

### Step 2: Mode-aware `classify_file` defaults

- **Test:** New bats file `hub/tests/init-mature-retrofit.bats` starts here with AC-4 and AC-5 scenarios. Fixture mature-repo with: custom CLAUDE.md (no delimiters), modified README.md, custom `docs/spec.md` with non-template content, custom `.github/workflows/ci.yml`. Assert `recommended_action` per spec: CLAUDE.md → `section-merge-create-delimiters`, README.md → `skip`, docs/spec.md → `skip` with "local file has node-specific content" reason, workflow → `review`. Separate test verifies AC-5: fresh-mode fixture returns identical recommendations to the pre-change `init-preflight.bats` baseline.
- **Implement:** Thread `$project_mode` through the classify loop. Extend `classify_file` to branch on mode before assigning the default action. Add new action string `section-merge-create-delimiters` emitted when mode is mature/partial AND CLAUDE.md lacks delimiter (use `grep -qx '<!-- HUB-MANAGED-START -->'` per AC-25).
- **Files:** `.ccanvil/scripts/ccanvil-sync.sh` (modified `classify_file` signature + dispatch), `hub/tests/init-mature-retrofit.bats` (new), fixture additions under `hub/tests/fixtures/mature-repo/`.
- **Verify:** Mature-mode recommendations match spec. Fresh-mode path unchanged. `init-preflight.bats` still green.

### Step 3: `section-merge-create-delimiters` action in `init-apply`

- **Test:** Extend `init-mature-retrofit.bats`: end-to-end scenario — fixture mature CLAUDE.md with custom prose, run init-apply against a plan containing the new action, assert the resulting file contains (a) all original prose verbatim in the node section, (b) `<!-- HUB-MANAGED-START -->` on its own line, (c) hub template content below the delimiter. Second test per AC-7: re-running the same action is a no-op (delimiters already exist → falls through to standard `section-merge`). Third test per AC-25: fixture CLAUDE.md that mentions `<!-- HUB-MANAGED` inside a code block or prose line is NOT treated as having a delimiter.
- **Implement:** Add new `case` branch in `cmd_init_apply` for `section-merge-create-delimiters`. Logic: if file has exact-line delimiter already (`grep -qx`), dispatch to the existing `section-merge` path; otherwise, wrap existing content as node section above the delimiter, append hub content below. Keep awk/sed minimal — line-based awk is simpler than regex sed.
- **Files:** `.ccanvil/scripts/ccanvil-sync.sh` (extended `cmd_init_apply` action table), `hub/tests/init-mature-retrofit.bats` (extended).
- **Verify:** Delimiter insertion preserves original content byte-for-byte; idempotent re-run produces no change; prose-mentions aren't treated as delimiters.

### Step 4: `retrofit-check` subcommand

- **Test:** Extend `init-mature-retrofit.bats` with AC-15 assertions: `ccanvil-sync.sh retrofit-check <hub>` exits 0, prints a table with columns File / Hub / Local / Action / Reason, and includes the detected mode in the header. Assert stdout contains `Detected mode:` and the mode string, plus at least one action row per fixture file. Verify read-only: no files created, no lockfile modified.
- **Implement:** New `cmd_retrofit_check` in `.ccanvil/scripts/ccanvil-sync.sh` — thin wrapper that calls `cmd_init_preflight` under the hood, then formats the JSON as a human-readable table. Reuse a shared `format_preflight_table` helper (single source of truth — the init skill will call this same function for AC-14). Wire `retrofit-check` into the dispatch `case` block and the usage string.
- **Files:** `.ccanvil/scripts/ccanvil-sync.sh` (new `cmd_retrofit_check`, new `format_preflight_table` helper, updated dispatch + usage), `hub/tests/init-mature-retrofit.bats` (extended).
- **Verify:** `bash .ccanvil/scripts/ccanvil-sync.sh retrofit-check ~/projects/ccanvil` on the current ccanvil repo (partial-ccanvil / already-initialized mode) prints a clean table.

### Step 5: Rewrite `global-commands/ccanvil-init.md` skill for mode-aware flow

- **Test:** New bats file `hub/tests/ccanvil-init-skill.bats` with grep assertions (AC-23): skill file references `project_mode`, `retrofit-check`, `section-merge-create-delimiters`, conditional `git init`, `PRESERVED:`, and the three already-initialized options (update / re-register / abort). Also new bats file `hub/tests/init-idempotent.bats` with fixture containing `.ccanvil/ccanvil.lock` + `ccanvil-sync.sh` — assert preflight emits `already-initialized` and grep the skill for the update-mode branch (AC-12, AC-13, AC-18). Extend `init-mature-retrofit.bats` for AC-10 (skip non-empty docs/*.md) and AC-11 (in-progress feature detection from `> Feature:` header).
- **Implement:** Rewrite `global-commands/ccanvil-init.md` end-to-end:
  - Step 2a (new): read `project_mode` from preflight output; print "Detected mode: **<mode>**" as header.
  - Step 4 (modified): if mode is `already-initialized`, short-circuit to update/re-register/abort menu; else present preflight table (AC-14) and await approval.
  - Step 7 (modified): for each of `docs/spec.md`, `docs/plan.md`, `docs/stasis.md`, `docs/roadmap.md`: `[[ -s "$f" ]]` → log `PRESERVED: $f` and skip; else copy from template. Detect in-progress feature by grepping `> Feature:` in `docs/stasis.md` and surface in the post-init summary.
  - Step 15 (modified): git lifecycle branches on `project_mode`. `fresh` / `source-no-git` → `git init` + `chore: initialize project with ccanvil preset`. `mature-repo` / `partial-ccanvil` → skip `git init`, commit `chore(ccanvil): retrofit preset onto existing project`. `already-initialized` → no commit, no `git init` (AC-13). Pre-push hook install is conditional (AC-9): if `.git/hooks/pre-push` exists AND differs from hub's template, warn and skip.
  - Drive-by: replace remaining `checkpoint.md` reference at line 26 with `stasis.md` (legacy-refs cleanup surfaced by the stasis-recall scan).
- **Files:** `global-commands/ccanvil-init.md` (rewrite), `hub/tests/ccanvil-init-skill.bats` (new), `hub/tests/init-idempotent.bats` (new), `hub/tests/init-mature-retrofit.bats` (extended for AC-10, AC-11).
- **Verify:** All new bats files green. Existing `init-preflight.bats` + `init-apply.bats` still green. Manually sanity-check skill wording against spec's AC list.

### Step 6: Documentation updates

- **Test:** Extend `hub/tests/docs-check.bats` (or equivalent) with grep assertions: `README.md` contains "Retrofitting an existing project", `hub/meta/HOW_TO_USE.md` contains "Adding ccanvil to an existing project", `.ccanvil/guide/command-reference.md` contains a `retrofit-check` entry and a note about `/ccanvil-init` mode-awareness.
- **Implement:**
  - `README.md`: new "Retrofitting an existing project" subsection under Quick Start, explaining the mature-repo flow and pointing to `retrofit-check` for dry-run.
  - `hub/meta/HOW_TO_USE.md`: "Adding ccanvil to an existing project" subsection mirroring README coverage.
  - `.ccanvil/guide/command-reference.md`: hub section (above `<!-- NODE-SPECIFIC-START -->`) gains a `retrofit-check` row and a sentence under `/ccanvil-init` noting mode-awareness.
- **Files:** `README.md`, `hub/meta/HOW_TO_USE.md`, `.ccanvil/guide/command-reference.md`, `hub/tests/docs-check.bats` (extended).
- **Verify:** All doc grep assertions pass. Full bats suite: 601+ tests green.

## Risks

- **Fixture complexity for mature-repo detection.** Creating a deterministic "mature repo" fixture inside a bats test requires `git init` + an initial commit inside the test temp dir, which interacts with the bats harness's working-dir assumptions. Mitigation: follow the existing fixture pattern in `init-preflight.bats`; use `cd "$BATS_TEST_TMPDIR"` consistently; verify fixtures survive `bats -f <single-test>` invocation.
- **Skill rewrite scope.** Step 5 touches 6 AC groups in one file. Mitigation: write all grep assertions first (fast failing tests), then edit the skill until each passes. Each AC becomes an independently verifiable grep, so partial progress is visible.
- **AC-26 vs AC-24 ordering.** A bare `git init` repo with source files already committed is mature. A bare `git init` repo with no commits is source-no-git. The tiebreaker is `git log -1` exit code — the order of checks in `detect_project_mode` must test HEAD existence before source-file count. Mitigation: explicit comment in the function; fixture in mode-detection.bats covers both directions.
- **`section-merge-create-delimiters` on macOS.** awk/sed behavior differs across macOS BSD tools vs GNU. Mitigation: lean on bash builtins and `grep -qx` for line matching; avoid sed -i; keep the awk pass strictly line-based.
- **Backward compatibility for fresh-mode path.** Existing users re-running `/ccanvil-init` on a fresh project must see no behavioral change (AC-5, AC-19). Mitigation: `init-preflight.bats` + `init-apply.bats` run unchanged after every step; treat any regression there as a Step failure.

## Definition of Done

- [ ] All 26 acceptance criteria from spec pass (AC-1 through AC-26).
- [ ] Four new bats files green: `init-mode-detection.bats`, `init-mature-retrofit.bats`, `init-idempotent.bats`, `ccanvil-init-skill.bats`.
- [ ] All existing tests still pass (601+ total).
- [ ] `bash .ccanvil/scripts/ccanvil-sync.sh retrofit-check ~/projects/ccanvil` prints a clean table.
- [ ] Running `/ccanvil-init` on a real mature repo (docint) produces: no `git init`, CLAUDE.md delimiters inserted with original content preserved, `docs/stasis.md` preserved with in-progress-feature callout.
- [ ] Documentation gates pass: README, HOW_TO_USE, command-reference.
- [ ] Code reviewed via `code-reviewer` agent on `/pr`.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
