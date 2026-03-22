<!-- Active checkpoint — overwritten each session. See docs/templates/checkpoint.md for format guide. -->

# Checkpoint

> Last updated: 2026-03-22
> Session objective: Determinism notes, /init update, README, lint tests, fucina sync

## Accomplished

- **format-on-write.sh** now config-driven via `.claude/lint.json` `"formatters"` section (same pattern as linters — hub provides framework, nodes register project-specific formatters)
- **Git pre-push hook** template runs `security-audit.sh --files-only` before allowing push. Installed in hub. Caught `.bats` allowlist gap on first real push.
- **Allowlisted `.bats` files** in security audit (test fixtures intentionally contain fake tokens)
- **/init updated** to copy GitHub templates (README, CONTRIBUTING, issue/PR templates), lint config, and pre-push hook to new projects
- **Hub README modernized** for GitHub — features list, quick start, updated file manifest with all new commands/hooks/scripts
- **12 lint hook tests** — built-in linters (bash, json, yaml), config-driven dispatch, graceful skip, edge cases
- **Fucina synced** — 4 auto-updates, 1 conflict resolved, 3 new files (security-audit command, lint hook, security audit script). Auto-committed by pull-finalize.
- **Both repos pushed to GitHub** with pre-push security audit active

## Current State

- **Branch:** main (both repos, pushed to GitHub)
- **Tests:** 68/68 passing (41 scaffold-sync + 15 security-audit + 12 lint-hook)
- **Uncommitted changes:** This checkpoint only
- **Build status:** Clean
- **Pre-push hook:** Active in hub, blocks on security findings

## Blocked On

- Nothing

## Next Steps

### 1. Clean up stale fucina files
- `.claude/scaffold-sync.log` still exists in fucina (no longer written to). Delete it.
- fucina needs `.claude/lint.json` configured for Arduino/C++ stack (e.g., `platformio check`)

### 2. Enhance /init with LICENSE selection
- Ask user which license during init (MIT, Apache 2.0, GPL, none)
- Copy appropriate LICENSE file to project root

### 3. Consider format-on-write tests
- The format hook is now config-driven but lacks dedicated tests
- Could share test patterns with lint-hook.bats

### 4. Explore GitHub Actions CI template
- Template workflow that runs `bats tests/` and `bash scripts/security-audit.sh`
- Would give projects CI out of the box from /init

### 5. Hub README — remaining sections
- The "Complete File Manifest" section references some outdated files (INIT_PROMPT.md, HOW_TO_USE.md, SCAFFOLD_SYSTEM_PROMPT.md)
- Verify all referenced files still exist and remove stale entries
- Consider whether the manifest is redundant with GUIDE.md

## Determinism Notes

- **Pre-push hook worked as designed**: Caught fake tokens in test fixtures. The fix (allowlisting `.bats`) is correct — test files containing fake secrets are expected. No stochastic intervention needed.
- **Bootstrap worked automatically**: fucina pre-check detected stale script, copied new version, exited with BOOTSTRAPPED. Re-run succeeded. Fully deterministic.
- **No stochastic interventions this session**: All sync operations were deterministic (auto-update, take-scaffold, accept-new). No conflicts requiring judgment.

## Context Notes

- The pre-push hook is a git hook (`.git/hooks/pre-push`), not a Claude Code hook. It's not tracked in git (`.git/` is excluded). The template lives at `docs/templates/github/pre-push` and is copied by /init.
- `.claude/lint.json` is node-specific (not tracked by scaffold sync). Each project maintains its own linter/formatter config.
- The README file manifest may need pruning — some referenced files (INIT_PROMPT.md, HOW_TO_USE.md) may be from an older scaffold version.
