# Implementation Plan: Modular provider connectivity

> Feature: bts-316-modular-provider-connectivity
> Work: linear:BTS-316
> Created: 1778273100
> Spec hash: 5ced306d
> Based on: docs/spec.md

## Objective

Land the operator-config layer (`~/.ccanvil/operator.json` as a third merge tier) and the `provider-activate` switch that flips routing for spec/plan/stasis/idea kinds end-to-end, plus the `/ccanvil-init` integration (flags + TTY prompt) so new and existing nodes can opt into a provider in one command.

## Sequence

Each step is one red-green-refactor cycle. Sub-steps within a step ride the same commit.

### Step 1: route-of accepts idea + backlog kinds (BTS-276 finding 4)

- **Test:** `hub/tests/route-of-idea-backlog.bats` — assert `route-of idea` and `route-of backlog` return the configured route under linear-routed, local-routed, and unconfigured fixtures (6 cases). Confirm prior `route-of spec/plan/stasis` cases still pass.
- **Implement:** In `.ccanvil/scripts/docs-check.sh` `cmd_route_of`:
  - Extend the case branch from `spec|plan|stasis)` to `spec|plan|stasis|idea|backlog)`.
  - Update the Usage strings (both the `--*` branch and the missing-kind branch) to list the four-or-five kinds.
  - Update the `@manifest` input clause to declare the expanded kind list and bump the contract anchor with BTS-316.
- **Files:** `.ccanvil/scripts/docs-check.sh`, `hub/tests/route-of-idea-backlog.bats` (new).
- **Verify:** `bash hub/tests/route-of-idea-backlog.bats` passes; full suite still 2035+ passing; `bash .ccanvil/scripts/module-manifest.sh validate --json | jq .drift` returns `[]`.

### Step 2: 3-tier merge_config (operator → hub → node)

- **Test:** Extend `hub/tests/operations-config.bats` (or create if absent) with cases covering: operator-only, operator+hub, operator+hub+node, operator+node (no hub), node overrides operator, hub overrides operator, missing operator-tier returns 2-tier behavior identical to today, invalid operator JSON exits 1. Use `HOME=$BATS_TMPDIR/fake-home` per test.
- **Implement:** In `.ccanvil/scripts/operations.sh`:
  - Add a `_operator_config_path()` helper that returns `$HOME/.ccanvil/operator.json` (one place to override for tests via `CCANVIL_OPERATOR_CONFIG_OVERRIDE` env var — mirrors existing `*_OVERRIDE` patterns).
  - Refactor `merge_config()` to 3-tier: collect each tier's content into a temp source list (or pipe via `<(echo)`), validate each separately, then `jq -s 'reduce .[] as $x ({}; . * $x)'` over the three sources in operator→hub→node order. When a tier file is missing, substitute `{}`. When invalid JSON, error out naming the file (mirror existing hub/node behavior).
- **Files:** `.ccanvil/scripts/operations.sh`, `hub/tests/operations-config.bats` (new or extended).
- **Verify:** All new bats cases pass; existing `read_config` consumers unaffected (full suite passes).

### Step 3: operator-config commands (init/get/set/show)

- **Test:** `hub/tests/operator-config.bats` — covers each of the four subcommands:
  - `init --provider linear --team X` writes the file with the documented schema; running twice produces zero diff.
  - `get providers.linear.team` round-trips the value written by init; missing key returns exit 0 + empty.
  - `set providers.linear.team Y` mutates the value; verifiable via subsequent `get`.
  - `show` emits pretty JSON; missing file emits `{}` with exit 0.
  - `set` on a missing file creates it (with parent dir).
  - Atomic write: confirm temp file pattern (no half-written state on simulated interrupt — sufficient to assert the post-write file is valid JSON).
  - Use `HOME=$BATS_TMPDIR/fake-home`.
