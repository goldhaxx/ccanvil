# Implementation Plan: diff-vs-manifest hunk function attribution

> Feature: bts-667-diff-vs-manifest-hunk-fn-attribution
> Work: linear:BTS-667
> Created: 1782530705
> Spec hash: 4e5c44db
> Based on: docs/spec.md

## Objective

Teach `diff-vs-manifest` to re-scope inline-marker attribution to a function newly defined *within* a diff hunk (both `name()` and `function` forms), eliminating xfuncname back-attribution false positives — then close the BTS-605 honest-narrow on `cmd_registry_prune_stale`.

## Anchor functions (fixtures)

Synthetic fixtures target the real, manifested `.ccanvil/scripts/module-manifest.sh`:

* **Surrounding / xfuncname** = `cmd_extract` (declares side-effect `writes-temp-file`).
* **New-def function** = `cmd_query` (declares side-effect `regenerates-index-if-stale`).
  Neither declares the bogus test markers (`writes-undeclared-marker`, dep `linear-query.sh`, exit `7`), so each test is falsifiable: RED pre-fix (marker attributed to `cmd_extract`), GREEN post-fix (attributed to `cmd_query`).

## Sequence

### Step 1: AC-1/AC-2 fixture + failing test (RED)

* **Test:** new fixture `hub/tests/fixtures/manifest/diffs/new-fn-reattribution-side-effect.diff` — hunk header context `cmd_extract() {`; added lines close cmd_extract (`+}`), blank, `+cmd_query() {`, `+  # @side-effect: writes-undeclared-marker`, `+  touch /tmp/x`. Add two bats cases: **AC-1** asserts no `new-side-effect-not-declared` entry with `id=="cmd_extract"`; **AC-2** asserts an entry with `id=="cmd_query"` and `value=="writes-undeclared-marker"`.
* **Implement:** nothing.
* **Files:** fixture (new); `hub/tests/module-manifest-diff-vs-manifest.bats` (edit).
* **Verify:** `bats hub/tests/module-manifest-diff-vs-manifest.bats` — AC-1 and AC-2 **FAIL** (pre-fix the marker attributes to `cmd_extract`). Confirms RED.

### Step 2: awk current-fn tracking (GREEN for AC-1/AC-2)

* **Implement:** in `_diff_files_added` (`module-manifest.sh` ~1632) add `current_fn`: init `current_fn=hunk_ctx` at each `@@`; in the `in_hunk && /^\+/` block, after stripping `+`, if the line matches `^[A-Za-z_][A-Za-z0-9_]*\(\)` **or** `^function[[:space:]]+[A-Za-z_]`, set `current_fn=line`; then `added_ctx[count]=current_fn`.
* **Files:** `module-manifest.sh`.
* **Verify:** AC-1 + AC-2 green; the 4 existing cases still green (AC-5 preview).

### Step 3: AC-3 parity — depends-on + exit-path

* **Test:** fixtures `new-fn-reattribution-depends-on.diff` (new `cmd_query` body adds `+  bash linear-query.sh save-issue …`) and `new-fn-reattribution-exit-path.diff` (adds `+  return 7`). bats: **AC-3a** `new-depends-on-not-declared` `id=="cmd_query"` `value=="linear-query.sh"` AND none with `id=="cmd_extract"`; **AC-3b** `new-exit-path-not-declared` `id=="cmd_query"` `value=="7"` AND none with `id=="cmd_extract"`.
* **Implement:** none expected — the awk fix is shared across all hunk-context-scoped types. (First confirm via `cmd_extract` that `cmd_query` declares neither `linear-query.sh` nor exit `7`.)
* **Files:** 2 fixtures; bats.
* **Verify:** both green; whole file green.

### Step 4: AC-4 function-keyword form (helper extension)

* **Test:** fixture `new-fn-reattribution-function-form.diff` with the new def as `+function cmd_query() {` (keyword form). bats **AC-4**: `new-side-effect-not-declared` with `id=="cmd_query"`.
* **Implement:** extend `_diff_ctx_to_primitive_id` (~1667) with a branch `^function[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)` (tolerating an optional trailing `()`) → echo the captured name; correct the aspirational `~line 1665` comment. (Awk boundary detection from Step 2 already matches the `function ` form.)
* **Files:** `module-manifest.sh`; fixture; bats.
* **Verify:** AC-4 green (keyword form attributes to `cmd_query`); AC-1/2/3/5 + existing still green.

