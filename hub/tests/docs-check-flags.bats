#!/usr/bin/env bats
# BTS-212 — drift-guard for uniform flag parsing across docs-check.sh
# project-tree-aware subcommands.
#
# Two contracts enforced per cmd in PROJECT_TREE_SUBCOMMANDS:
#   Shape A: `--project-dir <fixture>` exits 0 OR emits a clean substrate-level
#            usage/error message to stderr. Never `dirname:` / `jq:` / `sed:`
#            / `awk:` (downstream-tool errors that bypass substrate ownership
#            of the contract).
#   Shape B: `--bogus-flag-xyz` exits 2 AND stderr starts with `Usage:`.
#
# Plus a reverse-direction guard: every dispatched cmd in the case statement
# whose body parses `--project-dir` MUST appear in PROJECT_TREE_SUBCOMMANDS,
# so newly-added cmds inherit the contract by construction.

bats_require_minimum_version 1.5.0

# BTS-497 telemetry hooks.
source "$BATS_TEST_DIRNAME/_helpers/telemetry.bash"
setup_file()    { telemetry_setup_file; }
teardown_file() { telemetry_teardown_file; }
teardown()      { telemetry_teardown; }

DC="$BATS_TEST_DIRNAME/../../.ccanvil/scripts/docs-check.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR}"
  # Prepare a minimal project tree fixture so cmds that read docs/, .ccanvil/,
  # or .git find an empty-but-valid root. Shape A asserts exit 0 OR clean
  # usage; either is acceptable.
  mkdir -p "$BATS_TEST_TMPDIR/.ccanvil/state" "$BATS_TEST_TMPDIR/docs/specs"
  ( cd "$BATS_TEST_TMPDIR" && git init -q 2>/dev/null || true )
  telemetry_setup
}

# Extract PROJECT_TREE_SUBCOMMANDS[] without sourcing the script (sourcing
# triggers the dispatcher tail). Same awk-extract pattern as BTS-217's
# _normalize_feature_to_ticket helper test.
_extract_project_tree_subcommands() {
  awk '
    /^PROJECT_TREE_SUBCOMMANDS=\(/ { capturing=1; next }
    capturing && /^\)$/ { capturing=0; next }
    capturing { print }
  ' "$DC" \
    | tr -s '[:space:]' '\n' \
    | grep -v '^$' \
    | grep -v '^#'
}

# Shape A loop — every cmd accepts --project-dir without producing a
# downstream-tool error. Exit 0 is best; clean substrate-level usage/error
# (stderr starts with `Usage:` or `ERROR:`) is acceptable when the cmd
# requires additional positional args.
@test "BTS-212 shape A: every PROJECT_TREE_SUBCOMMAND accepts --project-dir without downstream-tool error" {
  set -e

  local fixture="$BATS_TEST_TMPDIR"
  local failures=()

  while IFS= read -r cmd; do
    [[ -z "$cmd" ]] && continue
    local stderr_file
    stderr_file=$(mktemp)
    local exit_code=0
    bash "$DC" "$cmd" --project-dir "$fixture" >/dev/null 2>"$stderr_file" || exit_code=$?

    # Reject downstream-tool error signatures regardless of exit code.
    if grep -qE '^(dirname|jq|sed|awk|cut|head|tail|tr|mktemp|cat):' "$stderr_file"; then
      failures+=("$cmd: downstream-tool error in stderr ($(head -1 "$stderr_file"))")
    elif [[ "$exit_code" -ne 0 ]]; then
      # Non-zero exit is acceptable iff stderr opens with a substrate-owned
      # message: ERROR:, Usage:, WARN:.
      if ! grep -qE '^(ERROR:|Usage:|WARN:)' "$stderr_file"; then
        failures+=("$cmd: exit $exit_code with non-substrate stderr: $(head -1 "$stderr_file")")
      fi
    fi
    rm -f "$stderr_file"
  done < <(_extract_project_tree_subcommands)

  if [[ "${#failures[@]}" -gt 0 ]]; then
    printf 'shape A failures:\n' >&2
    printf '  - %s\n' "${failures[@]}" >&2
    return 1
  fi
}

