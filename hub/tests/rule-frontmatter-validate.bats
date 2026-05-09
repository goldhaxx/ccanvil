#!/usr/bin/env bats
#
# BTS-386: rule-frontmatter validation in module-manifest.sh validate.
#
# Tests the new rule-scan extension that emits warn-shape rule-tier-budget-exceeded
# drift entries, frontmatter-missing info entries, malformed-yaml block-shape drift,
# and respects --strict to escalate warn-shape to exit 2.

bats_require_minimum_version 1.5.0

MM="$BATS_TEST_DIRNAME/../../.ccanvil/scripts/module-manifest.sh"
FIX_DIR="$BATS_TEST_DIRNAME/fixtures/rule-tier"

# Create a minimal project tree with .claude/rules/ + an empty manifest-allowlist
# so the validator's existing manifest-scan loop is a no-op and only the new
# rule-scan loop has work to do.
_make_rule_project() {
  local name="$1"
  shift
  local fx="$BATS_TEST_TMPDIR/$name"
  mkdir -p "$fx/.claude/rules" "$fx/.ccanvil"
  : > "$fx/.ccanvil/manifest-allowlist.txt"
  local rule
  for rule in "$@"; do
    cp "$FIX_DIR/$rule" "$fx/.claude/rules/$rule"
  done
  echo "$fx"
}

@test "BTS-386 Step 1: validate emits rule-tier-budget-exceeded info entry on over-budget tier-0 rule" {
  set -e
  fx=$(_make_rule_project "over-budget-fx" "over-budget.md")
  cd "$fx"
  run bash "$MM" validate --json
  echo "$output" | jq -e '.info | map(select(.reason == "rule-tier-budget-exceeded")) | length == 1'
  echo "$output" | jq -e '.info | map(select(.reason == "rule-tier-budget-exceeded")) | .[0].path | endswith("over-budget.md")'
  echo "$output" | jq -e '.info | map(select(.reason == "rule-tier-budget-exceeded")) | .[0].value > 150'
  echo "$output" | jq -e '.info | map(select(.reason == "rule-tier-budget-exceeded")) | .[0].threshold == 150'
}

@test "BTS-386 Step 3: under-budget tier-0 rule emits no info or drift entry" {
  set -e
  fx=$(_make_rule_project "under-budget-fx" "under-budget.md")
  cd "$fx"
  run bash "$MM" validate --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.drift | length == 0'
  echo "$output" | jq -e '.info | length == 0'
  echo "$output" | jq -e '.status == "ok"'
}

@test "BTS-386 Step 3: over-budget alone exits 0 with status=ok (info-only signal)" {
  set -e
  fx=$(_make_rule_project "over-budget-warn-fx" "over-budget.md")
  cd "$fx"
  run bash "$MM" validate --json
  [ "$status" -eq 0 ]
  # Status stays "ok" — warn-shape lives in info[], not drift[]. This preserves
  # backward compat for existing consumers (stasis, /pr) that read .status.
  echo "$output" | jq -e '.status == "ok"'
  echo "$output" | jq -e '.drift | length == 0'
  echo "$output" | jq -e '.info | length >= 1'
}

@test "BTS-386 Step 4: --strict escalates rule-tier-budget-exceeded to exit 2" {
  fx=$(_make_rule_project "over-budget-strict-fx" "over-budget.md")
  cd "$fx"
  run bash "$MM" validate --json --strict
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.info | map(select(.reason == "rule-tier-budget-exceeded")) | length == 1'
}

@test "BTS-386 Step 5: frontmatter-missing rule emits info entry, no drift, exit 0" {
  set -e
  fx=$(_make_rule_project "no-frontmatter-fx" "no-frontmatter.md")
  cd "$fx"
  run bash "$MM" validate --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.info | length == 1'
  echo "$output" | jq -e '.info[0].reason == "frontmatter-missing"'
  echo "$output" | jq -e '.info[0].path | endswith("no-frontmatter.md")'
  echo "$output" | jq -e '.drift | length == 0'
  echo "$output" | jq -e '.status == "ok"'
}

@test "BTS-386 Step 5: info array exists even when empty" {
  set -e
  fx=$(_make_rule_project "empty-fx" "under-budget.md")
  cd "$fx"
  run bash "$MM" validate --json
  echo "$output" | jq -e 'has("info")'
  echo "$output" | jq -e '.info | length == 0'
}

@test "BTS-386 Step 6: malformed-yaml frontmatter emits block-shape drift, exit 2" {
  fx=$(_make_rule_project "malformed-fx" "malformed.md")
  cd "$fx"
  run bash "$MM" validate --json
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.drift | map(select(.reason == "rule-frontmatter-malformed")) | length == 1'
  echo "$output" | jq -e '.drift | map(select(.reason == "rule-frontmatter-malformed")) | .[0].path | endswith("malformed.md")'
  echo "$output" | jq -e '.drift | map(select(.reason == "rule-frontmatter-malformed")) | .[0].reason_detail | length > 0'
}