### Step 5: AC-6 edge — file scope (no enclosing function)

* **Test:** fixture `new-fn-reattribution-file-scope.diff` — empty xfuncname header (`@@ -1,2 +1,4 @@`), adds `+# @side-effect: writes-x` with **no** function-def among the added lines (target `module-manifest.sh`). bats **AC-6**: the drift array contains no entry with `value=="writes-x"` (empty `prim_id` → skipped).
* **Implement:** none — verify the fix preserves the empty-ctx skip path (`module-manifest.sh:1835`).
* **Files:** fixture; bats.
* **Verify:** green.

### Step 6: AC-5 regression checkpoint

* **Verify:** full `bats hub/tests/module-manifest-diff-vs-manifest.bats` — the original 4 cases plus all new cases green. Explicit guard that current-fn tracking didn't regress same-function attribution.
* **Files:** none.

### Step 7: AC-7 dogfood — close the BTS-605 honest-narrow

* **Implement:** in `.ccanvil/scripts/ccanvil-sync.sh`, `cmd_registry_prune_stale`: add `# side-effect: writes-hub-registry-when-not-dry-run-and-prunes-found` to the `# @manifest` block (after the existing reads side-effect ~3429); add a matching inline `# @side-effect: writes-hub-registry-when-not-dry-run-and-prunes-found` at the write block (~3479, alongside the existing reads marker); delete the BTS-605 NOTE block (3408–3416). Function logic untouched.
* **Files:** `ccanvil-sync.sh`.
* **Verify:** `module-manifest.sh validate` → `cmd_registry_prune_stale` clean (Layer 2 marker↔key bijection holds, no `missing-side-effect-marker`); `git diff main...HEAD | module-manifest.sh diff-vs-manifest --diff -` → no drift on `cmd_registry` or `cmd_registry_prune_stale`.

### Step 8: substrate manifest contract + guide

* **Implement:** add `# contract: attributes-inline-markers-to-nearest-fn-def-within-hunk` to `cmd_diff_vs_manifest`'s `# @manifest` (~1732). Grep `.ccanvil/guide/` for any diff-vs-manifest/xfuncname attribution prose; update the hub section if present. Do **not** embed literal `# @side-effect:`-shaped pattern strings in new doc text (self-scan false-positive — `self-describing-doc-strings` rule).
* **Files:** `module-manifest.sh`; possibly `.ccanvil/guide/*.md`.
* **Verify:** full `module-manifest.sh validate` → coverage maintained, drift 0; branch `diff-vs-manifest` clean.

### Step 9: pre-merge gate

* **Verify:** full suite via `docs-check.sh test-suite-run --project-dir . --parallel --progress` green; full `module-manifest.sh validate` drift 0; `git diff main...HEAD | module-manifest.sh diff-vs-manifest --diff -` → `status: ok`. THE load-bearing gate (`test-discipline.md`).
* **Files:** none.

## Risks

* **awk ordering:** `current_fn` must update *before* `added_ctx[count]` is assigned for the def line, and reset at each `@@`. Mitigation: init at the hunk header; AC-5 regression guards same-function attribution.
* **Anchor false-green:** if `cmd_query`/`cmd_extract` happen to declare a chosen test marker, the test passes vacuously. Mitigation: markers chosen known-absent; Step 3 verifies declared arrays via `cmd_extract`.
* **Helper over-match:** the `_diff_ctx_to_primitive_id` `function` branch must anchor at `^`. Mitigation: existing `name()` cases (AC-5) catch regressions.
* **Recursive self-check:** editing `module-manifest.sh` makes the branch `diff-vs-manifest` run on this very change; new awk regexes / the contract line must not self-trip drift. Mitigation: no literal marker patterns in added comments; Step 9 verifies clean. (This is also the fix dogfooding itself.)
* **No live-API gate:** pure shell/awk/bats — no external contract uncertainty (`tdd.md` gate N/A).

## Definition of Done

- [ ] All 7 acceptance criteria pass.
- [ ] Existing `module-manifest-diff-vs-manifest.bats` + full suite still pass.
- [ ] `module-manifest.sh validate` drift 0; `git diff main...HEAD | diff-vs-manifest --diff -` → `status: ok`.
- [ ] BTS-605 NOTE removed; `cmd_registry_prune_stale` manifest declares the write side-effect.
- [ ] Code reviewed (run /review).

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
