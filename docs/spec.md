# Feature: Module manifest substrate — first ship (3 seed primitives, drift-guard)

> Feature: bts-239-module-manifest-substrate
> Work: linear:BTS-239
> Created: 1777351812
> Subject: Module manifest substrate — first ship (3 seed primitives, drift-guard)
> Status: In Progress

<!-- Layer 2 of Dark Code framework. Research: docs/research/dark-code-mapping.md. -->

## Summary

First ship of the Self-Describing Systems layer. Introduces an in-source `# @manifest` comment-block format, a four-verb substrate (`extract`, `validate`, `query`, `index`), an allowlist-driven drift-guard, and 100% manifest coverage on three seed primitives (`cmd_artifact_write`, `cmd_ship_finalize`, `cmd_idea_pending_replay`). The format is the foundation for ramping coverage across all ~159 candidate substrate units in subsequent ships; Layer 3 (manifest-aware review) ramps later.

## Job To Be Done

**When** a cold-start Claude (or operator) needs to safely modify, call, or reason about a substrate primitive,
**I want to** read its contract — purpose, callers, dependencies, side-effects, failure modes, anchors — in <30 seconds without reading the implementation,
**So that** comprehension debt does not compound and architecture-level intent stays legible across sessions.

## Acceptance Criteria

- [ ] **AC-1 (format documented):** `.ccanvil/templates/manifest.md` exists. It documents the `# @manifest` block: key-value comment lines, repeated keys for multi-value fields, required keys (`purpose`, `input`, `output`, `side-effect`, `failure-mode`, `contract`, `anchor`), optional keys (`routes-by`, `caller`, `depends-on`), and the `failure-mode` line schema (`id | exit=N | visible=<phrase> | mitigation=<phrase>`).

- [ ] **AC-2 (extract):** `bash .ccanvil/scripts/module-manifest.sh extract <path>` emits a JSON array of one object per `# @manifest` block found in `<path>`. Each object carries an `id` field (function name for function-level blocks; basename for file-level blocks); repeated keys collapse to JSON arrays. A file with no manifest blocks emits `[]` and exits 0.

- [ ] **AC-3 (validate succeeds on seeds):** `bash .ccanvil/scripts/module-manifest.sh validate` reads `.ccanvil/manifest-allowlist.txt`, walks every entry, and exits 0 when all required keys are non-empty, all `failure-mode` records parse, all `caller:` entries match grep-of-source, all `depends-on:` entries match calls in the body, and every declared `failure-mode: <id>` and `side-effect: <id>` has at least one matching `@failure-mode: <id>` or `@side-effect: <id>` source-marker inside the function body.

- [ ] **AC-4 (validate fails on drift):** Given a seed primitive whose manifest declares `caller: cmd_X` for a `cmd_X` that does not call it, `validate` exits 2 with structured stderr: `DRIFT: <path>:<id> reason=caller-not-found value=cmd_X`. Same shape for all six drift classes (missing key, malformed failure-mode, caller mismatch, depends-on mismatch, missing `@failure-mode` marker, missing `@side-effect` marker).

- [ ] **AC-5 (index):** `bash .ccanvil/scripts/module-manifest.sh index` regenerates `.ccanvil/state/manifests.json` (gitignored). Output is a JSON object keyed by `<path>:<id>`, sorted lexicographically; deterministic across runs on identical input.

- [ ] **AC-6 (query):** `bash .ccanvil/scripts/module-manifest.sh query '<key>:<value>'` reads the index (regenerating if mtime-stale relative to source files) and returns a JSON array of entries whose `<key>` field (scalar or array) contains `<value>` as a substring. Empty array on no match. Exit 0 either way.

- [ ] **AC-7 (allowlist + seed manifests):** `.ccanvil/manifest-allowlist.txt` exists and contains seven entries: three seed primitives (`.ccanvil/scripts/docs-check.sh:cmd_artifact_write`, `:cmd_ship_finalize`, `:cmd_idea_pending_replay`) plus four self-application verbs in `module-manifest.sh` (`cmd_extract`, `cmd_validate`, `cmd_query`, `cmd_index`). Each named function has a complete `# @manifest` block above it satisfying AC-3.

