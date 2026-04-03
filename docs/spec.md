# Feature: ccanvil rename and reorganization

> Feature: ccanvil-reorg
> Created: 1775015228
> Status: Draft

## Summary

Rename the project from "claude-code-scaffold" to "ccanvil" and reorganize the repo so that hub-only artifacts (tests, specs, research) are cleanly separated from distributable artifacts (rules, commands, scripts, templates). Downstream projects receive a `.ccanvil/` directory for preset infrastructure, keeping project roots clean and preset artifacts clearly identifiable. All tech-stack opinions (bats, TLS/WARP) are removed from distributed config so downstream projects are never muddied by hub-specific tooling.

## Job To Be Done

**When** I run `/init` in a new project,
**I want** only framework-agnostic preset artifacts to land in clearly namespaced directories,
**So that** downstream projects stay clean, preset artifacts are instantly recognizable, and no hub-specific opinions leak.

## Acceptance Criteria

Each criterion is independently testable. Binary pass/fail.

### Rename

- [ ] **AC-1:** GitHub repo is renamed to `ccanvil`. README, CLAUDE.md, and all internal references use the name "ccanvil" (not "claude-code-scaffold" or "scaffold" as a project name).
- [ ] **AC-2:** All sync script references, lockfile paths, and command docs use "ccanvil" terminology where referring to the project. The technical verb "scaffold" may be preserved where it describes the syncing concept (open question — see below).

### Hub vs preset separation

- [ ] **AC-3:** A `preset/` directory exists at the repo root containing ONLY artifacts that go to downstream projects. `/init` copies exclusively from `preset/`.
- [ ] **AC-4:** A `hub/` directory exists at the repo root containing ONLY artifacts used for developing ccanvil itself: tests, specs, research, meta-docs (HOW_TO_USE.md, INIT_PROMPT.md, SCAFFOLD_SYSTEM_PROMPT.md, GLOBAL_CLAUDE.md).
- [ ] **AC-5:** No file outside `preset/` is copied to downstream projects during init.

### .ccanvil/ namespace in downstream projects

- [ ] **AC-6:** After `/init`, all preset scripts live under `.ccanvil/scripts/` (not `scripts/` at project root).
- [ ] **AC-7:** After `/init`, all preset guide docs live under `.ccanvil/guide/` (not `docs/scaffold-guide/`).
- [ ] **AC-8:** After `/init`, all preset templates live under `.ccanvil/templates/` (not `docs/templates/`).
- [ ] **AC-9:** The downstream project's `docs/` directory contains ZERO preset artifacts — it is entirely project-owned.
- [ ] **AC-10:** The downstream project root contains no preset artifacts except `CLAUDE.md`, `.claudeignore`, `.claude/`, and `.ccanvil/`.

### Framework-agnostic distributed config

- [ ] **AC-11:** The distributed `CLAUDE.md` template does NOT mention bats, bats-core, or any specific test runner in hub-managed sections. Tech Stack and Commands sections are NODE-SPECIFIC.
- [ ] **AC-12:** The distributed `settings.json` does NOT contain `Bash(bats:*)` or any tech-stack-specific permissions.
- [ ] **AC-13:** The distributed rules do NOT include `tls-troubleshooting.md` (it moves to hub-only or global user config).
- [ ] **AC-14:** The distributed CI workflow template (`ci.yml`) does NOT hardcode bats installation. It uses a generic placeholder for the project's test command.
- [ ] **AC-15:** The TDD rule and TDD skill reference "the project's test command" generically, not a specific test runner.

### Sync integrity

- [ ] **AC-16:** Sync tracked patterns are updated to reflect the new directory structure (`.ccanvil/scripts/*.sh`, `.ccanvil/guide/*.md`, `.ccanvil/templates/*.md`).
- [ ] **AC-17:** All commands that reference script paths (e.g., `scripts/scaffold-sync.sh`) are updated to use `.ccanvil/scripts/` paths.
- [ ] **AC-18:** All hooks that reference script paths are updated to the new `.ccanvil/` paths.

### Tests pass

- [ ] **AC-19:** All existing bats tests pass after the reorganization (paths in tests updated accordingly).
- [ ] **AC-20:** The hub's own CLAUDE.md (not the template) retains bats config since the hub itself uses bats.

## Affected Files

| Area | Change |
|------|--------|
| Repo root | New `preset/`, `hub/` directories |
| `preset/.ccanvil/scripts/` | Moved from `scripts/` |
| `preset/.ccanvil/guide/` | Moved from `docs/scaffold-guide/` |
| `preset/.ccanvil/templates/` | Moved from `docs/templates/` |
| `preset/.claude/` | Rules, commands, agents, skills, hooks, settings (minus bats/tls opinions) |
| `preset/CLAUDE.md` | Template with NODE-SPECIFIC tech stack and commands |
| `hub/tests/` | Moved from `tests/` |
| `hub/specs/` | Moved from `docs/specs/` |
| `hub/research/` | Moved from `docs/research/` |
| `hub/meta/` | HOW_TO_USE.md, INIT_PROMPT.md, SCAFFOLD_SYSTEM_PROMPT.md, GLOBAL_CLAUDE.md |
| `scripts/scaffold-sync.sh` | Updated tracked patterns, paths, terminology |
| `.claude/commands/*.md` | Updated script path references |
| `.claude/hooks/*.sh` | Updated path references |
| `.claude/settings.json` | Removed bats permission, updated hook paths |
| `.claude/rules/tls-troubleshooting.md` | Removed from distributed rules |
| `global-commands/init.md` | Updated to copy from `preset/`, new directory structure |
| Root `CLAUDE.md` | Hub's own config — retains bats, describes new repo layout |

## Dependencies

- **Requires:** None — this is a reorganization of existing artifacts.
- **Blocked by:** Nothing.
- **Note:** GitHub repo rename is a manual step (Settings > General > Repository name).

## Out of Scope

- **Packs system** — tech-specific extensions (bash, typescript, python) are a future feature.
- **Renaming the local directory** — `~/projects/claude-code-scaffold/` → `~/projects/ccanvil/` is a separate manual step.
- **Migrating fucina** — updating fucina's lockfile and directory structure is a follow-up after this lands.
- **`.claude/` vs `.ccanvil/` boundary refinement** — the exact split may evolve. This spec establishes the initial boundary. Future specs may adjust.

## Open Questions

1. **Command naming:** Should `/scaffold-pull`, `/scaffold-push`, etc. become `/ccanvil-pull`, `/ccanvil-push`? Or keep "scaffold" as a verb? Leaning: rename for consistency.
2. **Script naming:** Should `scaffold-sync.sh` become `ccanvil-sync.sh`? Leaning: yes.
3. **Lockfile location:** Should the lockfile move from `.claude/scaffold.lock` to `.ccanvil/ccanvil.lock`? Leaning: yes — it's preset infrastructure.
4. **Downstream migration:** Do we need a migration script/command for existing downstream projects (fucina), or is manual update acceptable for now? Leaning: manual for now, migration script in a follow-up.

## Implementation Notes

- Break into phases: (1) create directory structure + move files, (2) update all internal references, (3) update tests, (4) update init command, (5) verify full test suite.
- The hub's own `CLAUDE.md` at repo root is NOT the template. It describes the hub's actual stack (bash + bats).
- `tls-troubleshooting.md` should move to Zach's global `~/.claude/CLAUDE.md` or `~/.claude/rules/` since it's personal to his Cloudflare WARP environment, not a preset concern.
