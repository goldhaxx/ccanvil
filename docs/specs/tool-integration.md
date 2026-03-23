# Feature: Modular Tool Integration Layer

> Feature: tool-integration
> Created: 1774238505
> Status: Draft

## Summary

Introduces `scripts/operations.sh` — a routing layer that reads `.claude/scaffold.json` and dispatches each scaffold operation (backlog, spec, plan, checkpoint, PR) to either a local bash adapter or an external MCP adapter. The workflow is the invariant; the tools are the variables. Zero-config projects continue to use local bash adapters with no behavior change.

## Job To Be Done

**When** a project has Linear, Notion, or GitHub configured via MCP,
**I want to** route scaffold operations to those tools transparently,
**So that** the workflow (spec → plan → build → review) stays identical regardless of which provider backs each operation.

## Acceptance Criteria

Each criterion is independently testable. Binary pass/fail.

- [ ] **AC-1:** `operations.sh resolve <operation>` with no `integrations` key in `.claude/scaffold.json` outputs JSON: `{"provider":"local","type":"bash","command":"<shell command>"}` for every defined operation name. Exit 0.

- [ ] **AC-2:** Given `integrations.routing.backlog: "linear"` and a `providers.linear` block in `.claude/scaffold.json`, `operations.sh resolve backlog.list` outputs JSON: `{"provider":"linear","type":"mcp","tool":"mcp__claude_ai_Linear__list_issues","params":{"project":"<configured project>","team":"<configured team>"},"output_contract":{"fields":["id","title","status","priority"]}}`. Exit 0.

- [ ] **AC-3:** Given `integrations.routing.backlog: "linear"` with no matching entry in `providers`, `operations.sh resolve backlog.list` exits 1 with stderr: `ERROR: provider "linear" is configured for backlog but has no entry in integrations.providers`.

- [ ] **AC-4:** Partial routing config — when `integrations.routing` contains only `backlog`, all other operation groups (`spec`, `plan`, `checkpoint`, `pr`) resolve to their local adapters unchanged.

- [ ] **AC-5:** `operations.sh resolve backlog.list` local adapter command, when executed, produces JSON with the same schema as `docs-check.sh list-specs`: array of `{feature_id, status, created}` objects. Verified by running both commands against the same `docs/specs/` directory and comparing output schemas with `jq`.

- [ ] **AC-6:** `operations.sh resolve backlog.get <id>` with linear routing outputs JSON including `"tool":"mcp__claude_ai_Linear__get_issue"` and an `"output_contract"` mapping Linear issue fields (`identifier`, `title`, `state.name`, `priority`) to scaffold contract fields (`id`, `title`, `status`, `priority`).

- [ ] **AC-7:** `.claude/commands/catchup.md` step 0c calls `operations.sh resolve backlog.list` instead of hardcoding `docs-check.sh list-specs`. Verified by: `grep -q "operations.sh resolve backlog.list" .claude/commands/catchup.md`.

- [ ] **AC-8:** `.claude/scaffold.json` with a valid `integrations` object passes `jq empty` validation. `scaffold-sync.sh`'s `TRACKED_PATTERNS` array includes `.claude/scaffold.json` so the config file is tracked in the lockfile.

- [ ] **AC-9 (error):** `operations.sh resolve backlog.list` when `.claude/scaffold.json` contains invalid JSON exits 1 with stderr: `ERROR: .claude/scaffold.json is not valid JSON`.

- [ ] **AC-10 (error):** `operations.sh resolve unknown.op` exits 1 with stderr: `ERROR: unknown operation "unknown.op"`. Exit 1.

- [ ] **AC-11 (edge):** `operations.sh resolve <op>` when `.claude/scaffold.json` does not exist behaves identically to AC-1 (all local). No error, exit 0.

## Affected Files

| File | Change |
|------|--------|
| `scripts/operations.sh` | New — routing layer, subcommand `resolve` |
| `tests/operations.bats` | New — bats tests |
| `.claude/scaffold.json` | Modified — add `integrations` schema |
| `scripts/scaffold-sync.sh` | Modified — add `.claude/scaffold.json` to `TRACKED_PATTERNS` |
| `.claude/commands/catchup.md` | Modified — call `operations.sh resolve backlog.list` in step 0c |
| `CLAUDE.md` | Modified — add `operations.sh` to Commands section |
| `GUIDE.md` | Modified — add to Command Reference table |

## Dependencies

- **Requires:** `jq` (already used by `scaffold-sync.sh`, `docs-check.sh`, `context-budget.sh`)
- **Requires:** Linear MCP tools present in `settings.local.json` (already: `mcp__claude_ai_Linear__list_issues`, `mcp__claude_ai_Linear__get_issue`)
- **Blocked by:** Nothing

## Out of Scope

- Linear adapters for `spec`, `plan`, `checkpoint`, `status`, `pr`, `review` operation groups
- Notion adapter, GitHub adapter
- Wiring commands other than `/catchup`
- Auto-detection of available MCP tools from `settings.local.json`
- Migration tooling (moving data between providers)
- Data format translation between providers (e.g., markdown spec → Notion page structure)

## Implementation Notes

- **Script pattern:** Follow `permissions-audit.sh` — `set -euo pipefail`, subcommand dispatch, JSON primary output, `--project-dir` flag pointing to directory containing `.claude/scaffold.json`.
- **Operations taxonomy** (all 17 defined, only backlog group gets Linear adapter in Phase 1): `backlog.{list,create,prioritize,get}`, `spec.{read,write,list,activate,complete}`, `plan.{read,write}`, `checkpoint.{read,write}`, `status.{get,update}`, `pr.{create,list}`, `review.run`.
- **Local adapter commands:** `backlog.list` → `docs-check.sh list-specs`; `backlog.get <id>` → read from `docs/specs/<id>.md`; spec/plan/checkpoint → corresponding `docs-check.sh` subcommands or direct file reads.
- **MCP adapter output:** When `type` is `mcp`, the JSON includes `tool` (MCP tool name), `params` (arguments for Claude to pass), and `output_contract` (field mapping from tool response to scaffold schema). Claude reads this and executes the MCP call.
- **Config fallback chain:** Missing file → all local. Missing `integrations` key → all local. Missing routing entry for a group → that group is local. `jq -r '.integrations.routing.<group> // "local"'`.
- **Routing groups:** An operation like `backlog.list` routes based on its group (`backlog`). All operations in a group share the same provider unless the config specifies per-operation overrides (future enhancement).
- **Test strategy:** `tests/operations.bats` uses fixture `.claude/scaffold.json` files in `mktemp -d`; assert JSON output with `jq -e`; assert exit codes and stderr content.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /scaffold-pull. -->
