#!/usr/bin/env bash
# context-budget.sh — Measure token cost of always-loaded scaffold files.
#
# Reports per-file and aggregate token estimates for files that load into
# Claude's context at every session start. Budget thresholds are model-aware.
#
# Exit codes:
#   0 — HEALTHY (under 70% of budget)
#   1 — WARNING (70-90% of budget)
#   2 — CRITICAL (over 90% of budget), or usage error
#
# Usage:
#   context-budget.sh check [--project-dir DIR] [--text] [--budget N]
#                           [--context-window N] [--model MODEL_ID]

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------

PROJECT_DIR="."
TEXT_MODE=false
BUDGET_FLAG=""
CONTEXT_WINDOW_FLAG=""
MODEL_FLAG=""

DEFAULT_CONTEXT_WINDOW=200000
BUDGET_PERCENT=4  # 4% of context window

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

CMD=""

usage() {
  echo "Usage: context-budget.sh check [--project-dir DIR] [--text] [--budget N] [--context-window N] [--model MODEL_ID]" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    check)
      CMD="$1"; shift ;;
    --project-dir)
      PROJECT_DIR="$2"; shift 2 ;;
    --text)
      TEXT_MODE=true; shift ;;
    --budget)
      BUDGET_FLAG="$2"; shift 2 ;;
    --context-window)
      CONTEXT_WINDOW_FLAG="$2"; shift 2 ;;
    --model)
      MODEL_FLAG="$2"; shift 2 ;;
    -h|--help)
      usage ;;
    *)
      echo "Unknown option: $1" >&2; usage ;;
  esac
done

[[ -z "$CMD" ]] && usage

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Measure a single file. Outputs JSON object: {path, lines, chars, estimated_tokens}
measure_file() {
  local filepath="$1"

  local chars lines tokens
  chars=$(wc -c < "$filepath" | tr -d ' ')
  lines=$(wc -l < "$filepath" | tr -d ' ')
  tokens=$(( (chars + 3) / 4 ))

  jq -n --arg p "$filepath" --argjson l "$lines" --argjson c "$chars" --argjson t "$tokens" \
    '{path: $p, lines: $l, chars: $c, estimated_tokens: $t}'
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

cmd_check() {
  local files_json="[]"

  # Project CLAUDE.md
  if [[ -f "$PROJECT_DIR/CLAUDE.md" ]]; then
    local entry
    entry=$(measure_file "$PROJECT_DIR/CLAUDE.md")
    files_json=$(echo "$files_json" | jq --argjson e "$entry" '. + [$e]')
  fi

  # Rules files
  for rule in "$PROJECT_DIR"/.claude/rules/*.md; do
    [[ -f "$rule" ]] || continue
    local entry
    entry=$(measure_file "$rule")
    files_json=$(echo "$files_json" | jq --argjson e "$entry" '. + [$e]')
  done

  # Settings file
  if [[ -f "$PROJECT_DIR/.claude/settings.json" ]]; then
    local entry
    entry=$(measure_file "$PROJECT_DIR/.claude/settings.json")
    files_json=$(echo "$files_json" | jq --argjson e "$entry" '. + [$e]')
  fi

  # .claudeignore
  if [[ -f "$PROJECT_DIR/.claudeignore" ]]; then
    local entry
    entry=$(measure_file "$PROJECT_DIR/.claudeignore")
    files_json=$(echo "$files_json" | jq --argjson e "$entry" '. + [$e]')
  fi

  # Compute totals
  local total_lines total_chars total_tokens
  total_lines=$(echo "$files_json" | jq '[.[].lines] | add // 0')
  total_chars=$(echo "$files_json" | jq '[.[].chars] | add // 0')
  total_tokens=$(echo "$files_json" | jq '[.[].estimated_tokens] | add // 0')

  jq -n --argjson files "$files_json" \
    --argjson tl "$total_lines" --argjson tc "$total_chars" --argjson tt "$total_tokens" \
    '{files: $files, totals: {lines: $tl, chars: $tc, estimated_tokens: $tt}}'
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

case "$CMD" in
  check) cmd_check ;;
  *)     usage ;;
esac
