# Implementation Plan: ideas-to-linear — pluggable idea capture + pre-activate push-guard

> Feature: ideas-to-linear
> Created: 1776828420
> Spec hash: 0a8c58a4
> Based on: docs/spec.md

## Objective

Land the 30 AC across 7 TDD cycles: replace git-tracked `docs/ideas.md` with a provider-routed idea pipeline (Linear MCP when configured, gitignored `.ccanvil/ideas.log` otherwise), bundled with a pre-activate push-guard — so both vectors of `ALLOW_MAIN=1`/local-main-divergence are closed in one PR that works cleanly on the hub and every downstream node.

## Sequence

Each step ends with the full bats suite green. Test files added incrementally per step.

### Step 1: Operations routing foundation — `idea.*` ops, dual adapter wiring

- **Test:** Extend `hub/tests/ideas-to-linear.bats` (new file). Assert: `operations.sh resolve idea.add` returns a `local`-provider bash command targeting `.ccanvil/ideas.log` when no Linear routing is set; with `routing.idea = "linear"` + provider config it returns an `mcp`-mechanism resolution with `mcp__claude_ai_Linear__save_issue` as the tool. Same shape tests for `idea.list`, `idea.triage`, `idea.sync`. Verify `is_valid_operation idea.add` returns 0.
- **Implement:** Extend `is_valid_operation` in `operations.sh` to recognize `idea.{add,list,triage,sync}`. Extend `local_adapter` with bash commands that read/write `.ccanvil/ideas.log` (JSONL schema per spec). Extend `linear_mcp_adapter` with case branches for each idea op (mapping to `save_issue`/`list_issues` with the right params pulled from provider config).
- **Files:** `.ccanvil/scripts/operations.sh`, `hub/tests/ideas-to-linear.bats` (new).
- **Verify:** Both providers resolve correctly depending on config. Existing operations.sh tests still pass.

### Step 2: Rewire `docs-check.sh` idea subcommands onto `.ccanvil/ideas.log`

- **Test:** Extend existing idea-subcommand bats (find and update the ones that currently target `docs/ideas.md`). Assert: `cmd_idea_add` appends a JSONL entry to `.ccanvil/ideas.log` (not `docs/ideas.md`); `cmd_idea_list` parses JSONL; `cmd_idea_count` returns correct totals by status; `cmd_idea_update` mutates the right line. Legacy `docs/ideas.md` is untouched if present (not read, not written).
- **Implement:** Rewrite `cmd_idea_add|list|count|update` in `.ccanvil/scripts/docs-check.sh`. Store file is `.ccanvil/ideas.log`. Format is JSONL `{uid, created, status, title, body, parent?}` per spec. Preserve the existing CLI contract (inputs, outputs) so callers don't change.
- **Files:** `.ccanvil/scripts/docs-check.sh`, updated bats in `hub/tests/docs-check.bats`.
- **Verify:** Local provider now fully works. Any project without Linear config gets the git-divergence fix immediately.

### Step 3: Pre-activate push-guard (AC-17/18/19)

- **Test:** New `hub/tests/activate-push-guard.bats`. Three fixtures: (a) local main ahead of origin/main → activate exits 1 with the unpushed-commit message; (b) same fixture with `--force-local-ahead` → activate proceeds; (c) repo with no `origin/main` → activate proceeds (guard is no-op).
- **Implement:** Add guard at the top of `cmd_activate` in `docs-check.sh` before the existing worktree-dirty check. Parse `--force-local-ahead` flag in the arg loop. Use `git rev-parse --verify origin/main` to detect AC-19 case.
- **Files:** `.ccanvil/scripts/docs-check.sh`, `hub/tests/activate-push-guard.bats` (new).
- **Verify:** Ship the guard independent of the Linear work — it's valuable on its own and the tests are hermetic.

### Step 4: Linear workspace setup + hub config isolation (AC-1/2/3/30)

