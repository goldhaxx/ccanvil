#!/usr/bin/env bash
# scaffold-sync.sh — Bi-directional sync between a project and the scaffold hub.
#
# Usage:
#   scaffold-sync.sh init [scaffold-path]   Generate lockfile from current state
#   scaffold-sync.sh status                 Show file provenance and sync state
#   scaffold-sync.sh diff [file]            Show diff between local and scaffold versions
#   scaffold-sync.sh hash <file>            Compute sha256 of a file
#   scaffold-sync.sh lock-get <file>        Read a lockfile entry (JSON)
#   scaffold-sync.sh lock-update <file> <field> <value>  Update a lockfile field
#   scaffold-sync.sh log <message>          Append to project sync log
#   scaffold-sync.sh changelog <message>    Append to scaffold changelog
#   scaffold-sync.sh section-merge <s> <l>  Merge hub/node sections of a delimited file
#   scaffold-sync.sh scan                   List all trackable files in the project

set -euo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
LOCKFILE=".claude/scaffold.lock"
SYNC_LOG=".claude/scaffold-sync.log"

# Directories and patterns to track (relative to project root)
TRACKED_PATTERNS=(
  ".claude/rules/*.md"
  ".claude/commands/*.md"
  ".claude/agents/*.md"
  ".claude/skills/*/SKILL.md"
  ".claude/settings.json"
  "docs/templates/*.md"
  "scripts/*.sh"
  "GUIDE.md"
  "CLAUDE.md"
  "SCAFFOLD_FRAMEWORK.md"
)

