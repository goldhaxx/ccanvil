# Implementation Plan: routing-key rename heal

> Feature: bts-324-routing-key-rename
> Work: linear:BTS-324
> Created: 1778541355
> Spec hash: d5aad149
> Based on: docs/spec.md

## Objective

Add a deterministic `provider-heal-routing-rename` substrate verb that detects legacy `integrations.routing.ticket` keys in downstream nodes, renames them to canonical `routing.idea` (or operator-named target set), and drains `.ccanvil/ideas-pending.log` so stuck Linear transitions land — all in one heal pass.

## Sequence

### Step 1: Test scaffolding + skeleton

* **Test:** Create `hub/tests/provider-heal-routing-rename.bats` with the standard setup/teardown (mirror `hub/tests/provider-activate.bats` — `TMPDIR_BATS`, `PROJECT_DIR`, seed `.claude/ccanvil.local.json` with legacy `routing.ticket = "linear"`). Add one failing smoke test: `provider-heal-routing-rename --help` exits 2 with usage on stderr.
* **Implement:** In `.ccanvil/scripts/docs-check.sh`, add a stub `cmd_provider_heal_routing_rename()` that emits the usage line and exits 2. Register `provider-heal-routing-rename) cmd_provider_heal_routing_rename "$@" ;;` in the dispatcher (near other `provider-heal-*` entries). Add to the help-listing line at the top.
* **Files:** `hub/tests/provider-heal-routing-rename.bats` (new), `.ccanvil/scripts/docs-check.sh`.
* **Verify:** `bats hub/tests/provider-heal-routing-rename.bats` green.

### Step 2: AC-1 — `--check` read-only envelope

* **Test:** With seed config `{"integrations":{"routing":{"ticket":"linear"}}}`, `provider-heal-routing-rename --check --project-dir <PROJECT_DIR>` exits 0, emits JSON with `status:"legacy-detected"`, `legacy_key_present:true`, `legacy_value:"linear"`, `canonical_keys_present:[]`, `proposed_target:["idea"]`. Assert byte-identical stdout across two consecutive runs. Assert config file mtime unchanged.
* **Implement:** Parse `--check` / `--apply` / `--routes` / `--project-dir` flags. Default mode `--check`. Read `.claude/ccanvil.local.json`, extract `.integrations.routing` via jq, classify ticket-key presence + collect canonical-key names already set. Emit envelope via single `jq -n`.
* **Files:** `.ccanvil/scripts/docs-check.sh`.
* **Verify:** Both tests green.

### Step 3: AC-7 — error/edge paths (missing file, no routing-config)

* **Test (a):** Without seeding the config file (delete it), `--check` exits 1, stderr matches `ERROR: no .claude/ccanvil.local.json at <path>`. **Test (b):** With seed config `{}` (no `integrations.routing`), `--check` exits 0 emits `{status:"no-op", reason:"no-routing-config"}`.
* **Implement:** Add the missing-file guard (`[[ -f "$cfg" ]] || { echo "ERROR..." >&2; exit 1; }`) and the no-routing-config branch before the legacy-detection logic.
* **Files:** `.ccanvil/scripts/docs-check.sh`.
* **Verify:** Both new tests green.

### Step 4: AC-5 — `--apply` no-op when legacy key absent

* **Test:** Seed config `{"integrations":{"routing":{"idea":"linear"}}}` (canonical-only). `--apply` exits 0, emits `{status:"no-op", reason:"no-legacy-key-found"}`. Assert config bytes unchanged via `cmp`.
* **Implement:** Branch `--apply` mode: when `routing.ticket` is absent, emit the no-op envelope and `return 0` BEFORE the rename block. Do not call temp+mv when nothing changes.
* **Files:** `.ccanvil/scripts/docs-check.sh`.
* **Verify:** Test green; AC-1 + AC-7 still green.

### Step 5: AC-2 — `--apply` default rename (ticket → idea)

* **Test:** Seed legacy config. `--apply` exits 0, emits `{status:"renamed", from:"ticket", to:["idea"], drained:...}`. After call: `.claude/ccanvil.local.json` has `routing.idea = "linear"` AND `routing.ticket` is absent. File passes `jq .`. Bytes match `jq -S` re-write (stable ordering for idempotency follow-up).
* **Implement:** Atomic write: read existing config → jq pipeline `del(.integrations.routing.ticket) | .integrations.routing.idea = "linear"` → write to `$cfg.tmp` → `mv` over original. Default `drained` to `{synced:0, failed:0, pending:0}` (Step 8 fills it in). Mirror `cmd_provider_activate`'s `jq -S` for stable key ordering.
* **Files:** `.ccanvil/scripts/docs-check.sh`.
* **Verify:** All four assertions green.

### Step 6: AC-3 — `--routes <list>` + invalid-kind validation

