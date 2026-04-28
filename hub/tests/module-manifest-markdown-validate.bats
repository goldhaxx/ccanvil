#!/usr/bin/env bats
# BTS-240 Step 3+4: cmd_validate markdown branch — AC-4, AC-5

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$REPO_ROOT/.ccanvil/scripts/module-manifest.sh"
  FIXTURES="$REPO_ROOT/hub/tests/fixtures/manifest"

  # Build a throwaway project layout so allowlist paths resolve cleanly.
  proj="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$proj/.ccanvil/scripts" "$proj/hub/tests/fixtures/manifest"
  cp "$SCRIPT" "$proj/.ccanvil/scripts/module-manifest.sh"
  cp "$FIXTURES/markdown-minimal.md" "$proj/hub/tests/fixtures/manifest/markdown-minimal.md"
}

@test "validate markdown: file-level entry passes (AC-4 base)" {
  set -e
  echo "hub/tests/fixtures/manifest/markdown-minimal.md" > "$proj/.ccanvil/manifest-allowlist.txt"
  cd "$proj"
  run bash "$SCRIPT" validate --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.coverage.covered == 1'
  echo "$output" | jq -e '.coverage.total == 1'
  echo "$output" | jq -e '.drift | length == 0'
}

@test "validate markdown: id falls back to basename .md (AC-4)" {
  set -e
  # No id: declared in body — id should be "markdown-minimal" (basename .md).
  echo "hub/tests/fixtures/manifest/markdown-minimal.md" > "$proj/.ccanvil/manifest-allowlist.txt"
  cd "$proj"
  run bash "$SCRIPT" validate --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.status == "ok"'
}

@test "validate markdown: missing failure-mode marker is SKIPPED (AC-5)" {
  set -e
  # markdown-minimal.md declares failure-mode but the body has no
  # `# @failure-mode: ...` markers (markdown body is prose, not code).
  # Without the marker-skip patch, this would fail with
  # missing-failure-mode-marker. With it, validate must exit 0.
  echo "hub/tests/fixtures/manifest/markdown-minimal.md" > "$proj/.ccanvil/manifest-allowlist.txt"
  cd "$proj"
  run bash "$SCRIPT" validate
  [ "$status" -eq 0 ]
  ! echo "$output$stderr" | grep -q "missing-failure-mode-marker"
}

@test "validate markdown: missing side-effect marker is SKIPPED (AC-5)" {
  set -e
  # Same logic for side-effect markers.
  echo "hub/tests/fixtures/manifest/markdown-minimal.md" > "$proj/.ccanvil/manifest-allowlist.txt"
  cd "$proj"
  run bash "$SCRIPT" validate
  [ "$status" -eq 0 ]
  ! echo "$output$stderr" | grep -q "missing-side-effect-marker"
}

@test "validate markdown: missing required key still fails for .md" {
  set -e
  # Missing 'purpose' should still fail — marker-skip does NOT bypass
  # required-key validation.
  no_purpose="$proj/hub/tests/fixtures/manifest/no-purpose.md"
  cat > "$no_purpose" <<'EOF'
---
manifest:
  input:
    - x
  output:
    - y
  side-effect:
    - z
  failure-mode:
    - "f | exit=1 | visible=none"
  contract:
    - c
  anchor:
    - a
---

body
EOF
  echo "hub/tests/fixtures/manifest/no-purpose.md" > "$proj/.ccanvil/manifest-allowlist.txt"
  cd "$proj"
  run bash "$SCRIPT" validate
  [ "$status" -eq 2 ]
  echo "$output$stderr" | grep -q "missing-required-key"
  echo "$output$stderr" | grep -q "value=purpose"
}