# Files to never track
EXCLUDED_FILES=(
  ".claude/scaffold.lock"
  ".claude/scaffold-sync.log"
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

die() { echo "ERROR: $*" >&2; exit 1; }

require_jq() {
  command -v jq >/dev/null 2>&1 || die "jq is required but not installed. Run: brew install jq"
}

require_lockfile() {
  [[ -f "$LOCKFILE" ]] || die "No $LOCKFILE found. Run: scaffold-sync.sh init"
}

get_scaffold_source() {
  jq -r '.scaffold_source' "$LOCKFILE" | sed "s|^~|$HOME|"
}

file_hash() {
  # Returns just the hex digest
  local file="$1"
  if [[ -f "$file" ]]; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    echo "MISSING"
  fi
}

timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

datestamp() {
  date +"%Y-%m-%d %H:%M"
}

is_excluded() {
  local file="$1"
  for excluded in "${EXCLUDED_FILES[@]}"; do
    [[ "$file" == "$excluded" ]] && return 0
  done
  return 1
}

# Scan project for all files matching tracked patterns
scan_tracked_files() {
  local files=()
  for pattern in "${TRACKED_PATTERNS[@]}"; do
    # Use bash glob expansion (nullglob handles no-match)
    local matches
    matches=( $pattern ) 2>/dev/null || true
    for f in "${matches[@]}"; do
      [[ -f "$f" ]] && ! is_excluded "$f" && files+=("$f")
    done
  done
  # Deduplicate and sort
  printf '%s\n' "${files[@]}" | sort -u
}

# Scan scaffold for all files matching tracked patterns
scan_scaffold_files() {
  local scaffold_path="$1"
  local files=()
  for pattern in "${TRACKED_PATTERNS[@]}"; do
    local matches
    matches=( "$scaffold_path"/$pattern ) 2>/dev/null || true
    for f in "${matches[@]}"; do
      if [[ -f "$f" ]]; then
        # Convert to relative path (strip scaffold_path prefix)
        local rel="${f#$scaffold_path/}"
        ! is_excluded "$rel" && files+=("$rel")
      fi
    done
  done
  printf '%s\n' "${files[@]}" | sort -u
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

cmd_init() {
  local scaffold_path="${1:-$HOME/projects/claude-code-scaffold}"
  scaffold_path="${scaffold_path/#\~/$HOME}"

  [[ -d "$scaffold_path" ]] || die "Scaffold not found at: $scaffold_path"

  # Get scaffold git version
  local scaffold_version="unknown"
  if git -C "$scaffold_path" rev-parse HEAD >/dev/null 2>&1; then
    scaffold_version=$(git -C "$scaffold_path" rev-parse --short HEAD)
  fi

  # Build the files object
  local files_json="{}"

  # Find all trackable files in the project
  while IFS= read -r file; do
    local scaffold_file="$scaffold_path/$file"
    local local_h
    local_h=$(file_hash "$file")

    if [[ -f "$scaffold_file" ]]; then
      local scaffold_h
      scaffold_h=$(file_hash "$scaffold_file")

      if [[ "$local_h" == "$scaffold_h" ]]; then
        local status="clean"
      else
        local status="modified"
      fi

      files_json=$(echo "$files_json" | jq --arg f "$file" --arg sh "$scaffold_h" --arg lh "$local_h" --arg st "$status" \
        '. + {($f): {"origin": "scaffold", "scaffold_hash": $sh, "local_hash": $lh, "status": $st}}')
    else
      # File exists locally but not in scaffold
      files_json=$(echo "$files_json" | jq --arg f "$file" --arg lh "$local_h" \
        '. + {($f): {"origin": "local", "scaffold_hash": null, "local_hash": $lh, "status": "local-only"}}')
    fi
  done < <(scan_tracked_files)

  # Check for files in scaffold that are NOT in the project
  while IFS= read -r file; do
    if ! echo "$files_json" | jq -e --arg f "$file" '.[$f]' >/dev/null 2>&1; then
      local scaffold_h
      scaffold_h=$(file_hash "$scaffold_path/$file")
      files_json=$(echo "$files_json" | jq --arg f "$file" --arg sh "$scaffold_h" \
        '. + {($f): {"origin": "scaffold", "scaffold_hash": $sh, "local_hash": null, "status": "scaffold-only"}}')
    fi
  done < <(scan_scaffold_files "$scaffold_path")

  # Write lockfile
  jq -n --arg src "$scaffold_path" --arg ver "$scaffold_version" --arg ts "$(timestamp)" --argjson files "$files_json" \
    '{scaffold_source: $src, scaffold_version: $ver, synced_at: $ts, files: $files}' > "$LOCKFILE"

  local total
  total=$(echo "$files_json" | jq 'length')
  local clean modified local_only scaffold_only
  clean=$(echo "$files_json" | jq '[.[] | select(.status == "clean")] | length')
  modified=$(echo "$files_json" | jq '[.[] | select(.status == "modified")] | length')
  local_only=$(echo "$files_json" | jq '[.[] | select(.status == "local-only")] | length')
  scaffold_only=$(echo "$files_json" | jq '[.[] | select(.status == "scaffold-only")] | length')

  echo "Scaffold lockfile generated: $LOCKFILE"
  echo "  Scaffold: $scaffold_path @ $scaffold_version"
  echo "  Total files: $total"
  echo "  Clean: $clean | Modified: $modified | Local: $local_only | Scaffold-only: $scaffold_only"
}

cmd_status() {
  require_lockfile

  local scaffold_source
  scaffold_source=$(get_scaffold_source)
  local scaffold_version
  scaffold_version=$(jq -r '.scaffold_version' "$LOCKFILE")
  local synced_at
  synced_at=$(jq -r '.synced_at' "$LOCKFILE")

  echo "Scaffold: $scaffold_source @ $scaffold_version"
  echo "Last synced: $synced_at"
  echo ""

  # Check if scaffold has new commits since last sync
  if git -C "$scaffold_source" rev-parse HEAD >/dev/null 2>&1; then
    local current_scaffold_version
    current_scaffold_version=$(git -C "$scaffold_source" rev-parse --short HEAD)
    if [[ "$current_scaffold_version" != "$scaffold_version" ]]; then
      echo "NOTE: Scaffold has new commits ($scaffold_version → $current_scaffold_version)"
      echo ""
    fi
  fi

  # Print each file's status
  local has_output=false
  while IFS= read -r file; do
    local status origin scaffold_hash local_hash
    status=$(jq -r --arg f "$file" '.files[$f].status' "$LOCKFILE")
    origin=$(jq -r --arg f "$file" '.files[$f].origin' "$LOCKFILE")

    # Check if local file has changed since lockfile was written
    local current_hash=""
    if [[ -f "$file" ]]; then
      current_hash=$(file_hash "$file")
    fi
    local recorded_local_hash
    recorded_local_hash=$(jq -r --arg f "$file" '.files[$f].local_hash // "null"' "$LOCKFILE")

    local display_status
    case "$status" in
      clean)
        if [[ -n "$current_hash" && "$current_hash" != "$recorded_local_hash" ]]; then
          display_status="MODIFIED*"  # Changed since last sync
        else
          display_status="CLEAN"
        fi
        ;;
      modified)     display_status="MODIFIED" ;;
      local-only)   display_status="LOCAL" ;;
      promoted)     display_status="PROMOTED" ;;
      scaffold-only) display_status="SCAFFOLD-ONLY" ;;
      *)            display_status="UNKNOWN" ;;
    esac

    printf "  %-16s %s\n" "$display_status" "$file"
    has_output=true
  done < <(jq -r '.files | keys[]' "$LOCKFILE" | sort)

  if [[ "$has_output" == "false" ]]; then
    echo "  No tracked files."
  fi

  echo ""
  echo "Statuses: CLEAN=synced, MODIFIED=locally changed, MODIFIED*=changed since last sync,"
  echo "          LOCAL=project-only, PROMOTED=pushed to scaffold, SCAFFOLD-ONLY=not yet pulled"
}

