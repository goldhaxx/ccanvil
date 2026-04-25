#!/usr/bin/env bats
# BTS-164 — linear-query.sh: Linear GraphQL client wrapper for bash scripts.
# Provides curl + jq + LINEAR_API_KEY env-var auth so docs-check.sh, radar-gather,
# operations.sh resolvers, etc. can read+write Linear without going through MCP.

bats_require_minimum_version 1.5.0

LQ="$BATS_TEST_DIRNAME/../../.ccanvil/scripts/linear-query.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR}"
  # Ensure tests start with a clean env — no leaked LINEAR_API_KEY from operator shell.
  unset LINEAR_API_KEY
  unset LINEAR_QUERY_ENDPOINT
}

# ===========================================================================
# AC-1, AC-2: skeleton + auth gate
# ===========================================================================

@test "BTS-164 AC-1: --help exits 0 with usage text" {
  run bash "$LQ" --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage:" ]]
  [[ "$output" =~ "linear-query.sh" ]]
}

@test "BTS-164 AC-1: bare invocation (no subcommand) exits 2 with usage to stderr" {
  run --separate-stderr bash "$LQ"
  [ "$status" -eq 2 ]
  [[ "$stderr" =~ "Usage:" ]]
}

@test "BTS-164 AC-1: unknown subcommand exits 2 with error to stderr" {
  run --separate-stderr bash "$LQ" not-a-real-subcommand
  [ "$status" -eq 2 ]
  [[ "$stderr" =~ "Unknown subcommand" ]]
}

@test "BTS-164 AC-2: list-issues without LINEAR_API_KEY exits 2 with clear message" {
  run --separate-stderr bash "$LQ" list-issues
  [ "$status" -eq 2 ]
  [[ "$stderr" =~ "LINEAR_API_KEY not set" ]]
}

@test "BTS-164 AC-2: viewer without LINEAR_API_KEY exits 2 with clear message" {
  run --separate-stderr bash "$LQ" viewer
  [ "$status" -eq 2 ]
  [[ "$stderr" =~ "LINEAR_API_KEY not set" ]]
}

@test "BTS-164 AC-2: --help bypasses LINEAR_API_KEY check" {
  # Even with no key set, --help must succeed so operators can discover the tool.
  unset LINEAR_API_KEY
  run bash "$LQ" --help
  [ "$status" -eq 0 ]
}

# ===========================================================================
# AC-3: curl transport + viewer subcommand (auth smoke test)
# ===========================================================================
#
# The stub fixture (hub/tests/fixtures/linear-stub.sh) shadows curl with a
# bash function exported into the subshell. Side-channel env vars:
#   LINEAR_STUB_CAPTURE   path to capture raw curl args (one per line)
#   LINEAR_STUB_RESPONSE  path containing the JSON the stub will echo
#
# Tests stage a response file, run the subcommand, then grep the capture file
# for headers, URL, and body.

_setup_stub() {
  STUB_FIXTURE="$BATS_TEST_DIRNAME/fixtures/linear-stub.sh"
  export LINEAR_STUB_CAPTURE="$BATS_TEST_TMPDIR/curl-args"
  export LINEAR_STUB_RESPONSE="$BATS_TEST_TMPDIR/curl-response.json"
  export LINEAR_API_KEY="test-key-abc123"
  export LINEAR_QUERY_ENDPOINT="https://stub.example.test/graphql"
}

@test "BTS-164 AC-3: viewer returns parsed identity from stub response" {
  set -e
  _setup_stub
  cat > "$LINEAR_STUB_RESPONSE" <<'JSON'
{"data":{"viewer":{"id":"user-123","name":"Test User"}}}
JSON
  run bash -c "source '$STUB_FIXTURE' && bash '$LQ' viewer"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.id == "user-123" and .name == "Test User"'
}

@test "BTS-164 AC-3: viewer sends Authorization header with LINEAR_API_KEY value" {
  _setup_stub
  cat > "$LINEAR_STUB_RESPONSE" <<'JSON'
{"data":{"viewer":{"id":"u","name":"n"}}}
JSON
  run bash -c "source '$STUB_FIXTURE' && bash '$LQ' viewer"
  [ "$status" -eq 0 ]
  grep -F "Authorization: test-key-abc123" "$LINEAR_STUB_CAPTURE"
}

@test "BTS-164 AC-3: viewer POSTs to LINEAR_QUERY_ENDPOINT (stub override honored)" {
  _setup_stub
  cat > "$LINEAR_STUB_RESPONSE" <<'JSON'
{"data":{"viewer":{"id":"u","name":"n"}}}
JSON
  run bash -c "source '$STUB_FIXTURE' && bash '$LQ' viewer"
  [ "$status" -eq 0 ]
  grep -F "https://stub.example.test/graphql" "$LINEAR_STUB_CAPTURE"
}

@test "BTS-164 AC-3: viewer body contains the viewer GraphQL query" {
  _setup_stub
  cat > "$LINEAR_STUB_RESPONSE" <<'JSON'
{"data":{"viewer":{"id":"u","name":"n"}}}
JSON
  run bash -c "source '$STUB_FIXTURE' && bash '$LQ' viewer"
  [ "$status" -eq 0 ]
  # Body line in capture file should contain the viewer GraphQL query.
  grep -F "viewer" "$LINEAR_STUB_CAPTURE"
}