# Shape B loop — every cmd emits a clean Usage message + exit 2 when given
# an unknown flag. No silent fall-through, no downstream-tool error.
@test "BTS-212 shape B: every PROJECT_TREE_SUBCOMMAND emits Usage + exit 2 on unknown flag" {
  set -e

  local failures=()

  while IFS= read -r cmd; do
    [[ -z "$cmd" ]] && continue
    local stderr_file
    stderr_file=$(mktemp)
    local exit_code=0
    bash "$DC" "$cmd" --bogus-flag-xyz >/dev/null 2>"$stderr_file" || exit_code=$?

    if [[ "$exit_code" -ne 2 ]]; then
      failures+=("$cmd: expected exit 2, got $exit_code")
    elif ! grep -qE '^Usage:' "$stderr_file"; then
      failures+=("$cmd: stderr did not start with 'Usage:' (saw: $(head -1 "$stderr_file"))")
    elif grep -qE '^(dirname|jq|sed|awk|cut|head|tail|tr|mktemp|cat):' "$stderr_file"; then
      failures+=("$cmd: downstream-tool error leaked: $(head -1 "$stderr_file")")
    fi
    rm -f "$stderr_file"
  done < <(_extract_project_tree_subcommands)

  if [[ "${#failures[@]}" -gt 0 ]]; then
    printf 'shape B failures:\n' >&2
    printf '  - %s\n' "${failures[@]}" >&2
    return 1
  fi
}

# Reverse-direction guard — any dispatched cmd whose body parses --project-dir
# must appear in PROJECT_TREE_SUBCOMMANDS. Catches new cmds that quietly
# canonicalize the flag without registering for the contract test.
@test "BTS-212 reverse: every cmd parsing --project-dir is registered in PROJECT_TREE_SUBCOMMANDS" {
  set -e

  # Pure-utility / internal-only cmds explicitly excluded from the contract.
  # If you add a new entry here, document why in the comment block above
  # PROJECT_TREE_SUBCOMMANDS.
  local exclusions="extract-work title-from-body idea-template-body derive-pr-title auto-close-emit auto-transition-emit idea-pending-append idea-pending-validate"

  # Snapshot the array for membership tests.
  local registered=" $(_extract_project_tree_subcommands | tr '\n' ' ') "

  # Walk the dispatcher case statement; for each cmd, check if its cmd_*
  # body parses --project-dir. If yes, assert it's in PROJECT_TREE_SUBCOMMANDS.
  local missing=()
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*([a-z_-]+)\)[[:space:]]*cmd_([a-z_]+)[[:space:]] ]] || continue
    local subcmd="${BASH_REMATCH[1]}"
    local fnname="cmd_${BASH_REMATCH[2]}"

    # Skip explicitly-excluded utility/internal cmds.
    [[ " $exclusions " == *" $subcmd "* ]] && continue

    # Detect --project-dir parsing in the function body via awk.
    local parses_flag
    parses_flag=$(awk -v fn="^${fnname}\\\\(\\\\) \\\\{" '
      $0 ~ fn { capturing=1; next }
      capturing && /^\}$/ { capturing=0 }
      capturing && /--project-dir/ { print "yes"; exit }
    ' "$DC")

    if [[ "$parses_flag" == "yes" && "$registered" != *" $subcmd "* ]]; then
      missing+=("$subcmd")
    fi
  done < "$DC"

  if [[ "${#missing[@]}" -gt 0 ]]; then
    printf 'cmds parse --project-dir but are NOT in PROJECT_TREE_SUBCOMMANDS:\n' >&2
    printf '  - %s\n' "${missing[@]}" >&2
    return 1
  fi
}
