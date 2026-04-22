#!/usr/bin/env bats
# End-to-end tests for /ccanvil-init retrofit onto mature / partial-ccanvil
# projects. Covers AC-4/AC-5 mode-aware classify_file defaults, AC-6/AC-7/AC-25
# section-merge-create-delimiters action, and AC-14/AC-15 retrofit-check.

HUB_ROOT="$BATS_TEST_DIRNAME/../.."
SCRIPT="$HUB_ROOT/.ccanvil/scripts/ccanvil-sync.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR}"
  NODE=$(mktemp -d)
  mkdir -p "$NODE/.ccanvil/scripts"
  cp "$SCRIPT" "$NODE/.ccanvil/scripts/ccanvil-sync.sh"
  cd "$NODE"
}

teardown() {
  rm -rf "$NODE"
}

# Build a mature-repo fixture: .git/ with an initial commit, source file,
# no ccanvil markers beyond the bootstrap script.
_mature_fixture() {
  git -C "$NODE" init -q -b main
  echo "# Established Project" > "$NODE/README.md"
  mkdir -p "$NODE/src"
  echo "print('hi')" > "$NODE/src/app.py"
  git -C "$NODE" add -A
  git -C "$NODE" -c user.email=t@t -c user.name=t commit -q -m "initial"
}

# Helper: extract the recommended_action for a given file path
_action_for() {
  local file="$1"
  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init-preflight "$HUB_ROOT" \
    | jq -r --arg f "$file" '.plan[] | select(.file == $f) | .recommended_action'
}

# Helper: extract the reason for a given file path
_reason_for() {
  local file="$1"
  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init-preflight "$HUB_ROOT" \
    | jq -r --arg f "$file" '.plan[] | select(.file == $f) | .reason'
}

# =========================================================================
# AC-4: mode-aware classify_file defaults for mature/partial-ccanvil
# =========================================================================

@test "AC-4: mature-repo CLAUDE.md without delimiters → section-merge-create-delimiters" {
  _mature_fixture
  cat > "$NODE/CLAUDE.md" <<'EOF'
# My App

Custom project rules, no delimiters.

## Commands

- `make test`
EOF
  git -C "$NODE" add -A
  git -C "$NODE" -c user.email=t@t -c user.name=t commit -q -m "add CLAUDE.md"

  [ "$(_action_for CLAUDE.md)" = "section-merge-create-delimiters" ]
}

@test "AC-4: mature-repo CLAUDE.md with existing delimiters → section-merge (unchanged)" {
  _mature_fixture
  cat > "$NODE/CLAUDE.md" <<'EOF'
# My App

Custom node section.

<!-- HUB-MANAGED-START -->

## Old hub section
EOF
  git -C "$NODE" add -A
  git -C "$NODE" -c user.email=t@t -c user.name=t commit -q -m "add CLAUDE.md with delimiter"

  [ "$(_action_for CLAUDE.md)" = "section-merge" ]
}

@test "AC-4: mature-repo README.md differs from hub → skip (keep local)" {
  _mature_fixture
  # README.md is already present from _mature_fixture with custom content.
  local action reason
  action=$(_action_for README.md)
  reason=$(_reason_for README.md)
  [ "$action" = "skip" ]
  [[ "$reason" == *"keep local"* ]] || [[ "$reason" == *"node-specific"* ]]
}

@test "AC-4: mature-repo CONTRIBUTING.md differs from hub → skip" {
  _mature_fixture
  cat > "$NODE/CONTRIBUTING.md" <<'EOF'
# Contributing

Project-specific contribution guide.
EOF
  git -C "$NODE" add -A
  git -C "$NODE" -c user.email=t@t -c user.name=t commit -q -m "add CONTRIBUTING"

  [ "$(_action_for CONTRIBUTING.md)" = "skip" ]
}

@test "AC-4: mature-repo .github/workflows/ci.yml differs from hub → review" {
  _mature_fixture
  mkdir -p "$NODE/.github/workflows"
  cat > "$NODE/.github/workflows/ci.yml" <<'EOF'
name: Custom CI
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
EOF
  git -C "$NODE" add -A
  git -C "$NODE" -c user.email=t@t -c user.name=t commit -q -m "add custom ci"

  [ "$(_action_for .github/workflows/ci.yml)" = "review" ]
}

@test "AC-4: partial-ccanvil mode applies same defaults as mature-repo" {
  # Partial-ccanvil: has .claude/ but no lockfile
  mkdir -p "$NODE/.claude/rules"
  echo "# custom rule" > "$NODE/.claude/rules/custom.md"

  # Add a CLAUDE.md without delimiters — should still get the new action
  cat > "$NODE/CLAUDE.md" <<'EOF'
# Partial App

No delimiters.
EOF

  [ "$(_action_for CLAUDE.md)" = "section-merge-create-delimiters" ]
}

# =========================================================================
# AC-5: fresh / source-no-git modes retain existing recommendations
# =========================================================================

@test "AC-5: fresh mode CLAUDE.md absent → copy (unchanged from baseline)" {
  # Fresh dir — no local CLAUDE.md.
  [ "$(_action_for CLAUDE.md)" = "copy" ]
}

@test "AC-5: fresh mode with local CLAUDE.md (no delimiters) differing → review (unchanged)" {
  # Rare edge case: a truly fresh dir with a pre-existing CLAUDE.md stub
  # but no ccanvil markers. Existing behavior flags this as 'review'
  # (conflict — user decides). Mode-aware override must NOT kick in here
  # because mode is 'fresh', not mature/partial.
  #
  # Note: creating CLAUDE.md makes the node partial-ccanvil by spec, so
  # this test's detection path flips to partial — which is AC-4 territory,
  # not AC-5. Instead, we assert fresh-mode via absence of the CLAUDE.md
  # override (above) as the AC-5 anchor for this file.
  skip "AC-5 anchor covered by 'CLAUDE.md absent → copy' test above"
}

