#!/usr/bin/env bats
# Tests for stasis-recall: comprehensive rename of checkpoint/catchup →
# stasis/recall across verbs, artifact filename, template, internal
# identifiers, and guide references. Spec: docs/specs/stasis-recall.md

REPO_ROOT="$BATS_TEST_DIRNAME/../.."

# --- Step 1: Template rename + three new sections ---

@test "template: .ccanvil/templates/stasis.md exists" {
  [ -f "$REPO_ROOT/.ccanvil/templates/stasis.md" ]
}

@test "template: legacy .ccanvil/templates/checkpoint.md no longer exists" {
  [ ! -f "$REPO_ROOT/.ccanvil/templates/checkpoint.md" ]
}

@test "template: stasis.md has Cross-Session Patterns section" {
  grep -q "^## Cross-Session Patterns" "$REPO_ROOT/.ccanvil/templates/stasis.md"
}

@test "template: stasis.md has Security Review section" {
  grep -q "^## Security Review" "$REPO_ROOT/.ccanvil/templates/stasis.md"
}

@test "template: stasis.md has Memory Candidates section" {
  grep -q "^## Memory Candidates" "$REPO_ROOT/.ccanvil/templates/stasis.md"
}

@test "template: stasis.md retains existing required sections" {
  grep -q "^## Accomplished" "$REPO_ROOT/.ccanvil/templates/stasis.md"
  grep -q "^## Current State" "$REPO_ROOT/.ccanvil/templates/stasis.md"
  grep -q "^## Next Steps" "$REPO_ROOT/.ccanvil/templates/stasis.md"
  grep -q "^## Determinism Review" "$REPO_ROOT/.ccanvil/templates/stasis.md"
}
