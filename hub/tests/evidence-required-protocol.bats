#!/usr/bin/env bats
# BTS-201 — drift-guards for the capture-time evidence requirement.
#
# These tests assert structural properties across the rule file, the three
# skill files (/idea, /stasis, /recall), and the stasis template — guarding
# against regression of the "evidence, not suspicions" protocol that closes
# the failure mode that produced BTS-198.

bats_require_minimum_version 1.5.0

REPO_ROOT="$BATS_TEST_DIRNAME/../.."
RULE="$REPO_ROOT/.claude/rules/evidence-required-for-captures.md"
IDEA_SKILL="$REPO_ROOT/.claude/skills/idea/SKILL.md"
STASIS_SKILL="$REPO_ROOT/.claude/skills/stasis/SKILL.md"
RECALL_SKILL="$REPO_ROOT/.claude/skills/recall/SKILL.md"
STASIS_TPL="$REPO_ROOT/.ccanvil/templates/stasis.md"

# =========================================================================
# AC-1, AC-2: rule file
# =========================================================================

@test "AC-1: rule file exists" {
  [ -f "$RULE" ]
}

@test "AC-2: rule documents the four evidence anchors" {
  set -e
  grep -qF 'Command:' "$RULE"
  grep -qF 'Output:' "$RULE"
  grep -qF 'Exit:' "$RULE"
  grep -qF 'Reproduce:' "$RULE"
}

@test "AC-2: rule documents DIAGNOSE: vs FIX: titling convention" {
  set -e
  grep -qF 'DIAGNOSE:' "$RULE"
  grep -qF 'FIX:' "$RULE"
}

@test "AC-2: rule documents the four anchor names by label" {
  set -e
  grep -qE 'exact command' "$RULE"
  grep -qE 'exit code' "$RULE"
  grep -qE 'reproducer' "$RULE"
}

@test "AC-2: rule is anchored on BTS-198 (origin incident) and BTS-201 (this ship)" {
  set -e
  grep -qF 'BTS-198' "$RULE"
  grep -qF 'BTS-201' "$RULE"
}
