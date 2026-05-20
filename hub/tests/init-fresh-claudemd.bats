#!/usr/bin/env bats

# BTS-497 telemetry hooks.
source "$BATS_TEST_DIRNAME/_helpers/telemetry.bash"
setup_file()    { telemetry_setup_file; }
teardown_file() { telemetry_teardown_file; }
# BTS-327 — fresh-mode CLAUDE.md template wedge.
#
# Verifies that /ccanvil-init in `fresh` mode uses .ccanvil/templates/CLAUDE.md.fresh
# (a clean placeholder template) as the hub source for CLAUDE.md, not the hub's
# actual CLAUDE.md (which carries hub-specific operator content above
# <!-- HUB-MANAGED-START -->).

HUB_ROOT="$BATS_TEST_DIRNAME/../.."
SCRIPT="$HUB_ROOT/.ccanvil/scripts/ccanvil-sync.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR}"
  NODE=$(mktemp -d)
  mkdir -p "$NODE/.ccanvil/scripts"
  cp "$SCRIPT" "$NODE/.ccanvil/scripts/ccanvil-sync.sh"
  cd "$NODE"
  telemetry_setup
}

teardown() {
  telemetry_teardown
  rm -rf "$NODE"
}

# Build a synthetic hub directory that has CLAUDE.md but NO
# .ccanvil/templates/CLAUDE.md.fresh. Used to verify the missing-template
# guard fires correctly (AC-7).
_synthetic_hub_without_template() {
  local hub
  hub=$(mktemp -d)
  echo "# synthetic-hub" > "$hub/CLAUDE.md"
  echo "<!-- HUB-MANAGED-START -->" >> "$hub/CLAUDE.md"
  mkdir -p "$hub/.ccanvil/scripts" "$hub/.ccanvil/templates"
  cp "$SCRIPT" "$hub/.ccanvil/scripts/ccanvil-sync.sh"
  # NOTE: intentionally NO .ccanvil/templates/CLAUDE.md.fresh
  echo "$hub"
}

# =========================================================================
# AC-7: missing-template error path
# =========================================================================

@test "AC-7: fresh-mode preflight fails fast when CLAUDE.md.fresh is missing" {
  local hub
  hub=$(_synthetic_hub_without_template)

  run bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init-preflight "$hub"

  rm -rf "$hub"

  [ "$status" -ne 0 ]
  [[ "$output" == *"fresh-mode CLAUDE.md template not found"* ]]
}

# =========================================================================
# AC-1: template file with placeholders + hub-managed mirror
# =========================================================================

@test "AC-1: hub ships .ccanvil/templates/CLAUDE.md.fresh" {
  [ -f "$HUB_ROOT/.ccanvil/templates/CLAUDE.md.fresh" ]
}

@test "AC-1: template carries all 5 placeholders line-leading" {
  local tpl="$HUB_ROOT/.ccanvil/templates/CLAUDE.md.fresh"
  # Use fixed-string grep (-F) to avoid BRE-dot escape footguns; each line
  # must exactly match the placeholder literal.
  grep -qxF '# [Project Name]' "$tpl"
  grep -qxF '[One-line description.]' "$tpl"
  grep -qxF '[Tech Stack TBD]' "$tpl"
  grep -qxF '[Commands TBD]' "$tpl"
  grep -qxF '[Architecture TBD]' "$tpl"
}

@test "AC-1: template has exactly one HUB-MANAGED-START delimiter" {
  local tpl="$HUB_ROOT/.ccanvil/templates/CLAUDE.md.fresh"
  local count
  count=$(grep -cx '<!-- HUB-MANAGED-START -->' "$tpl")
  [ "$count" -eq 1 ]
}

@test "AC-1: template's hub-managed section byte-matches the hub's canonical section" {
  # The bytes from the delimiter forward in the template must equal
  # the bytes from the delimiter forward in the hub root CLAUDE.md.
  local hub_section tpl_section
  hub_section=$(awk '/^<!-- HUB-MANAGED-START -->$/,EOF' "$HUB_ROOT/CLAUDE.md")
  tpl_section=$(awk '/^<!-- HUB-MANAGED-START -->$/,EOF' "$HUB_ROOT/.ccanvil/templates/CLAUDE.md.fresh")
  [ "$hub_section" = "$tpl_section" ]
}

# =========================================================================
# AC-2: preflight emits hub_source field for fresh-mode CLAUDE.md
# =========================================================================

