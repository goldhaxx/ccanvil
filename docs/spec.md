# Feature: docs-check.sh lifecycle-cluster manifests

> Feature: bts-241-docs-check-lifecycle-manifests
> Work: linear:BTS-241
> Created: 1777407252
> Subject: docs-check.sh lifecycle-cluster manifests
> Status: In Progress

<!-- Subject: docs-check.sh lifecycle-cluster manifests (24 primitives) -->

## Summary

Session 2 of the manifest rollout (`docs/manifest-rollout.md`). Add full `# @manifest` blocks + inline source markers to 24 lifecycle-cluster `cmd_*` primitives in `.ccanvil/scripts/docs-check.sh`. Allowlist grows 11 → 35; `module-manifest.sh validate` reports 35/35 with drift 0. No substrate changes — pure coverage expansion using BTS-239 + BTS-240 plumbing.

## Job To Be Done

**When** future-Claude / future-operators read or modify the spec→activate→plan→PR→ship→land lifecycle code,
**I want to** see machine-readable contracts inline at every primitive declaring its purpose, inputs, outputs, callers, dependencies, side effects, failure modes, and design anchors,
**So that** comprehension cost drops to read-the-block-above (no codebase archaeology), drift-guard catches behavior changes that drift from declared contracts, and `cmd_query` enables substrate-discovery by depends-on / failure-mode / contract.

## Acceptance Criteria

Each criterion is independently testable. Binary pass/fail.

- [ ] **AC-1:** Each of the 24 lifecycle-cluster primitives carries a `# @manifest` block immediately above its function definition. Required keys (`purpose`, `input`, `output`, `side-effect`, `failure-mode`, `contract`, `anchor`) are non-empty for every entry.
- [ ] **AC-2:** Each declared `failure-mode: <id>` has a matching inline `# @failure-mode: <id>` marker at the failing code path. Each declared `side-effect: <id>` has a matching inline `# @side-effect: <id>` marker at the mutation site.
- [ ] **AC-3:** Each declared `caller:` resolves via `_caller_actually_calls_primitive` (existing function-name search across `.ccanvil/scripts`, `.claude/hooks`, `.claude/hooks/_lib`, OR `skill:/<name>` markdown form). No phantom callers.
- [ ] **AC-4:** Each declared `depends-on:` value appears (word-boundary) inside the primitive's body. No phantom dependencies.
- [ ] **AC-5:** `failure-mode` line schema preserved — `<id> | exit=N | visible=<phrase> | mitigation=<phrase>`. Each id maps to exactly one return/exit path.
- [ ] **AC-6:** `.ccanvil/manifest-allowlist.txt` grows from 11 to 35 entries. The 24 new entries follow the section header `# BTS-241: docs-check.sh lifecycle cluster (Session 2 of manifest rollout).`
- [ ] **AC-7:** `bash .ccanvil/scripts/module-manifest.sh validate --json` reports `coverage.covered == 35`, `coverage.total == 35`, `drift == []`. Production drift-guard test (`module-manifest-drift-guard.bats`) green.
- [ ] **AC-8:** Existing bats suite (1923 baseline) still passes. No regression in existing tests.
- [ ] **AC-9:** Self-application — at least 4 of the 24 manifests declare `caller: skill:/<name>` referring to skills/commands that genuinely invoke that primitive (e.g., `cmd_activate` callers include `skill:/activate`, `cmd_pr_cleanup` callers include `skill:/pr`).
- [ ] **AC-10:** `docs/manifest-rollout.md` Inventory `Done` column updated — `docs-check.sh` row `Done` increases from 3 to 27 (3 prior + 24 new).
- [ ] **AC-11:** Live-AC — next session's `/recall` step 11 surfaces `Manifest coverage: 35 / 35 (allowlist), drift: 0`.

## Affected Files

| File | Change |
|------|--------|
| `.ccanvil/scripts/docs-check.sh` | Modified — 24 `# @manifest` blocks + inline `# @failure-mode:` / `# @side-effect:` markers added at each primitive |
| `.ccanvil/manifest-allowlist.txt` | Modified — 24 new entries appended under a Session-2 section header |
| `docs/manifest-rollout.md` | Modified — Inventory table `Done` column update |

No new test files. No substrate changes. No new fixtures.

## Dependencies

- **Requires:** BTS-239 (origin substrate) + BTS-240 (markdown extension) — both landed.
- **Blocked by:** none.

## Out of Scope

- The 24 remaining `cmd_*` in `docs-check.sh` (capture + audit cluster). Sessions 3 ships those.
- Other mega-scripts (`ccanvil-sync.sh`, `linear-query.sh`, etc.). Sessions 4-7.
- New ACs beyond manifest correctness — drift-guard semantics are unchanged from BTS-239.

## Implementation Notes

- **Per-primitive workflow:** read the function body, enumerate inputs (positional + flags + env-vars + stdin), outputs (stdout shape + exit-code class + file writes), side-effects (every mutation outside the call frame), failure-modes (every non-zero `return`/`exit`), depends-on (helper functions called within body), callers (grep for `cmd_<name>`/dispatch-verb form across project). Compose manifest, add markers at the failing/mutating lines.
- **Quality bar (per `docs/manifest-rollout.md` "Quality bar"):** every field semantically true, not best-guess; `purpose` answers "what does this do that no other primitive does" (not "wraps X").
- **Batching:** ~6 manifests per commit, one drift-guard verify after each batch. Catches errors early.
- **Bash 3.2 compat preserved:** no substrate change, just data declarations + inline markers in comments.
- **Frontmatter on rules/commands sanity-check:** N/A — all targets are shell function-level, not markdown.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
