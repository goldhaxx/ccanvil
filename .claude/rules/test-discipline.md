---
tier: 0
scope: universal
stack: any
anchors:
  evidence:
    - docs/research/test-discipline-research.md
manifest_ref: test-discipline.manifest.yaml
---

# Test-Run Discipline

Long-running test substrates are expensive. Test-run decisions are driven by three axes — **state**, **intent**, **scope** — not reflexive verification:

| Phase | Run? | Scope |
|-------|------|-------|
| TDD cycle | Targeted file only | one test file |
| pre-review | Manifest validate, gated on state-key match + no allowlisted changes | full validate |
| pre-commit | Touched files only | partial |
| **pre-merge** | **Full suite + manifest validate — THE load-bearing gate** | full |
| session-boundary | None | n/a (records state, doesn't test) |
| post-merge | None | n/a |

**Anti-patterns** (each costs wall time, adds no signal):

1. **Reflexive full-suite re-run** after a change that touched zero suite-relevant files.
2. **Re-running manifest validate** when the prior validate is cached for the same commit AND nothing manifest-tracked has changed.
3. **Running the full suite to verify ONE file** — use the targeted runner instead.

**SHOULD-I-RUN decision rule:** consult the `test-state` envelope before invoking any long-running substrate. Skip iff zero relevant files have changed since the last successful run (the diff between the cached SHA and HEAD, intersected with the allowlist, is empty). Mid-PR commits that touch only docs, tests, or non-allowlisted code still allow the skip. Empty / uncertain state → run (fail-safe).

For the full audit catalog, redundancy analysis, framework derivation, and per-gate decision trees: see evidence anchor `docs/research/test-discipline-research.md`.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
