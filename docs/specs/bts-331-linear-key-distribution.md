# Feature: LINEAR_API_KEY auth-chain extension — ~/.env + macOS Keychain

> Feature: bts-331-linear-key-distribution
> Work: linear:BTS-331
> Created: 1778185600
> Subject: LINEAR_API_KEY auth-chain extension — ~/.env + macOS Keychain
> Status: Complete

## Summary

`linear-query.sh`'s `_load_env_if_needed` currently resolves `LINEAR_API_KEY` from two sources: an exported shell env var, or a `.env` file at the nearest `.git` ancestor of `$PWD`. This works for the hub but fails silently in any downstream-node session whose project tree doesn't carry the key — verified across 9 of 11 registered nodes (web-browser-toolbox, microsoft365-toolbox, taxes, fieldnation-toolbox, etc.). Every Linear-routed substrate primitive (idea.add, ticket.transition, backlog.list, artifact-write/read) exits 2 in those sessions. This spec extends the auth chain with two well-bounded fallbacks — a `~/.env` user-default and a macOS Keychain lookup — closing the gap with one canonical key location and an encrypted-at-rest option, no per-node distribution required.

## Job To Be Done

**When** I open a fresh shell in any ccanvil downstream node and dispatch a Linear-routed substrate primitive,
**I want to** have my Linear API key auto-resolved from a single canonical location I configured once,
**So that** every node works without per-project `.env` distribution and without the "set -a; source ~/projects/ccanvil/.env" ritual.

## Acceptance Criteria

Each criterion is independently testable. Binary pass/fail.

- [ ] **AC-1:** When `LINEAR_API_KEY` is exported in the shell environment, `_load_env_if_needed` returns immediately — no walk-up, no `~/.env` read, no Keychain query. Existing precedence preserved.
- [ ] **AC-2:** When `LINEAR_API_KEY` is unset AND a project-root `.env` (found via the existing `.git`-ancestor walk) defines it, that file wins. Existing behavior preserved.
- [ ] **AC-3:** When `LINEAR_API_KEY` is unset AND no project-root `.env` resolves the key (file missing, file present but key not defined, or `$PWD` outside any git tree), `_load_env_if_needed` falls back to `~/.env` if it exists and defines `LINEAR_API_KEY`.
- [ ] **AC-4:** When tiers 1–3 all miss, `_load_env_if_needed` queries macOS Keychain via `security find-generic-password -a "$USER" -s linear_api_key -w 2>/dev/null` and exports the result as `LINEAR_API_KEY` if the lookup succeeds (exit 0, non-empty output).
- [ ] **AC-5:** Service-name mapping for the Keychain tier is the lowercased env var name: `LINEAR_API_KEY` → `linear_api_key`. The mapping is mechanical and documented in the script comment.
- [ ] **AC-6 (edge):** When `security` is not on `PATH` (non-macOS host, or stripped environment), the Keychain step exits silently (no stderr noise, no non-zero propagation) and the auth chain proceeds to the existing `LINEAR_API_KEY not set` error.
- [ ] **AC-7 (edge):** When the Keychain entry exists but `security` requires interactive approval (first-run "Always Allow" prompt), the call still succeeds non-interactively from the operator's terminal. (The Bats test stubs `security` and does not exercise this; the AC is verified live as part of impl per the live-API gate.)
- [ ] **AC-8 (error):** When tiers 1–4 all miss, `_require_api_key` exits 2 with an updated error message that names all four resolution tiers verbatim (env var, project `.env`, `~/.env`, Keychain entry `linear_api_key`) so the operator can pick whichever fits their setup.
- [ ] **AC-9:** Bats coverage at `hub/tests/linear-query-auth-chain.bats` exercises AC-1 through AC-8 using a stubbed `security` binary on `PATH` (intercepts the keychain query) and a controlled `HOME` + tmpdir + injected `.env` files. No real Keychain access; no real `~/.env` writes.
- [ ] **AC-10:** Live-API validation — after impl, run `cd ~/projects/web-browser-toolbox && bash ~/projects/ccanvil/.ccanvil/scripts/linear-query.sh viewer` from a fresh shell with `LINEAR_API_KEY` unset and project `.env` lacking the key. Must succeed via the keychain tier. Captured per `.claude/rules/tdd.md#live-api-validation-gate`.

## Affected Files

| File | Change |
|------|--------|
| `.ccanvil/scripts/linear-query.sh` | Modified — extend `_load_env_if_needed` with `~/.env` then Keychain fallback; update `_require_api_key` error message (lines 82-128 region) |
| `hub/tests/linear-query-auth-chain.bats` | New — AC-1 through AC-8 with `security` stub injection |
| `.ccanvil/manifest-allowlist.txt` | Modified — register the new bats file |

## Dependencies

- **Requires:** macOS host for AC-4/AC-7/AC-10 verification (graceful no-op on non-macOS per AC-6). Operator has already stored the key under `linear_api_key` in their login keychain (confirmed 2026-05-07).
- **Blocked by:** Nothing.

## Out of Scope

- **Generic `secret-resolve` substrate primitive.** BTS-332 captures the broader research-and-design effort for a unified secret resolver and naming convention. This spec lands the minimum viable Linear-specific extension; generalization is a follow-on.
- **Other providers' API keys** (GitHub, Notion, etc.). The scope is Linear only — the substrate touched (`linear-query.sh`) is provider-specific by name. Generalization waits for BTS-332.
- **Distributing the key per-node.** Explicitly rejected — multiplies leak surface and key-rotation friction.
- **Symlinks** between node `.env` and hub `.env`. Explicitly rejected per operator preference.
- **Auto-migration from existing `~/projects/ccanvil/.env`** to `~/.env` or Keychain. The hub `.env` continues to work via tier 2; operator decides if/when to consolidate.

## Implementation Notes

- Existing `_load_env_if_needed` is in `linear-query.sh` lines ~82–119. Extend the function in place; do NOT factor into a separate helper without revisiting the `set -a` scope-leak comment already in the source (the existing code calls out that scope behavior explicitly — preserve it across the new tiers).
- Tier order (top wins): exported env → project-root `.env` (existing walk) → `~/.env` → `security find-generic-password -a "$USER" -s linear_api_key -w`.
- Keychain query uses `2>/dev/null` to absorb the "item not found" stderr noise. Check both exit code AND non-empty stdout before exporting (AC-4).
- `command -v security >/dev/null 2>&1` gates the Keychain tier — AC-6 graceful no-op pattern.
- Bats `security` stub: write a small wrapper script in the test's `PATH=$STUB_DIR:$PATH` that responds based on `STUB_KEYCHAIN_VALUE` env var (mirrors the `LINEAR_QUERY_OVERRIDE` pattern from BTS-203).
- Updated error message preserves the actionable shape — list tiers in resolution order, not alphabetical.

## Open Questions

None — all four tier choices, mapping rule, and edge cases pinned in ACs.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
