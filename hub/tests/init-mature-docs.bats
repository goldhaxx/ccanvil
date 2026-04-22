#!/usr/bin/env bats
# Documentation coverage for the init-mature-project feature.
# AC-20, AC-21, AC-22.

REPO_ROOT="$BATS_TEST_DIRNAME/../.."

# =========================================================================
# AC-20: README.md mentions the retrofit flow
# =========================================================================

@test "AC-20: README.md has 'Retrofitting an existing project' subsection" {
  grep -qE '^##.*Retrofit' "$REPO_ROOT/README.md"
}

@test "AC-20: README.md retrofit section references retrofit-check" {
  grep -q 'retrofit-check' "$REPO_ROOT/README.md"
}

# =========================================================================
# AC-21: HOW_TO_USE.md has an 'Adding ccanvil to an existing project' subsection
# =========================================================================

@test "AC-21: HOW_TO_USE.md has 'Adding ccanvil to an existing project' subsection" {
  grep -qE '^##.*Adding ccanvil to an existing project|^##.*[Rr]etrofit' "$REPO_ROOT/hub/meta/HOW_TO_USE.md"
}

@test "AC-21: HOW_TO_USE.md mentions retrofit-check or mode-aware init" {
  grep -qE 'retrofit-check|mature-repo|project mode' "$REPO_ROOT/hub/meta/HOW_TO_USE.md"
}

# =========================================================================
# AC-22: command-reference.md lists retrofit-check + notes mode-awareness
# =========================================================================

@test "AC-22: command-reference.md lists retrofit-check" {
  grep -q 'retrofit-check' "$REPO_ROOT/.ccanvil/guide/command-reference.md"
}

@test "AC-22: command-reference.md notes /ccanvil-init mode-awareness" {
  grep -qE 'mode-aware|project_mode|mature-repo' "$REPO_ROOT/.ccanvil/guide/command-reference.md"
}
