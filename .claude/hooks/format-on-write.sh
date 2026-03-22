#!/usr/bin/env bash
# format-on-write.sh — PostToolUse hook for Write|Edit|MultiEdit
# Auto-formats files after Claude writes them.
# Uncomment the formatter line matching your project's toolchain.
# Exit 0 always — formatting failures should not block writes.

set -uo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[[ -z "$FILE_PATH" ]] && exit 0
[[ ! -f "$FILE_PATH" ]] && exit 0

# Detect file type and format accordingly
case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx|*.json|*.css|*.scss|*.html|*.md|*.yaml|*.yml)
    # Uncomment ONE of these for your project:
    # npx prettier --write "$FILE_PATH" 2>/dev/null || true
    # pnpm exec prettier --write "$FILE_PATH" 2>/dev/null || true
    # deno fmt "$FILE_PATH" 2>/dev/null || true
    ;;
  *.py)
    # ruff format "$FILE_PATH" 2>/dev/null || true
    # black "$FILE_PATH" 2>/dev/null || true
    ;;
  *.go)
    # gofmt -w "$FILE_PATH" 2>/dev/null || true
    ;;
  *.rs)
    # rustfmt "$FILE_PATH" 2>/dev/null || true
    ;;
  *.sh)
    # shfmt -w "$FILE_PATH" 2>/dev/null || true
    ;;
esac

exit 0
