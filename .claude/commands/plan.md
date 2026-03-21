Create an implementation plan for the feature described in the user's message (or in `docs/spec.md` if no message provided).

## Steps

1. Read `docs/templates/plan.md` for the plan format guide.
2. If `docs/spec.md` has content (not just the placeholder comment), read it for acceptance criteria.
3. Analyze the codebase to identify affected files and existing patterns.
4. Write a plan to `docs/plan.md` following the template format.
5. Each step should be small enough to complete in one TDD cycle (~5-15 minutes).
6. Order steps so each builds on the previous — earlier steps establish foundations, later steps add features.

7. If any step adds, removes, or modifies scaffold infrastructure (commands, rules, agents, skills, hooks, scripts, or sync behavior), add a final step to update `GUIDE.md` — its diagrams, tables, and descriptions must stay current. Read `GUIDE.md` only when this step applies.

Do NOT implement anything. Plan only.
