#!/usr/bin/env bash
# permissions-audit.sh — Deterministic permissions auditor for Claude Code settings.
#
# Parses Bash permission entries from .claude/settings.json and
# .claude/settings.local.json, classifies each as DANGER / UNREVIEWED / REVIEWED
# based on pattern matching and a decision log.
#
# Exit codes:
#   0 — all entries REVIEWED, no DANGER
#   1 — UNREVIEWED entries exist (no DANGER)
#   2 — DANGER entries exist (or usage/parse error)
#
# Usage:
#   permissions-audit.sh check [--settings-dir DIR] [--log FILE]
#   permissions-audit.sh init  [--settings-dir DIR] [--log FILE]

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------

SETTINGS_DIR=".claude"
LOG_FILE=""  # set after parsing args; defaults to SETTINGS_DIR/permissions-log.json

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

CMD=""
TEXT_MODE=false
VERBOSE=false

usage() {
  echo "Usage: permissions-audit.sh <check|init> [--settings-dir DIR] [--log FILE] [--text] [--verbose]" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    check|init)
      CMD="$1"; shift ;;
    --settings-dir)
      SETTINGS_DIR="$2"; shift 2 ;;
    --log)
      LOG_FILE="$2"; shift 2 ;;
    --text)
      TEXT_MODE=true; shift ;;
    --verbose)
      VERBOSE=true; shift ;;
    -h|--help)
      usage ;;
    *)
      echo "Unknown option: $1" >&2; usage ;;
  esac
done

[[ -z "$CMD" ]] && usage

# Default log file location
[[ -z "$LOG_FILE" ]] && LOG_FILE="$SETTINGS_DIR/permissions-log.json"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Collect all permission entries from a settings file into a jq-compatible format.
# Outputs JSON array of {permission, source} objects.
parse_settings_file() {
  local file="$1"
  local source_name="$2"

  if [[ ! -f "$file" ]]; then
    echo "[]"
    return
  fi

  jq -r --arg src "$source_name" '
    [
      (.permissions.allow // [] | .[] | {permission: ., source: $src, type: "allow"}),
      (.permissions.deny // [] | .[] | {permission: ., source: $src, type: "deny"})
    ]
  ' "$file"
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

cmd_check() {
  local settings_file="$SETTINGS_DIR/settings.json"
  local settings_local_file="$SETTINGS_DIR/settings.local.json"

  # settings.json must exist
  if [[ ! -f "$settings_file" ]]; then
    echo "ERROR: $settings_file not found" >&2
    exit 2
  fi

  # Parse both files
  local entries_main entries_local all_entries
  entries_main=$(parse_settings_file "$settings_file" "settings.json")
  entries_local=$(parse_settings_file "$settings_local_file" "settings.local.json")

  # Merge and deduplicate: group by permission, collect sources into arrays
  all_entries=$(jq -n --argjson a "$entries_main" --argjson b "$entries_local" '
    ($a + $b) | group_by(.permission) | map({
      permission: .[0].permission,
      source: [.[].source] | unique,
      status: "UNREVIEWED"
    })
  ')

  # Build JSON output
  local result
  result=$(echo "$all_entries" | jq '
    {
      entries: .,
      danger: 0,
      unreviewed: length,
      reviewed: 0
    }
  ')

  echo "$result"

  # Exit code: 1 if any unreviewed (no danger detection yet)
  local unreviewed
  unreviewed=$(echo "$result" | jq '.unreviewed')
  if [[ "$unreviewed" -gt 0 ]]; then
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

case "$CMD" in
  check) cmd_check ;;
  init)  echo "TODO: init not implemented" >&2; exit 2 ;;
  *)     usage ;;
esac