- [ ] **AC-8 (drift-guard test):** `hub/tests/module-manifest-drift-guard.bats` runs `validate` and asserts exit 0. Includes mutation tests: temporarily corrupt one seed manifest's `caller:` field → assert exit 2 + correct stderr shape; revert and reassert exit 0.

- [ ] **AC-9 (stasis surfaces coverage):** `.ccanvil/templates/stasis.md` gains a `## Manifest Coverage` section template. The `/stasis` skill populates it via `module-manifest.sh validate --json | jq -r '"\(.coverage.covered) / \(.coverage.total) (allowlist), drift incidents: \(.drift | length)"'`. When the allowlist is empty, render literal `Manifest coverage: N/A (no allowlist yet).`

- [ ] **AC-10 (error: malformed manifest):** When a manifest's `failure-mode` line has missing `id` or non-numeric `exit=`, `extract` exits 2 with stderr `MALFORMED: <path>:<line>: <reason>` and writes no partial JSON to stdout.

- [ ] **AC-11 (live-AC, post-merge):** The next ship after this one merges runs `module-manifest.sh validate` cleanly (exit 0) when invoked from `/recall`'s deterministic data-gathering, and the next ship's stasis carries a populated `## Manifest Coverage` section. Proves the substrate is live across sessions, not just CI-bound.

## Affected Files

| File | Change |
|------|--------|
| `.ccanvil/templates/manifest.md` | New |
| `.ccanvil/scripts/module-manifest.sh` | New (verbs: extract, validate, query, index; ~400 LOC est.) |
| `.ccanvil/manifest-allowlist.txt` | New (7 entries) |
| `.ccanvil/scripts/docs-check.sh` | Modify — add `# @manifest` blocks above the 3 seed primitives; insert `@failure-mode:` and `@side-effect:` markers in their bodies |
| `.ccanvil/templates/stasis.md` | Modify — `## Manifest Coverage` section |
| `.claude/skills/stasis/SKILL.md` | Modify — populate-coverage step |
| `.gitignore` | Add `.ccanvil/state/manifests.json` |
| `hub/tests/module-manifest-extract.bats` | New |
| `hub/tests/module-manifest-validate.bats` | New |
| `hub/tests/module-manifest-query.bats` | New |
| `hub/tests/module-manifest-index.bats` | New |
| `hub/tests/module-manifest-drift-guard.bats` | New |
| `hub/tests/module-manifest-self-application.bats` | New |

## Dependencies

- **Requires:** none. Existing precedent: BTS-215 (dispatch-table → usage-at-runtime → drift-guard) is the same shape applied at a different layer.
- **Blocked by:** none.

## Out of Scope

- Markdown frontmatter manifests for `.claude/skills/`, `.claude/rules/`, `.claude/agents/`. First ship covers `.sh` only; markdown ramps later.
- Pre-commit warn hook (adherence layer 4) — follow-up ship.
- `code-reviewer` agent / `/review` skill manifest-aware checks (Layer 3) — ramps after coverage > 50%.
- Existing `manifest-check.sh` (different domain — README file-presence lockfile). Naming overlap is verbal, not functional.
- Refactoring the 3 seed primitives. Manifests describe current shape, not improved shape.
- Index query CLI beyond simple `<key>:<value>` substring matching. Composable expressions, AND/OR, regex — defer.

## Implementation Notes

- Pattern precedent: BTS-215 (`docs-check.sh` usage-from-dispatch-table). Same shape — source-of-truth → derived artifact → drift-guard test.
- `# @failure-mode: <id>` and `# @side-effect: <id>` markers attach to specific source lines (the `exit N`, the file write, the network call). Bidirectional drift-guard validates manifest-entries-match-markers AND markers-match-manifest-entries.
- Manifest line shape: `# <key>: <value>`. Multi-line values not supported — force decomposition into separate keys instead.
- `failure-mode` value parser: split on `|`, trim each segment, first segment is `id`, remaining segments are `key=value`.
- Index regeneration is read-side lazy: `query` and `validate` check `.ccanvil/state/manifests.json` mtime against newest source file mtime; regenerate if stale. No write-side hook this ship.
- `validate --json` emits `{coverage: {covered: N, total: M}, drift: [{path, id, reason, ...}], status: "ok"|"drift"}`.
- Self-application: the four `cmd_*` verbs in `module-manifest.sh` are the first non-`docs-check.sh` primitives covered. Validates the format works across files.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