cmd_diff() {
  require_lockfile
  local file="${1:-}"
  local scaffold_source
  scaffold_source=$(get_scaffold_source)

  if [[ -n "$file" ]]; then
    # Diff a specific file
    local scaffold_file="$scaffold_source/$file"
    if [[ ! -f "$scaffold_file" ]]; then
      echo "File not in scaffold: $file"
      [[ -f "$file" ]] && echo "(exists locally as local-only file)"
      return 0
    fi
    if [[ ! -f "$file" ]]; then
      echo "File not in project: $file"
      echo "(exists in scaffold — run scaffold-pull to add it)"
      return 0
    fi
    echo "--- scaffold: $file"
    echo "+++ local: $file"
    diff --unified "$scaffold_source/$file" "$file" || true
  else
    # Diff all modified files
    while IFS= read -r f; do
      local status
      status=$(jq -r --arg f "$f" '.files[$f].status' "$LOCKFILE")
      if [[ "$status" == "modified" || "$status" == "clean" ]]; then
        local current_hash
        current_hash=$(file_hash "$f")
        local scaffold_hash
        scaffold_hash=$(jq -r --arg f "$f" '.files[$f].scaffold_hash // "null"' "$LOCKFILE")
        if [[ "$current_hash" != "$scaffold_hash" && -f "$scaffold_source/$f" ]]; then
          echo "=== $f ==="
          diff --unified "$scaffold_source/$f" "$f" || true
          echo ""
        fi
      fi
    done < <(jq -r '.files | keys[]' "$LOCKFILE")
  fi
}

cmd_hash() {
  local file="${1:?Usage: scaffold-sync.sh hash <file>}"
  echo "$(file_hash "$file")  $file"
}

cmd_lock_get() {
  require_lockfile
  local file="${1:?Usage: scaffold-sync.sh lock-get <file>}"
  jq --arg f "$file" '.files[$f] // "not found"' "$LOCKFILE"
}