@test "AC-2: fresh-mode CLAUDE.md plan entry carries hub_source field" {
  local plan
  plan=$(bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init-preflight "$HUB_ROOT")

  local entry
  entry=$(echo "$plan" | jq '.plan[] | select(.file == "CLAUDE.md")')

  [ "$(echo "$entry" | jq -r '.source')" = "hub-only" ]
  [ "$(echo "$entry" | jq -r '.recommended_action')" = "copy" ]
  [ "$(echo "$entry" | jq -r '.hub_source')" = ".ccanvil/templates/CLAUDE.md.fresh" ]
}

# =========================================================================
# AC-3 + AC-6: cmd_init_apply consumes hub_source; produces placeholder file
# =========================================================================

@test "AC-3: fresh-mode init-apply writes placeholder CLAUDE.md" {
  local plan_file
  plan_file=$(mktemp)
  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init-preflight "$HUB_ROOT" > "$plan_file"

  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init-apply "$HUB_ROOT" "$plan_file"

  rm -f "$plan_file"

  # Placeholders must be present (so /ccanvil-init Step 8 can sed against them).
  grep -qx '# \[Project Name\]' "$NODE/CLAUDE.md"
  grep -qx '\[One-line description.\]' "$NODE/CLAUDE.md"

  # Hub identity prose must NOT have leaked into the node-section.
  ! grep -qx '# ccanvil' "$NODE/CLAUDE.md"
  ! grep -q 'bats hub/tests/' "$NODE/CLAUDE.md"
}

# =========================================================================
# AC-5: other modes don't get the fresh-template branch
# =========================================================================

@test "AC-5: partial-ccanvil CLAUDE.md without delimiter — section-merge-create-delimiters, no hub_source" {
  # Pre-existing CLAUDE.md without HUB-MANAGED-START delimiter — the
  # original BTS-327 mature-repo scenario; classifies as partial-ccanvil
  # because the CLAUDE.md presence alone is a ccanvil marker.
  echo "# Existing Project" > "$NODE/CLAUDE.md"
  echo "Some existing node content." >> "$NODE/CLAUDE.md"

  local plan
  plan=$(bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init-preflight "$HUB_ROOT")
  [ "$(echo "$plan" | jq -r '.project_mode')" = "partial-ccanvil" ]

  local entry
  entry=$(echo "$plan" | jq '.plan[] | select(.file == "CLAUDE.md")')
  [ "$(echo "$entry" | jq -r '.recommended_action')" = "section-merge-create-delimiters" ]
  [ "$(echo "$entry" | jq -r '.hub_source // "absent"')" = "absent" ]
}

@test "AC-5: mature-repo (git+source, no CLAUDE.md) — hub-only/copy, no hub_source" {
  # Mature repo with real commits + source file, no CLAUDE.md, no .claude/.
  git -C "$NODE" init -q -b main
  git -C "$NODE" config user.email test@local
  git -C "$NODE" config user.name test
  echo "# Established Project" > "$NODE/README.md"
  echo "console.log('hi');" > "$NODE/index.js"
  git -C "$NODE" add -A
  git -C "$NODE" commit -q -m "initial"

  local plan
  plan=$(bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init-preflight "$HUB_ROOT")
  [ "$(echo "$plan" | jq -r '.project_mode')" = "mature-repo" ]

  local entry
  entry=$(echo "$plan" | jq '.plan[] | select(.file == "CLAUDE.md")')
  # Mature-repo (no local CLAUDE.md) → hub-only/copy from default source.
  [ "$(echo "$entry" | jq -r '.source')" = "hub-only" ]
  [ "$(echo "$entry" | jq -r '.recommended_action')" = "copy" ]
  [ "$(echo "$entry" | jq -r '.hub_source // "absent"')" = "absent" ]
}

@test "AC-5: partial-ccanvil CLAUDE.md plan entry has no hub_source override" {
  # Simulate partial-ccanvil: .claude/ marker, no lockfile, existing CLAUDE.md with delimiter.
  mkdir -p "$NODE/.claude"
  echo "{}" > "$NODE/.claude/settings.json"
  cat > "$NODE/CLAUDE.md" <<EOF
# Local
Local content.
<!-- HUB-MANAGED-START -->
hub stuff
EOF

  local plan
  plan=$(bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init-preflight "$HUB_ROOT")
  [ "$(echo "$plan" | jq -r '.project_mode')" = "partial-ccanvil" ]

  local entry
  entry=$(echo "$plan" | jq '.plan[] | select(.file == "CLAUDE.md")')
  [ "$(echo "$entry" | jq -r '.hub_source // "absent"')" = "absent" ]
}