- **Manual setup (one-time, documented):** In Linear UI (no MCP equivalent for status creation): Team Settings → Blocktech Solutions → Issue statuses & automations → add `Idea` (Backlog category) and `Icebox` (Backlog category). Also enable Triage on the team if not already on.
- **Automated setup:** Call `mcp__claude_ai_Linear__create_issue_label` once to create workspace-level `idea` label (color `#F2C94C`, the spec-defined description). Dogfood — record the issue created by step 6 below.
- **Test:** `hub/tests/ideas-to-linear.bats` grep-asserts `.claude/ccanvil.json` contains `"routing": {"idea": "linear"}` and `integrations.providers.linear` shared defaults (no `project`/`team`). Asserts `.claude/ccanvil.local.json` contains `project: "ccanvil"` + `team: "Blocktech Solutions"`. Asserts `git grep "ccanvil" .claude/ccanvil.json` returns 0 hits related to project identity (AC-30 isolation check).
- **Implement:** Edit hub `.claude/ccanvil.json` (shared defaults) and `.claude/ccanvil.local.json` (hub's own project/team). Create the `idea` label via MCP.
- **Files:** `.claude/ccanvil.json`, `.claude/ccanvil.local.json`, `hub/tests/ideas-to-linear.bats`.
- **Verify:** `bash .ccanvil/scripts/operations.sh resolve idea.add` on the hub returns a Linear MCP resolution targeting the `ccanvil` project.

### Step 5: `/idea` skill rewrite for dual-provider flow (AC-4/5/6/7/8/22/23)

- **Test:** Grep-assertions in `hub/tests/ideas-to-linear.bats` on `.claude/skills/idea/SKILL.md`. Verify: references `operations.sh resolve idea.add`, branches on the `mechanism` field, calls `mcp__claude_ai_Linear__save_issue` when Linear-routed, writes to `.ccanvil/ideas.log` when local, describes the title-summarization step (AC-4), names the short-text shortcut (AC-22), documents triage outcomes mapping (promote / merge / park / dismiss), references the pending-log behavior.
- **Implement:** Rewrite `.claude/skills/idea/SKILL.md` end-to-end. Capture flow: receive text → generate concise summary title (skip if text ≤80 chars + single-line) → call `operations.sh resolve idea.add` → dispatch based on mechanism → report issue ID (Linear) or UID (local) → return to prior task. List/triage flows: resolve the op, run the returned command/MCP call, render output. Triage maps outcomes to Linear native actions (`save_issue state=Backlog`, `duplicateOf=<parent>`, `state=Icebox`, `state=Canceled`).
- **Files:** `.claude/skills/idea/SKILL.md`, `hub/tests/ideas-to-linear.bats`.
- **Verify:** Grep tests pass. Manual sanity-check skill wording against AC list.

### Step 6: Offline pending log, `idea-sync`, `idea-migrate` (AC-9/10/11/12/13/20/21/27/29)

- **Test:** Extend `hub/tests/ideas-to-linear.bats`. Fixtures for: (a) pending-log append on simulated Linear failure — use a stub shim that exports `CCANVIL_MCP_STUB_FAIL=1` so the skill path detects it and falls through to pending; (b) `idea-sync` drains entries from a pending file; (c) `idea-migrate` on a fixture with existing `docs/ideas.md` + `routing.idea = "local"` writes entries to `.ccanvil/ideas.log`, `git rm`s the file, updates `.gitignore`; (d) same migrate with `routing.idea = "linear"` calls `save_issue` per entry (stubbed); (e) missing-config error path (AC-21); (f) unconfigured node defaults to local (AC-29 → same as 'local'); (g) migrate is idempotent when file absent (AC-13).
- **Implement:** Add `cmd_idea_sync` and `cmd_idea_migrate` to `docs-check.sh`. Error-handling hooks in skill to append to `.ccanvil/ideas-pending.log` on failure. `.gitignore` updater (append if not present). Config-resolution precedence: `routing.idea` unset defaults to `local`.
- **Files:** `.ccanvil/scripts/docs-check.sh`, `.claude/skills/idea/SKILL.md`, `hub/tests/ideas-to-linear.bats`.
- **Verify:** Full local + Linear flows work end-to-end including error modes.

### Step 7: Broadcast hint + hub migration + documentation sweep (AC-24/25/26/28)

- **Test:** Fixture in existing `hub/tests/ccanvil-sync.bats` (or new `broadcast-ideas-hint.bats`): registered node with a tracked `docs/ideas.md` → `broadcast` output contains the migration hint line naming that node. Node without `docs/ideas.md` → no hint. Separate grep tests on `.ccanvil/guide/command-reference.md` (Idea Management section updated, Linear dependency noted) and `docs-check.sh` (activate allowlist no longer includes `ideas.md`).
- **Implement:** Extend `cmd_broadcast` in `ccanvil-sync.sh` — per node, check if `docs/ideas.md` is tracked, print hint if so. Update `.ccanvil/guide/command-reference.md`. Remove `ideas.md` from the `cmd_activate` dirty-file allowlist in `docs-check.sh`. Run `docs-check.sh idea-migrate` on the hub to move its own `docs/ideas.md` entries to Linear (this is the first real dogfood). Update `.gitignore` with the two new lines.
- **Files:** `.ccanvil/scripts/ccanvil-sync.sh`, `.ccanvil/guide/command-reference.md`, `.ccanvil/scripts/docs-check.sh`, `.gitignore`, `docs/ideas.md` (deleted), `hub/tests/ccanvil-sync.bats` or new bats.
- **Verify:** 600+ bats tests green. `docs/ideas.md` absent. `/idea "test"` on hub creates a Linear issue in Triage. Downstream broadcast dry-run prints expected hints for nodes that still have `ideas.md`.

## Risks

- **MCP status creation isn't supported.** AC-1 requires `Idea` and `Icebox` statuses on the BTS team, but `create_issue_status` isn't in the MCP toolset. Mitigation: document the one-time UI setup step explicitly in Step 4 + in the skill's header. Verify via `list_issue_statuses` rather than auto-creating.
- **MCP stubbing in bats.** The skill is the dispatcher; `save_issue`/`list_issues` are invoked from Claude's tool layer, not bash. True end-to-end tests aren't practical in bats. Mitigation: bats covers the script layer (operations.sh, docs-check.sh idea-sync/migrate, broadcast hint) and grep-asserts skill wording. The Linear round-trip itself is verified by dogfooding — Step 7's hub migration + a final /idea test issue confirm the full flow works.
- **Config precedence bugs.** Merging `ccanvil.json` (shared) with `ccanvil.local.json` (per-node) is already handled by `merge_config` — but edge cases around partial Linear configs need explicit tests. Mitigation: AC-21 tests three states (routing=linear + missing provider, routing=local, routing unset) and asserts the correct fallback.
- **Broadcast hint cost.** Checking every registered node for tracked `docs/ideas.md` adds a `git ls-files` call per node during broadcast. With a dozen nodes this is cheap, but worth keeping a no-op fast path for nodes whose lockfile declares no `docs/ideas.md`.
- **Dogfooding the hub migration mid-PR.** The hub currently tracks `docs/ideas.md`. Step 7 migrates + deletes it. If something goes wrong after migration but before PR merge, entries could be lost. Mitigation: migration creates Linear issues first, THEN `git rm`s the file — Linear issues survive any local rollback.

## Definition of Done

- [ ] All 30 AC from `docs/spec.md` pass.
- [ ] `hub/tests/ideas-to-linear.bats` + `hub/tests/activate-push-guard.bats` green; existing tests still pass.
- [ ] Hub's `docs/ideas.md` migrated to Linear Triage (dogfood).
- [ ] `/idea "test capture"` on the hub creates a new Linear Triage issue with correct title + description + label + status.
- [ ] `ccanvil-sync.sh broadcast --dry-run` prints migration hints for every downstream node still carrying `docs/ideas.md`.
- [ ] `docs-check.sh activate` halts on a local-ahead-of-origin fixture; `--force-local-ahead` bypasses cleanly.
- [ ] Code reviewed via `/pr`.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
