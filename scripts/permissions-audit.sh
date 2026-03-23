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
# Dangerous pattern detection
# ---------------------------------------------------------------------------

# Each pattern: "label|regex"
# The regex is matched against the inner command (after stripping Bash(...) wrapper).
# Order matters — first match wins.
DANGER_PATTERNS=(
  # Broad command wildcards — grants access to entire command namespace
  "broad-wildcard|^(echo|cat|find|bash|env|sort|rm|cp|mv|chmod|chown):\*$"
  # Compound operators — bypass allow-list matching
  "compound-operator|;|&&|[|][|]"
  # Redirect operators — can overwrite arbitrary files (excludes 2>&1 stderr redirect)
  "redirect| [^2][^>]*>[^&]| >>|^>"
  # Env-prefix commands — execute arbitrary commands with modified environment
  "env-prefix|^[A-Z_]+="
  # find -exec / find -delete — arbitrary command execution via find
  "find-exec|find .* -exec|find .* -delete"
  # Loop primitives — shell control flow shouldn't be in permissions
  "loop-primitive|^for |^do |^done"
  # Arbitrary execution — run arbitrary commands
  "arbitrary-exec|xargs -I|^env "
  # File mutation — destructive git operations or file overwrites
  "file-mutation|sort -o|git branch -[Dd]|git tag -d|git push.*--force|git reset --hard"
)

# Extract the inner command from a permission string.
# "Bash(git status:*)" → "git status:*"
# "Bash(rm -rf /)*" → "rm -rf /)*"  (deny entries may have trailing pattern)
strip_bash_wrapper() {
  local perm="$1"
  # Remove leading "Bash(" and trailing ")" if present
  perm="${perm#Bash(}"
  # Remove trailing ) only if it's the last char
  if [[ "$perm" == *")" ]]; then
    perm="${perm%)}"
  fi
  echo "$perm"
}

# Check if a permission matches any dangerous pattern.
# Returns the pattern label if matched, empty string if safe.
check_danger() {
  local inner="$1"

  for pattern_entry in "${DANGER_PATTERNS[@]}"; do
    local label="${pattern_entry%%|*}"
    local regex="${pattern_entry#*|}"

    if echo "$inner" | grep -qE "$regex"; then
      echo "$label"
      return 0
    fi
  done

  echo ""
  return 1
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
      source: [.[].source] | unique
    })
  ')

  # Classify each entry
  local classified danger_count=0 unreviewed_count=0 reviewed_count=0
  classified="[]"

  local entry_count
  entry_count=$(echo "$all_entries" | jq 'length')

  for (( i=0; i<entry_count; i++ )); do
    local perm sources
    perm=$(echo "$all_entries" | jq -r ".[$i].permission")
    sources=$(echo "$all_entries" | jq -c ".[$i].source")

    local inner matched_pattern status
    inner=$(strip_bash_wrapper "$perm")
    matched_pattern=$(check_danger "$inner" || true)

    if [[ -n "$matched_pattern" ]]; then
      status="DANGER"
      danger_count=$((danger_count + 1))
      classified=$(echo "$classified" | jq --arg p "$perm" --argjson s "$sources" --arg mp "$matched_pattern" \
        '. + [{permission: $p, source: $s, status: "DANGER", matched_pattern: $mp}]')
    else
      status="UNREVIEWED"
      unreviewed_count=$((unreviewed_count + 1))
      classified=$(echo "$classified" | jq --arg p "$perm" --argjson s "$sources" \
        '. + [{permission: $p, source: $s, status: "UNREVIEWED"}]')
    fi
  done

  # Build final output
  local result
  result=$(jq -n --argjson entries "$classified" \
    --argjson d "$danger_count" --argjson u "$unreviewed_count" --argjson r "$reviewed_count" \
    '{entries: $entries, danger: $d, unreviewed: $u, reviewed: $r}')

  echo "$result"

  # Exit codes: 2 = DANGER, 1 = UNREVIEWED, 0 = all REVIEWED
  if [[ "$danger_count" -gt 0 ]]; then
    return 2
  elif [[ "$unreviewed_count" -gt 0 ]]; then
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