* **Test (a):** Seed legacy config. `--apply --routes spec,plan,stasis,idea` exits 0, all four canonical keys set to `"linear"`, `ticket` absent, envelope's `to` array reflects all four kinds. **Test (b):** `--apply --routes spec,bogus` exits 2, stderr matches `ERROR: unknown route kind 'bogus' (valid: spec, plan, stasis, idea, backlog)`. **Test (c):** `--check --routes spec,plan` reports `proposed_target:["spec","plan"]`.
* **Implement:** Parse `--routes` into an array; validate each against the canonical set (mirror `cmd_provider_activate`'s validation loop, lines 5099-5104). Build the jq mutation dynamically by iterating the target array. Use the parsed target list for the `proposed_target` (`--check`) and `to` (`--apply`) envelope fields.
* **Files:** `.ccanvil/scripts/docs-check.sh`.
* **Verify:** All three tests green; AC-2 default-target test still green.

### Step 7: AC-6 — target-set-scoped conflict refusal

* **Test (a):** Seed config `{"integrations":{"routing":{"ticket":"linear","idea":"local"}}}`. Default `--apply` (target `[idea]`) exits 1, emits `{status:"conflict", existing_canonical:["idea"], legacy_value:"linear", target_routes:["idea"]}`. Config bytes unchanged. **Test (b):** Same seed BUT `--apply --routes spec,plan` (legacy `ticket` collides with neither — `idea` is outside the target set) succeeds normally, sets `routing.spec` + `routing.plan` to `"linear"`, removes `ticket`, leaves `routing.idea = "local"` untouched. **Test (c):** `--check` with a colliding seed exits 0 (read-only never fails) but envelope's status is `"conflict"`.
* **Implement:** After parsing `--routes`, compute `intersection = (canonical_keys_present) ∩ (target_routes)`. When non-empty AND `--apply` mode AND legacy key present: emit conflict envelope, return 1. `--check` mode emits the same envelope but returns 0.
* **Files:** `.ccanvil/scripts/docs-check.sh`.
* **Verify:** All three tests green; AC-2 / AC-3 still green.

### Step 8: AC-4 — drain step via `cmd_idea_pending_replay`

* **Test (a):** Seed legacy config + populate `.ccanvil/ideas-pending.log` with 2 entries (use `docs-check.sh idea-pending-append` to write them deterministically — stub Linear dispatch via `LINEAR_QUERY_OVERRIDE` so replay succeeds locally). After `--apply`, envelope's `drained` reflects the replay outcome (synced ≥ 0, failed accumulator, pending). **Test (b):** Seed legacy config with NO pending log file. `--apply` succeeds; `drained` is `{synced:0, failed:0, pending:0}`. **Test (c):** Stub the replay to fail (set override to return non-zero); rename still succeeds (canonical key is durable), envelope's `drained.failed > 0`.
* **Implement:** After successful temp+mv, invoke `cmd_idea_pending_replay --project-dir "$project_dir" --json` capturing stdout; parse the envelope and embed under `drained`. Wrap the replay call in `|| true` so a failing replay doesn't abort the function. Default `drained` to all-zeros when the call output is empty.
* **Files:** `.ccanvil/scripts/docs-check.sh`.
* **Verify:** All three tests green; idempotency test (AC-1) re-asserts.

### Step 9: Manifest annotations + final polish

* **Test:** Run `bash .ccanvil/scripts/module-manifest.sh validate --json`; assert `drift:[]` and the new function appears in the manifest extract.
* **Implement:** Add full `@manifest` block above `cmd_provider_heal_routing_rename`: purpose, inputs (`--check`, `--apply`, `--routes`, `--project-dir`, `--json`), outputs, exit codes, `depends-on: cmd_idea_pending_replay` + `depends-on: jq`, `side-effect: writes-ccanvil-local-json-on-apply-only` + `side-effect: read-only-on-check`, failure-modes (missing-file, conflict, invalid-kind), `contract: idempotent-on-rerun` + `contract: no-half-renamed-state-on-drain-failure`, `anchor: BTS-324 (routing-key rename heal, sibling under BTS-316)`. Update `.ccanvil/manifest-allowlist.txt` only if needed (the function lives in already-allowlisted `docs-check.sh`).
* **Files:** `.ccanvil/scripts/docs-check.sh`.
* **Verify:** Manifest validate clean (194 → 195/195, drift 0). Full bats sweep `bash .ccanvil/scripts/bats-report.sh --parallel` green.

## Risks

* **Atomic-write race:** mirror `cmd_provider_activate`'s temp+mv pattern exactly; do not invent. Same risk profile (filesystem race on concurrent invocations) — acceptable for a single-operator heal verb.
* **Replay-cascade failures:** the drain step can return non-zero envelopes; explicit `|| true` + envelope-embed ensures the substrate's primary contract (rename happened) holds even if replay fails. Surface failures via `drained.failed > 0` for operator action.
* **Test-injection point for replay:** `cmd_idea_pending_replay` itself supports `LINEAR_QUERY_OVERRIDE` (via the http resolver); no new override is needed. Stub Linear in the bats fixture as `provider-activate.bats` already does.

## Definition of Done

- [ ] All 7 acceptance criteria from `docs/spec.md` pass via `hub/tests/provider-heal-routing-rename.bats`
- [ ] All existing tests still pass (`bash .ccanvil/scripts/bats-report.sh --parallel` green)
- [ ] Module-manifest `validate --json` clean (drift 0)
- [ ] Code reviewed via `/review` (manifest pre-flight + code-reviewer agent)
