---
tier: 0
scope: universal
stack: any
anchors: {}
---

# Over-Budget Rule Fixture

This fixture rule deliberately carries an inflated body so that the rule-tier-budget validator emits a drift entry. The threshold is 150 tokens (char-count / 4 heuristic, matching context-budget.sh). Pass-through fixtures should land under 600 chars; this one targets ≥ 1200 chars to leave headroom above the 600-char threshold (~150 tokens).

## Why over budget

In a properly atomized tier-0 rule, the body is a brief directive — typically one to three sentences plus a pointer to the evidence anchor. Anything longer suggests the rule has accreted operational detail that belongs in a Tier-1 skill or a Tier-2 reference document. The validator surfaces this as a drift entry so authors (or follow-up audits like BTS-387) can identify which rules need atomization work.

This fixture exists purely to exercise the over-budget code path. It does not represent a real rule directive; do not interpret the prose here as guidance. The signal we are testing is: validator counts the body, computes char-count divided by 4, compares against the 150-token threshold, and emits one drift entry of shape `{path, id, reason: "rule-tier-budget-exceeded", value: <count>, threshold: 150}` when the count exceeds the threshold.

## Anti-patterns the validator should NOT trip

- A tier-1 skill file in the same fixture directory should be ignored — only `.claude/rules/*.md` files are scanned.
- A tier-0 rule with no frontmatter is a separate case (`frontmatter-missing` info entry, not drift).
- A tier-0 rule with malformed yaml frontmatter is a separate case (`rule-frontmatter-malformed` drift entry, block-shape).
