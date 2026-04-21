# Implementation Plan: Stasis & Recall

> Feature: stasis-recall
> Created: 1776795339
> Spec hash: 65a46071
> Based on: docs/spec.md

## Objective

Comprehensively rename ccanvil's session-boundary surface from checkpoint/catchup → stasis/recall (verbs, artifact filename, template, internal identifiers, guide references), expand `/stasis`'s scope beyond the current checkpoint (security + cross-session + memory-candidates), add downstream migration logic, and add an ongoing legacy-refs-scan safety net — all in one branch, no compat shims.

## Sequence

### Step 1: Template rename + three new sections
- **Test:** `.ccanvil/templates/stasis.md` exists, contains required headings including `## Cross-Session Patterns`, `## Security Review`, `## Memory Candidates`. `.ccanvil/templates/checkpoint.md` does NOT exist.
- **Implement:** Copy the current checkpoint template contents, rename file, append the three new sections with placeholders matching the existing template style.
- **Files:** `.ccanvil/templates/stasis.md` (new), `.ccanvil/templates/checkpoint.md` (delete).
- **Verify:** `ls .ccanvil/templates/stasis.md` succeeds; `! ls .ccanvil/templates/checkpoint.md`.

### Step 2: docs-check.sh — artifact path + state name rename
- **Test:** Add bats that asserts `cmd_status` reads from `docs/stasis.md`, `cmd_validate` returns `stale-stasis` (not `stale-checkpoint`) in the stale case, and variable names in the script are `stasis_*` (grep assertion on script source).
- **Implement:** In `.ccanvil/scripts/docs-check.sh`: replace all `docs/checkpoint.md` → `docs/stasis.md`, `checkpoint.md` → `stasis.md`, `cp_entry/cp_exists/cp_fid/cp_stored_plan_hash` → `stasis_entry/stasis_exists/stasis_fid/stasis_stored_plan_hash`, `stale-checkpoint` → `stale-stasis`, `cmd_validate`'s result-priority comment, `cmd_recommend`'s branch string + reason, `Checkpoint exists` etc. in reasons. Leave `missing-determinism-review` untouched (per AC-18).
- **Files:** `.ccanvil/scripts/docs-check.sh`, `hub/tests/stasis-recall.bats` (new file, first tests).
- **Verify:** Existing docs-check.sh bats tests updated and green; new stasis-state tests green.

### Step 3: operations.sh op rename
- **Test:** `operations.sh resolve stasis.read` returns invocation; `operations.sh resolve stasis.write` returns invocation; `operations.sh resolve checkpoint.read` returns unknown/error.
- **Implement:** Rename two operation entries in operations.sh (`checkpoint.read` → `stasis.read`, `checkpoint.write` → `stasis.write`). Update the commands they emit (`cat docs/checkpoint.md` → `cat docs/stasis.md`, `cp .ccanvil/templates/checkpoint.md docs/checkpoint.md` → stasis paths). Update the `checkpoint.{read,write}` validation in the known-ops list.
- **Files:** `.ccanvil/scripts/operations.sh`, `hub/tests/stasis-recall.bats`.
- **Verify:** Existing operations.sh bats tests pass after rename; new resolve tests pass.

