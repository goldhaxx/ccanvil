---
tier: 0
scope: universal
stack: any
anchors:
  evidence:
    - docs/research/tdd-foundations.md
manifest_ref: sidecar.manifest.yaml
---

# Probe Rule

**Directive:** this is a probe rule body for extraction-parity testing.

<!-- AC-1 extraction-parity fixture ONLY. The sidecar declares id: probe (to
     match inline.md), which intentionally MISMATCHES this file's basename
     (sidecar). Do NOT use this pair in a validate-based test — it would emit
     rule-manifest-ref-broken: id-mismatch. -->
