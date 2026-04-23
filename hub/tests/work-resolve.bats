#!/usr/bin/env bats
# Tests for work.resolve — provider-neutral work identity resolution.
# BTS-130 (work-identity) — Phase 2: resolver.

OPS="$BATS_TEST_DIRNAME/../../.ccanvil/scripts/operations.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR}"
  PROJECT=$(mktemp -d)
  mkdir -p "$PROJECT/.ccanvil" "$PROJECT/.claude"
}

teardown() {
  rm -rf "$PROJECT"
}

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

_linear_config() {
  cat > "$PROJECT/.claude/ccanvil.json" <<'JSON'
{
  "integrations": {
    "providers": {
      "linear": {
        "mechanism": "mcp",
        "project": "Test Project",
        "team": "Test Team",
        "workspace": "testws"
      }
    },
    "routing": { "idea": "linear" }
  }
}
JSON
}

_local_config() {
  # No config file → local adapter (default).
  rm -f "$PROJECT/.claude/ccanvil.json"
}

# ===========================================================================
# AC-1 — work.resolve on Linear provider (implicit, via routing)
# ===========================================================================

@test "BTS-130 AC-1: work.resolve BTS-130 on Linear node returns Linear-shape JSON" {
  _linear_config
  run bash "$OPS" resolve work.resolve BTS-130 --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.provider == "linear"'
  echo "$output" | jq -e '.id == "BTS-130"'
  echo "$output" | jq -e '.slug == "bts-130"'
  # URL must be a non-empty string when workspace is configured
  local url
  url=$(echo "$output" | jq -r '.url')
  [ -n "$url" ]
  [ "$url" != "null" ]
}

# ===========================================================================
# AC-2 — work.resolve on local provider
# ===========================================================================

@test "BTS-130 AC-2: work.resolve idea-29 on local node returns local-shape JSON" {
  _local_config
  run bash "$OPS" resolve work.resolve idea-29 --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.provider == "local"'
  echo "$output" | jq -e '.id == "idea-29"'
  echo "$output" | jq -e '.slug == "idea-29"'
}

# ===========================================================================
# AC-3 — explicit provider prefix overrides routing
# ===========================================================================

@test "BTS-130 AC-3: work.resolve linear:BTS-130 on local node returns Linear shape" {
  _local_config
  run bash "$OPS" resolve work.resolve linear:BTS-130 --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.provider == "linear"'
  echo "$output" | jq -e '.id == "BTS-130"'
  echo "$output" | jq -e '.slug == "bts-130"'
}

@test "BTS-130 AC-3: work.resolve local:custom-id on Linear node returns local shape" {
  _linear_config
  run bash "$OPS" resolve work.resolve local:custom-id --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.provider == "local"'
  echo "$output" | jq -e '.id == "custom-id"'
  echo "$output" | jq -e '.slug == "custom-id"'
}

# ===========================================================================
# AC-4 — error paths
# ===========================================================================

@test "BTS-130 AC-4: work.resolve with empty arg exits non-zero" {
  _linear_config
  run bash "$OPS" resolve work.resolve --project-dir "$PROJECT"
  [ "$status" -ne 0 ]
}

# ===========================================================================
# Slug derivation edge cases — tests the helper indirectly
# ===========================================================================

@test "BTS-130 slug: lowercases uppercase ticket keys" {
  _linear_config
  run bash "$OPS" resolve work.resolve PROJ-42 --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.slug == "proj-42"'
}

@test "BTS-130 slug: preserves already-safe lowercase local UIDs" {
  _local_config
  run bash "$OPS" resolve work.resolve idea-1776973070 --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.slug == "idea-1776973070"'
}

# ===========================================================================
# Review feedback — format validation: reject inputs that look like
# descriptions, not work refs (closes /spec stop-condition gap)
# ===========================================================================

@test "BTS-130 validation: bare Linear ID with wrong format rejected" {
  _linear_config
  # Lowercase letters are not a valid Linear ticket key
  run bash "$OPS" resolve work.resolve not-a-ticket --project-dir "$PROJECT"
  [ "$status" -ne 0 ]
}

@test "BTS-130 validation: multi-word input rejected (reads as description)" {
  _local_config
  run bash "$OPS" resolve work.resolve "my description here" --project-dir "$PROJECT"
  [ "$status" -ne 0 ]
}

@test "BTS-130 validation: bare 'idea' (without number) rejected on local node" {
  _local_config
  run bash "$OPS" resolve work.resolve idea --project-dir "$PROJECT"
  [ "$status" -ne 0 ]
}

@test "BTS-130 validation: pathological input producing empty slug rejected" {
  _local_config
  run bash "$OPS" resolve work.resolve "!!!" --project-dir "$PROJECT"
  [ "$status" -ne 0 ]
}

@test "BTS-130 validation: explicit provider prefix bypasses strict validation" {
  _local_config
  # With explicit prefix, caller is asserting intent — trust the id.
  run bash "$OPS" resolve work.resolve "linear:anything-goes" --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.provider == "linear"'
}

@test "BTS-130 validation: local:<id> explicit prefix also bypasses strict" {
  _linear_config
  run bash "$OPS" resolve work.resolve "local:custom-format-999" --project-dir "$PROJECT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.provider == "local"'
  echo "$output" | jq -e '.id == "custom-format-999"'
}
