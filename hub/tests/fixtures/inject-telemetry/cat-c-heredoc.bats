#!/usr/bin/env bats
# Cat C fixture with a heredoc whose body contains a bare `}` on its own
# line. The state-machine MUST NOT treat the heredoc-internal `}` as the
# function close — that was the BTS-504 Step 9 rollout regression.

bats_require_minimum_version 1.5.0

setup() {
  TMPDIR_BATS=$(mktemp -d)
  cat > "$TMPDIR_BATS/payload.json" <<'EOF'
{
  "key": "value"
}
EOF
  EXAMPLE_VAR="hello"
}

teardown() {
  rm -rf "$TMPDIR_BATS"
}

@test "cat-c-heredoc fixture: setup heredoc with bare-} content survives wiring" {
  [ "$EXAMPLE_VAR" = "hello" ]
  [ -f "$TMPDIR_BATS/payload.json" ]
}
