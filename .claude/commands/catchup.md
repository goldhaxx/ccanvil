Read the current state of the project to resume work after a context reset.

1. Read `docs/checkpoint.md` if it exists — this contains the last session's progress and next steps.
2. Run `git log --oneline -10` to see recent commits.
3. Run `git diff --stat` to see any uncommitted changes.
4. Run `git diff --cached --stat` to see any staged changes.
5. Read `docs/spec.md` if it exists — this is the current feature specification.

Then provide a brief summary:
- What was accomplished in previous sessions
- Current state (clean/dirty, passing/failing tests)
- What the next step should be based on checkpoint and spec

Do NOT start implementing anything. Just orient and report.
