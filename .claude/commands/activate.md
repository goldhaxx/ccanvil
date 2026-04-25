Activate a Draft spec — create the feature branch, copy the spec to active, push origin, open a draft PR, and transition the linked Linear issue to In Progress.

`/activate` is the canonical pre-implementation step. It wraps `docs-check.sh activate` (git mechanics + branch + draft PR) and follows up by dispatching the `AUTO-TRANSITION` intent the script emits — flipping the linked Linear issue to `In Progress` via the BTS-128 `ticket.transition` primitive. On MCP failure, the transition stays queued in `.ccanvil/ideas-pending.log` (the script enqueues it deterministically) for `/idea sync` to replay later. Mirrors `/land`'s AUTO-CLOSE precedent.

## Steps

1. Run `bash .ccanvil/scripts/docs-check.sh activate <feature-id>` and capture its stdout.
2. Grep the captured stdout for a line matching `^AUTO-TRANSITION: `. If none, you're done — just print the script's output and exit (legacy spec, local-provider, or non-Linear node).
3. If a marker line is present, extract the JSON payload (everything after `AUTO-TRANSITION: `). Parse `provider`, `id`, and `role`.
4. If `provider != "linear"`: this should not happen (the script only emits the marker for `linear:`), but be defensive — log `auto-transition: unexpected provider '<p>' — skipping` and exit 0 without dispatching. The pending-log entry the script enqueued will still get drained by the next `/idea sync`.
5. Resolve the transition intent:
   ```bash
   bash .ccanvil/scripts/operations.sh resolve ticket.transition <id> <role> --project-dir .
   ```
   The resolver returns `.invocation.tool` (`mcp__claude_ai_Linear__save_issue`) and `.invocation.params` (`{id, state}`).
6. Dispatch the MCP call with the resolved params. The tool is `mcp__claude_ai_Linear__save_issue`; pass `id` and `state` from `.invocation.params`.
7. **On MCP success:** ack the pending-log entry the script just enqueued. Find the most recent entry matching `op == "ticket.transition" AND args.id == <id>`, then run `bash .ccanvil/scripts/docs-check.sh idea-sync --ack <ts>`. Echo `Auto-transitioned <id> → <role>`.
8. **On MCP failure** (network/auth/server error): the script already enqueued the entry to `.ccanvil/ideas-pending.log` — DO NOT re-enqueue, DO NOT ack. Echo `PENDING: auto-transition queued for /idea sync (<id> → <role>)`. Exit 0 — auto-transition failure NEVER blocks activation.

## Idempotency

If the Linear issue is already in the target state (e.g., manually transitioned, or replayed from an earlier pending-log entry), Linear's `save_issue` accepts the transition without error. No client-side dedup needed.

The script enqueues a new entry on every activate call. If two consecutive activates happen on the same spec (rare — second one would fail at the branch-already-exists check), two pending-log entries accumulate. They both converge to the same state on dispatch, so Linear is happy; the agent can ack all matching entries.

## Acking the right entry

The pending log can contain prior entries from `/land` MCP failures or previous activates. To ack only the entry just enqueued by THIS activate:

```bash
ts=$(jq -r 'select(.op == "ticket.transition" and .args.id == "<id>" and .args.role == "<role>") | .ts' \
  .ccanvil/ideas-pending.log | tail -1)
bash .ccanvil/scripts/docs-check.sh idea-sync --ack "$ts"
```

`tail -1` picks the most recent entry matching the predicate — the one the script just appended.

## Rules

- `/activate` is the canonical pre-TDD entry point. Users who run `docs-check.sh activate` directly bypass the MCP dispatch — the `AUTO-TRANSITION: {...}` marker prints on stdout, the pending-log entry is enqueued, but no immediate flip happens. The next `/idea sync` will drain the entry.
- `/activate` NEVER fails the activation step because of MCP/Linear errors — the pending-log fallback guarantees forward progress.
- When no AUTO-TRANSITION marker is emitted (legacy spec, local provider, non-claude branch), `/activate` is a transparent passthrough over `docs-check.sh activate`.
- The `--no-auto-push` flag (BTS-145) is passed through to the script if specified by the user.

## Arguments

- `<feature-id>`: required. The kebab-cased feature_id (e.g., `bts-148-deterministic-activate-transition`).
- `--no-auto-push`: optional. Pass through to the script — disables the BTS-145 auto-push of `origin main` when local main is AHEAD.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