@test "AC-5: source-no-git CLAUDE.md plan entry has no hub_source override" {
  # Source-no-git: real source file, no .git/, no .claude/, no CLAUDE.md.
  echo "console.log('hi');" > "$NODE/index.js"

  local plan
  plan=$(bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init-preflight "$HUB_ROOT")
  [ "$(echo "$plan" | jq -r '.project_mode')" = "source-no-git" ]

  local entry
  entry=$(echo "$plan" | jq '.plan[] | select(.file == "CLAUDE.md")')
  # source-no-git falls through to default hub-only/copy; no override.
  [ "$(echo "$entry" | jq -r '.hub_source // "absent"')" = "absent" ]
}

# =========================================================================
# AC-4: Step 8 sed substitution succeeds
# =========================================================================

@test "AC-4: post-apply CLAUDE.md accepts the canonical Step 8 sed substitution" {
  local plan_file
  plan_file=$(mktemp)
  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init-preflight "$HUB_ROOT" > "$plan_file"
  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init-apply "$HUB_ROOT" "$plan_file"
  rm -f "$plan_file"

  # Mirrors /ccanvil-init Step 8: in-place sed substitution against the
  # placeholders. Use a sentinel that wouldn't naturally appear in the file.
  sed -i'' -e 's/\[Project Name\]/MyTestProject/' "$NODE/CLAUDE.md"
  sed -i'' -e 's/\[One-line description\.\]/A test app./' "$NODE/CLAUDE.md"

  grep -qx '# MyTestProject' "$NODE/CLAUDE.md"
  grep -qx 'A test app.' "$NODE/CLAUDE.md"
  # Original placeholders gone.
  ! grep -qF '[Project Name]' "$NODE/CLAUDE.md"
  ! grep -qF '[One-line description.]' "$NODE/CLAUDE.md"
}

# =========================================================================
# AC-8: re-run preflight after init completes — no fresh-template branch
# =========================================================================

@test "AC-8: already-initialized re-run produces no fresh-template plan entry" {
  # First pass — full fresh init.
  local plan_file
  plan_file=$(mktemp)
  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init-preflight "$HUB_ROOT" > "$plan_file"
  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init-apply "$HUB_ROOT" "$plan_file"
  # init-apply alone doesn't create the lockfile; cmd_init does.
  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init "$HUB_ROOT" >/dev/null 2>&1 || true

  # Second pass — re-run preflight. detect_project_mode should short-circuit
  # to already-initialized so the fresh-template branch never fires.
  local plan2
  plan2=$(bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init-preflight "$HUB_ROOT" 2>/dev/null)
  rm -f "$plan_file"

  local mode
  mode=$(echo "$plan2" | jq -r '.project_mode')
  [ "$mode" = "already-initialized" ]

  # No CLAUDE.md plan entry should carry the fresh-template hub_source.
  local override
  override=$(echo "$plan2" | jq -r '[.plan[] | select(.file == "CLAUDE.md") | .hub_source // empty] | length')
  [ "$override" = "0" ]
}

@test "AC-6: fresh-mode init-apply preserves hub-managed section byte-for-byte" {
  local plan_file
  plan_file=$(mktemp)
  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init-preflight "$HUB_ROOT" > "$plan_file"
  bash "$NODE/.ccanvil/scripts/ccanvil-sync.sh" init-apply "$HUB_ROOT" "$plan_file"
  rm -f "$plan_file"

  # Exactly one HUB-MANAGED-START delimiter.
  local dlim_count
  dlim_count=$(grep -cx '<!-- HUB-MANAGED-START -->' "$NODE/CLAUDE.md")
  [ "$dlim_count" -eq 1 ]

  # Bytes from delimiter forward must equal the hub canonical hub-managed section.
  local node_section hub_section
  node_section=$(awk '/^<!-- HUB-MANAGED-START -->$/,EOF' "$NODE/CLAUDE.md")
  hub_section=$(awk '/^<!-- HUB-MANAGED-START -->$/,EOF' "$HUB_ROOT/CLAUDE.md")
  [ "$node_section" = "$hub_section" ]
}
