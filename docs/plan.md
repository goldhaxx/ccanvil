# Plan: Main branch guard and land command

> Feature: safe-land
> Spec hash: (from docs/spec.md)
> Created: 1775619120

## Approach

Two independent units built in sequence: the hook first (it's simpler and establishes the invariant), then the land command (which depends on the invariant). Both follow established patterns — protect-files.sh for hooks, cmd_complete for lifecycle commands.

## Steps

### Step 1: Write protect-main hook
**File:** `preset/.claude/hooks/protect-main.sh`

Pattern: match existing `protect-files.sh`. The hook receives the tool use event via environment. Check if the Bash command contains `git commit` and the current branch is main/master.

```bash
#!/usr/bin/env bash
# protect-main.sh — Block direct commits to main/master.
# PreToolUse hook for Bash commands.

# Only check Bash tool uses
[[ "$CLAUDE_TOOL_NAME" == "Bash" ]] || exit 0

# Extract the command
cmd="$CLAUDE_TOOL_INPUT"

# Check if it's a git commit command
if echo "$cmd" | grep -qE '(^|[;&|] *)git\s+commit'; then
  # Allow if --allow-main bypass is present
  echo "$cmd" | grep -q '\-\-allow-main' && exit 0

  # Check current branch
  branch=$(git branch --show-current 2>/dev/null)
  if [[ "$branch" == "main" || "$branch" == "master" ]]; then
    echo "BLOCKED: Direct commits to main are not allowed. Create a feature branch first."
    exit 2
  fi
fi

exit 0
```

### Step 2: Register hook in settings.json
**File:** `preset/.claude/settings.json`

Read current settings, add protect-main.sh to the hooks array.

### Step 3: Test — hook blocks commit on main (RED → GREEN)
**File:** `hub/tests/feature-lifecycle.bats` (or dedicated hooks test file)

Test the hook script directly by setting env vars and running it. Tests:
- On main + git commit → exit 2
- On feature branch + git commit → exit 0
- On main + git status → exit 0
- On main + git commit with --allow-main → exit 0

### Step 4: Test — land fails on main (RED)
**File:** `hub/tests/feature-lifecycle.bats`

```bash
@test "land: fails when already on main" {
  cd "$PROJECT"
  run "$PROJECT/.ccanvil/scripts/docs-check.sh" land
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "Already on main"
}
```

### Step 5: Implement cmd_land (GREEN)
**File:** `preset/.ccanvil/scripts/docs-check.sh`

```bash
cmd_land() {
  local force=false
  [[ "${1:-}" == "--force" ]] && force=true

  local branch
  branch=$(git branch --show-current 2>/dev/null)

  # Must not be on main
  if [[ "$branch" == "main" || "$branch" == "master" ]]; then
    echo "ERROR: Already on main. Nothing to land." >&2
    exit 1
  fi

  # Check if PR is merged (unless --force)
  if ! $force && command -v gh >/dev/null 2>&1; then
    local pr_state
    pr_state=$(gh pr view --json state -q '.state' 2>/dev/null || echo "NONE")
    if [[ "$pr_state" != "MERGED" ]]; then
      echo "ERROR: No merged PR found for branch '$branch'. Merge the PR first, or use --force." >&2
      exit 1
    fi
  fi

  # Switch to main
  git checkout main 2>/dev/null || git checkout master 2>/dev/null || {
    echo "ERROR: Could not switch to main/master." >&2
    exit 1
  }
  echo "Switched to main."

  # Fetch and reset (if remote exists)
  if git remote get-url origin >/dev/null 2>&1; then
    git fetch origin 2>/dev/null
    echo "Fetched origin."
    local sha
    sha=$(git rev-parse --short origin/main 2>/dev/null || git rev-parse --short origin/master 2>/dev/null)
    git reset --hard "origin/main" 2>/dev/null || git reset --hard "origin/master" 2>/dev/null
    echo "Main updated to $sha."
  fi

  # Delete local branch
  git branch -d "$branch" 2>/dev/null || git branch -D "$branch" 2>/dev/null || true
  echo "Deleted local branch '$branch'."

  # Delete remote branch (if remote exists)
  if git remote get-url origin >/dev/null 2>&1; then
    git push origin --delete "$branch" 2>/dev/null && \
      echo "Deleted remote branch '$branch'." || \
      echo "Remote branch '$branch' already deleted."
  fi

  echo "Land complete."
}
```

### Step 6: Test — land from feature branch after merge (RED → GREEN)
Setup: create feature branch, make commit, simulate merged state (use --force since no real GitHub). Run land, assert: on main, branch deleted.

### Step 7: Test — land fails with unmerged PR (RED → GREEN)
Skip if gh not available in test env. Or test with --force bypass.

### Step 8: Test — land handles no remote (RED → GREEN)
Remove origin, run land --force, assert: switches to main, deletes local branch, no error.

### Step 9: Test — land handles already-deleted remote branch (RED → GREEN)
Delete remote branch before running land, assert: no error, graceful skip message.

### Step 10: Register land in dispatch table
**File:** `preset/.ccanvil/scripts/docs-check.sh`

Add `land) shift; cmd_land "$@" ;;` to the case statement.

### Step 11: Update /pr skill
**File:** `preset/.claude/commands/pr.md`

Add at the end: `"After the PR is merged, run: docs-check.sh land"`

### Step 12: Update workflow.md
**File:** `preset/.claude/rules/workflow.md`

Add `Land` to the lifecycle table:
```
| **Land** | Switch to main, sync, delete branch | `docs-check.sh land` |
```

### Step 13: Update command-reference.md
**File:** `preset/.ccanvil/guide/command-reference.md`

Add land to the lifecycle scripts table.

### Step 14: Run full suite, verify 386+ all green

### Step 15: Commit
```
feat(lifecycle): add main branch guard and land command
```
