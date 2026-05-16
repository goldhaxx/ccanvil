#!/usr/bin/env bats
# BTS-497 Step 1 — drift-guard for the runner-neutral observability schema.
#
# AC-9: span schema documented as a runner-neutral contract in
#       .ccanvil/observability/SCHEMA.md — every attribute typed, semver'd,
#       required vs optional marked. Future runners (pytest, vitest, go, ...)
#       emit the same shape.
# AC-10/AC-12: flat JSONL record schema (snake_cased fields, schema_version,
#              error_excerpt optional iff outcome=fail) documented in the
#              same file so the contract for `.ccanvil/state/test-runs.jsonl`
#              is single-source.

SCHEMA="$BATS_TEST_DIRNAME/../../.ccanvil/observability/SCHEMA.md"
GITIGNORE="$BATS_TEST_DIRNAME/../../.ccanvil/observability/.gitignore"

# =========================================================================
# File-existence gates
# =========================================================================

@test "AC-9: SCHEMA.md exists at .ccanvil/observability/SCHEMA.md" {
  [ -f "$SCHEMA" ]
}

# =========================================================================
# Versioning — both schemas versioned v1.0.0
# =========================================================================

@test "AC-9: schema documents v1.0.0 version markers" {
  # Both the span schema and the flat record schema must be tagged v1.0.0.
  # Grep two occurrences to catch both sections.
  local count
  count=$(grep -c '^Version: v1\.0\.0$\|`v1\.0\.0`\|version: v1\.0\.0' "$SCHEMA" || true)
  [ "$count" -ge 2 ]
}

# =========================================================================
# Span schema (AC-9) — required attributes per spec Implementation Note
# =========================================================================

@test "AC-9: span schema declares test.name, test.file, test.outcome" {
  grep -qE '^[|`-].*test\.name' "$SCHEMA"
  grep -qE '^[|`-].*test\.file' "$SCHEMA"
  grep -qE '^[|`-].*test\.outcome' "$SCHEMA"
}

@test "AC-9: span schema declares worker.id, runner.kind, run.id, git.sha" {
  grep -qE '^[|`-].*worker\.id' "$SCHEMA"
  grep -qE '^[|`-].*runner\.kind' "$SCHEMA"
  grep -qE '^[|`-].*run\.id' "$SCHEMA"
  grep -qE '^[|`-].*git\.sha' "$SCHEMA"
}

@test "AC-9: span schema marks test.outcome enum {pass, fail, skip}" {
  grep -qE 'test\.outcome.*(pass.*fail.*skip|\{.*pass.*fail.*skip.*\})' "$SCHEMA"
}

@test "AC-9: span schema marks runner.kind enum includes bats + pytest + vitest" {
  # Runner-neutral contract: at least bats + 2 other runner kinds enumerated.
  grep -qE 'runner\.kind.*bats' "$SCHEMA"
  grep -qE 'runner\.kind.*pytest' "$SCHEMA"
  grep -qE 'runner\.kind.*vitest' "$SCHEMA"
}

@test "AC-9: span schema declares optional fields test.duration_ms + test.error_excerpt" {
  grep -qE 'test\.duration_ms.*[Oo]ptional|[Oo]ptional.*test\.duration_ms' "$SCHEMA"
  grep -qE 'test\.error_excerpt.*[Oo]ptional|[Oo]ptional.*test\.error_excerpt' "$SCHEMA"
}

# =========================================================================
# Flat JSONL record schema (AC-10 / AC-12)
# =========================================================================

@test "AC-10: flat record schema declares all 10 required fields snake_cased" {
  # run_id, test_name, test_file, test_outcome, worker_id, runner_kind,
  # git_sha, started_at_unix_nano, duration_ms, schema_version.
  local fields=(run_id test_name test_file test_outcome worker_id runner_kind \
                git_sha started_at_unix_nano duration_ms schema_version)
  for field in "${fields[@]}"; do
    grep -qE "^[|\`-].*\b${field}\b" "$SCHEMA" \
      || { echo "MISSING flat schema field: $field" >&2; return 1; }
  done
}

@test "AC-10: flat record schema marks error_excerpt optional iff outcome=fail" {
  # The conditional optionality is load-bearing — single-source the rule here.
  grep -qE 'error_excerpt.*outcome.*fail|fail.*error_excerpt|present iff' "$SCHEMA"
}

@test "AC-12: schema_version field documented as required on every record" {
  grep -qE 'schema_version.*[Rr]equired|[Rr]equired.*schema_version' "$SCHEMA"
}

# =========================================================================
# Section structure
# =========================================================================

@test "AC-9/AC-10: SCHEMA.md has Span Schema + Flat JSONL Record Schema sections" {
  grep -qE '^## .*Span Schema|^## Span' "$SCHEMA"
  grep -qE '^## .*Flat.*JSONL|^## .*Record Schema|^## .*JSONL.*Schema' "$SCHEMA"
}

# =========================================================================
# .gitignore for raw-traces.jsonl (AC-10 prep — Step 2 of plan)
# =========================================================================

@test "AC-10: .ccanvil/observability/.gitignore exists and excludes raw-traces.jsonl" {
  [ -f "$GITIGNORE" ]
  grep -qE '^raw-traces\.jsonl$' "$GITIGNORE"
}
