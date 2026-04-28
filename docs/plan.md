# Plan: provider integration strategy + dead-code sweep

> Feature: bts-183-provider-integration-strategy
> Created: 1777343926
> Spec hash: 1d8142e5

## Strategy

(a) Audit confirmed: 6 verbs are dead code in operations.sh (zero live skill/script callers): idea.{promote,defer,dismiss,merge}, backlog.get, ticket.find-by-title.

(b) Codify the canonical rule in `.claude/rules/provider-integration.md` — substrate=http, MCP=operator-tool. Reference the migration evidence (BTS-164/166/167) and the http-vs-MCP comparison table from BTS-183 body.

(c) Sweep: remove dead-code branches from operations.sh + delete/edit related bats coverage.
- operations.sh: 6 verb removals + EXACT flag removal + is_valid_operation update.
- hub/tests/ticket-find-by-title.bats: DELETED entirely.
- hub/tests/idea-triage-native.bats: ~22 tests removed.
- hub/tests/operations.bats: 3 tests removed/edited (registry list, MCP exec, hyphenated-provider section heading).
- hub/tests/ticket-transition.bats: 1 test rewritten to use a still-live single-arg verb.

(d) Generalization to future providers — out of scope.

## Suite delta

1874 (post-BTS-208) → 1839 — net −35 (matches expected dead-code test count).

## Files

- `.claude/rules/provider-integration.md` (new)
- `.ccanvil/scripts/operations.sh` (sweep)
- `hub/tests/ticket-find-by-title.bats` (deleted)
- `hub/tests/idea-triage-native.bats` (edited)
- `hub/tests/operations.bats` (edited)
- `hub/tests/ticket-transition.bats` (edited)

## Risks

- A consumer somewhere we missed could break. Mitigation: full repo grep on each verb returns only operations.sh + tests. Confirmed.
- Future-self might re-introduce one of these as MCP. Mitigation: rule file documents the prohibition + this ship's evidence.