- **Implement:** In `.ccanvil/scripts/docs-check.sh`:
  - `cmd_operator_config_init` — accepts `--provider linear --team <name> [--routes <list>]`; if file missing or `providers.linear.team` absent, writes the seeded shape `{providers:{linear:{team}}, default_routes:{spec,plan,stasis,idea: <provider>}}`. Idempotent.
  - `cmd_operator_config_get <key>` — jq `getpath(<dotted>)` semantics; empty for missing. Exit 0 always (caller may distinguish empty-vs-absent if needed; spec keeps it simple).
  - `cmd_operator_config_set <key> <value>` — jq `setpath`; creates `$HOME/.ccanvil/` and `operator.json` if missing; atomic temp+mv.
  - `cmd_operator_config_show` — `jq .` on the file, or `{}` when absent.
  - Add dispatch in the bottom case statement: `operator-config init|get|set|show)`.
  - Add a single `mkdir -p "$HOME/.ccanvil"` helper; reuse across the four commands.
  - All four carry full `@manifest` blocks.
- **Files:** `.ccanvil/scripts/docs-check.sh`, `hub/tests/operator-config.bats` (new), `.ccanvil/manifest-allowlist.txt`.
- **Verify:** All new bats cases pass; manifests validate clean.

### Step 4: provider-activate verb (the switch)

- **Test:** `hub/tests/provider-activate.bats`:
  - Happy path: stub `LINEAR_QUERY_OVERRIDE` to return canned team/project/state/label; run `provider-activate --provider linear --team X --project Y --routes spec,plan,stasis,idea --project-dir <tmp>`; assert `.claude/ccanvil.local.json` carries flipped routing keys + provider IDs.
  - Idempotency: run twice; assert second run is a no-op (file content byte-identical).
  - Partial routes: `--routes spec,plan`; assert stasis and idea are NOT flipped if they were `local`.
  - Operator-config team fallback: omit `--team`; pre-seed `~/.ccanvil/operator.json` with `providers.linear.team`; assert provider-heal called with that team.
  - Phase failures: stub auth/drift/resolve to return non-zero; assert provider-activate exits non-zero AND `.claude/ccanvil.local.json` is unchanged.
  - `--json` envelope shape.
- **Implement:** In `.ccanvil/scripts/docs-check.sh` add `cmd_provider_activate`:
  - Parse flags: `--provider`, `--team`, `--project`, `--routes` (default — uses operator-config or hard `spec,plan,stasis,idea`), `--project-dir`, `--json`.
  - Resolve team from `--team` arg → operator-config `providers.linear.team` (via `cmd_operator_config_get`) → fail if neither.
  - Resolve routes from `--routes` arg → operator-config `default_routes` (per-kind dict) → hard default.
  - Stage 1: snapshot `<project_dir>/.claude/ccanvil.local.json` content (or empty if missing).
  - Stage 2: invoke `cmd_provider_heal --provider linear --team X --project Y --project-dir <path>` — auth/drift/resolve. On any failure: restore snapshot if mutated (provider-heal already gates writes behind success, but defensive), surface phase failure on stderr, exit 1.
  - Stage 3: jq-edit `.claude/ccanvil.local.json` to set `integrations.routing.<kind>=linear` for each kind in `--routes`. Atomic temp+mv.
  - Stage 4: emit success summary or `--json` envelope.
  - Full `@manifest` block: failure-modes for each phase, contract for idempotency.
  - Add dispatch entry: `provider-activate)`.
- **Files:** `.ccanvil/scripts/docs-check.sh`, `hub/tests/provider-activate.bats` (new), `.ccanvil/manifest-allowlist.txt`.
- **Verify:** All new bats cases pass; manifests clean; full suite passes.

### Step 5: /ccanvil-init skill prose integration

- **Test:** `hub/tests/ccanvil-init-skill.bats` — extend with three new tests:
  - Flag-driven: skill prose contains the flag list `--provider --team --project --routes` documented and references `provider-activate` post-registration.
  - TTY-prompt branch: skill prose contains `[[ -t 0 ]]` test and the prompt copy.
  - Non-TTY default: skill prose surfaces the post-hoc command in the success message.
  - These are documentation-shape tests (grep-based), not executable-flow tests, since the skill prose is consumed by Claude not bash.
- **Implement:** Edit `global-commands/ccanvil-init.md`:
  - After Step 10 (Register with hub), insert Step 10a (Provider activation):
    - Read `--provider/--team/--project/--routes` from the operator's invocation args (claude reads them from the user's message).
    - When `--provider linear` flag is present: run `bash .ccanvil/scripts/docs-check.sh provider-activate --provider linear --team "$TEAM" --project "$PROJECT" [--routes "$ROUTES"]`.
    - When no `--provider` flag AND `[[ -t 0 ]]` (interactive): prompt the user "Activate Linear for this node? [y/N]"; on yes, prompt for team (default = operator-config team), project, routes. Then run provider-activate.
    - When no `--provider` flag AND not a TTY: skip activation; surface "to activate later, run: bash .ccanvil/scripts/docs-check.sh provider-activate --provider linear --team <name> --project <name>".