cmd_lock_update() {
  require_lockfile
  local file="${1:?Usage: scaffold-sync.sh lock-update <file> <field> <value>}"
  local field="${2:?}"
  local value="${3:?}"

  local tmp
  tmp=$(mktemp)
  if [[ "$value" == "null" ]]; then
    jq --arg f "$file" --arg k "$field" '.files[$f][$k] = null' "$LOCKFILE" > "$tmp"
  else
    jq --arg f "$file" --arg k "$field" --arg v "$value" '.files[$f][$k] = $v' "$LOCKFILE" > "$tmp"
  fi
  mv "$tmp" "$LOCKFILE"
}

cmd_lock_add() {
  require_lockfile
  local file="${1:?Usage: scaffold-sync.sh lock-add <file> <origin> <scaffold_hash> <local_hash> <status>}"
  local origin="${2:?}"
  local scaffold_hash="${3}"
  local local_hash="${4}"
  local status="${5:?}"

  local tmp
  tmp=$(mktemp)
  if [[ "$scaffold_hash" == "null" ]]; then
    jq --arg f "$file" --arg o "$origin" --arg lh "$local_hash" --arg st "$status" \
      '.files[$f] = {"origin": $o, "scaffold_hash": null, "local_hash": $lh, "status": $st}' "$LOCKFILE" > "$tmp"
  elif [[ "$local_hash" == "null" ]]; then
    jq --arg f "$file" --arg o "$origin" --arg sh "$scaffold_hash" --arg st "$status" \
      '.files[$f] = {"origin": $o, "scaffold_hash": $sh, "local_hash": null, "status": $st}' "$LOCKFILE" > "$tmp"
  else
    jq --arg f "$file" --arg o "$origin" --arg sh "$scaffold_hash" --arg lh "$local_hash" --arg st "$status" \
      '.files[$f] = {"origin": $o, "scaffold_hash": $sh, "local_hash": $lh, "status": $st}' "$LOCKFILE" > "$tmp"
  fi
  mv "$tmp" "$LOCKFILE"
}

cmd_lock_remove() {
  require_lockfile
  local file="${1:?Usage: scaffold-sync.sh lock-remove <file>}"

  local tmp
  tmp=$(mktemp)
  jq --arg f "$file" 'del(.files[$f])' "$LOCKFILE" > "$tmp"
  mv "$tmp" "$LOCKFILE"
}

cmd_lock_set_version() {
  require_lockfile
  local version="${1:?Usage: scaffold-sync.sh lock-set-version <version>}"

  local tmp
  tmp=$(mktemp)
  jq --arg v "$version" --arg ts "$(timestamp)" '.scaffold_version = $v | .synced_at = $ts' "$LOCKFILE" > "$tmp"
  mv "$tmp" "$LOCKFILE"
}

cmd_log() {
  local message="${1:?Usage: scaffold-sync.sh log <message>}"

  # Prepend entry to sync log (newest first)
  local entry
  entry="## $(datestamp) — $message"

  if [[ -f "$SYNC_LOG" ]]; then
    local tmp
    tmp=$(mktemp)
    echo "$entry" > "$tmp"
    echo "" >> "$tmp"
    cat "$SYNC_LOG" >> "$tmp"
    mv "$tmp" "$SYNC_LOG"
  else
    echo "$entry" > "$SYNC_LOG"
    echo "" >> "$SYNC_LOG"
  fi
}

cmd_log_detail() {
  # Append a detail line to the most recent log entry
  local detail="${1:?Usage: scaffold-sync.sh log-detail <detail>}"

  if [[ -f "$SYNC_LOG" ]]; then
    # Insert detail after the first line (the header)
    local tmp
    tmp=$(mktemp)
    local header_done=false
    local inserted=false
    while IFS= read -r line; do
      echo "$line" >> "$tmp"
      if [[ "$header_done" == "false" && "$line" == "## "* ]]; then
        header_done=true
      elif [[ "$header_done" == "true" && "$inserted" == "false" ]]; then
        # Insert before first empty line after header
        if [[ -z "$line" ]]; then
          echo "- $detail" >> "$tmp"
          inserted=true
        fi
      fi
    done < "$SYNC_LOG"
    # If we never found an empty line, append
    if [[ "$inserted" == "false" ]]; then
      echo "- $detail" >> "$tmp"
    fi
    mv "$tmp" "$SYNC_LOG"
  fi
}

