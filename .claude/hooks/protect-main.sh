#!/usr/bin/env bash
# protect-main.sh — PreToolUse hook for Bash
# Blocks git commit on main/master to prevent divergent branch errors.
# The land command depends on this invariant: main never has local-only commits.
# Exit 2 = hard block (stderr becomes Claude's feedback)
# Exit 0 = allow

set -uo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

[[ -z "$COMMAND" ]] && exit 0

# Only check git commit commands
if [[ ! "$COMMAND" =~ git[[:space:]]+commit ]]; then
  exit 0
fi

# Allow bypass with --allow-main (for init commits, hotfixes)
if [[ "$COMMAND" =~ --allow-main ]]; then
  exit 0
fi

# Check current branch
BRANCH=$(git branch --show-current 2>/dev/null || echo "")

if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
  echo "BLOCKED: Direct commits to main are not allowed. Create a feature branch first." >&2
  echo "  Use docs-check.sh activate <feature-id> to create a branch." >&2
  echo "  If this is an init commit or hotfix, add --allow-main to bypass." >&2
  exit 2
fi

exit 0
