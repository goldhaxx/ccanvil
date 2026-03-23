<!-- Active checkpoint — overwritten each session. See docs/templates/checkpoint.md for format guide. -->

# Checkpoint

> Feature: feature-lifecycle
> Last updated: 1774229091
> Plan hash: e3381a95
> Session objective: Build branch-based feature lifecycle (ZWR-10) + establish Linear tracking + research agentic git workflows

## Accomplished

### Feature lifecycle (ZWR-10, complete)
- **All 24 ACs implemented** across 12 TDD steps, 34 new tests (222 total), all passing.
- `docs-check.sh` extended: `list-specs`, `activate`, `complete`, `config-get` commands; `validate`/`recommend` adapted for multi-spec.
- Hooks: `branch-name-lint.sh` (warn on non-convention branches), `commit-msg-lint.sh` (warn on non-conventional commits). Both PostToolUse, exit 0 always.
- Commands: `/commit` (test → stage → conventional message → co-authored-by), `/pr` (evaluation gates → optional critic review → draft PR).
- Scaffold config: `.claude/scaffold.json` with feature toggles (`pr_review`), node-only, defaults template.
- Assumptions tracking: `docs/assumptions.md` template, included in PR body, cleared on `complete`.
- Worktree compatibility: `.gitignore`/`.claudeignore` entries, GUIDE.md parallel sessions docs, path resolution tested.
- GUIDE.md + CLAUDE.md updated with new commands, architecture, tables.

### Settings.json hardening (ZWR-13, complete)
- Established read-only permission principle: auto-allow reads, require approval for mutations.
- Removed 7 dangerous entries (cat, find, env, echo, sort, git branch, git tag).
- Split `Bash(git:*)` into individual read-only git commands.
- Identified compound command issue (`;`/`&&` bypass allow-list matching).

### Permissions audit spec (ZWR-11, backlogged)
- Spec written at `docs/specs/permissions-audit.md` with 11 ACs.
- Blocked by ZWR-10 (now complete — ready to plan).

### Research
- Deep research on agentic git workflows: `docs/research/agentic-git-workflows.md` — 25+ sources, 12 teams.
- Key findings: worktrees universal, agent-prefixed branches, draft PRs mandatory, deterministic/stochastic separation validates our approach.

### Linear setup
- Project "Claude Code Scaffold" created at https://linear.app/zwright/project/claude-code-scaffold-a2b015bd5fb5
- 10 issues created (ZWR-10 through ZWR-21), labels (scaffold, has-spec, needs-research).
- Completed features backfilled (ZWR-13 through ZWR-18).

## Current State

- **Branch:** main
- **Tests:** 222/222 passing
- **Uncommitted changes:** This checkpoint only
- **Build status:** Clean
- **Docs lifecycle:** feature-lifecycle spec Complete

## Blocked On

- Nothing

## Next Steps

### Next session: Backlog review + Linear integration planning
Zach requested a dedicated planning session to:
1. **Review full backlog** — prioritize across all ZWR issues with Linear as source of truth
2. **Resolve Linear's role in the lifecycle** — how does Linear fit with `docs/specs/`, `activate`, `/pr`? Does modular tool integration (ZWR-19) need to come before other backlog items?
3. **Adjust to the new lifecycle** — first real use of `activate` → branch → `/commit` → `/pr` flow
4. **Deep discussion** — not implementation. Planning and alignment only.

### Backlog (in Linear, priority order)
- **ZWR-11** Permissions security audit (has-spec, was blocked by ZWR-10)
- **ZWR-12** Context budget measurement
- **ZWR-19** Modular tool integration layer (Linear, GitHub, etc.)
- **ZWR-20** Workflow engine / deterministic state machine
- **ZWR-21** GitHub Agentic Workflows integration

### Open question
How should Linear integrate with the lifecycle? Today: specs live in `docs/specs/`, Linear tracks the backlog separately. Risk of drift. Options:
- Linear is source of truth for backlog priority; specs remain in git for deterministic validation
- Linear issues link to spec files; `/activate` updates Linear status
- Full integration waits for ZWR-19 (modular tool layer)

## Determinism Review

- **operations_reviewed:** 12
- **candidates_found:** 0
- All implementation followed TDD (red → green → refactor → commit pattern).
- Script commands are deterministic (list-specs, activate, complete, config-get).
- Hooks are deterministic (regex matching on command strings).
- Research was delegated to sub-agent (isolated context).
- Settings.json edits were direct targeted changes.
- Linear operations used MCP tools (deterministic API calls).
- No manual `cp`, `jq`, `shasum`, or `git -C` improvised outside scripts.
- No candidates this session.
