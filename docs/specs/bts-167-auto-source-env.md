# Feature: Auto-source .env in linear-query.sh

> Feature: bts-167-auto-source-env
> Work: linear:BTS-167
> Created: 1777148448
> Status: Complete

## Summary

Make `linear-query.sh` self-sufficient about `LINEAR_API_KEY`: when the env var is unset and a `.env` file exists at the project root, source it before failing. Eliminates the `set -a; source .env; set +a` ritual that has to run before every `Bash` invocation that touches Linear (`/recall`, `/radar`, `docs-check.sh idea-count`, `radar-gather`, every http-routed resolver call). Single fix at the substrate's auth gate; every consumer benefits transparently.

## Job To Be Done

**When** I run any http-routed Linear operation in a fresh shell (the default state for every `Bash` tool call),
**I want to** have `LINEAR_API_KEY` loaded from `.env` automatically when present,
**So that** the operation succeeds without a manual env-loading incantation.

## Acceptance Criteria

- [ ] **AC-1:** Given `LINEAR_API_KEY` is unset in the environment AND `.env` at the project root exports `LINEAR_API_KEY=<key>`, when any `linear-query.sh` subcommand other than `--help` runs, then it succeeds and uses the value from `.env`.
- [ ] **AC-2:** Given `LINEAR_API_KEY` is already exported in the environment AND `.env` at the project root has a different value, when a subcommand runs, then the exported value wins (no override) and `.env` is not sourced.
- [ ] **AC-3:** Given `LINEAR_API_KEY` is unset AND `.env` does not exist (or exists but does not define the key), when a subcommand runs, then the existing fail-loud error fires unchanged: exit 2 with the current "LINEAR_API_KEY not set..." remediation hint.
- [ ] **AC-4:** Project root discovery is anchored at `.git` (walk up from the script's invocation directory). When no `.git` ancestor is found, fall back to current behavior (no auto-source). Works whether the script is invoked via relative path, absolute path, or symlinked into PATH.
- [ ] **AC-5:** Auto-source is silent on success — no stderr noise, no stdout pollution. Failure path (key still missing after attempted source) is unchanged.
- [ ] **AC-6:** `set -e` and `set -u` semantics are preserved through the source step. A malformed `.env` (syntax error) does NOT cause the wrapper to silently lose the failure mode — surface the parse error or fall through to the "not set" path.
- [ ] **AC-7:** Bats coverage: at minimum one test per AC-1, AC-2, AC-3. AC-4 covered by a fixture that invokes the script via absolute path from `/tmp` with `cd` away from the project. AC-5 covered by asserting empty stderr when auto-source succeeds.

## Affected Files

| File | Change |
|------|--------|
| `.ccanvil/scripts/linear-query.sh` | Modify `_require_api_key` (and/or add a `_load_env_file` helper) to auto-source `.env` when key is unset |
| `hub/tests/linear-query-env.bats` | New test file — covers AC-1 through AC-6 |

## Dependencies

- **Requires:** BTS-164 substrate (already shipped — `_require_api_key` exists at `linear-query.sh:64`)
- **Blocked by:** none

## Out of Scope

- `.env` discovery in non-git directories (rare; not worth the policy ambiguity).
- Sourcing other dotfiles (`.envrc`, `.env.local`, etc.) — single-file scope keeps the contract simple.
- Caching the resolved key across invocations (each invocation is short-lived; no win).
- Changing the `LINEAR_QUERY_ENDPOINT` discovery — same shell pattern, but separate ticket if needed.
- Modifying `operations.sh`, `docs-check.sh`, or any caller — fix lives entirely in `linear-query.sh`.

## Implementation Notes

- The fix lives in `_require_api_key()` at `linear-query.sh:64-68`. Insert a `_load_env_if_needed` step before the existence check.
- Project root discovery: walk up from `$(dirname "${BASH_SOURCE[0]}")` looking for `.git`. Use a small loop, not `git rev-parse` — we don't want to depend on git being on PATH or working in submodules/worktrees.
- Sourcing pattern: `set -a; . "$root/.env"; set +a` inside a subshell-safe block. Don't use `source` (bash-only); `.` is POSIX. Actually — the script is `#!/usr/bin/env bash` with `set -euo pipefail`, so `source` is fine. Pick whichever reads cleaner.
- Idempotence: only attempt the source when `LINEAR_API_KEY` is unset (`-z "${LINEAR_API_KEY:-}"`). Don't double-source if the var is already set.
- The existing error message at line 66 should reference both env-var and `.env` paths in the remediation hint.
- Test pattern: use a tmpdir as the project root with a fake `.git/` directory and a controlled `.env`. Stub the actual GraphQL endpoint via `LINEAR_QUERY_ENDPOINT` (existing pattern in `hub/tests/fixtures/linear-stub.sh`) so AC tests don't hit the network.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
