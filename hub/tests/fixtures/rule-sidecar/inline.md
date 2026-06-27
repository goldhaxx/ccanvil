---
tier: 0
scope: universal
stack: any
anchors:
  evidence:
    - docs/research/tdd-foundations.md
manifest:
  id: probe
  purpose: Probe rule for sidecar extraction parity
  input:
    - "read-only: probe rule consumed by Claude"
  output:
    - "behavior-shape: probe"
  caller:
    - .claude/commands/plan.md
  depends-on:
    - bats-report.sh
  side-effect:
    - "no-op probe (behavioral influence only)"
  failure-mode:
    - "probe-fail | exit=n/a | visible=none | mitigation=none"
  contract:
    - probe-contract-one
  anchor:
    - BTS-666 (probe)
---

# Probe Rule

**Directive:** this is a probe rule body for extraction-parity testing.
