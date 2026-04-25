Activate a Draft spec — create the feature branch, copy the spec to active, push origin, open a draft PR, and transition the linked Linear issue to In Progress.

`/activate` is the canonical pre-implementation step. It wraps `docs-check.sh activate` (git mechanics + branch + draft PR) and follows up by dispatching the `AUTO-TRANSITION` intent the script emits — flipping the linked Linear issue to `In Progress` via the BTS-128 `ticket.transition` primitive. On MCP failure, the skill enqueues the transition to `.ccanvil/ideas-pending.log` for `/idea sync` to replay later. Mirrors `/land`'s AUTO-CLOSE precedent.

## Steps

1. Run `bash .ccanvil/scripts/docs-check.sh activate <feature-id>` and capture its stdout.
2. Grep the captured stdout for a line matching `^AUTO-TRANSITION: `. If none, you're done — just print the script's output and exit (legacy spec, local-provider, or non-Linear node).
3. If a marker line is present, extract the JSON payload (everything after `AUTO-TRANSITION: `). Parse `provider`, `id`, and `role`.
4. If `provider != "linear"`: this should not happen (the script only emits the marker for `linear:`), but be defensive — log `auto-transition: unexpected provider '<p>' — skipping` and exit 0 without dispatching.
5. Resolve the transition intent:
   ```bash
   bash .ccanvil/scripts/operations.sh resolve ticket.transition <id> <role> --project-dir .
   ```
   The resolver returns `.invocation.tool` (`mcp__claude_ai_Linear__save_issue`) and `.invocation.params` (`{id, state}`).
6. Dispatch the MCP call with the resolved params. The tool is `mcp__claude_ai_Linear__save_issue`; pass `id` and `state` from `.invocation.params`.
7. **On MCP success:** echo `Auto-transitioned <id> → <role>`. Done — nothing was enqueued, nothing to ack.
8. **On MCP failure** (network/auth/server error): enqueue a pending entry deterministically:
   ```bash
   bash .ccanvil/scripts/docs-check.sh idea-pending-append \
     --op ticket.transition --id <id> --role <role>
   ```
   Echo `PENDING: auto-transition queued for /idea sync (<id> → <role>)`. Exit 0 — auto-transition failure NEVER blocks activation.

## BTS-149 — enqueue-on-failure-only

The script no longer pre-enqueues. The success path writes nothing to `.ccanvil/ideas-pending.log` and requires no ack — eliminating the write+ack churn (and the stochastic jq pipeline) that BTS-148 introduced. The failure path uses the deterministic `idea-pending-append` helper (BTS-123) — one command, no hand-rolled JSON, no predicate queries. Linear's `save_issue` is idempotent on already-transitioned states, so duplicate entries from past failures (or sync replays) are no-ops.

## Rules

- `/activate` is the canonical pre-TDD entry point. Users who run `docs-check.sh activate` directly bypass the MCP dispatch — the `AUTO-TRANSITION: {...}` marker prints on stdout, but nothing is enqueued and nothing dispatches. The user can dispatch manually or accept the missed transition (Linear stays in Triage until manually moved).
- `/activate` NEVER fails the activation step because of MCP/Linear errors — the failure-path enqueue guarantees forward progress via `/idea sync`.
- When no AUTO-TRANSITION marker is emitted (legacy spec, local provider, non-claude branch), `/activate` is a transparent passthrough over `docs-check.sh activate`.
- The `--no-auto-push` flag (BTS-145) is passed through to the script if specified by the user.

## Arguments

- `<feature-id>`: required. The kebab-cased feature_id (e.g., `bts-149-interactive-permissions-review`).
- `--no-auto-push`: optional. Pass through to the script — disables the BTS-145 auto-push of `origin main` when local main is AHEAD.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
