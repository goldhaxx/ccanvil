# Self-Review: Continuous Determinism Improvement

## The Rule

During every checkpoint, review, and catchup, briefly assess whether any stochastic operations in the current session should become deterministic. This is not a full audit — just a quick scan for low-hanging fruit.

## When to Flag

Flag an operation if ALL of these are true:
1. Claude performed it during the current session
2. The operation is computable (same input → same output)
3. A script command, hook, or improved output format could replace it
4. It consumed meaningful context (more than a trivial one-liner)

## What to Do

Add a "Determinism Notes" section to `docs/checkpoint.md` when flagging:

```markdown
## Determinism Notes

- **[operation]**: Claude [what happened]. Should be [deterministic replacement]. Impact: [high/medium/low].
```

## When NOT to Flag

- Merge conflict resolution (requires semantic understanding)
- Change classification (generalizable vs specific)
- Spec writing, planning, code review
- One-time exploratory operations that won't recur
- Operations that are already minimally stochastic (single command + read output)

## Full Audit

For a comprehensive analysis, run `/scaffold-audit`. The rule above is the lightweight, always-on version.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /scaffold-pull. -->
