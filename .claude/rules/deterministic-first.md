---
tier: 0
scope: universal
stack: any
anchors:
  evidence:
    - docs/research/deterministic-first-foundations.md
manifest_ref: deterministic-first.manifest.yaml
---

# Deterministic-First

When an operation is computable (same input → same output), it MUST be deterministic machinery — **hook → script → slash-command-with-script-calls → reasoning**, in that order of preference. Every token spent on deterministic ops is stolen from judgment calls that actually need a transformer.

**When adding automation, ask:**
- Can this step produce a wrong answer? If no → script/hook, not Claude.
- Does this step require code semantics? If no → script/hook, not Claude.
- Would a shell script do this identically every time? If yes → it should BE a shell script.

For the rationale (zero-sum attention argument), expanded hierarchy with examples, and anti-pattern catalog: see the evidence anchor `docs/research/deterministic-first-foundations.md`.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
