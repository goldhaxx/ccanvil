# Feature: routing-key rename heal

> Feature: bts-324-routing-key-rename
> Work: linear:BTS-324
> Created: 1778541168
> Subject: routing-key rename heal
> Status: Complete

## Summary

Some downstream nodes initialized via the agent's stochastic interpretation of `/ccanvil-init` wrote `integrations.routing.ticket = "linear"` instead of one or more of the canonical keys (`routing.{idea,spec,plan,stasis}`). The non-canonical key silently routes to local logging despite a fully-populated Linear providers block: `_lifecycle_route` only reads canonical kinds, so captures land in `.ccanvil/ideas-pending.log` and never dispatch. This feature adds `docs-check.sh provider-heal-routing-rename` to detect the legacy key, rename it to canonical form, and drain the pending log so stuck transitions land. Sibling under the BTS-316 provider-heal umbrella.

## Job To Be Done

**When** I discover a downstream node's `routing.ticket` key is silently routing Linear-shaped captures to local logging,
**I want to** run one substrate verb to rename the key to canonical form AND drain the resulting pending log,
**So that** Linear dispatch resumes without manual JSON editing or per-pending-entry replay.

## Acceptance Criteria

Each criterion is independently testable. Binary pass/fail.

- [ ] **AC-1:** `bash .ccanvil/scripts/docs-check.sh provider-heal-routing-rename --project-dir <path> --check` exits 0 and emits a JSON envelope describing detection: `{status, legacy_key_present, legacy_value, canonical_keys_present:[], proposed_target}`. No filesystem writes. Two consecutive invocations produce byte-identical stdout (idempotent).

- [ ] **AC-2: Given** `.claude/ccanvil.local.json` contains `integrations.routing.ticket = "linear"` AND no `routing.{idea,spec,plan,stasis,backlog}` keys, **when** `provider-heal-routing-rename --apply` runs, **then** the substrate (a) sets `routing.idea = "linear"` (default target), (b) removes the `ticket` key, (c) writes atomically via temp+mv (same pattern as `cmd_provider_activate`), and (d) the resulting file passes `jq` validation. Emits envelope `{status:"renamed", from:"ticket", to:["idea"], drained:{synced, failed, pending}}`.

- [ ] **AC-3: Given** the operator passes `--routes spec,plan,stasis,idea` (SSOT-Linear shape), **when** `--apply` runs against a node with `routing.ticket = "linear"`, **then** all four canonical kinds receive the legacy value AND the `ticket` key is removed. Envelope's `to` array reflects the named kinds. Unknown kinds in `--routes` cause exit 2 with stderr `ERROR: unknown route kind '<k>' (valid: spec, plan, stasis, idea, backlog)`.

- [ ] **AC-4: Given** `--apply` succeeded AND `.ccanvil/ideas-pending.log` exists with N entries, **when** the rename completes, **then** the substrate invokes `cmd_idea_pending_replay` and surfaces its `{synced, failed, pending, emergency_pending}` envelope under the `drained` key. When the pending log is missing or empty, `drained` is `{synced:0, failed:0, pending:0}`. Drain failure does NOT roll back the rename — the canonical key is the durable state.

- [ ] **AC-5: Edge: When** `routing.ticket` is absent (already-canonical or fresh config), `--apply` is a no-op: emits `{status:"no-op", reason:"no-legacy-key-found"}`, exits 0, file untouched (mtime unchanged is sufficient; substrate may rewrite if and only if content changes).

- [ ] **AC-6: Error: When** `routing.ticket` is present AND any canonical key **named in the target set** (the explicit `--routes` list, or the default `[idea]` when `--routes` is omitted) is already set, refuse the rename: emit `{status:"conflict", existing_canonical:[...], legacy_value, target_routes:[...]}`, exit 1. Canonical keys outside the target set are left untouched and do NOT trigger conflict (e.g., `--routes spec,plan` against a node with pre-existing `routing.stasis` proceeds normally; only collisions on `spec` or `plan` block). `--check` mode surfaces the same conflict but exits 0 (read-only never fails). Operator resolves a real collision by either widening/narrowing `--routes`, removing the legacy `ticket` key manually, or accepting the existing canonical value.

- [ ] **AC-7: Error: When** `.claude/ccanvil.local.json` is missing, exit 1 with stderr `ERROR: no .claude/ccanvil.local.json at <path>`. **When** the file exists but `integrations.routing` is absent, emit `{status:"no-op", reason:"no-routing-config"}` exit 0.

## Affected Files

| File | Change |
|------|--------|
| `.ccanvil/scripts/docs-check.sh` | Modified — add `cmd_provider_heal_routing_rename` (mirrors `cmd_provider_heal_preflight` shape for read-only + `cmd_provider_activate` atomic write pattern) + dispatcher entry `provider-heal-routing-rename`. |
| `hub/tests/provider-heal-routing-rename.bats` | New — fixture pattern mirrors `hub/tests/provider-activate.bats` (TMPDIR_BATS + PROJECT_DIR + write seed config); tests cover AC-1 through AC-7. |

## Dependencies

- **Requires:** `cmd_idea_pending_replay` (BTS-179), `_lifecycle_route` helper for canonical-kind reference, atomic-write-via-temp+mv pattern from `cmd_provider_activate`. All shipped.
- **Blocked by:** Nothing.

## Out of Scope

- Auto-rename on every `docs-check.sh` invocation — this is an explicit heal verb, not background migration.
- Renaming non-`ticket` legacy keys — `ticket` is the only known stochastic-init divergence per BTS-324 evidence.
- Fleet-wide cross-node sweep — BTS-330 (`fleet-heal-orchestration`) owns that umbrella.
- Re-resolving Linear team/project/state IDs — `cmd_provider_heal` already covers that; this verb is rename + drain only.
- Modifying `.claude/ccanvil.json` (hub file) — only the local file carries node-specific routing.
- Auto-promotion to SSOT-Linear shape — explicit `--routes` flag required; default is `routing.idea` only (preserves operator agency).

## Implementation Notes

- **Substrate shape:** mirror `cmd_provider_heal_preflight`'s read-only `--json` envelope shape and `cmd_provider_activate`'s atomic-write (jq → temp → mv). New `cmd_provider_heal_routing_rename` accepts `--project-dir <path>` (default `.`), `--check` (read-only, default), `--apply` (mutate), `--routes <comma-list>` (target kinds; default `idea`), `--json` (structured output; default).
- **Manifest annotations:** anchor on BTS-324, sibling under BTS-316. Declare `depends-on: cmd_idea_pending_replay`, `side-effect: writes-ccanvil-local-json-on-apply-only`, `contract: idempotent-on-rerun`, `contract: no-half-renamed-state-on-drain-failure`.
- **Drain step:** call `cmd_idea_pending_replay --json` after rename success; parse envelope and embed under `drained`. Replay failure surfaces via `drained.failed > 0` — no exception flow needed.
- **Test pattern:** follow `hub/tests/provider-activate.bats` fixture (`TMPDIR_BATS`, seed `.claude/ccanvil.local.json` with the legacy shape, stub `cmd_idea_pending_replay` via `IDEA_PENDING_REPLAY_OVERRIDE` env var if a test-injection point is needed). Per-AC bats tests; idempotency test pipes two consecutive `--check` outputs through `diff`.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
