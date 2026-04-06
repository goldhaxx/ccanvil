# Checkpoint

> Feature: scaffold-terminology-eradication
> Last updated: 1775453686
> Plan hash: (no plan yet — spec is Draft)
> Session objective: Migrate downstream projects to ccanvil structure + write terminology eradication spec

## Accomplished

### Fucina migrated to ccanvil structure
- `scripts/` → `.ccanvil/scripts/`, `docs/scaffold-guide/` → `.ccanvil/guide/`, `docs/templates/` → `.ccanvil/templates/`
- `.claude/scaffold.lock` → `.ccanvil/ccanvil.lock`
- All `scaffold-*` commands → `ccanvil-*`, agent renamed
- settings.json merged: new hub base + PlatformIO permissions preserved
- tls-troubleshooting.md removed (in global config)
- settings.local.json paths updated
- Lockfile: 57 clean, 1 modified (settings.json), 3 local (node-only)
- Committed and pushed: `8dc86a5`

### Luxlook migrated to ccanvil structure
- Same directory/command/agent renames as fucina
- CLAUDE.md preserved project name/description, merged with new hub-managed section
- .github/ workflows and templates updated to new script paths
- CONTRIBUTING.md updated
- Lockfile: 56 clean, 2 modified (CLAUDE.md, scaffold.json)
- Committed locally: `73f01a8` (no remote configured)

### Bug found and fixed in hub: cmd_init() hub path mapping
- `cmd_init()` used raw `$scaffold_path` instead of `scaffold_dist_root()` for file hashing
- Caused freshly-copied CLAUDE.md to show as "modified" after init
- Fixed, tested (352/352 pass), committed and pushed: `18702ff`

### Terminology eradication spec written
- Comprehensive inventory: ~815 occurrences across 81 hub files, ~400+ in downstream projects
- 27 acceptance criteria covering scripts, lockfile keys, docs, commands, agents, rules, tests, downstream
- `scaffold-framework.md` brought INTO scope — renamed to `foundations.md` (scaffolding metaphor is inaccurate for persistent config)
- Committed and pushed: `f6741be`

### Lifecycle docs cleared
- spec.md, plan.md, checkpoint.md cleared after ccanvil-reorg completion
- Committed and pushed: `9670127`

## Current State

- **Branch:** `main` (no feature branch yet — spec is Draft, not activated)
- **Hub tests:** 352/352 passing
- **Working tree:** clean
- **Downstream:** Both fucina and luxlook migrated to new structure
- **Spec status:** Draft — ready to activate

## Next Steps

1. Activate the spec: `bash .ccanvil/scripts/docs-check.sh activate scaffold-terminology-eradication`
2. Run `/plan` to create the implementation plan
3. Begin TDD implementation starting with `ccanvil-sync.sh` (most complex, all lockfile key changes ripple from there)

## Determinism Review

- **operations_reviewed:** 12
- **candidates_found:** 2

**Manual downstream migration**: Claude ran ~15 manual commands per project (mkdir, cp, rm, edit ignore files, init lockfile) to migrate fucina and luxlook. This was a repeatable, mechanical process. Should be a `ccanvil-sync.sh migrate <hub-path>` subcommand that: detects old structure, creates new directories, copies fresh files from hub preset, moves node-only files, re-inits lockfile. Impact: **high** — every new downstream project migration would benefit.

**Manual lockfile inspection**: Claude ran `python3 -c "import json..."` to read lockfile status fields. Should be a `ccanvil-sync.sh status --json` or `ccanvil-sync.sh lock-get <file> status` subcommand. Impact: **medium** — already partially exists but no convenient filter for non-clean files.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
