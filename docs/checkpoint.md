<!-- Active checkpoint — overwritten each session. See docs/templates/checkpoint.md for format guide. -->

# Checkpoint

> Last updated: 2026-03-22
> Session objective: Fix manifest issues, push repos, spec + plan docs lifecycle linking

## Accomplished

- **Manifest issues fixed** — `docs/templates/github/` expanded from directory entry to 7 individual file entries; `.claude/lint.json` removed from hub manifest (downstream-only). Manifest now clean: 55/55 verified.
- **Hub pushed** — 14 commits to GitHub (manifest-check feature + fix)
- **Fucina synced** — pulled GUIDE.md update, fetch-license.sh, manifest-check.sh; pushed to GitHub
- **Docs lifecycle linking specced** — 14 ACs covering docs-check.sh (status, validate, recommend), template metadata, agent/command/rule updates, epoch timestamps
- **Plan written** — 9-step TDD plan ready for implementation
- **Epoch timestamps added to spec** — AC-14: all timestamp metadata uses Unix epoch instead of date strings for deterministic ordering and within-day granularity

## Current State

- **Branch:** main
- **Tests:** 106/106 passing
- **Uncommitted changes:** spec.md, plan.md, checkpoint.md (this commit)
- **Build status:** Clean

## Blocked On

- Nothing

## Next Steps

### 1. Implement docs-check.sh via 9-step TDD plan
- Follow `docs/plan.md` steps 1-9
- Start with Step 1: metadata extraction + `status` subcommand
- Pattern follows `manifest-check.sh` (bash script, subcommands, JSON output, bats tests)

### 2. After implementation, self-test the lifecycle
- The spec, plan, and checkpoint for *this feature* should be the first docs to carry lifecycle metadata
- Run `docs-check.sh validate` against the feature's own docs as a real integration test

## Determinism Notes

- **Manifest issues were fully deterministic fixes** — directory→files expansion and hub-only file removal. No judgment calls.
- **The lifecycle linking feature is designed for maximum determinism** — hash comparison, metadata parsing, and state machine recommendations are all script-based. Claude's judgment is only needed for: populating metadata when writing docs (unavoidable — doc content is stochastic).
- **"Plan before checkpoint" convention identified** — planning in warm context is cheaper than in cold context. Codified as: (1) `recommend` subcommand in docs-check.sh (deterministic state machine), (2) workflow rule (judgment-based convention), (3) checkpoint template comment (passive reminder).

## Context Notes

- The `recommend` subcommand maps document state → next action. Key states: spec-only → "/plan", spec+plan → "build", stale-plan → "re-run /plan", all-linked-with-checkpoint → "/clear + /catchup", nothing → "describe a feature".
- Metadata lives in blockquote `>` lines after the heading. Hash is sha256 (first 8 chars) of content below the metadata section, so metadata changes don't invalidate the chain.
- Templates get placeholder fields; agents/commands/rules get instructions to populate them. The script validates; it never writes.