cmd_changelog() {
  require_lockfile
  local message="${1:?Usage: scaffold-sync.sh changelog <message>}"

  local scaffold_source
  scaffold_source=$(get_scaffold_source)
  local changelog="$scaffold_source/SCAFFOLD_CHANGELOG.md"

  if [[ ! -f "$changelog" ]]; then
    echo "# Scaffold Changelog" > "$changelog"
    echo "" >> "$changelog"
    echo "All CRUD operations on the scaffold are logged here, newest first." >> "$changelog"
    echo "" >> "$changelog"
  fi

  # Insert new entry after the header (after "newest first." line)
  local entry="## $(datestamp) — $message"
  local tmp
  tmp=$(mktemp)
  local inserted=false
  while IFS= read -r line; do
    echo "$line" >> "$tmp"
    if [[ "$inserted" == "false" && "$line" == "" ]]; then
      # Check if previous content suggests we're past the header
      if grep -q "newest first" "$changelog" 2>/dev/null; then
        echo "$entry" >> "$tmp"
        echo "" >> "$tmp"
        inserted=true
      fi
    fi
  done < "$changelog"
  if [[ "$inserted" == "false" ]]; then
    echo "" >> "$tmp"
    echo "$entry" >> "$tmp"
    echo "" >> "$tmp"
  fi
  mv "$tmp" "$changelog"
}

cmd_changelog_detail() {
  require_lockfile
  local detail="${1:?Usage: scaffold-sync.sh changelog-detail <detail>}"

  local scaffold_source
  scaffold_source=$(get_scaffold_source)
  local changelog="$scaffold_source/SCAFFOLD_CHANGELOG.md"

  [[ -f "$changelog" ]] || die "Changelog not found at: $changelog"

  # Find the most recent entry and append detail
  local tmp
  tmp=$(mktemp)
  local found_entry=false
  local inserted=false
  while IFS= read -r line; do
    if [[ "$found_entry" == "false" && "$line" == "## "* ]]; then
      found_entry=true
      echo "$line" >> "$tmp"
      continue
    fi
    if [[ "$found_entry" == "true" && "$inserted" == "false" && -z "$line" ]]; then
      echo "- $detail" >> "$tmp"
      echo "" >> "$tmp"
      inserted=true
      continue
    fi
    echo "$line" >> "$tmp"
  done < "$changelog"
  if [[ "$found_entry" == "true" && "$inserted" == "false" ]]; then
    echo "- $detail" >> "$tmp"
  fi
  mv "$tmp" "$changelog"
}