- **Files:** `global-commands/ccanvil-init.md`, `hub/tests/ccanvil-init-skill.bats`.
- **Verify:** Skill-prose grep tests pass; full suite passes.

### Step 6: Dogfood — activate tour-scheduler

- **Test:** Live-API validation gate (per `.claude/rules/tdd.md`). The composed primitives are already verified, but the COMPOSED contract is new — so we run one live activation against `~/projects/tour-scheduler`.
- **Implement (operator-driven):**
  - Run: `bash ~/projects/ccanvil/.ccanvil/scripts/docs-check.sh operator-config init --provider linear --team "Blocktech Solutions"` (one-time setup).
  - Run: `bash ~/projects/ccanvil/.ccanvil/scripts/docs-check.sh provider-activate --provider linear --project "<TBD: tour-scheduler or operator-chosen Linear project>" --project-dir ~/projects/tour-scheduler`.
  - Verify: `for k in spec plan stasis idea; do bash ~/projects/ccanvil/.ccanvil/scripts/docs-check.sh route-of $k --project-dir ~/projects/tour-scheduler; done` returns `linear` four times.
- **Files:** None — this is verification only. (If a Linear project named `tour-scheduler` does not exist yet, operator creates it via Linear UI before running the dogfood.)
- **Verify:** Above command sequence works without error; spot-check `.claude/ccanvil.local.json` in tour-scheduler shows the flipped routes + resolved IDs.

### Step 7: /pr → /review → /ship

- **Test:** `bash .ccanvil/scripts/bats-report.sh --parallel` — green.
- **Implement:**
  - Run `/pr` (auto-runs cleanup + push + draft→ready transition).
  - Run `/review` for diff sanity.
  - Run `/ship 168` to merge + auto-close BTS-316.
- **Files:** None.
- **Verify:** PR #168 merged; BTS-316 → Done; main is back at HEAD.

## Risks

- **`merge_config` 3-tier refactor risk.** The function is called from many code paths via `read_config`. Refactor must preserve the 2-tier behavior exactly when the operator tier is absent. Mitigation: write a regression bats case that runs through the existing 2-tier fixtures unchanged before touching the implementation.
- **TTY detection in skill prose risk.** Claude executes prose, not bash directly. The `[[ -t 0 ]]` test happens inside whatever subprocess the agent spawns. If Claude runs the test inside `bash -c "..."` invoked by the harness, the TTY status reflects the harness's TTY, not the operator's. Mitigation: the prose pattern is already used elsewhere (see how /ccanvil-init currently asks "Project name?"); this is a continuation of the same pattern. The agent reads context to decide. Treat TTY behavior as agent-driven, not bash-driven.
- **Operator-config home outside workspace.** `$HOME/.ccanvil/operator.json` is outside `/Users/zacharywright/projects/`, so any direct path argument would be blocked by `guard-workspace.sh`. Mitigation: the substrate reads `$HOME` from env inside the script (no path arg from the shell), same way `linear-query.sh` reads `~/.env`. No guard friction.
- **Idempotency check via `git diff --quiet`.** If `provider-activate` writes the same content as before but jq's whitespace-handling produces a byte-different output, the test will flap. Mitigation: assert content via `jq` field-equality, not byte-for-byte, OR canonicalize via `jq -S` before write (sorted keys, stable formatting).
- **Test count drift in AC-21.** The "2035 + N" expectation assumes no other tests change. If the manifest hits any drift, the count moves. Mitigation: assert `>= 2035 + N` and inspect the delta if surprising.

## Definition of Done

- [ ] All 22 acceptance criteria from spec pass.
- [ ] All existing tests still pass.
- [ ] Manifest coverage 100%, drift 0.
- [ ] Code reviewed (`/review`).
- [ ] Live dogfood on `~/projects/tour-scheduler` succeeds (AC-22).
- [ ] PR #168 merged, BTS-316 → Done.
