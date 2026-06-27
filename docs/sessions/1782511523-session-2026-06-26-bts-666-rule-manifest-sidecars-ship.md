# Stasis: session-2026-06-26-bts-666-rule-manifest-sidecars-ship

> Feature: session-2026-06-26-bts-666-rule-manifest-sidecars-ship
> Kind: session
> Session: 87
> Boundary: 2026-06-26T15:05:23-07:00
> Last updated: 1782511523

## Accomplished

* **BTS-666 SHIPPED & LANDED** (PR #202, squash `bc4052f`, ticket Done). Relocated the inline `manifest:` frontmatter block of 8 tier-0 rules into co-located `.claude/rules/<id>.manifest.yaml` sidecars (`manifest_ref:` pointer in the rule). **Context budget CRITICAL \~113% → WARNING 81.4%** — ~2,758t of machine-only metadata off the per-turn surface.
* New drift-safety guards in `module-manifest.sh validate`: `rule-manifest-ref-broken` (back-ref + id-match), `rule-manifest-sidecar-orphan` (bijection), `rule-manifest-sidecar-malformed` — all block-shape (exit 2). Bijection domain = manifest-carrying rules only (exempts manifest-less tier-0 like background-task-discipline).
* `_extract_markdown` follows `manifest_ref` to the sidecar (golden-equal to inline). `code-quality.md` body atomized → `docs/research/code-quality-foundations.md`. Sidecars added to `ccanvil-sync.sh` TRACKED_PATTERNS (downstream propagation).
* Full lifecycle: spec → /spec --review (caught a real AC-3 bijection ambiguity) → activate → plan → 11 TDD steps → /review → /pr → /ship → land.
* Triage drained 22→0 earlier this session (7 promoted incl BTS-666/667 P2; 15 drift-watchdog alerts → icebox). Captured BTS-672 (cmd_rule_resolve surface manifest_ref).

## Current State

* **Branch:** main (clean, synced with origin at `bc4052f`).
* **Tests:** full suite 2512/2513 — the 1 failure is a pre-existing telemetry parallel-ordering flake (`bats-report-end-to-end-trace.bats` AC-7) that passes in isolation; no telemetry code touched.
* **Uncommitted changes:** none.
* **Build status:** clean. Manifest validate 206/206 drift 0; Layer-3 diff clean.

## Blocked On

Nothing.

## Next Steps

1. **BTS-667** (P2) — diff-vs-manifest xfuncname substrate fix. The other high-leverage Dark Code substrate-health item; pairs with BTS-666.
2. **BTS-672** (Triage) — cmd_rule_resolve surface manifest_ref + sidecar path (BTS-666 follow-up).
3. **BTS-612** (P2) — ticket.transition duplicate ordering FIX.
4. 1 untriaged idea (BTS-672) — `/idea triage`.

## Context Notes

* **Architectural decision (operator-made):** rule manifests are dual-purpose (always-loaded agent context AND Layer-2 manifested primitives). The `manifest:` frontmatter was ~49% of rule token cost yet read only by the drift-guard. Chose Option A (relocate to sidecar) over body-only-atomize (insufficient — bodies already atomized by BTS-387) or strip-manifests (regresses Layer-2). Operator's hard constraint: no new manifest↔subject drift surface → satisfied by bijection + back-ref guards.
* **AC-4 regression caught at the pre-merge gate:** relocating workflow's manifest broke radar's caller link (radar declared workflow.md a caller; the `/radar` token that satisfied it lived in workflow's manifest `purpose`, now in the sidecar). Fixed by grepping the sidecar alongside the rule body in `_caller_actually_calls_primitive` — (body + sidecar) = the original whole file. This is the general fix, not just radar.
* **AC-10 gap caught:** sidecars weren't in `ccanvil-sync.sh` TRACKED_PATTERNS — un-pulled downstream nodes would get a rule whose manifest_ref points to a missing sidecar. Added the glob.
* **Harness-auto-load assumption** (sidecars not loaded as rules) rests on strong indirect evidence (session-start loaded only `*.md`; context-budget globs `*.md`; tested-excluded) but the definitive cross-session probe fires on next session start. Fallback documented: `.claude/rules/manifests/` subdir.
* Full manifest validate is SLOW (~4.5 min — caller-index rebuild over 264 entries). Ran it ~4× this session.

## Determinism Review

* **operations_reviewed:** ~40 (recall, /idea triage drain, /radar, BTS-666 spec + critic + activate + plan + 11 TDD steps + review-fix + /pr + /ship + land).
* **candidates_found:** 2.

**pr-body-render-substrate**: Claude hand-composed the PR #202 body via heredoc again (summary from spec, test plan from ACs). Should be `docs-check.sh pr-body-render --feature <id>`. Recurring — already captured as BTS-670. Impact: medium.

**mid-pr-validate-changed-only**: Claude ran the full ~4.5-min `module-manifest.sh validate` ~4× this session for mid-impl confirmation when `--changed-only` (BTS-383) would suffice; only the pre-merge gate needs the full caller-index rebuild. A /review-or-validate wrapper that auto-scopes to `--changed-only` mid-PR (mirroring check-skip-validate) would save ~3-4 min per redundant run. Impact: medium.

## Evidence Gaps

No evidence gaps this session.

## Manifest Coverage

206 / 206 (allowlist), drift incidents: 0

## Permissions Review Pending

8 TRIAGE candidates from settings.local.json + 0 DANGER entries lacking rationale.

* All 8 are settings.local.json delta candidates classified TRIAGE (operator-personal MCP/Read entries from the BTS-603 split; not new this session).
  Run `/permissions-review` to triage interactively.

## Cross-Session Patterns

* **BTS-562 (legacy-refs raw-traces false-positive):** RECURRING — 231 matches, all from `.ccanvil/observability/raw-traces.jsonl` (runtime artifact). ~11th consecutive. node-specific; the BTS-562 gitignored-runtime-dir filter is still unshipped.
* **BTS-563 (concurrent-edit own-caller override):** RECURRING — hit once this session on the spec Linear doc (4 dispatches advanced updatedAt past cache). Verified own-caller divergence → override. ~8th consecutive; substrate fix still pending.
* **pr-body hand-composition:** RECURRING — = BTS-670 (this session's determinism candidate #1).
* **audit-session shasum/cp noise:** benign stylistic patterns from test-fixture authoring; not bugs.

## Security Review

PASS. 50-file diff (bash/yaml/md). No secrets, private keys, or PII; grep matches were manifest `purpose` prose and guard-force-push token-matching code, not credentials.

## Memory Candidates

* **feedback:** When a rule/primitive is dual-purpose (always-loaded context AND machine-validated manifest), relocate the machine-only metadata to where the machine reads it (sidecar) rather than accept the per-turn cost — but only behind a bijection/back-ref guard so decoupling adds no drift surface. Operator-validated on BTS-666.
* **reference:** `module-manifest.sh validate` full run is ~4.5 min (caller-index rebuild over ~264 allowlist entries); use `--changed-only` (BTS-383) for mid-PR checks, reserve full for pre-merge.
* **reference:** Rule manifests now live in `.claude/rules/<id>.manifest.yaml` sidecars (BTS-666); `_extract_markdown` follows `manifest_ref`. Tests asserting rule-manifest content must grep (body + sidecar).