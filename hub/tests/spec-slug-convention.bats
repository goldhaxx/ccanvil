#!/usr/bin/env bats
# Tests for slug-prefixed spec filenames and branch names.
# BTS-130 (work-identity) — Phase 4: /spec filename + branch convention.
#
# The /spec skill (agentic) resolves a work ref via work.resolve, derives
# a slug, and writes the spec file as docs/specs/<slug>-<kebab-name>.md.
# The downstream activate command derives the branch name from the
# filename, so the slug appears in the branch name too — which is the
# gate for Linear's GitHub integration auto-linking.

SCRIPT="$BATS_TEST_DIRNAME/../../.ccanvil/scripts/docs-check.sh"
OPS="$BATS_TEST_DIRNAME/../../.ccanvil/scripts/operations.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR}"
  REPO=$(mktemp -d)
  BARE=$(mktemp -d)
  git -C "$REPO" init -q -b main
  git -C "$REPO" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "init"
  git -C "$BARE" init --bare -q -b main
  git -C "$REPO" remote add origin "$BARE"
  git -C "$REPO" push -q -u origin main
  mkdir -p "$REPO/docs/specs"
}

teardown() {
  rm -rf "$REPO" "$BARE"
}

# ===========================================================================
# AC-14 — activate branch name contains the work slug as a substring
# (Linear's GitHub integration matcher is substring-based; this is the gate.)
# ===========================================================================

@test "BTS-130 AC-14: activate on a slug-prefixed spec creates a branch containing the slug" {
  cat > "$REPO/docs/specs/bts-130-example-feature.md" <<'EOF'
# Feature: Example

> Feature: bts-130-example-feature
> Work: linear:BTS-130
> Created: 1776973070
> Status: Draft

## Summary

Test body.
EOF
  cd "$REPO"
  run bash "$SCRIPT" activate bts-130-example-feature "$REPO/docs"
  [ "$status" -eq 0 ]
  local branch
  branch=$(git -C "$REPO" branch --show-current)
  # Branch must contain the slug substring for Linear's auto-link to fire
  [[ "$branch" == *"bts-130"* ]]
}

@test "BTS-130 AC-14: local-provider slug (idea-29) also appears in branch" {
  cat > "$REPO/docs/specs/idea-29-example-feature.md" <<'EOF'
# Feature: Local Example

> Feature: idea-29-example-feature
> Work: local:idea-29
> Created: 1776973070
> Status: Draft

## Summary

Local body.
EOF
  cd "$REPO"
  run bash "$SCRIPT" activate idea-29-example-feature "$REPO/docs"
  [ "$status" -eq 0 ]
  local branch
  branch=$(git -C "$REPO" branch --show-current)
  [[ "$branch" == *"idea-29"* ]]
}

# ===========================================================================
# Skill contract — operations.sh produces the expected filename components
# when invoked by the /spec skill. This is the building-block contract the
# skill's agentic flow depends on.
# ===========================================================================

@test "BTS-130 Phase 4: work.resolve slug is suitable for filename prefix" {
  # Use explicit prefix so this test doesn't depend on the repo's routing config.
  run bash "$OPS" resolve work.resolve linear:BTS-130 --project-dir "$REPO"
  [ "$status" -eq 0 ]
  local slug
  slug=$(echo "$output" | jq -r '.slug')
  # Slug must be filesystem- and branch-safe
  [[ "$slug" =~ ^[a-z0-9][a-z0-9-]*$ ]]
  # Constructed filename must be predictable
  local expected_fname="${slug}-my-example.md"
  [ "$expected_fname" = "bts-130-my-example.md" ]
}
