---
tier: 0
scope: universal
stack: any
anchors:
  evidence:
    - docs/research/self-review-detail.md
manifest_ref: self-review.manifest.yaml
---

# Self-Review: Determinism

The `## Determinism Review` section in `docs/stasis.md` is **mandatory** in every stasis. Format: `.ccanvil/templates/stasis.md`.

**Flag an operation when all four hold:**
1. Claude performed it this session
2. The operation is computable (same input → same output)
3. A script, hook, or improved output format could replace it
4. It consumed meaningful context (not a trivial one-liner)

Also flag a plan-flagged live-API risk where the implementer skipped live-validation before commit (BTS-171).

**Write each candidate as:** `**[operation]**: Claude [what happened]. Should be [deterministic replacement]. Impact: [high|medium|low].` If none: `No candidates this session.`

For dual-capture mechanics (BTS-115), when-NOT-to-flag list, `audit-session` safety net, and `/ccanvil-audit` full-audit pointer: see evidence anchor `docs/research/self-review-detail.md`.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
