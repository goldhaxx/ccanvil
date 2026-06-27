# Feature: diff-vs-manifest — attribute markers to new functions defined in a hunk

> Feature: bts-667-diff-vs-manifest-hunk-fn-attribution
> Work: linear:BTS-667
> Created: 1782530350
> Status: In Progress
> Subject: Attribute diff markers to new functions defined inside the hunk

## Summary

The Layer-3 `diff-vs-manifest` gate (`module-manifest.sh`) attributes each newly-added inline `# @<marker>:` to a primitive using git's xfuncname hunk header — which walks *backward* from the added lines to the nearest function definition *above* the hunk. When a brand-new function is added between two existing functions, the new function's body markers are mis-attributed to the surrounding (preceding) function, producing false-positive `new-*-not-declared` drift on a function that legitimately doesn't declare them. BTS-605 hit this (`cmd_registry_prune_stale` added below `cmd_registry`) and shipped an honest-narrow workaround. This feature teaches the diff walker to update its attribution context when a function definition appears *among the added lines*, so markers land on the function they actually belong to — and removes the BTS-605 workaround.

## Job To Be Done

**When** I add a new function (with its own inline manifest markers) between two existing functions in an allowlisted script,
**I want to** have `diff-vs-manifest` attribute that new function's markers to *it*, not to the function above it,
**So that** Layer 3 stops emitting false-positive drift on the surrounding function and I no longer need per-addition honest-narrow workarounds.

## Acceptance Criteria

Each criterion is independently testable. Binary pass/fail.

- [ ] **AC-1 (suppression):** Given a unified diff that adds a new function definition `cmd_newfn() {` inside a hunk whose xfuncname header points to a *different* existing manifested function `cmd_surrounding`, and the new function's body adds an inline `# @side-effect: <marker>` that `cmd_surrounding` does not declare, when `diff-vs-manifest --diff` runs, then **no** `new-side-effect-not-declared` drift entry has `id == cmd_surrounding`. (Pre-fix: `cmd_surrounding` is flagged.)
- [ ] **AC-2 (positive re-attribution):** Given the same diff where the newly-defined function is itself a manifested primitive that does not declare `<marker>`, when `diff-vs-manifest` runs, then the emitted `new-side-effect-not-declared` entry has `id == cmd_newfn` — the marker is re-attributed to the nearest function definition *within* the hunk, not dropped and not mis-attributed.
- [ ] **AC-3 (parity across ctx-scoped types):** The same re-attribution applies to `new-depends-on-not-declared` and `new-exit-path-not-declared` (the other two hunk-context-scoped drift types), verified by at least one fixture per type. (`new-caller-not-declared` is file-level, not context-scoped, and is unchanged.)
- [ ] **AC-4 (definition forms — positive re-attribution):** A new definition in **either** the POSIX `name() {` form **or** the `function name {` / `function name() {` keyword form is recognized as a boundary **and** resolved to its bare function name, so an inline marker in that new function's body is attributed to it (`id == name`) — not the surrounding function, and not dropped to the AC-6 file-scope skip path. This requires extending `_diff_ctx_to_primitive_id`: its current regex `^([a-zA-Z_][a-zA-Z0-9_]*)\(\)` resolves only the `name()` form (for the keyword form it captures `function`, fails on `\(\)`, and returns empty), so awk boundary detection alone does not satisfy this AC.
- [ ] **AC-5 (no regression on same-function edits):** Given a diff that adds a marker inside an existing function's body with **no** function definition among the added lines, attribution is unchanged (the marker maps to the xfuncname function). The pre-existing `module-manifest-diff-vs-manifest.bats` cases continue to pass unmodified.
- [ ] **AC-6 (edge — file scope):** Given a hunk whose xfuncname header is empty AND that adds a marker with **no** function definition among the added lines (global/file scope), `diff-vs-manifest` resolves an empty `prim_id` and the marker is skipped — no new `*-not-declared` false positive is introduced.
- [ ] **AC-7 (close BTS-605 debt — dogfood):** The BTS-605 honest-narrow on `cmd_registry_prune_stale` (`.ccanvil/scripts/ccanvil-sync.sh`) is removed: the conditional registry-write is re-declared as a proper `# side-effect:` manifest key with a matching inline `# @side-effect:` body marker at the write site (~line 3479), and the BTS-605 NOTE block (3408–3416) is deleted. When the full `module-manifest.sh validate` and a branch-level `diff-vs-manifest` run, both stay clean (no `missing-side-effect-marker`, no mis-attributed drift) — the manifest is now fully informative instead of narrowed.