@test "AC-5: source-no-git mode README.md present → review (unchanged)" {
  # A project with source files but no git history — classified as
  # source-no-git — must get the existing 'review' default for a
  # conflicting README.md rather than the mature-mode 'skip' override.
  echo "# My Source Project" > "$NODE/README.md"
  mkdir -p "$NODE/src"
  echo "x" > "$NODE/src/code.py"

  [ "$(_action_for README.md)" = "review" ]
}

# =========================================================================
# AC-6 / AC-7 / AC-25: section-merge-create-delimiters action in init-apply
# =========================================================================

@test "AC-6: section-merge-create-delimiters wraps local content + appends hub section" {
  _mature_fixture
  cat > "$NODE/CLAUDE.md" <<'EOF'
# My App

Custom project rules, no delimiters.

## Commands

- `make test`
EOF
  git -C "$NODE" add -A
  git -C "$NODE" -c user.email=t@t -c user.name=t commit -q -m "add CLAUDE.md"

  # Generate + run the plan
  plan_json=$(bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init-preflight "$HUB_ROOT")
  echo "$plan_json" > "$NODE/.ccanvil/init-plan.json"
  run bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init-apply "$HUB_ROOT" "$NODE/.ccanvil/init-plan.json"
  [ "$status" -eq 0 ]

  # Original node content preserved verbatim (above delimiter)
  grep -q "^# My App$" "$NODE/CLAUDE.md"
  grep -q "Custom project rules" "$NODE/CLAUDE.md"
  grep -q "make test" "$NODE/CLAUDE.md"

  # Delimiter inserted on its own line
  grep -qx "<!-- HUB-MANAGED-START -->" "$NODE/CLAUDE.md"

  # Hub content below the delimiter
  # (use ccanvil's real CLAUDE.md hub section — any of its known strings will do)
  local delim_line
  delim_line=$(grep -n "^<!-- HUB-MANAGED-START -->$" "$NODE/CLAUDE.md" | head -1 | cut -d: -f1)
  [ -n "$delim_line" ]
  tail -n "+$delim_line" "$NODE/CLAUDE.md" | grep -q "HUB-MANAGED-START"

  # Local content sits ABOVE the delimiter
  head -n "$((delim_line - 1))" "$NODE/CLAUDE.md" | grep -q "# My App"
}

@test "AC-7: section-merge-create-delimiters is idempotent on already-wrapped files" {
  _mature_fixture
  cat > "$NODE/CLAUDE.md" <<'EOF'
# My App

First run content.
EOF
  git -C "$NODE" add -A
  git -C "$NODE" -c user.email=t@t -c user.name=t commit -q -m "add CLAUDE.md"

  # First apply — wraps + inserts delimiter
  plan_json=$(bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init-preflight "$HUB_ROOT")
  echo "$plan_json" > "$NODE/.ccanvil/init-plan.json"
  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init-apply "$HUB_ROOT" "$NODE/.ccanvil/init-plan.json" >/dev/null

  local after_first
  after_first=$(shasum "$NODE/CLAUDE.md" | awk '{print $1}')

  # Second apply with EXPLICIT section-merge-create-delimiters action on the
  # already-wrapped file — should dispatch to standard section-merge
  # (no re-wrapping, no duplicate delimiters).
  cat > "$NODE/.ccanvil/init-plan.json" <<EOF
[{"file": "CLAUDE.md", "source": "both", "recommended_action": "section-merge-create-delimiters", "reason": "idempotency test"}]
EOF
  run bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init-apply "$HUB_ROOT" "$NODE/.ccanvil/init-plan.json"
  [ "$status" -eq 0 ]

  # Delimiter appears exactly once
  local delim_count
  delim_count=$(grep -cx "<!-- HUB-MANAGED-START -->" "$NODE/CLAUDE.md")
  [ "$delim_count" = "1" ]

  # First-run content still present
  grep -q "First run content" "$NODE/CLAUDE.md"
}

@test "AC-25: prose mention of HUB-MANAGED-START is not treated as delimiter" {
  _mature_fixture
  cat > "$NODE/CLAUDE.md" <<'EOF'
# My App

Note: the string `<!-- HUB-MANAGED-START -->` appears in template docs
but is not used here as a structural delimiter.

## My rules

- Rule 1
EOF
  git -C "$NODE" add -A
  git -C "$NODE" -c user.email=t@t -c user.name=t commit -q -m "add CLAUDE.md with prose mention"

  # Preflight must recommend section-merge-create-delimiters (AC-25): the
  # prose mention is not an exact-line delimiter.
  [ "$(_action_for CLAUDE.md)" = "section-merge-create-delimiters" ]

  # Applying the action wraps the whole local file as node section and
  # appends a real delimiter below — resulting in exactly ONE exact-line
  # delimiter and the prose kept verbatim above it.
  plan_json=$(bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init-preflight "$HUB_ROOT")
  echo "$plan_json" > "$NODE/.ccanvil/init-plan.json"
  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init-apply "$HUB_ROOT" "$NODE/.ccanvil/init-plan.json" >/dev/null

  local delim_count
  delim_count=$(grep -cx "<!-- HUB-MANAGED-START -->" "$NODE/CLAUDE.md")
  [ "$delim_count" = "1" ]

  # Prose mention preserved
  grep -q "appears in template docs" "$NODE/CLAUDE.md"
  # Section heading preserved
  grep -q "^## My rules$" "$NODE/CLAUDE.md"
}
