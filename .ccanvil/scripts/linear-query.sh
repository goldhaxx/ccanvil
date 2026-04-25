#!/usr/bin/env bash
# linear-query.sh — Linear GraphQL client wrapper for bash scripts.
#
# BTS-164: provides curl + jq + LINEAR_API_KEY env-var auth so docs-check.sh,
# radar-gather, operations.sh resolvers, etc. can read+write Linear without
# routing through MCP. Uniform path for scripts and skills; closes the
# read-path provider asymmetry (cmd_idea_count was opening the local JSONL
# log directly even on Linear-routed projects).
#
# Subcommands ship in phases:
#   v1 — viewer, list-issues, get-issue, list-states, list-labels, save-issue
#
# Auth: requires LINEAR_API_KEY in the environment for every subcommand
# except --help. Endpoint defaults to https://api.linear.app/graphql; tests
# override via LINEAR_QUERY_ENDPOINT.
#
# Exit codes:
#   0 — success
#   2 — usage / configuration error (missing env var, unknown subcommand)
#   3 — runtime error (network, API error response, malformed JSON)

set -euo pipefail

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

usage() {
  cat <<'EOF'
Usage: linear-query.sh <subcommand> [args...]

Subcommands:
  viewer                              Auth smoke test — returns {id, name} for the authenticated user.
  list-issues  [flags]                List issues. Flags: --project, --team, --state, --label, --limit.
  get-issue    <id>                   Fetch one issue by identifier (e.g., BTS-164).
  list-states  [flags]                List workflow states. Flags: --team.
  list-labels  [flags]                List labels. Flags: --team.
  save-issue   [flags]                Create or update an issue. Flags: --id, --title, --description,
                                      --state, --priority, --labels, --project, --team, --parent-id,
                                      --duplicate-of.

Environment:
  LINEAR_API_KEY        Required for every subcommand except --help.
                        Generate one at https://linear.app/settings/api.
  LINEAR_QUERY_ENDPOINT Optional override (default: https://api.linear.app/graphql).
                        Tests use this to point at a stub endpoint.

Exit codes:
  0  ok
  2  usage / configuration error (missing env var, unknown subcommand, bad flags)
  3  runtime error (network, API error, malformed response)
EOF
}

# Print to stderr and exit. First arg = exit code, rest = message.
_die() {
  local code="$1"; shift
  printf '%s\n' "$*" >&2
  exit "$code"
}

# Every subcommand calls this before doing any work. Exits 2 with a clear
# remediation hint when the env var is missing.
_require_api_key() {
  if [[ -z "${LINEAR_API_KEY:-}" ]]; then
    _die 2 "LINEAR_API_KEY not set. Generate a key at https://linear.app/settings/api and export it: export LINEAR_API_KEY=<key>"
  fi
}

# POST a GraphQL query to Linear. Args:
#   $1 — the GraphQL query string
#   $2 — variables JSON (object), defaults to {}
# Emits the parsed response payload (the .data field) on stdout.
# Exits 3 with the GraphQL error message on stderr if the response carries
# an "errors" array.
_post_graphql() {
  local query="$1"
  local variables="${2:-{}}"
  local endpoint="${LINEAR_QUERY_ENDPOINT:-https://api.linear.app/graphql}"

  local body
  body=$(jq -nc --arg q "$query" --argjson v "$variables" '{query:$q,variables:$v}')

  local response
  response=$(
    curl -sS -X POST "$endpoint" \
      -H "Authorization: $LINEAR_API_KEY" \
      -H "Content-Type: application/json" \
      -d "$body"
  ) || _die 3 "linear-query: HTTP request failed (curl exit $?)"

  # GraphQL errors: surface the first one and exit 3. Linear's WAF and auth
  # layer both return 200 OK with an errors array, so HTTP status alone is
  # not a reliable signal.
  local err
  err=$(printf '%s' "$response" | jq -r '.errors[0].message // empty' 2>/dev/null || true)
  if [[ -n "$err" ]]; then
    _die 3 "linear-query: GraphQL error: $err"
  fi

  printf '%s' "$response" | jq '.data'
}

# -----------------------------------------------------------------------------
# Subcommand stubs (filled in by later steps in the BTS-164 plan)
# -----------------------------------------------------------------------------

cmd_viewer() {
  _require_api_key
  local query='query { viewer { id name } }'
  _post_graphql "$query" | jq '.viewer'
}

cmd_list_issues() {
  _require_api_key
  _die 3 "list-issues: not yet implemented (Step 3)"
}

cmd_get_issue() {
  _require_api_key
  _die 3 "get-issue: not yet implemented (Step 3)"
}

cmd_list_states() {
  _require_api_key
  _die 3 "list-states: not yet implemented (Step 3)"
}

cmd_list_labels() {
  _require_api_key
  _die 3 "list-labels: not yet implemented (Step 3)"
}

cmd_save_issue() {
  _require_api_key
  _die 3 "save-issue: not yet implemented (Step 6)"
}

# -----------------------------------------------------------------------------
# Dispatcher
# -----------------------------------------------------------------------------

main() {
  if [[ $# -eq 0 ]]; then
    usage >&2
    exit 2
  fi

  local subcommand="$1"; shift

  case "$subcommand" in
    -h|--help|help)
      usage
      exit 0
      ;;
    viewer)       cmd_viewer       "$@" ;;
    list-issues)  cmd_list_issues  "$@" ;;
    get-issue)    cmd_get_issue    "$@" ;;
    list-states)  cmd_list_states  "$@" ;;
    list-labels)  cmd_list_labels  "$@" ;;
    save-issue)   cmd_save_issue   "$@" ;;
    *)
      _die 2 "Unknown subcommand: $subcommand. Run 'linear-query.sh --help' for usage."
      ;;
  esac
}

main "$@"
