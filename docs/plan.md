# Implementation Plan: drift-watchdog

> Feature: bts-21-drift-watchdog
> Work: linear:BTS-21
> Created: 1777226400
> Spec hash: f0711c02
> Based on: docs/spec.md

## Objective

Ship a Claude Code-native scheduled drift-watchdog as substrate (3 ccanvil-sync.sh subcommands + 1 skill + 1 agent + drift-guard tests), with launchd as the schedule trigger, idempotent issue creation via the http substrate, and zero MCP coupling.

## Sequence

### Step 1: drift-watchdog-list — happy path
- **Test:** Empty registry → `[]`. One node with `last_synced_version == current HEAD` → `[]`.
- **Implement:** New `cmd_drift_watchdog_list` in `ccanvil-sync.sh`. Reads `.ccanvil/registry.json`, gets current hub HEAD via `git rev-parse HEAD`, iterates nodes, emits `[]` when no drift.
- **Files:** `.ccanvil/scripts/ccanvil-sync.sh`, `hub/tests/drift-watchdog.bats`.
- **Verify:** Both tests green.

### Step 2: drift-watchdog-list — drift detection
- **Test:** Node with `last_synced_version` ≠ current HEAD → emits `[{node_uuid, node_name, drift_key, paths_drifted[], commits_behind, summary}]`.
- **Implement:** For each drifted node, `git log --name-only <last_synced_version>..HEAD` to get touched paths, filter to hub-tracked paths via existing `is_node_only` / scan helpers, compute drift_key as `sha256("$node_name:" + sorted-paths-joined-by-newline) | head -c 16`. Summary = "N commits behind, M paths touched".
- **Files:** Same.
- **Verify:** Test asserts JSON shape, drift_key length 16, sorted paths.

### Step 3: drift-watchdog-list — read-only drift-guard (AC-2)
- **Test:** awk-bound `cmd_drift_watchdog_list` function range; grep within asserts no `git -C` write subcommand (`git -C <path> commit|add|push|reset|checkout`), no `>` redirections to `.json`/`.lockfile` paths, no `commit_node_file` invocations.
- **Implement:** No code change — test asserts the function as written never mutates.
- **Files:** `hub/tests/drift-watchdog.bats`.
- **Verify:** Test green.

### Step 4: drift-watchdog-preflight (AC-6)
- **Test:** With both `command -v claude` and `linear-query.sh viewer` mocked to succeed → `{"claude_p_available": true, "linear_query_works": true}`. With either failing → respective field is `false`. Test stubs the commands by prepending PATH.
- **Implement:** New `cmd_drift_watchdog_preflight` runs the two checks, builds JSON via `jq -n --argjson claude --argjson linear`.
- **Files:** Same.
- **Verify:** All 4 mock combinations pass.