@test "BTS-164 AC-3: viewer surfaces GraphQL errors as exit 3" {
  _setup_stub
  cat > "$LINEAR_STUB_RESPONSE" <<'JSON'
{"errors":[{"message":"Invalid API key"}]}
JSON
  run --separate-stderr bash -c "source '$STUB_FIXTURE' && bash '$LQ' viewer"
  [ "$status" -eq 3 ]
  [[ "$stderr" =~ "Invalid API key" ]]
}

# ===========================================================================
# AC-1, AC-8: read subcommands (list-issues, get-issue, list-states, list-labels)
# ===========================================================================

# Helper: extract the body sent to curl (after the <<BODY>> sentinel).
_get_body() {
  awk '/<<BODY>>/{flag=1;next} flag' "$LINEAR_STUB_CAPTURE"
}

@test "BTS-164 AC-1: list-issues parses .issues.nodes into canonical shape" {
  set -e
  _setup_stub
  cat > "$LINEAR_STUB_RESPONSE" <<'JSON'
{"data":{"issues":{"nodes":[
  {"id":"u1","identifier":"BTS-100","title":"first","priority":2,"createdAt":"2026-04-25","state":{"name":"Triage","type":"triage","id":"s1"},"labels":{"nodes":[{"name":"idea"}]}},
  {"id":"u2","identifier":"BTS-101","title":"second","priority":3,"createdAt":"2026-04-26","state":{"name":"Backlog","type":"backlog","id":"s2"},"labels":{"nodes":[]}}
]}}}
JSON
  run bash -c "source '$STUB_FIXTURE' && bash '$LQ' list-issues"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'length == 2'
  echo "$output" | jq -e '.[0].id == "BTS-100" and .[0].status == "Triage" and .[0].statusType == "triage"'
  echo "$output" | jq -e '.[0].labels == ["idea"]'
}

@test "BTS-164 AC-1: list-issues --state triage --label idea --project P --team T builds combined filter" {
  set -e
  _setup_stub
  cat > "$LINEAR_STUB_RESPONSE" <<'JSON'
{"data":{"issues":{"nodes":[]}}}
JSON
  run bash -c "source '$STUB_FIXTURE' && bash '$LQ' list-issues --state triage --label idea --project P --team T"
  [ "$status" -eq 0 ]
  local body
  body=$(_get_body)
  echo "$body" | jq -e '.variables.filter.state.type.eq == "triage"'
  echo "$body" | jq -e '.variables.filter.labels.some.name.eq == "idea"'
  echo "$body" | jq -e '.variables.filter.project.name.eq == "P"'
  echo "$body" | jq -e '.variables.filter.team.name.eq == "T"'
}

@test "BTS-164 AC-1: list-issues --limit overrides default first" {
  set -e
  _setup_stub
  cat > "$LINEAR_STUB_RESPONSE" <<'JSON'
{"data":{"issues":{"nodes":[]}}}
JSON
  run bash -c "source '$STUB_FIXTURE' && bash '$LQ' list-issues --limit 10"
  [ "$status" -eq 0 ]
  _get_body | jq -e '.variables.first == 10'
}

@test "BTS-164 AC-1: list-issues unknown flag exits 2" {
  _setup_stub
  run --separate-stderr bash -c "source '$STUB_FIXTURE' && bash '$LQ' list-issues --bogus x"
  [ "$status" -eq 2 ]
  [[ "$stderr" =~ "unknown flag" ]]
}

@test "BTS-164 AC-1: get-issue requires identifier arg" {
  _setup_stub
  run --separate-stderr bash -c "source '$STUB_FIXTURE' && bash '$LQ' get-issue"
  [ "$status" -eq 2 ]
  [[ "$stderr" =~ "requires" ]]
}

@test "BTS-164 AC-1: get-issue BTS-100 sends issue(id) query and parses response" {
  set -e
  _setup_stub
  cat > "$LINEAR_STUB_RESPONSE" <<'JSON'
{"data":{"issue":{"id":"u1","identifier":"BTS-100","title":"first","priority":2,"createdAt":"2026-04-25","state":{"name":"Triage","type":"triage","id":"s1"},"labels":{"nodes":[{"name":"idea"}]}}}}
JSON
  run bash -c "source '$STUB_FIXTURE' && bash '$LQ' get-issue BTS-100"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.id == "BTS-100" and .title == "first" and .status == "Triage"'
  _get_body | jq -e '.variables.id == "BTS-100"'
}

@test "BTS-164 AC-1: list-states --team T sends workflowStates query and parses nodes" {
  set -e
  _setup_stub
  cat > "$LINEAR_STUB_RESPONSE" <<'JSON'
{"data":{"workflowStates":{"nodes":[
  {"id":"s1","name":"Triage","type":"triage"},
  {"id":"s2","name":"Backlog","type":"backlog"}
]}}}
JSON
  run bash -c "source '$STUB_FIXTURE' && bash '$LQ' list-states --team T"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'length == 2'
  echo "$output" | jq -e '.[0].id == "s1" and .[0].name == "Triage" and .[0].type == "triage"'
  _get_body | jq -e '.variables.filter.team.name.eq == "T"'
}

@test "BTS-164 AC-1: list-labels --team T sends issueLabels query and parses nodes" {
  set -e
  _setup_stub
  cat > "$LINEAR_STUB_RESPONSE" <<'JSON'
{"data":{"issueLabels":{"nodes":[
  {"id":"l1","name":"idea"},
  {"id":"l2","name":"scaffold"}
]}}}
JSON
  run bash -c "source '$STUB_FIXTURE' && bash '$LQ' list-labels --team T"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e 'length == 2'
  echo "$output" | jq -e '.[0].name == "idea"'
  _get_body | jq -e '.variables.filter.team.name.eq == "T"'
}
