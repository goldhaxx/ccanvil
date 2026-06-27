#!/usr/bin/env bats
#
# BTS-666: rule manifests relocated from .claude/rules/<id>.md frontmatter into
# co-located .claude/rules/<id>.manifest.yaml sidecars. Covers:
#   - AC-1: _extract_markdown reads the sidecar (golden-equal to inline)
#   - AC-2: back-reference integrity (manifest_ref resolves + id matches)
#   - AC-3: bijection guard (manifest-carrying rules <-> sidecars)
#   - AC-4: preserved structural validation through the sidecar
#   - AC-8: malformed-sidecar guard

bats_require_minimum_version 1.5.0

# BTS-497 telemetry hooks.
source "$BATS_TEST_DIRNAME/_helpers/telemetry.bash"
setup_file()    { telemetry_setup_file; }
teardown_file() { telemetry_teardown_file; }
setup()         { telemetry_setup; }
teardown()      { telemetry_teardown; }

MM="$BATS_TEST_DIRNAME/../../.ccanvil/scripts/module-manifest.sh"
FIX="$BATS_TEST_DIRNAME/fixtures/rule-sidecar"

# Build a minimal project tree with .claude/rules/ + empty allowlist so only the
# rule-scan path has work. Copies the named fixture files into .claude/rules/.
_make_sidecar_project() {
  local name="$1"; shift
  local fx="$BATS_TEST_TMPDIR/$name"
  mkdir -p "$fx/.claude/rules" "$fx/.ccanvil"
  : > "$fx/.ccanvil/manifest-allowlist.txt"
  local f
  for f in "$@"; do
    cp "$FIX/$f" "$fx/.claude/rules/$f"
  done
  echo "$fx"
}

# AC-1 ---------------------------------------------------------------------

@test "AC-1: _extract_markdown reads manifest from sidecar (golden-equal to inline)" {
  golden=$(bash "$MM" extract "$FIX/inline.md")
  via_sidecar=$(bash "$MM" extract "$FIX/sidecar.md")
  [ "$golden" = "$via_sidecar" ]
}

# AC-2: back-reference integrity ------------------------------------------

@test "AC-2: manifest_ref pointing to a missing sidecar is block-shape drift (exit 2)" {
  fx=$(_make_sidecar_project "ref-missing" "goodrule.md")  # sidecar NOT copied
  cd "$fx"
  run bash "$MM" validate --json
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.drift | map(select(.reason == "rule-manifest-ref-broken")) | length >= 1'
  echo "$output" | jq -e '.status == "drift"'
}

@test "AC-2: sidecar manifest.id != rule id is block-shape drift (exit 2)" {
  fx=$(_make_sidecar_project "id-mismatch" "goodrule.md")
  cat > "$fx/.claude/rules/goodrule.manifest.yaml" <<'EOF'
manifest:
  id: wrongid
  purpose: id does not match the rule basename
  failure-mode:
    - "x | exit=n/a | visible=none | mitigation=none"
EOF
  cd "$fx"
  run bash "$MM" validate --json
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.drift | map(select(.reason == "rule-manifest-ref-broken")) | length >= 1'
}

# AC-3: bijection guard ----------------------------------------------------

@test "AC-3: valid rule<->sidecar pairing produces no manifest drift (exit 0)" {
  fx=$(_make_sidecar_project "bijection-ok" "goodrule.md" "goodrule.manifest.yaml")
  cd "$fx"
  run bash "$MM" validate --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.drift | map(select(.reason | startswith("rule-manifest"))) | length == 0'
}

@test "AC-3: orphan sidecar with no referencing rule is block-shape drift (exit 2)" {
  fx=$(_make_sidecar_project "orphan" "exempt.md")  # exempt.md references nothing
  cat > "$fx/.claude/rules/orphan.manifest.yaml" <<'EOF'
manifest:
  id: orphan
  purpose: a sidecar with no rule pointing at it
EOF
  cd "$fx"
  run bash "$MM" validate --json
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.drift | map(select(.reason == "rule-manifest-sidecar-orphan")) | length == 1'
}

@test "AC-3: tier-0 rule with no manifest and no manifest_ref is exempt (no drift)" {
  fx=$(_make_sidecar_project "exempt" "exempt.md")
  cd "$fx"
  run bash "$MM" validate --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.drift | map(select(.reason | startswith("rule-manifest"))) | length == 0'
}

# AC-8: malformed sidecar --------------------------------------------------

@test "AC-8: malformed-YAML sidecar is block-shape drift naming the file (exit 2)" {
  fx=$(_make_sidecar_project "malformed" "badyaml.md" "badyaml.manifest.yaml")
  cd "$fx"
  run bash "$MM" validate --json
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.drift | map(select(.reason == "rule-manifest-sidecar-malformed")) | length == 1'
  echo "$output" | jq -e '.drift | map(select(.reason == "rule-manifest-sidecar-malformed")) | .[0].path | endswith("badyaml.manifest.yaml")'
}

# AC-4: preserved structural validation through the sidecar -----------------

@test "AC-4: allowlisted migrated rule with complete sidecar validates clean (exit 0)" {
  fx=$(_make_sidecar_project "ac4-ok" "goodrule.md" "goodrule.manifest.yaml")
  echo ".claude/rules/goodrule.md" > "$fx/.ccanvil/manifest-allowlist.txt"
  cd "$fx"
  run bash "$MM" validate --json
  [ "$status" -eq 0 ]
  # The allowlist loop read required-keys from the sidecar — no spurious drift.
  echo "$output" | jq -e '.drift | map(select(.id == "goodrule")) | length == 0'
}

@test "AC-4: required-key omitted from the SIDECAR drifts missing-required-key (exit 2)" {
  fx=$(_make_sidecar_project "ac4-missing" "goodrule.md")
  echo ".claude/rules/goodrule.md" > "$fx/.ccanvil/manifest-allowlist.txt"
  # Sidecar missing the required `purpose` key.
  cat > "$fx/.claude/rules/goodrule.manifest.yaml" <<'EOF'
manifest:
  id: goodrule
  input:
    - "read-only: rule"
  output:
    - "behavior-shape: x"
  side-effect:
    - "no-op"
  failure-mode:
    - "x | exit=n/a | visible=none | mitigation=none"
  contract:
    - c1
  anchor:
    - BTS-666
EOF
  cd "$fx"
  # validate echoes DRIFT lines to stderr (allowlist loop); capture stdout only
  # so $output is clean JSON.
  run --separate-stderr bash "$MM" validate --json
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.drift | map(select(.reason == "missing-required-key" and .value == "purpose")) | length == 1'
}
