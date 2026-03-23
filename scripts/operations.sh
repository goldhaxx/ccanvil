#!/usr/bin/env bash
# operations.sh — Mechanism-agnostic routing layer for scaffold operations.
#
# Reads .claude/scaffold.json and dispatches each scaffold operation to a
# pluggable provider via any supported mechanism (bash, mcp, cli, api, etc.).
# Zero-config projects resolve everything to local bash adapters.
#
# Exit codes:
#   0 — success
#   1 — operation error (unknown op, missing provider, invalid config)
#   2 — usage error
#
# Usage:
#   operations.sh resolve <operation> [--project-dir DIR]

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------

PROJECT_DIR="."

# ---------------------------------------------------------------------------
# Operations registry — all 17 defined operations
# ---------------------------------------------------------------------------

is_valid_operation() {
  case "$1" in
    backlog.list|backlog.create|backlog.prioritize|backlog.get) return 0 ;;
    spec.read|spec.write|spec.list|spec.activate|spec.complete) return 0 ;;
    plan.read|plan.write) return 0 ;;
    checkpoint.read|checkpoint.write) return 0 ;;
    status.get|status.update) return 0 ;;
    pr.create|pr.list) return 0 ;;
    review.run) return 0 ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------

usage() {
  cat >&2 <<'EOF'
Usage: operations.sh resolve <operation> [--project-dir DIR]

Operations:
  backlog.{list,create,prioritize,get}
  spec.{read,write,list,activate,complete}
  plan.{read,write}
  checkpoint.{read,write}
  status.{get,update}
  pr.{create,list}
  review.run
EOF
  exit 2
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

CMD=""
OPERATION=""

[[ $# -eq 0 ]] && usage

while [[ $# -gt 0 ]]; do
  case "$1" in
    resolve)
      CMD="resolve"; shift
      # Next positional arg is the operation name
      if [[ $# -gt 0 && "$1" != --* ]]; then
        OPERATION="$1"; shift
      fi
      ;;
    --project-dir)
      PROJECT_DIR="$2"; shift 2 ;;
    -h|--help)
      usage ;;
    *)
      echo "Unknown option: $1" >&2; usage ;;
  esac
done

[[ -z "$CMD" ]] && usage
[[ "$CMD" == "resolve" && -z "$OPERATION" ]] && usage

# ---------------------------------------------------------------------------
# Config reading
# ---------------------------------------------------------------------------

CONFIG_FILE=""

read_config() {
  CONFIG_FILE="$PROJECT_DIR/.claude/scaffold.json"

  # No config file → all local (not an error)
  if [[ ! -f "$CONFIG_FILE" ]]; then
    CONFIG_FILE=""
    return 0
  fi

  # Validate JSON
  if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
    echo "ERROR: .claude/scaffold.json is not valid JSON" >&2
    exit 1
  fi
}

# Extract the routing group from an operation name (e.g., "backlog.list" → "backlog")
operation_group() {
  echo "${1%%.*}"
}

# ---------------------------------------------------------------------------
# Local adapter definitions
# ---------------------------------------------------------------------------

local_adapter() {
  local op="$1"
  local cmd="" output_contract=""

  case "$op" in
    # --- backlog ---
    backlog.list)
      cmd="scripts/docs-check.sh list-specs"
      output_contract='["feature_id","status","created"]'
      ;;
    backlog.create)
      cmd="scripts/docs-check.sh create-spec"
      output_contract='["feature_id","status"]'
      ;;
    backlog.prioritize)
      cmd="scripts/docs-check.sh list-specs"
      output_contract='["feature_id","status","priority"]'
      ;;
    backlog.get)
      cmd="cat docs/specs/SPEC_ID.md"
      output_contract='["feature_id","status","created","body"]'
      ;;
    # --- spec ---
    spec.read)
      cmd="cat docs/spec.md"
      output_contract='["feature_id","status","body"]'
      ;;
    spec.write)
      cmd="cp docs/templates/spec.md docs/spec.md"
      output_contract='["feature_id"]'
      ;;
    spec.list)
      cmd="scripts/docs-check.sh list-specs"
      output_contract='["feature_id","status","created"]'
      ;;
    spec.activate)
      cmd="scripts/docs-check.sh activate"
      output_contract='["feature_id","branch"]'
      ;;
    spec.complete)
      cmd="scripts/docs-check.sh complete"
      output_contract='["feature_id","status"]'
      ;;
    # --- plan ---
    plan.read)
      cmd="cat docs/plan.md"
      output_contract='["feature_id","spec_hash","body"]'
      ;;
    plan.write)
      cmd="cp docs/templates/plan.md docs/plan.md"
      output_contract='["feature_id"]'
      ;;
    # --- checkpoint ---
    checkpoint.read)
      cmd="cat docs/checkpoint.md"
      output_contract='["feature_id","plan_hash","body"]'
      ;;
    checkpoint.write)
      cmd="cp docs/templates/checkpoint.md docs/checkpoint.md"
      output_contract='["feature_id"]'
      ;;
    # --- status ---
    status.get)
      cmd="scripts/docs-check.sh status"
      output_contract='["spec","plan","checkpoint"]'
      ;;
    status.update)
      cmd="scripts/docs-check.sh validate"
      output_contract='["result","details"]'
      ;;
    # --- pr ---
    pr.create)
      cmd="gh pr create --draft"
      output_contract='["url","number"]'
      ;;
    pr.list)
      cmd="gh pr list --json number,title,state"
      output_contract='["number","title","state"]'
      ;;
    # --- review ---
    review.run)
      cmd="echo review"
      output_contract='["status","concerns"]'
      ;;
  esac

  printf '{"provider":"local","mechanism":"bash","invocation":{"command":"%s"},"contract":{"output":%s}}' \
    "$cmd" "$output_contract"
}

# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------

cmd_resolve() {
  local op="$1"

  # Validate operation name
  if ! is_valid_operation "$op"; then
    echo "ERROR: unknown operation \"$op\"" >&2
    exit 1
  fi

  # Read config (sets CONFIG_FILE or leaves empty)
  read_config

  # No config or no integrations key → local adapter
  if [[ -z "$CONFIG_FILE" ]]; then
    local_adapter "$op"
    return 0
  fi

  # Check for integrations.routing.<group>
  local group
  group=$(operation_group "$op")
  local routed_provider
  routed_provider=$(jq -r ".integrations.routing.${group} // \"local\"" "$CONFIG_FILE")

  if [[ "$routed_provider" == "local" ]]; then
    local_adapter "$op"
    return 0
  fi
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

case "$CMD" in
  resolve) cmd_resolve "$OPERATION" ;;
  *) usage ;;
esac
