#!/usr/bin/env bats
# BTS-125: drift-guard — verify the safe-markdown rule is encoded in
# .claude/skills/idea/SKILL.md so future hub edits don't silently drop
# it. Mirrors the BTS-171 pattern.

bats_require_minimum_version 1.5.0

SKILL="$BATS_TEST_DIRNAME/../../.claude/skills/idea/SKILL.md"

@test "AC-1: SKILL.md contains the Safe-markdown section heading" {
  grep -qE "^##+ Safe-markdown" "$SKILL"
}

@test "AC-2: SKILL.md documents the failing pattern shape (bold-around-leading-codespan)" {
  # Anchor on the structural shape rather than full prose. The fail-pattern
  # must be visible: bold markers with a backtick immediately inside.
  grep -qF '**`' "$SKILL"
}

@test "AC-2: SKILL.md documents at least one rewrite shape" {
  # Either codespan-then-text (`code` — text.) or bold-with-late-backtick
  # (**Text with `code` later.**) — accept either as evidence the rule
  # surfaces the avoidance.
  grep -qE 'rewrite|avoid|prefer' "$SKILL"
}

@test "AC-3: SKILL.md anchors the rule on BTS-125 by name" {
  grep -q "BTS-125" "$SKILL"
}

@test "AC-4: Safe-markdown section is in the hub-managed area (above NODE-SPECIFIC-START)" {
  set -e
  rule_line=$(grep -nE "^##+ Safe-markdown" "$SKILL" | head -1 | cut -d: -f1)
  marker_line=$(grep -n "NODE-SPECIFIC-START" "$SKILL" | head -1 | cut -d: -f1)
  [ -n "$rule_line" ]
  [ -n "$marker_line" ]
  [ "$rule_line" -lt "$marker_line" ]
}
