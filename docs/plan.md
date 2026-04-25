# Implementation Plan: Auto-source .env in linear-query.sh

> Feature: bts-167-auto-source-env
> Work: linear:BTS-167
> Created: 1777148448
> Spec hash: e3062719
> Based on: docs/spec.md

## Objective

Make `linear-query.sh` self-load `LINEAR_API_KEY` from project-root `.env` when present, eliminating the per-shell manual source ritual that has been recurring across `/recall`, `/radar`, and every http-routed resolver call.

## Sequence

### Step 1: Test scaffold + AC-3 regression (existing fail-loud preserved)
- **Test:** New file `hub/tests/linear-query-env.bats`. Setup unsets `LINEAR_API_KEY` and `LINEAR_QUERY_ENDPOINT`. First test asserts: when no `.env` exists at `BATS_TEST_TMPDIR/.git`-rooted dir AND `LINEAR_API_KEY` unset, `viewer` exits 2 with the existing `"LINEAR_API_KEY not set"` message. Run from a tmpdir (not the project root) to isolate from real `.env`.
- **Implement:** No code change yet — confirms baseline before adding behavior.
- **Files:** `hub/tests/linear-query-env.bats` (new).
- **Verify:** `bats hub/tests/linear-query-env.bats` — first test passes against the unmodified script.

### Step 2: Add `_load_env_if_needed` helper (RED for AC-1)
- **Test:** Add a test that creates a tmpdir with a `.git/` subdir and a `.env` containing `LINEAR_API_KEY=fixture-key`, sets `LINEAR_QUERY_ENDPOINT` to a stub, sources `hub/tests/fixtures/linear-stub.sh` (curl shadow), and runs `viewer` from inside that tmpdir. Asserts exit 0 + the GraphQL request used `Authorization: fixture-key` (grep the captured curl args).
- **Implement:** Add helper `_load_env_if_needed()` in `linear-query.sh`. Walk up from `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)` looking for `.git`; alternate walk from `$PWD` if the script-relative walk doesn't find one. When found AND `LINEAR_API_KEY` unset AND `<root>/.env` exists, run `set -a; . "<root>/.env"; set +a`. Call the helper from `_require_api_key()` BEFORE the `-z` check.
- **Files:** `.ccanvil/scripts/linear-query.sh` (modify), `hub/tests/linear-query-env.bats` (extend).
- **Verify:** AC-1 test goes red → green. Existing AC-3 fail-loud test still green.

### Step 3: AC-2 — exported var wins, no override (RED → GREEN)
- **Test:** Same fixture (`.env` with `LINEAR_API_KEY=from-dotenv`) but ALSO export `LINEAR_API_KEY=from-env` before invocation. Assert the captured curl `Authorization` header carries `from-env`, not `from-dotenv`.
- **Implement:** The `[[ -z "${LINEAR_API_KEY:-}" ]]` guard in `_load_env_if_needed` already enforces this — verify by running the new test. If it fails, the helper is wrong; fix.
- **Files:** `hub/tests/linear-query-env.bats` (extend).
- **Verify:** Test passes; no script edit expected.

