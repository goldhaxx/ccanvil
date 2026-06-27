---
tier: 0
scope: universal
stack: any
anchors:
  evidence:
    - docs/research/evidence-gate-incident.md
manifest_ref: evidence-required-for-captures.manifest.yaml
---

# Evidence Required for Bug Captures

Bug-shape captures (via `/idea` mid-session and `/stasis` at session boundaries) MUST be backed by reproducible evidence before being logged as fix-shaped tickets. Hypothesis-backed captures use `DIAGNOSE: <symptom>` titling — the first ship is the diagnostic capture, not the fix.

**The four anchors (case-sensitive, line-leading) — required for `FIX:` shape:**

- `Command:` — exact command that exhibited the bug, copy-pasteable.
- `Output:` — exact error output (or hook BLOCKED message, or stack trace) — verbatim, not summarized.
- `Exit:` — exit code of the failing command.
- `Reproduce:` — one-line reproducer recipe.

If any are missing, the capture must use `DIAGNOSE:` titling (bypasses the anchor requirement; first ship = diagnostic).

**Bug-shape heuristic** (case-insensitive regex used by the `/idea` skill's Step 0.5 evidence gate):

```
fail|false[- ]positive|broken|errored?|blocked by|doesn'?t work|crashes?|hang(s|ing)?
```

When matched and no anchors are present, the skill refuses fix-shape capture and offers `DIAGNOSE:` retitle as the only forward path.

For the BTS-198 origin incident, the DIAGNOSE-vs-FIX rationale, lifecycle application detail (`/idea`/`/stasis`/`/recall` integration), and out-of-scope clarifications: see evidence anchor `docs/research/evidence-gate-incident.md`.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
