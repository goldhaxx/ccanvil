# Plan: Codified feature lifecycle with draft PR and doc cleanup

> Feature: feature-lifecycle
> Spec hash: (from docs/spec.md)
> Created: 1775614129

## Approach

Enhance `cmd_activate` to create a draft PR, enhance `cmd_complete` to remove lifecycle docs and commit, add a CI check for stale docs, and repurpose `/pr` as a finalize command. All changes follow existing patterns in docs-check.sh and the test fixtures in feature-lifecycle.bats.

## Key Design Decisions

1. **`gh` is optional.** Both activate and complete wrap gh calls in `command -v gh` guards. The workflow works fully offline — PR creation is a bonus, not a gate.
2. **Remote detection.** Before pushing or creating PRs, check `git remote get-url origin`. If no remote, skip silently. This handles fresh local repos.
3. **Complete does the commit.** Currently complete doesn't commit. Enhanced complete will `git add` + `git commit` the spec status change AND the doc removal in one commit. This keeps the branch tip clean.
4. **`/pr` becomes finalize.** It still runs tests/validation, but its primary job shifts from "create PR" to "ensure PR is ready" — cleaning docs if needed, pushing, and marking the draft PR as ready.

## Steps

### Step 1: Test — activate creates draft PR (RED)
**File:** `hub/tests/feature-lifecycle.bats`

Add test after existing activate tests. Mock `gh` with a stub script that records args to a file. Assert: stub was called with `pr create --draft`, branch was pushed.

Since we can't actually push to a remote in tests, we need to set up a bare remote in the fixture. Add to setup: `REMOTE=$(mktemp -d) && git -C "$REMOTE" init -q --bare && git -C "$PROJECT" remote add origin "$REMOTE"`.

But this changes setup for ALL tests. Instead, add the remote setup only in the new tests that need it, or add it to setup and verify existing tests still pass (they should — having a remote doesn't break anything).

Decision: add bare remote to setup. It's harmless and more realistic.

### Step 2: Implement — activate draft PR (GREEN)
**File:** `preset/.ccanvil/scripts/docs-check.sh`

After the existing commit in `cmd_activate`, add:
```bash
# Push branch and create draft PR (if gh available and remote exists)
if git -C "$repo_root" remote get-url origin >/dev/null 2>&1; then
  git -C "$repo_root" push -u origin "$branch_name" 2>/dev/null || true
  if command -v gh >/dev/null 2>&1; then
    local summary
    summary=$(sed -n '/^## Summary$/,/^## /{ /^## Summary$/d; /^## /d; p; }' "$spec_file" | head -5)
    local pr_title="${spec_type}(${feature_id}): ${summary%% *}"
    # Better: use first line of summary
    local first_line
    first_line=$(sed -n '/^## Summary$/,/^## /{ /^## /d; /^$/d; p; }' "$spec_file" | head -1 | sed 's/^[[:space:]]*//')
    [[ -n "$first_line" ]] && pr_title="${spec_type}(${feature_id}): ${first_line}"
    local spec_body
    spec_body=$(cat "$spec_file")
    gh pr create --draft \
      --title "$pr_title" \
      --body "$(printf '## Spec\n\n%s\n\n---\n🤖 Generated with [Claude Code](https://claude.com/claude-code)' "$spec_body")" \
      2>/dev/null && echo "Draft PR created." || echo "NOTE: Draft PR not created — gh pr create failed." >&2
  else
    echo "NOTE: Draft PR not created — gh CLI not available. Run /pr to create manually."
  fi
fi
```

### Step 3: Test — activate succeeds without gh (GREEN)
Already tested implicitly (existing tests have no gh), but add explicit test:
- Temporarily rename gh in PATH, run activate, assert success and warning message.

### Step 4: Test — activate skips PR when no remote (GREEN)
Test: no remote configured, activate succeeds, no push attempted.

### Step 5: Test — complete removes lifecycle docs (RED → GREEN)
**File:** `hub/tests/feature-lifecycle.bats`

Setup: create spec.md, plan.md, checkpoint.md in docs/. Activate, then complete. Assert: all three removed, archived spec preserved in specs/.

### Step 6: Implement — complete removes lifecycle docs
**File:** `preset/.ccanvil/scripts/docs-check.sh`

Add to `cmd_complete` after marking status Complete:
```bash
# Remove lifecycle docs
rm -f "$docs_dir/spec.md" "$docs_dir/plan.md" "$docs_dir/checkpoint.md"

# Commit the completion + cleanup
local repo_root
repo_root=$(cd "$docs_dir" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) || repo_root="."
git -C "$repo_root" add "$spec_file" "$docs_dir/spec.md" "$docs_dir/plan.md" "$docs_dir/checkpoint.md"
[[ -f "$assumptions_file" ]] && git -C "$repo_root" add "$assumptions_file"
git -C "$repo_root" commit -q -m "docs(lifecycle): complete $feature_id — clean up lifecycle docs" || true
```

### Step 7: Test — complete commits cleanup (GREEN)
Assert: git log shows the cleanup commit, working tree is clean after complete.

### Step 8: Test — complete marks PR as ready (RED → GREEN)
Mock gh, assert `gh pr ready` was called.

### Step 9: Implement — complete marks PR as ready
Add to `cmd_complete` after commit:
```bash
if command -v gh >/dev/null 2>&1; then
  gh pr ready 2>/dev/null || true
fi
```

### Step 10: Add CI lifecycle docs check
**File:** `preset/.ccanvil/templates/github/workflows/ci.yml`

Add a new job:
```yaml
lifecycle-docs:
  runs-on: ubuntu-latest
  if: github.event_name == 'pull_request'
  steps:
    - uses: actions/checkout@v4
    - name: Check for stale lifecycle docs
      run: |
        stale=""
        [ -f docs/spec.md ] && stale="$stale docs/spec.md"
        [ -f docs/plan.md ] && stale="$stale docs/plan.md"
        [ -f docs/checkpoint.md ] && stale="$stale docs/checkpoint.md"
        if [ -n "$stale" ]; then
          echo "::error::Lifecycle docs must be cleaned up before merge:$stale"
          echo "Run: docs-check.sh complete <feature-id>"
          exit 1
        fi
```

### Step 11: Test CI check (RED → GREEN)
Test the logic as a bash snippet: create stale docs, run the check, assert failure. No docs, assert success.

### Step 12: Update /pr skill
**File:** `preset/.claude/commands/pr.md`

Repurpose: tests → validate → clean up docs (if still present) → push → create PR if none exists → mark ready. Add `--skip-review` passthrough. Key change: if PR already exists (from activate), just push and mark ready. If PR doesn't exist, create one.

### Step 13: Update workflow.md
**File:** `preset/.claude/rules/workflow.md`

Add a "Feature Lifecycle" section documenting the full flow:
```
Spec → Activate (branch + draft PR) → Plan → Implement → Complete (cleanup + PR ready) → Merge
```

### Step 14: Update command-reference.md
**File:** `preset/.ccanvil/guide/command-reference.md`

Update the activate and complete descriptions to reflect new behaviors.

### Step 15: Run full suite, verify 378+ all green

### Step 16: Commit
```
feat(lifecycle): draft PR at activate, doc cleanup at complete
```