### Step 4: AC-4 — invocation-path independence
- **Test:** Two cases. (a) Invoke `linear-query.sh viewer` via absolute path from `cd /tmp` with `BATS_TEST_TMPDIR/.git` as the project root — expect failure (no `.git` ancestor of `linear-query.sh`'s real location matches the fixture). (b) Invoke via `cd "$tmpdir"; bash "$LQ" viewer` so `$PWD` provides the discovery anchor — expect success.
- **Implement:** Confirm dual-walk strategy: try `$PWD` first (caller's working dir), fall back to script's own dirname. This matches user intuition — when I `cd` into a project and call the script, `.env` from that project should load even if the script lives elsewhere (e.g., symlinked into PATH).
- **Files:** `.ccanvil/scripts/linear-query.sh` (refine helper if needed), `hub/tests/linear-query-env.bats` (extend).
- **Verify:** Both AC-4 cases behave as specified.

### Step 5: AC-5 — silent success
- **Test:** Run the AC-1 success path with `run --separate-stderr` and assert stderr is empty (or contains only the legitimate stub-response trace, but not auto-source breadcrumbs).
- **Implement:** Ensure helper produces no output. `set -a; . file; set +a` is silent by default; just don't add `echo`/`>&2` lines in the helper.
- **Files:** `hub/tests/linear-query-env.bats` (extend).
- **Verify:** stderr is empty when auto-source succeeds.

### Step 6: AC-6 — malformed `.env` doesn't silently lose fail-loud
- **Test:** Create `.env` with a clear syntax error (e.g., `LINEAR_API_KEY=$(`). Invoke `viewer`. Assert exit code is non-zero AND stderr indicates a problem (either bash parse error from `set -a; . file` OR the unchanged `LINEAR_API_KEY not set` message). Critically: NOT exit 0 with a silent skip.
- **Implement:** With `set -euo pipefail` already at top, `set -a; . file; set +a` will abort the script on parse error. That's the correct behavior — surface the syntax error rather than swallow it. Verify this empirically. If `set -e` is somehow ineffective inside the helper (subshell, etc.), wrap the source in a check.
- **Files:** `hub/tests/linear-query-env.bats` (extend).
- **Verify:** Malformed `.env` triggers a non-silent failure.

### Step 7: Update remediation hint in `_require_api_key`
- **Test:** Update the AC-3 baseline test from Step 1 to assert the new error message references both env-var AND `.env` paths (e.g., `"export LINEAR_API_KEY=<key> or add LINEAR_API_KEY=<key> to .env at the project root"`).
- **Implement:** Edit the `_die 2` call in `_require_api_key` at `linear-query.sh:66`.
- **Files:** `.ccanvil/scripts/linear-query.sh` (modify), `hub/tests/linear-query-env.bats` (update).
- **Verify:** New message visible in failure path; existing BTS-164 fail-loud tests still pass (the substring `"LINEAR_API_KEY not set"` should still appear — extending, not replacing, the message).

### Step 8: Manual end-to-end verification
- **Test:** From a fresh shell with no exported `LINEAR_API_KEY`, run `bash .ccanvil/scripts/docs-check.sh idea-count`. Should succeed and emit live counts (replicating the originally-broken path).
- **Implement:** No code change — ritual.
- **Files:** None.
- **Verify:** `idea-count` returns the JSON envelope without manual env-loading. Same with `radar-gather`.

### Step 9: Documentation update
- **Test:** None (docs-only).
- **Implement:** Update `.ccanvil/guide/` if any reference doc enumerates `linear-query.sh` env-var requirements (likely the operations/resolver section). Mention auto-source from `.env` as a hub-wide behavior. Read `.ccanvil/guide/index.md` first to find the right file; only edit if existing content needs the update.
- **Files:** `.ccanvil/guide/<applicable>.md` (modify, if applicable).
- **Verify:** Doc section reflects the new behavior; no stray references to the manual-source ritual.

## Risks

- **`.env` with shell expansion / command substitution.** A `.env` containing `$(date)` or backticks would execute on source. Mitigation: this is the same risk every project carries when sourcing dotenv files; we don't introduce new exposure. The file is already trusted by the project (lives next to `.git/`); attackers with write access there have bigger leverage. Note in the AC-6 test that command substitution in `.env` IS executed — that's expected dotenv behavior.
- **Multiple `.env` files in nested subprojects.** If a developer runs the script from inside a nested git repo (e.g., a vendor/ submodule), `$PWD`-walk finds the inner `.git` first. Mitigation: use the closest `.git` to the caller, not the outermost. Document the precedence in the helper's comment.
- **Performance — file-walk on every invocation.** Each `linear-query.sh` call scans up the directory tree. Cost: ~5 syscalls. Negligible. No caching needed.
- **Whitespace / quoting in `.env` values.** `set -a; .` handles `KEY=value` and `KEY="value with spaces"` correctly. `KEY='hard quotes'` also works. Multi-line values are not supported by bash `.` — out of scope.

## Definition of Done

- [ ] All acceptance criteria from spec pass
- [ ] All existing tests still pass (1140+ baseline)
- [ ] `bash .ccanvil/scripts/docs-check.sh idea-count` succeeds in a fresh shell with no exported `LINEAR_API_KEY`
- [ ] Code reviewed (run /review)

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
