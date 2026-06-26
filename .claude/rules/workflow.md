---
tier: 0
scope: universal
stack: any
anchors:
  evidence:
    - docs/research/feature-lifecycle.md
manifest_ref: workflow.manifest.yaml
---

# Workflow

**Feature lifecycle:** Spec → Activate → Plan → Implement → Complete → Merge → Land. Main is protected (PreToolUse hook blocks direct commits).

**Session discipline:** one objective per session. End with summary → next-action → `/stasis` → `/compact`. Resume after reset via `/recall`. Determinism review is mandatory in every stasis — see `self-review.md`.

**Error recovery:** after 2 failed attempts, STOP. Run `/stasis` and surface alternatives instead of looping.

For the full lifecycle table, per-phase commands, strategic-awareness primitives, context-preservation detail, hub-sync classification, and reasoning behind each rule: see the evidence anchor `docs/research/feature-lifecycle.md`.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
