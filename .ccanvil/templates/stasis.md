# Stasis

> Feature: [feature-id]
> Last updated: [epoch]
> Plan hash: [hash]
> Session objective: [what we set out to do]
<!-- Reminder: if no plan exists yet, run /plan before /stasis (plan before stasis). -->

## Accomplished

- [What was completed this session]

## Current State

- **Branch:** [branch name]
- **Tests:** [all passing / N failing — list which]
- **Uncommitted changes:** [yes/no — what]
- **Build status:** [clean / errors — what]

## Blocked On

- [Any issues preventing progress]

## Next Steps

1. [Exact next action to take when resuming]
2. [Following action]
3. [...]

## Context Notes

[Anything the next session needs to know that isn't captured elsewhere — failed approaches, decisions made, alternatives considered]

## Determinism Review

- **operations_reviewed:** [count]
- **candidates_found:** [count]
- [For each candidate: **[operation]**: Claude [what happened]. Should be [deterministic replacement]. Impact: [high/medium/low].]
- [If no candidates: "No candidates this session."]

## Cross-Session Patterns

[Any determinism-review candidates or audit-session findings that also appeared in the previous stasis. Run `docs-check.sh legacy-refs-scan` as part of this check. If no prior stasis exists: "First stasis — no prior state to compare." If no patterns: "No recurring patterns."]

## Security Review

[Run the project's security scan (via `security-audit` skill if present, else static grep for secrets/PII keywords in the session's diff). Report `PASS` or a bullet list of findings.]

## Memory Candidates

[List insights that meet auto-memory criteria — non-obvious feedback, surprising project facts, external references. If none: "No candidates this session."]

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