## Affected Files

| File | Change |
| -- | -- |
| `.ccanvil/scripts/module-manifest.sh` | Modified — (1) `_diff_files_added` awk: track current-fn context across added lines, updating on a function-definition line before assigning per-line `ctx`; (2) `_diff_ctx_to_primitive_id`: extend to resolve the `function` keyword form to a bare name; (3) add a `contract:` line to `cmd_diff_vs_manifest`'s manifest documenting the behavior. |
| `hub/tests/module-manifest-diff-vs-manifest.bats` | Modified — add AC-1…AC-6 cases. |
| `hub/tests/fixtures/manifest/diffs/*.diff` | New — new-function re-attribution fixtures (side-effect, depends-on, exit-path, definition-form variants, file-scope edge). |
| `.ccanvil/scripts/ccanvil-sync.sh` | Modified (AC-7) — re-declare `cmd_registry_prune_stale` write side-effect (manifest key + inline marker); remove BTS-605 NOTE. Function logic untouched. |

## Dependencies

* **Requires:** BTS-268 `diff-vs-manifest` substrate (shipped); `.ccanvil/manifest-allowlist.txt` already lists `cmd_registry_prune_stale` (line 147).
* **Blocked by:** none.

## Out of Scope

* `new-caller-not-declared` — file-level (scans all added text for the fn name), not hunk-context-scoped; unaffected.
* Mid-hunk context re-derivation *after* a function closes (trailing added lines that belong to a different existing function whose definition is not in the hunk) — remains best-effort, as today. The fix handles the new-function-definition boundary only.
* Nested/inner function definitions (not a ccanvil convention).
* Any change to drift_type names or the envelope shape.

## Implementation Notes

* **Seam (two coordinated edits, same file):** (1) the awk in `_diff_files_added` (`module-manifest.sh` ~1632) — today `added_ctx[count]=hunk_ctx` is constant per hunk; introduce `current_fn` (init `= hunk_ctx` at each `@@`) and, when an added line matches the boundary regex `^[A-Za-z_][A-Za-z0-9_]*\(\)` **or** `^function[[:space:]]+[A-Za-z_]`, set `current_fn` to that line *before* `added_ctx[count]=current_fn`. (2) `_diff_ctx_to_primitive_id` (~1667) — its regex resolves only `name()`; add a `^function[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)` branch (tolerating an optional trailing `()`) so the keyword form resolves to a bare name. The awk boundary regex and this extraction regex must agree on both forms; the comment at ~line 1665 claiming `function foo()` already resolves is currently aspirational and must be made true by edit (2).
* **Optional hardening:** reset `current_fn=""` on a column-0 `}` (function close) so trailing markers fall to file scope (skipped) rather than mis-attribute — strictly safer; plan decides whether to include.
* **Fixtures:** follow the existing `hub/tests/fixtures/manifest/diffs/` pattern — synthetic diffs whose declared arrays are read from the real on-disk manifest via `cmd_extract`; the xfuncname header is the surrounding function and the added function-def line is the new boundary.
* **AC-7:** `cmd_registry_prune_stale`'s logic is unchanged — only its `# @manifest` declaration, one inline `# @side-effect:` marker, and the NOTE block. This is the only behavioral-neutral edit to `ccanvil-sync.sh`.
* **Meta:** editing `module-manifest.sh` (an allowlisted file) means the pre-merge `diff-vs-manifest` self-check runs on this very change — expect it to validate the new `contract:` line cleanly.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
