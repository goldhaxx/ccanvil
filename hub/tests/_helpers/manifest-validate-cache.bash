# BTS-281 — shared setup_file() helper for bats files that run
# `module-manifest.sh validate` against the full hub allowlist.
#
# Hub-validate is ~7 min wall / ~10 min CPU per call (M4 Max, 189 entries).
# Per-test re-invocations dominated suite CPU per BTS-282 profile evidence
# (94% of measured substrate CPU). This helper runs validate ONCE per
# bats-file lifetime and stashes the JSON envelope in $BATS_FILE_TMPDIR.
# Per-test bodies read the stash via `cat $MANIFEST_VALIDATE_JSON` instead
# of re-running the validate verb.

manifest_validate_cache_setup_file() {
  # BTS-281: prefer the suite-level cache (BTS_MANIFEST_VALIDATE_CACHE) when
  # set by bats-report.sh's pre-warm. Falls back to a fresh per-file run when
  # the env var is unset (e.g., bats-file invoked standalone via raw `bats`).
  if [[ -n "${BTS_MANIFEST_VALIDATE_CACHE:-}" ]] && [[ -s "$BTS_MANIFEST_VALIDATE_CACHE" ]]; then
    cp "$BTS_MANIFEST_VALIDATE_CACHE" "$BATS_FILE_TMPDIR/manifest-validate.json"
    return 0
  fi
  local repo_root
  # The bats file is in hub/tests/; the helper is in hub/tests/_helpers/.
  # BATS_TEST_FILENAME is the absolute path of the running .bats file.
  repo_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  cd "$repo_root"
  bash .ccanvil/scripts/module-manifest.sh validate --json \
    > "$BATS_FILE_TMPDIR/manifest-validate.json"
}

# Exposed in per-test setup() to give @test bodies a stable env var.
manifest_validate_cache_setup() {
  export MANIFEST_VALIDATE_JSON="$BATS_FILE_TMPDIR/manifest-validate.json"
}
