# Feature: Fresh-mode CLAUDE.md template wedge

> Feature: bts-327-fresh-mode-claudemd-template
> Work: linear:BTS-327
> Created: 1778638083
> Subject: Fresh-mode CLAUDE.md template wedge
> Status: Complete

## Summary

`/ccanvil-init` in `fresh` mode copies the hub's actual `CLAUDE.md` verbatim into the new project. The hub's `CLAUDE.md` has hub-specific operator content (title `# ccanvil`, hub tech stack `Bash (preset automation scripts)`, hub commands like `bats hub/tests/`, hub architecture diagram) above the `<!-- HUB-MANAGED-START -->` delimiter — and that entire block becomes the new project's "node-specific" prefix. Step 8 of the init skill then attempts to sed-replace `[Project Name]` and `[One-line description.]` placeholders that don't exist in the copied file. Net result: fresh projects ship with `# ccanvil` as their title and hub-stack prose as their tech-stack section.

Add a dedicated template at `.ccanvil/templates/CLAUDE.md.fresh` with clean placeholders for the node section. In `fresh` mode (only), `cmd_init_preflight` + `cmd_init_apply` use that template as the hub source for `CLAUDE.md` instead of the hub's root `CLAUDE.md`. Mature-repo and partial-ccanvil flows are unchanged.

## Job To Be Done

**When** I run `/ccanvil-init` on a fresh project,
**I want to** end up with a `CLAUDE.md` whose node-specific (pre-delimiter) section contains clean placeholders for project name, description, tech stack, commands, and architecture,
**So that** Step 8's sed pass can substitute real project metadata — and the new project doesn't ship with `# ccanvil` and hub-stack prose as its identity.

## Acceptance Criteria

- [ ] **AC-1:** `.ccanvil/templates/CLAUDE.md.fresh` exists at the hub. Its node section (above `<!-- HUB-MANAGED-START -->`) contains line-leading placeholder strings: `[Project Name]`, `[One-line description.]`, `[Tech Stack TBD]`, `[Commands TBD]`, `[Architecture TBD]`. Its hub-managed section (below the delimiter) is byte-identical to the hub root `CLAUDE.md`'s hub-managed section.
- [ ] **AC-2:** When `cmd_init_preflight` runs in `project_mode == "fresh"` AND emits a plan entry for `CLAUDE.md`, the entry resolves its hub source to `.ccanvil/templates/CLAUDE.md.fresh` (not the hub root `CLAUDE.md`). Other plan entries unaffected.
- [ ] **AC-3:** After `cmd_init_apply` completes in fresh mode, the project's `CLAUDE.md` contains the literal strings `[Project Name]` and `[One-line description.]` in the node section, and does NOT contain `# ccanvil` or `bats hub/tests/`.
- [ ] **AC-4:** Step 8 of the `/ccanvil-init` skill prose (the sed-substitution pass against `[Project Name]` / `[One-line description.]`) succeeds — i.e., the placeholders are present in the on-disk file when Step 8 runs.
- [ ] **AC-5:** `project_mode` values `mature-repo`, `partial-ccanvil`, `already-initialized`, and `source-no-git` continue to use the hub root `CLAUDE.md` as their hub source. The mode-aware branches at `classify_file` (ccanvil-sync.sh:759) for mature-repo `section-merge-create-delimiters` and for partial-ccanvil are unchanged.
- [ ] **AC-6:** After a fresh-mode init, the project's `CLAUDE.md` contains exactly one `<!-- HUB-MANAGED-START -->` line, and the bytes from that delimiter forward byte-match the hub root `CLAUDE.md`'s hub-managed section. (Ensures `/ccanvil-pull` sees no drift on the hub-managed half immediately after init.)
- [ ] **AC-7 (error):** When `project_mode == "fresh"` but `.ccanvil/templates/CLAUDE.md.fresh` is missing from the hub, `cmd_init_preflight` fails fast with a clear stderr `ERROR: fresh-mode CLAUDE.md template not found at <path>` and exits non-zero. (Prevents silent regression to the broken pre-fix behavior.)
- [ ] **AC-8 (edge):** A re-run of `cmd_init_preflight` after the fresh-mode init completed (now `already-initialized`) does NOT emit a new fresh-template plan entry for `CLAUDE.md`. The `already-initialized` short-circuit at `detect_project_mode` (ccanvil-sync.sh:617) gates this.

## Affected Files

| File | Change |
|------|--------|
| `.ccanvil/templates/CLAUDE.md.fresh` | New — template with node-section placeholders + hub-managed mirror |
| `.ccanvil/scripts/ccanvil-sync.sh` | Modified — `classify_file` fresh-mode branch resolves CLAUDE.md source to template; `cmd_init_apply` reads from same |
| `hub/tests/init-fresh-claudemd.bats` | New — fresh-mode init produces placeholder CLAUDE.md, not hub content |

## Dependencies

- **Requires:** `detect_project_mode` (ccanvil-sync.sh:616) — already shipping `fresh` classification.
- **Requires:** existing `<!-- HUB-MANAGED-START -->` delimiter in hub's `CLAUDE.md` at line 46 — already present.
- **Blocked by:** none.

## Out of Scope

- Restructuring the hub's own `CLAUDE.md` (it stays hub-specific by design; this spec only adds a parallel template).
- Hub/node separation refactor — that's BTS-460, separate effort.
- Changes to `mature-repo`, `partial-ccanvil`, `already-initialized`, or `source-no-git` flows.
- Step 8 sed-substitution logic itself — no change needed; it works once placeholders are present.
- README.md / CONTRIBUTING.md template wedges (similar pattern; not in this ticket's scope).
- Auto-generating tech stack / commands / architecture content during init.

## Implementation Notes

- Follow the existing classification override pattern at ccanvil-sync.sh:755-781 (`AC-4: Mode-aware overrides for mature-repo / partial-ccanvil`). Add a parallel `if [[ "$project_mode" == "fresh" ]]` branch for `CLAUDE.md` that switches the hub source path. Same predictability shape as the mature-repo case.
- The plan-entry `recommended_action` stays `copy`; only the hub-source path differs. This keeps `cmd_init_apply`'s `copy|overwrite` branch (ccanvil-sync.sh:991) unchanged — it still does a verbatim `cp`, just from a different source file.
- Hub-managed section mirroring: the template should embed an `@hub-managed-mirror: CLAUDE.md` comment or be regenerated by a small script. For first ship, hand-author the mirror and accept that it must be updated when the hub's hub-managed section changes. Future-cycle: add a drift-guard test that diffs the two hub-managed sections (out of scope here).
- TDD order: AC-7 (missing-template error) first — pure error path, no template needed. Then AC-1 (template content), AC-2 (preflight resolves correct source), AC-3 (apply produces expected file), AC-4/AC-5/AC-6/AC-8 fall out of the substrate change naturally. AC-7 is the smallest meaningful first test.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
