<!-- Active checkpoint — overwritten each session. See docs/templates/checkpoint.md for format guide. -->

# Checkpoint

> Last updated: 2026-03-22
> Session objective: Security audit, lint hooks, GitHub-ready templates

## Accomplished

- Created `scripts/security-audit.sh` — deterministic PII/secrets scanner (15 tests)
  - Detects: GitHub/AWS/OpenAI tokens, absolute home paths, personal emails, .env/.pem/.key files
  - Supports: --json, --files-only, --history-only flags
  - Allowlists: the script itself and documentation files with example patterns
- Created `/security-audit` command, integrated into `/review` as post-code-review step
- Created `lint-on-write.sh` — config-driven universal syntax validation hook
  - Built-in (hub): bash -n, jq empty, yaml check
  - Extensible (node): .claude/lint.json config for project-specific linters
  - Exit 2 blocks writes on syntax errors
- Created GitHub-ready templates in `docs/templates/github/`:
  - README.md, CONTRIBUTING.md, ISSUE_TEMPLATE/bug_report.md, ISSUE_TEMPLATE/feature_request.md, PULL_REQUEST_TEMPLATE.md
- Created `docs/templates/lint.json` template for node lint configuration
- Pushed all changes to GitHub

## Current State

- **Branch:** main (pushed to GitHub)
- **Tests:** 56/56 passing (41 scaffold-sync + 15 security-audit)
- **Uncommitted changes:** This checkpoint only
- **Build status:** Clean

## Blocked On

- Nothing

## Next Steps

### 1. Update /init to copy GitHub templates
- Copy `docs/templates/github/README.md` to project root
- Copy `docs/templates/github/CONTRIBUTING.md` to project root
- Copy `docs/templates/github/ISSUE_TEMPLATE/` to `.github/ISSUE_TEMPLATE/`
- Copy `docs/templates/github/PULL_REQUEST_TEMPLATE.md` to `.github/`
- Copy `docs/templates/lint.json` to `.claude/lint.json`
- Populate README placeholders from CLAUDE.md content

### 2. Sync all changes to fucina
- Hub has 4 new commits since last fucina sync
- Run /scaffold-pull from fucina
- Set up fucina's .claude/lint.json for Arduino/C++ stack

### 3. Create hub's own README
- The scaffold hub itself needs a proper README (not from the template — the hub is a meta-project)
- Should explain: what the scaffold is, how to use /init, how sync works, link to GUIDE.md

### 4. Add lint hook tests
- Test built-in linters (sh, json, yaml validation)
- Test config-driven linter dispatch
- Test graceful skip when linter command not installed

## Determinism Notes

- **Lint hook is config-driven**: No Claude judgment needed. Hub script handles dispatch, node JSON config handles registration. Fully deterministic.
- **Security audit is fully deterministic**: Pattern matching via grep/regex. No semantic analysis needed. Could become a pre-push hook in the future.
- **format-on-write.sh**: Still has commented-out formatters. Should also be config-driven like lint-on-write.sh. Same .claude/lint.json could have a "formatters" section.

## Context Notes

- The lint hook uses `run_linter` helper that captures stderr to a temp file and blocks with exit 2. The temp file is cleaned up via trap.
- Config-driven linters check if the base command exists (`command -v`) before running. Missing linters are silently skipped — this prevents failures on machines without project-specific tooling.
- The format hook (format-on-write.sh) could be merged with or made parallel to lint-on-write.sh in the future. Currently they're separate hooks: lint blocks on errors, format silently fixes style.
