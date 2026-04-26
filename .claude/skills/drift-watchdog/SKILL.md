Run the drift watchdog: detect drift between the hub and registered downstream nodes, then open a thoughtful, idempotent Linear issue per drifted node via the http substrate.

This skill is designed to be invoked autonomously via `claude -p "/drift-watchdog"` from a launchd entry (see `bash .ccanvil/scripts/ccanvil-sync.sh drift-watchdog-launchd-print`). It runs end-to-end without operator interaction.

## Steps

### 1. Pre-flight check

Run:
```bash
PREFLIGHT=$(bash .ccanvil/scripts/ccanvil-sync.sh drift-watchdog-preflight)
echo "$PREFLIGHT" | jq -e '.claude_p_available == true and .linear_query_works == true' >/dev/null \
  || { echo "drift-watchdog: preflight failed"; echo "$PREFLIGHT"; exit 1; }
```

Both fields must be `true`. If either fails, abort — re-running on a broken substrate would just produce errors.

### 2. Enumerate drift

```bash
DRIFT=$(bash .ccanvil/scripts/ccanvil-sync.sh drift-watchdog-list)
N=$(echo "$DRIFT" | jq 'length')
if (( N == 0 )); then
  echo "drift-watchdog: no drift detected"
  exit 0
fi
```

### 3. Fetch existing watchdog issues for idempotency

Resolve `idea.list` filtered by the `drift-watchdog` label and pull the current set:

```bash
RESOLUTION=$(bash .ccanvil/scripts/operations.sh resolve idea.list --project-dir .)
EXISTING=$(eval "$(echo "$RESOLUTION" | jq -r '.invocation.command')" \
  | jq '[.[] | select(.labels | index("drift-watchdog"))]')
```

Each existing issue's title carries the `drift_key` — used to skip duplicate creation.

### 4. Per drifted node — synthesize + create

For each entry in `$DRIFT`:

```bash
DRIFT_KEY=$(echo "$drift" | jq -r '.drift_key')
NODE_NAME=$(echo "$drift" | jq -r '.node_name')

# Idempotency check: skip if a non-terminal issue with this drift_key already exists.
DUP=$(echo "$EXISTING" | jq --arg k "$DRIFT_KEY" \
  '[.[] | select(.title | contains($k)) | select(.statusType != "canceled" and .statusType != "duplicate" and .statusType != "completed")]')
if (( $(echo "$DUP" | jq 'length') > 0 )); then
  echo "drift-watchdog: skip — existing issue for $NODE_NAME ($DRIFT_KEY)"
  continue
fi
```

Spawn the `drift-analyst` sub-agent with the drift record + recent git context + a roadmap snippet. The agent returns the issue body.

Title: `[drift-watchdog] <node_name>: <drift_key>` — the `drift_key` in the title is the dedup key. Never compose with timestamps.

Dispatch the create via http:

```bash
RESOLUTION=$(bash .ccanvil/scripts/operations.sh resolve idea.add --project-dir .)
cmd=$(echo "$RESOLUTION" | jq -r '.invocation.command')
TITLE="[drift-watchdog] $NODE_NAME: $DRIFT_KEY"
if jq -n --arg title "$TITLE" --arg description "$BODY" \
  '{title:$title, description:$description}' \
  | eval "$cmd --label drift-watchdog --input-json -" >/dev/null 2>&1; then
  echo "drift-watchdog: created issue for $NODE_NAME ($DRIFT_KEY)"
else
  bash .ccanvil/scripts/docs-check.sh idea-pending-append \
    --op add --title "$TITLE" --body "$BODY"
  PENDING_N=$(bash .ccanvil/scripts/docs-check.sh idea-pending-validate | jq -r .count)
  echo "drift-watchdog: PENDING — $TITLE queued ($PENDING_N total)"
fi
```

The `--label drift-watchdog` is mandatory — every issue must carry it so future runs find them. Pending-log fallback always counts entries via `idea-pending-validate`, never via line-count utilities.

### 5. Substrate purity

This skill MUST use the http substrate (the resolver's `linear-query.sh save-issue` invocation) for issue creation. Direct MCP tool invocations are forbidden by the drift-guards; rely on the resolver-eval pattern above (`eval "$(echo "$RESOLUTION" | jq -r '.invocation.command')"`) — that's the established shape.

## Re-running

If Claude Code is upgraded, re-run `bash .ccanvil/scripts/ccanvil-sync.sh drift-watchdog-preflight` manually before relying on the next scheduled fire — substrate breakage is cheap to verify, expensive to discover at fire time.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