### Step 4: CI workflow template + manifest.lock paths
- **Test:** CI template grep pattern references `docs/stasis.md`. manifest.lock has `.ccanvil/templates/stasis.md` entry (and `docs/stasis.md` if the existing docs/checkpoint.md entry stays tracked — verify whether it's an active path or just historical).
- **Implement:** Update `.ccanvil/templates/github/workflows/ci.yml` grep pattern. Update `.claude/manifest.lock` path entries. Check `.claudeignore` patterns.
- **Files:** `.ccanvil/templates/github/workflows/ci.yml`, `.claude/manifest.lock`, `.claudeignore` (if needed).
- **Verify:** Manifest hash check passes; CI template grep catches correct file.

### Step 5: cmd_complete + pr skill cleanup list
- **Test:** `cmd_complete` removes `docs/stasis.md`; running `/pr`'s cleanup step references stasis.md in its removal list.
- **Implement:** `.ccanvil/scripts/docs-check.sh` `cmd_complete`: update `rm -f` path. `.claude/skills/pr/SKILL.md` (or equivalent): update lifecycle cleanup list from `docs/checkpoint.md` → `docs/stasis.md`.
- **Files:** `.ccanvil/scripts/docs-check.sh`, `.claude/skills/pr/SKILL.md`.
- **Verify:** `cmd_complete` test exercises stasis.md removal; pr skill grep confirms update.

### Step 6: legacy-refs-scan subcommand (new)
- **Test:** Given a fixture project dir with known legacy refs (`/catchup` in a markdown file above NODE-SPECIFIC marker, `docs/checkpoint.md` referenced in a script, `/checkpoint` in node-specific content), `docs-check.sh legacy-refs-scan` returns JSON with each match, classified as `hub-owned` or `node-specific`, and exits 1. Clean project exits 0.
- **Implement:** New `cmd_legacy_refs_scan` function in `.ccanvil/scripts/docs-check.sh`. Scans for patterns `/catchup`, `/checkpoint`, `docs/checkpoint.md`, `checkpoint\.(read|write)`, `stale-checkpoint`. For each match, determines scope by checking whether the line is above or below `<!-- NODE-SPECIFIC-START -->` in files that have that marker. Emits JSON array `[{file, line, match, scope}]`.
- **Files:** `.ccanvil/scripts/docs-check.sh`, `hub/tests/legacy-refs-scan.bats` (new).
- **Verify:** 3-4 bats tests cover: clean repo (exit 0), legacy matches (exit 1), scope classification, empty project.

### Step 7: ccanvil-sync.sh migration — artifact rename
- **Test:** Downstream node with `docs/checkpoint.md` and no `docs/stasis.md` → after broadcast/pull-apply, file is git-mv'd to `docs/stasis.md`. Both-exist case aborts with clear message. Idempotent — second run no-ops.
- **Implement:** New `migrate_stasis_artifact` function in `.ccanvil/scripts/ccanvil-sync.sh`. Called from `cmd_pull_apply` (and/or broadcast per-node loop). Performs `git mv` when conditions met; appends `migrate_stasis_rename` event to `.ccanvil/events.log`.
- **Files:** `.ccanvil/scripts/ccanvil-sync.sh`, `hub/tests/stasis-migration.bats` (new).
- **Verify:** 3 bats tests: happy-path rename, both-exist abort, idempotency.

### Step 8: ccanvil-sync.sh migration — legacy command file cleanup
- **Test:** Downstream node with `.claude/commands/catchup.md` → migration deletes it. Missing file → no-op.
- **Implement:** Extend `migrate_stasis_artifact` to also remove `.claude/commands/catchup.md` when present.
- **Files:** `.ccanvil/scripts/ccanvil-sync.sh`, `hub/tests/stasis-migration.bats`.
- **Verify:** 2 bats tests (exists + deleted, absent + no-op).

### Step 9: /recall skill (port from catchup, delete old command file)
- **Test:** `.claude/skills/recall/SKILL.md` exists, contains all the data-gathering steps equivalent to current catchup (validate, recommend, backlog.list, branch, stasis read, git log, etc.), reads from `docs/stasis.md`, references `/stasis` not "checkpoint". `.claude/commands/catchup.md` does NOT exist.
- **Implement:** Create new skill file following `.claude/skills/radar/SKILL.md` format. Port content from catchup.md with all path + verb updates. Delete the old command file.
- **Files:** `.claude/skills/recall/SKILL.md` (new), `.claude/commands/catchup.md` (delete).
- **Verify:** Grep for "catchup" in `.claude/` returns zero results; recall skill grep check passes.

### Step 10: /stasis skill (new, includes legacy-refs-scan invocation)
- **Test:** `.claude/skills/stasis/SKILL.md` exists, has "Data gathering (deterministic)" section listing all scripts from AC-2, has "Synthesis" section describing the Cross-Session Patterns (including `legacy-refs-scan` call), Security Review, Memory Candidates sections. Closes with "Run `/compact` to wrap session" directive line. References `git show HEAD~1:docs/stasis.md` for prior-state diff (AC-5, AC-10).
- **Implement:** Follow `.claude/skills/radar/SKILL.md` structural pattern. Deterministic data-gathering calls, synthesis prompts, explicit next-action close.
- **Files:** `.claude/skills/stasis/SKILL.md` (new).
- **Verify:** Grep assertions for required sections and script invocations.

### Step 11: Rules rename — workflow.md + self-review.md
- **Test:** Grep for `checkpoint` or `catchup` in `.claude/rules/workflow.md` and `.claude/rules/self-review.md` returns zero results. workflow.md contains `Run /stasis before /compact`; self-review.md references `docs/stasis.md`.
- **Implement:** Edit both rules files per AC-22, AC-23.
- **Files:** `.claude/rules/workflow.md`, `.claude/rules/self-review.md`.
- **Verify:** Grep assertions.

### Step 12: Guide + README + hub/meta rename
- **Test:** Grep for `checkpoint` or `catchup` in `.ccanvil/guide/*.md`, `hub/meta/*.md`, and `README.md` returns zero unexpected matches. Mermaid diagrams updated.
- **Implement:** Edit each file with find/replace for vocabulary + update Mermaid node labels + update command-reference.md table (remove "Checkpoint this" and /catchup rows, add /stasis and /recall rows).
- **Files:** `.ccanvil/guide/session-management.md`, `.ccanvil/guide/decision-guide.md`, `.ccanvil/guide/command-reference.md`, `.ccanvil/guide/system-overview.md`, `.ccanvil/guide/configuration.md`, `.ccanvil/guide/index.md`, `hub/meta/SYSTEM_PROMPT.md`, `hub/meta/HOW_TO_USE.md`, `README.md`.
- **Verify:** Grep sweep; manual Mermaid render check if feasible.

### Step 13: Comprehensive grep verification (AC-29)
- **Test:** New bats test runs the AC-29 grep command and asserts output matches only the documented allowlist (git's literal checkpoint feature, archived spec references, migration-test fixtures).
- **Implement:** Define the allowlist regex as a file (e.g., `hub/tests/legacy-refs-allowlist.txt`). Bats test greps, filters against allowlist, asserts empty remainder.
- **Files:** `hub/tests/legacy-refs-allowlist.txt` (new), `hub/tests/stasis-recall.bats`.
- **Verify:** Test passes. Any unexpected hit = CI failure = pre-merge guard.

### Step 14: /stasis invokes legacy-refs-scan in Cross-Session Patterns
- **Test:** `/stasis` SKILL.md text instructs the model to call `docs-check.sh legacy-refs-scan` as part of the Cross-Session Patterns section. (AC-37)
- **Implement:** Update the `/stasis` skill's Cross-Session Patterns synthesis prompt to include the scan call and report findings.
- **Files:** `.claude/skills/stasis/SKILL.md`.
- **Verify:** Grep assertion; content review.

### Step 15: Hub guide documentation pass (updated workflow)
- **Test:** `.ccanvil/guide/session-management.md` and `.ccanvil/guide/command-reference.md` describe the new `/stasis` + `/recall` workflow, including the migration that runs during broadcast/pull-apply.
- **Implement:** Extend the guide docs beyond mechanical rename to explain: what `/stasis` does vs the old checkpoint, how migration works for existing downstream nodes, what `legacy-refs-scan` catches. This is the hub-section update per the plan skill's step-7 guidance.
- **Files:** `.ccanvil/guide/session-management.md`, `.ccanvil/guide/command-reference.md` (hub sections, above `<!-- NODE-SPECIFIC-START -->`).
- **Verify:** Content review; table entries present; migration behavior documented.

### Step 16: CLAUDE.md hub-section update (if workflow sentence changed)
- **Test:** Hub-managed section of `CLAUDE.md` references `/stasis` + `/recall` where previously it referenced checkpoint/catchup (if at all).
- **Implement:** Check CLAUDE.md for any mentions; update hub section below `<!-- HUB-MANAGED-START -->`. If no mentions exist today, skip this step.
- **Files:** `CLAUDE.md` (hub section only).
- **Verify:** Grep check.

## Risks

- **Partial migration on downstream nodes.** If a node runs broadcast/pull while mid-edit of `docs/checkpoint.md`, the `git mv` could conflict. Mitigation: migration checks dirty-tree state and aborts with clear message (AC-34 path).
- **Test suite breakage from the state-name rename.** Existing bats tests that assert on `stale-checkpoint` will fail. Mitigation: find all such tests in Step 2's red phase, update assertion strings in the same TDD cycle.
- **manifest.lock drift.** The lockfile has content hashes tied to file paths. Renaming a tracked file means the old path's entry needs deletion + the new path's entry needs re-hashing. Mitigation: Step 4 includes explicit lockfile audit; any stale entries surface via `manifest-check.sh hash-check`.
- **"checkpoint" as an English word in prose.** The grep in AC-29 can produce false positives on legitimate uses (e.g., a docstring that uses "checkpoint" conceptually for something unrelated). Mitigation: explicit allowlist file (Step 13); any new addition requires justification.
- **/compact interaction.** `/compact` is a built-in that compresses context. If a user runs `/compact` without first running `/stasis`, their Cross-Session Patterns data disappears. Mitigation: keep workflow.md + guide emphatic that `/stasis` precedes `/compact`, plus `/stasis`'s closing directive forces the habit.
- **Downstream nodes that skip a pull.** A node that doesn't sync for weeks and then pulls may find a mid-stream migration state. Mitigation: migration is idempotent (AC-31); `legacy-refs-scan` surfaces any residual drift; `/stasis` invokes the scanner every session.

## Definition of Done

- [ ] All 38 acceptance criteria from spec pass (stasis-recall.bats, stasis-migration.bats, legacy-refs-scan.bats all green)
- [ ] All existing bats tests still pass (541+ total, pre-merge count confirmed)
- [ ] AC-29 grep sweep returns only allowlisted entries
- [ ] Migration verified on a real downstream node (at minimum: one test node broadcast-synced cleanly post-merge)
- [ ] Code reviewed (run `/review`)
- [ ] Linear BTS-75 title updated from "Pylon" → "Stasis & Recall"

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
