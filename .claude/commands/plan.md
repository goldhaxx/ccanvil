Create an implementation plan for the feature described in the user's message (or in `docs/spec.md` if no message provided).

## Steps

1. If `docs/spec.md` exists, read it for acceptance criteria.
2. Analyze the codebase to identify affected files and existing patterns.
3. Write a plan to `docs/plan.md` with the following structure:

```markdown
# Implementation Plan: [Feature Name]

## Objective
One sentence.

## Sequence
Ordered list of implementation steps. Each step is one red-green-refactor cycle:

### Step 1: [Description]
- **Test:** Write test for [specific behavior]
- **Implement:** [What code to write/modify]
- **Files:** [Specific files to create/edit]
- **Verify:** [How to confirm it works]

### Step 2: [Description]
...

## Risks
- [What could go wrong and mitigation strategies]

## Definition of Done
- [ ] All acceptance criteria from spec pass
- [ ] All existing tests still pass
- [ ] No TypeScript errors
- [ ] Code reviewed (run /review)
```

4. Each step should be small enough to complete in one TDD cycle (~5-15 minutes).
5. Order steps so each builds on the previous — earlier steps establish foundations, later steps add features.

Do NOT implement anything. Plan only.
