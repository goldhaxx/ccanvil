# Feature: Init Completeness

> Feature: init-completeness
> Created: 1776108528
> Status: In Progress

## Summary

New projects initialized with `/init` are missing two things: a default .gitignore and automatic hub registration. Without .gitignore, the first commit includes OS junk (.DS_Store) and local-only files. Without registration, the hub doesn't know the project exists until the user manually runs `register`.

## Job To Be Done

**When** initializing a new ccanvil project,
**I want to** get a sensible .gitignore and be registered with the hub automatically,
**So that** the project is immediately production-ready and discoverable.

## Acceptance Criteria

Each criterion is independently testable. Binary pass/fail.

- [ ] **AC-1:** A .gitignore template exists at `.ccanvil/templates/.gitignore` with OS, IDE, env, and ccanvil-specific patterns
- [ ] **AC-2:** `init-preflight` includes `.gitignore` in its plan for empty projects (action: copy)
- [ ] **AC-3:** `init-preflight` recommends `review` when a local .gitignore already exists and differs from template
- [ ] **AC-4:** `cmd_init` automatically calls `cmd_register` after generating the lockfile (no advisory message)
- [ ] **AC-5:** After a full init flow on an empty project, `.gitignore` exists with expected patterns
- [ ] **AC-6:** After a full init flow, the project is registered in the hub's registry.json
- [ ] **AC-7:** Edge: `cmd_init` handles registration failure gracefully (warning, not fatal)

## Affected Files

| File | Change |
|------|--------|
| `.ccanvil/templates/.gitignore` | New — default gitignore template |
| `.ccanvil/scripts/ccanvil-sync.sh` | Modified — add .gitignore to INIT_EXTRA_FILES, auto-register in cmd_init |
| `hub/tests/ccanvil-sync.bats` | Modified — new tests for AC-1 through AC-7 |
| `global-commands/init.md` | Modified — remove manual registration step mention |

## Dependencies

- **Requires:** BTS-68 (init format fix) — merged
- **Blocked by:** None

## Out of Scope

- Project-specific .gitignore patterns (e.g., PlatformIO, Next.js) — those are added by the user after init
- Changes to the existing register/registry commands
- Updating existing downstream projects' .gitignore files

## Implementation Notes

- The .gitignore template should contain only universal patterns (OS, IDE, env, ccanvil internals) — no framework-specific entries
- Add `.gitignore` to `INIT_EXTRA_FILES` array so `init-preflight` discovers it via `scan_hub_files`
- In `cmd_init`, replace the advisory message block (lines 258-268) with a direct `cmd_register` call wrapped in `|| echo "WARNING: ..."`
- Registration requires a lockfile, which `cmd_init` just created — so ordering is correct
