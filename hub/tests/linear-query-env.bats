#!/usr/bin/env bats
# BTS-167 — linear-query.sh auto-sources .env from project root when
# LINEAR_API_KEY is unset. Eliminates the per-shell `set -a; source .env`
# ritual recurring across /recall, /radar, and every http-routed resolver.

bats_require_minimum_version 1.5.0

LQ="$BATS_TEST_DIRNAME/../../.ccanvil/scripts/linear-query.sh"
STUB_FIXTURE="$BATS_TEST_DIRNAME/fixtures/linear-stub.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR}"
  # Strip operator env so tests don't pick up a leaked real key.
  unset LINEAR_API_KEY
  unset LINEAR_QUERY_ENDPOINT
}

# Stage a fake project root: $PROJECT/.git/ (sentinel) and optionally $PROJECT/.env.
# Tests cd into $PROJECT before invoking the script so $PWD walk anchors there.
_make_project() {
  PROJECT="$BATS_TEST_TMPDIR/project"
  mkdir -p "$PROJECT/.git"
  echo "$PROJECT"
}

# ===========================================================================
# AC-3 baseline: existing fail-loud preserved when no .env and no env var.
# ===========================================================================

@test "BTS-167 AC-3: no .env and no LINEAR_API_KEY → exit 2 with not-set error" {
  PROJECT=$(_make_project)
  run --separate-stderr bash -c "cd '$PROJECT' && bash '$LQ' viewer"
  [ "$status" -eq 2 ]
  [[ "$stderr" =~ "LINEAR_API_KEY not set" ]]
}

@test "BTS-167 AC-3: tmpdir without .git ancestor → exit 2 (no auto-source attempted)" {
  # No .git anywhere up the tree from BATS_TEST_TMPDIR — discovery should
  # terminate without trying to source anything.
  run --separate-stderr bash -c "cd '$BATS_TEST_TMPDIR' && bash '$LQ' viewer"
  [ "$status" -eq 2 ]
  [[ "$stderr" =~ "LINEAR_API_KEY not set" ]]
}

@test "BTS-167 AC-3: error message references both env-var and .env paths" {
  PROJECT=$(_make_project)
  run --separate-stderr bash -c "cd '$PROJECT' && bash '$LQ' viewer"
  [ "$status" -eq 2 ]
  [[ "$stderr" =~ "export LINEAR_API_KEY" ]]
  [[ "$stderr" =~ ".env" ]]
}

# ===========================================================================
# AC-1: auto-source from project-root .env when LINEAR_API_KEY is unset.
# ===========================================================================

@test "BTS-167 AC-1: viewer succeeds with LINEAR_API_KEY in .env (env var unset)" {
  set -e
  PROJECT=$(_make_project)
  cat > "$PROJECT/.env" <<EOF
LINEAR_API_KEY=fixture-key-from-dotenv
EOF
  export LINEAR_STUB_CAPTURE="$BATS_TEST_TMPDIR/curl-args"
  export LINEAR_STUB_RESPONSE="$BATS_TEST_TMPDIR/curl-response.json"
  export LINEAR_QUERY_ENDPOINT="https://stub.example.test/graphql"
  cat > "$LINEAR_STUB_RESPONSE" <<'JSON'
{"data":{"viewer":{"id":"u","name":"n"}}}
JSON
  run bash -c "cd '$PROJECT' && source '$STUB_FIXTURE' && bash '$LQ' viewer"
  [ "$status" -eq 0 ]
  grep -F "Authorization: fixture-key-from-dotenv" "$LINEAR_STUB_CAPTURE"
}

@test "BTS-167 AC-1: auto-source walks up tree (subdir → parent .git/.env)" {
  set -e
  PROJECT=$(_make_project)
  mkdir -p "$PROJECT/sub/dir"
  cat > "$PROJECT/.env" <<EOF
LINEAR_API_KEY=walked-up-key
EOF
  export LINEAR_STUB_CAPTURE="$BATS_TEST_TMPDIR/curl-args"
  export LINEAR_STUB_RESPONSE="$BATS_TEST_TMPDIR/curl-response.json"
  export LINEAR_QUERY_ENDPOINT="https://stub.example.test/graphql"
  cat > "$LINEAR_STUB_RESPONSE" <<'JSON'
{"data":{"viewer":{"id":"u","name":"n"}}}
JSON
  run bash -c "cd '$PROJECT/sub/dir' && source '$STUB_FIXTURE' && bash '$LQ' viewer"
  [ "$status" -eq 0 ]
  grep -F "Authorization: walked-up-key" "$LINEAR_STUB_CAPTURE"
}