cmd_section_merge() {
  local scaffold_file="${1:?Usage: scaffold-sync.sh section-merge <scaffold-file> <local-file>}"
  local local_file="${2:?Usage: scaffold-sync.sh section-merge <scaffold-file> <local-file>}"

  [[ -f "$scaffold_file" ]] || die "Scaffold file not found: $scaffold_file"
  [[ -f "$local_file" ]] || die "Local file not found: $local_file"

  # Detect which delimiter the scaffold file uses
  local delimiter=""
  if grep -q '<!-- NODE-SPECIFIC-START -->' "$scaffold_file"; then
    delimiter="<!-- NODE-SPECIFIC-START -->"
  elif grep -q '<!-- HUB-MANAGED-START -->' "$scaffold_file"; then
    delimiter="<!-- HUB-MANAGED-START -->"
  else
    # No delimiter in scaffold file — not a section-merge file
    echo "ERROR: No section delimiter found in scaffold file" >&2
    return 1
  fi

  if [[ "$delimiter" == "<!-- NODE-SPECIFIC-START -->" ]]; then
    # Pattern: hub content above delimiter, node content below
    # Take ABOVE delimiter from scaffold, BELOW delimiter from local

    # Get hub content (everything before delimiter) from scaffold
    sed -n "/$delimiter/q;p" "$scaffold_file"

    # Get node content (delimiter + everything after) from local
    if grep -q "$delimiter" "$local_file"; then
      sed -n "/$delimiter/,\$p" "$local_file"
    else
      # Local has no delimiter — treat entire local file as node content
      echo "$delimiter"
      echo "<!-- Everything above is managed by the scaffold hub and updated via /scaffold-pull. -->"
      echo "<!-- Everything below is specific to this project. -->"
      echo ""
      echo "## Project-Specific Features"
      echo ""
      echo "_Migrated from pre-delimiter version:_"
      echo ""
      cat "$local_file"
    fi

  elif [[ "$delimiter" == "<!-- HUB-MANAGED-START -->" ]]; then
    # Pattern: node content above delimiter, hub content below
    # Take ABOVE delimiter from local, BELOW delimiter from scaffold

    # Get node content (everything before delimiter) from local
    if grep -q "$delimiter" "$local_file"; then
      sed -n "/$delimiter/q;p" "$local_file"
    else
      # Local has no delimiter — treat entire local file as node content
      cat "$local_file"
      echo ""
    fi

    # Get hub content (delimiter + everything after) from scaffold
    sed -n "/$delimiter/,\$p" "$scaffold_file"
  fi
}

cmd_scan() {
  echo "Tracked files in project:"
  scan_tracked_files | while IFS= read -r f; do
    echo "  $f"
  done

  if [[ -f "$LOCKFILE" ]]; then
    local scaffold_source
    scaffold_source=$(get_scaffold_source)
    echo ""
    echo "Tracked files in scaffold ($scaffold_source):"
    scan_scaffold_files "$scaffold_source" | while IFS= read -r f; do
      echo "  $f"
    done
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

require_jq

case "${1:-}" in
  init)             shift; cmd_init "$@" ;;
  status)           cmd_status ;;
  diff)             shift; cmd_diff "${1:-}" ;;
  hash)             shift; cmd_hash "$@" ;;
  lock-get)         shift; cmd_lock_get "$@" ;;
  lock-update)      shift; cmd_lock_update "$@" ;;
  lock-add)         shift; cmd_lock_add "$@" ;;
  lock-remove)      shift; cmd_lock_remove "$@" ;;
  lock-set-version) shift; cmd_lock_set_version "$@" ;;
  log)              shift; cmd_log "$@" ;;
  log-detail)       shift; cmd_log_detail "$@" ;;
  changelog)        shift; cmd_changelog "$@" ;;
  changelog-detail) shift; cmd_changelog_detail "$@" ;;
  section-merge)    shift; cmd_section_merge "$@" ;;
  scan)             cmd_scan ;;
  *)
    echo "Usage: scaffold-sync.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  init [scaffold-path]                  Generate lockfile from current state"
    echo "  status                                Show file provenance and sync state"
    echo "  diff [file]                           Show diff between local and scaffold"
    echo "  hash <file>                           Compute sha256 of a file"
    echo "  lock-get <file>                       Read a lockfile entry"
    echo "  lock-update <file> <field> <value>    Update a lockfile field"
    echo "  lock-add <file> <origin> <sh> <lh> <status>  Add a lockfile entry"
    echo "  lock-remove <file>                    Remove a lockfile entry"
    echo "  lock-set-version <version>            Update scaffold version in lockfile"
    echo "  log <message>                         Append to project sync log"
    echo "  log-detail <detail>                   Add detail to last log entry"
    echo "  changelog <message>                   Append to scaffold changelog"
    echo "  changelog-detail <detail>             Add detail to last changelog entry"
    echo "  section-merge <scaffold> <local>       Merge hub/node sections of delimited file"
    echo "  scan                                  List all trackable files"
    exit 1
    ;;
esac