### Step 5: drift-watchdog-launchd-print (AC-9)
- **Test:** Output contains `<key>Label</key>`, `com.ccanvil.drift-watchdog`, `<key>StartCalendarInterval</key>`, `<key>Weekday</key>` `<integer>1</integer>`, `<key>Hour</key>` `<integer>9</integer>`, `<key>Minute</key>` `<integer>13</integer>`, `claude -p` and `/drift-watchdog`. Output parses cleanly via `xmllint --noout` (or `plutil -lint -` on stdin if available — pick what's portable).
- **Implement:** New `cmd_drift_watchdog_launchd_print` emits a heredoc with the .plist body. WorkingDirectory hard-codes `git rev-parse --show-toplevel` of the hub.
- **Files:** Same.
- **Verify:** Tests green; launchd validity check passes.

### Step 6: drift-analyst sub-agent (AC-3)
- **Test:** New `hub/tests/drift-watchdog-skill.bats` — drift-guards. Asserts `.claude/agents/drift-analyst.md` exists, frontmatter parses (name, description, tools list, model), tools list is exactly `[Read, Grep, Glob, Bash(git log:*)]`, model is `sonnet`.
- **Implement:** Write `.claude/agents/drift-analyst.md` with frontmatter + tight body (one short paragraph per output section: "What drifted", "Why this might matter (or not)", "Recommended action").
- **Files:** `.claude/agents/drift-analyst.md`, `hub/tests/drift-watchdog-skill.bats`.
- **Verify:** Tests green.

### Step 7: drift-watchdog skill (AC-4, AC-7, AC-8, AC-10)
- **Test:** Drift-guards on `.claude/skills/drift-watchdog/SKILL.md` — asserts it mentions `drift-watchdog-list`, `drift-analyst`, `linear-query.sh save-issue`, `--label drift-watchdog`, `idea-pending-append`, the eval-resolution pattern. Asserts it does NOT contain `mcp__claude_ai_Linear__save_issue` or `wc -l`.
- **Implement:** Write `.claude/skills/drift-watchdog/SKILL.md` orchestrating: (1) preflight check, (2) drift-list, (3) idempotency check via `operations.sh resolve idea.list --label drift-watchdog`, (4) per-drift agent spawn + issue creation, (5) pending-log fallback.
- **Files:** `.claude/skills/drift-watchdog/SKILL.md`, `hub/tests/drift-watchdog-skill.bats`.
- **Verify:** Tests green.

### Step 8: Idempotency (AC-5) — drift-guard at the prose level
- **Test:** `hub/tests/drift-watchdog-skill.bats` adds an assertion that the SKILL.md prose explicitly describes the idempotency check (titles parsed for `<drift_key>`, skip if match exists in non-terminal state).
- **Implement:** Already covered by Step 7's skill prose — this step just adds the drift-guard assertion. No new code.
- **Files:** `hub/tests/drift-watchdog-skill.bats`.
- **Verify:** Test green.

### Step 9: Live dogfood
- **Test:** Run `bash .ccanvil/scripts/ccanvil-sync.sh drift-watchdog-preflight` against the live system; both fields `true`. Run `drift-watchdog-list` against the live registry; output is well-formed JSON. Run `drift-watchdog-launchd-print` and pipe to `xmllint --noout`; clean parse. Manual verification only — not a bats test.
- **Verify:** All three subcommands behave as designed live.

### Step 10: Doc updates + dispatcher
- **Test:** None new. Existing legacy-refs-scan must stay green.
- **Implement:** Add dispatcher cases for the three subcommands at the end of `ccanvil-sync.sh`. Add command-reference.md entry under the appropriate section (hub guide). Update CLAUDE.md commands table only if the watchdog gets a top-level operator command (it does — listed via `claude -p "/drift-watchdog"`).
- **Files:** `.ccanvil/scripts/ccanvil-sync.sh` (dispatcher), `.ccanvil/guide/command-reference.md`, `CLAUDE.md` (optional).
- **Verify:** Full suite green.

### Step 11: Full-suite regression + /pr
- **Test:** `bash .ccanvil/scripts/bats-report.sh --parallel`. Tests trend +N for the new file count.
- **Verify:** No existing test regresses; assert-pr-title computes a clean title; PR body summarizes the three substrate primitives + the launchd correction story.

## Risks

- **`cmd_diff` was the original "reuse" path; I'm using `git log` directly instead.** That's a deliberate simplification — `cmd_diff` operates on a downstream node's local lockfile, not the hub's commit drift. Hub-commit drift via `git log <last_synced_version>..HEAD --name-only` is the right primitive for the watchdog. File-level drift on each downstream node is a future ticket.
- **launchd validity:** `xmllint` is universally available on macOS; `plutil -lint -` is more strict but only on macOS. I'll use `xmllint` for portability of the bats test (it works on Linux CI runners too) — the strict semantic check ("does launchd accept this") is implicitly verified by the live-dogfood step.
- **Schedule jitter:** `Weekday=1 Hour=9 Minute=13` is the chosen jitter (Monday 09:13). 13 ≠ 0 ≠ 30, follows the CronCreate scheduling discipline.
- **`drift-watchdog-launchd-print`'s `WorkingDirectory` references `git rev-parse --show-toplevel`** — that's evaluated AT print time (the operator's hub repo), not at launchd fire time. The .plist will hard-code the absolute path. That's correct for a single-machine install.
- **MCP wrapper used by `/idea`:** AC-10 asserts the watchdog opens issues with `--label drift-watchdog`. `idea.list --label drift-watchdog` filtering must exist. Verify at Step 7 — if missing, scope-up to add it (small substrate addition).

## Definition of Done

- [ ] All 10 acceptance criteria pass
- [ ] All existing tests still pass (≥1503)
- [ ] Live dogfood: preflight returns both `true`; list emits clean JSON; launchd-print parses
- [ ] /review run (this is substrate-tier work — no skip)
- [ ] PR #106 finalized + landed; BTS-21 → Done

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