# ===========================================================================
# AC-2: exported LINEAR_API_KEY wins over .env (no override).
# ===========================================================================

@test "BTS-167 AC-2: exported env var beats .env (no override)" {
  set -e
  PROJECT=$(_make_project)
  cat > "$PROJECT/.env" <<EOF
LINEAR_API_KEY=from-dotenv-should-not-win
EOF
  export LINEAR_API_KEY="from-env-wins"
  export LINEAR_STUB_CAPTURE="$BATS_TEST_TMPDIR/curl-args"
  export LINEAR_STUB_RESPONSE="$BATS_TEST_TMPDIR/curl-response.json"
  export LINEAR_QUERY_ENDPOINT="https://stub.example.test/graphql"
  cat > "$LINEAR_STUB_RESPONSE" <<'JSON'
{"data":{"viewer":{"id":"u","name":"n"}}}
JSON
  run bash -c "cd '$PROJECT' && source '$STUB_FIXTURE' && bash '$LQ' viewer"
  [ "$status" -eq 0 ]
  grep -F "Authorization: from-env-wins" "$LINEAR_STUB_CAPTURE"
  ! grep -qF "from-dotenv-should-not-win" "$LINEAR_STUB_CAPTURE"
}

# ===========================================================================
# AC-4: invocation-path independence — $PWD walk anchors discovery, not script path.
# ===========================================================================

@test "BTS-167 AC-4: invoking via absolute path from outside project does NOT auto-source" {
  # cd into a tmpdir with no .git ancestor; even though the script lives
  # inside ccanvil's git tree, $PWD-anchored discovery should yield nothing.
  run --separate-stderr bash -c "cd '$BATS_TEST_TMPDIR' && bash '$LQ' viewer"
  [ "$status" -eq 2 ]
  [[ "$stderr" =~ "LINEAR_API_KEY not set" ]]
}

@test "BTS-167 AC-4: cd into project then invoke via absolute path → auto-source fires" {
  set -e
  PROJECT=$(_make_project)
  cat > "$PROJECT/.env" <<EOF
LINEAR_API_KEY=cwd-anchored-discovery
EOF
  export LINEAR_STUB_CAPTURE="$BATS_TEST_TMPDIR/curl-args"
  export LINEAR_STUB_RESPONSE="$BATS_TEST_TMPDIR/curl-response.json"
  export LINEAR_QUERY_ENDPOINT="https://stub.example.test/graphql"
  cat > "$LINEAR_STUB_RESPONSE" <<'JSON'
{"data":{"viewer":{"id":"u","name":"n"}}}
JSON
  # Absolute path to the script, $PWD inside the fixture project.
  run bash -c "cd '$PROJECT' && source '$STUB_FIXTURE' && bash '$LQ' viewer"
  [ "$status" -eq 0 ]
  grep -F "Authorization: cwd-anchored-discovery" "$LINEAR_STUB_CAPTURE"
}

# ===========================================================================
# AC-5: silent success — no stderr noise when auto-source loads cleanly.
# ===========================================================================

@test "BTS-167 AC-5: auto-source emits no stderr noise on success" {
  PROJECT=$(_make_project)
  cat > "$PROJECT/.env" <<EOF
LINEAR_API_KEY=quiet-key
EOF
  export LINEAR_STUB_CAPTURE="$BATS_TEST_TMPDIR/curl-args"
  export LINEAR_STUB_RESPONSE="$BATS_TEST_TMPDIR/curl-response.json"
  export LINEAR_QUERY_ENDPOINT="https://stub.example.test/graphql"
  cat > "$LINEAR_STUB_RESPONSE" <<'JSON'
{"data":{"viewer":{"id":"u","name":"n"}}}
JSON
  run --separate-stderr bash -c "cd '$PROJECT' && source '$STUB_FIXTURE' && bash '$LQ' viewer"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
}

# ===========================================================================
# AC-6: malformed .env doesn't silently lose fail-loud — must surface OR
# fall through to the not-set error, never exit 0 with empty/wrong key.
# ===========================================================================

@test "BTS-167 AC-6: malformed .env produces non-zero exit (no silent skip)" {
  PROJECT=$(_make_project)
  # Unbalanced quote → bash parse error during source.
  cat > "$PROJECT/.env" <<'EOF'
LINEAR_API_KEY="unterminated
EOF
  run --separate-stderr bash -c "cd '$PROJECT' && bash '$LQ' viewer"
  [ "$status" -ne 0 ]
}
