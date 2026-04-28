# Stasis

> Feature: session-2026-04-27-bts-239-dark-code-layer-2-shipped
> Kind: session
> Last updated: 1777358678
> Session: 10
> Boundary: 2026-04-27T20:24:05-07:00
> Session objective: Begin Dark Code Phase 1 — research lap, then spec + ship Layer 2 first substrate (module-manifest format + parser + drift-guard + 3 seed primitives).

## Accomplished

* **Phase 1 research lap completed.** Read convergent written sources (transcript not directly fetchable from YouTube): SOCFortress *Driving into the Void: Amazon's $100M Autopsy of the "Dark Code" Crisis* (Apr 2026 — direct video summary), Osmani *Comprehension Debt* (counter-evidence on the limits of specifications), Nate B Jones substack excerpt. Synthesized into `docs/research/dark-code-mapping.md` (commit 36c4ed3): three layers mapped to ccanvil, current-state assessment (Layer 1 \~80%, Layer 2 \~10% — biggest gap, Layer 3 \~40%), first-ship recommendation = in-source kv-comment manifests.
* **BTS-239 spec-to-merge in one session.** PR #138 squash-merged as commit 37aca8a. 30 files changed, +2067 insertions. Manifest substrate (`module-manifest.sh`: extract / validate / query / index, \~400 LOC), 7-entry allowlist, format documented at `.ccanvil/templates/manifest.md`, stasis + recall integrations, command-reference doc updated.
* **Bidirectional drift-guard live.** `cmd_validate` enforces 6 drift classes: file-not-found, manifest-not-found, missing-required-key, caller-not-found, depends-on-not-found, missing-failure-mode-marker, missing-side-effect-marker. Source markers (`# @failure-mode: <id>`, `# @side-effect: <id>`) attach to specific call-sites; manifest entries cross-checked against grep-of-source AND in-body markers.
* **Self-application by construction.** All four module-manifest verbs (cmd_extract, cmd_validate, cmd_query, cmd_index) carry their own manifests. Format describes its own substrate. Allowlist: 3 production seeds (cmd_artifact_write, cmd_ship_finalize, cmd_idea_pending_replay) + 4 self-application = 7 entries.
* **AC-11 live-AC armed.** `/recall` [SKILL.md](<http://SKILL.md>) gained step 11 (run validate, surface coverage on cold start). `/stasis` template + skill prose gained `## Manifest Coverage` section. Next session's recall will surface `**Manifest coverage:** 7 / 7 (allowlist), drift: 0` automatically.
* **One mid-ship substrate refinement.** Skill-shape caller resolution unified under `.claude/skills/<n>/SKILL.md` AND `.claude/commands/<n>.md` because the runtime treats them as one operator-callable namespace.
* `exit=` value relaxation. Originally the manifest-format validator enforced numeric `exit=N`; pushed back when cmd_artifact_write declared `save-failure | exit=passthrough` (the [linear-query.sh](<http://linear-query.sh>) exit code propagates). Validator now accepts numeric codes OR special tokens (passthrough, propagate, \*) — captures real semantics without forcing fictional fixed codes.

## Current State

* **Branch:** `main`, fast-forwarded to origin (`37aca8a`). Working tree clean.
* **Tests:** **1892 / 1892 passing.** Net delta: 1839 → 1892 (+53). 36 new bats tests across 10 new files.
* **Uncommitted changes:** none.
* **Build status:** clean.
* **Backlog: 0 / Triage: 0 / Icebox: 2** (BTS-22 + BTS-21 — long-tail research, deferred).

## Blocked On

Nothing.

## Next Steps

1. **Soak observation (Dark Code live-throughput guard).** Watch new-capture cadence for the next 1-2 sessions. >2 captures/week during this theme = stabilization didn't hold, pause and re-stabilize. Live-AC fires automatically: next `/recall` surfaces `Manifest coverage: 7/7 (allowlist), drift: 0` from the substrate.
2. **Layer 2 follow-up ship — markdown frontmatter.** Extend manifest format to skills/rules/agents (currently shell-only). 9 skills + 7 rules + 5 agents = 21 new units, all already YAML-frontmatter-friendly. Same drift-guard schema; container varies (HTML comment block vs YAML frontmatter).
3. **Layer 2 follow-up ship — pre-commit hook.** Adherence layer 4 — fast feedback when source changes without manifest update. WARN-only, drift-guard CI is the actual fence.
4. **Layer 3 ramp (when coverage > 50%).** Augment `code-reviewer` agent / `/review` skill with manifest-aware checks: PR adds new caller of cmd_X not declared in manifest → reviewer flags as architecture-shaped change.
5. **Backlog growth.** Triage incoming captures during Dark Code work. WIP-limit one active spec at a time. Speculative captures allowed in Triage (relaxed from Stabilization theme).

## Context Notes

* **Operator pushback on minimal manifest shape, mid-conversation.** Initial recommendation was a 6-field minimal manifest (purpose, inputs, outputs, failure-modes, side-effects, anchors) with auto-derived callers/depends-on to minimize drift surface. Operator countered: "Storing this context in-line is mature and arms you, and anyone or anything reading these files with extremely valuable context. The challenge is keeping the manifests up-to-date and somehow gating/ensuring that this happens." Yielded — full-breadth manifest (10 fields including caller/depends-on/contract) with bidirectional drift-guard as the gating mechanism. Validates the principle: **for self-describing systems, inline richness > drift-minimal terseness**; the readers (cold-start Claude, future operators) outweigh the writers, and the drift-guard converts redundancy into a load-bearing comprehension test.
* **Heterogeneous file-type granularity surfaced via second-source.** Operator brought a separate excerpt that used "every core module or directory must contain a [README.md](<http://README.md>) or a manifest file" (directory-level). Initial recommendation was function-level only (per-cmd\_\* in mega-scripts). Settled on heterogeneous: function-level for shell mega-scripts (\~106 units), file-level for single-purpose scripts (\~30 units), YAML frontmatter for markdown (\~21 units, future ship). Format consistent across containers; container varies by file-type idiom.
* **Allowlist scope decided as option (a):** 100% drift-guard on the 3 seed primitives at first ship; allowlist mechanic carries forward, growing per ship. Rejected option (b) (\~159 manifests in one ship) as too big to hold quality.
* **Bash 3.2 compatibility hit early.** First implementation used `mapfile` (bash 4+) and `local -n` namerefs (bash 4.3+). System bash on macOS is 3.2 (GPLv3 licensing — Apple won't ship newer). Refactored `module-manifest.sh` to use indexed arrays + `while IFS= read` loop + global `lines` array referenced by helper. Recurring constraint for any new ccanvil substrate.
* `set -u` + empty-array gotcha caught on first validate test: bash 3.2 `for x in "${empty_array[@]}"` triggers "unbound variable" under `set -u`. Workaround: guard with `if [[ ${#arr[@]} -gt 0 ]]; then for ... done; fi`. Captured for future substrate work.
* **Bidirectional drift-guard's hidden value.** The `@failure-mode: <id>` / `@side-effect: <id>` source markers are the actual gate. Manifests can be retro-edited in isolation, but adding a new failure path REQUIRES adding both the marker AND the manifest entry — drift-guard fails CI otherwise. This is the "self-describing systems made enforceable" innovation. Goes beyond just docs.
* **Process discipline maintained.** Full TDD across 14 plan steps: spec, activate, plan, RED, GREEN, pr-cleanup, push, land. No skipped steps even under context pressure across the 50+ message ship. Process held.

## Determinism Review

* operations_reviewed: \~50 (14 TDD cycles × \~4 ops each: RED-bats / GREEN-impl / verify / commit)
* candidates_found: 0
* No candidates this session. The substrate this ship was built on (BTS-235 ship-finalize, BTS-237 spec-activate cache fix, BTS-236 PR title from Subject) made the lifecycle deterministic. Pre-PR phase is irreducible Claude-judgment (spec design, plan decomposition, RED-test design, GREEN implementation). The ship's only mid-flight stochastic surface — choosing the manifest format granularity and field set — was an architectural decision, not a recurring operation.

## Evidence Gaps

No evidence gaps this session.

## Manifest Coverage

7 / 7 (allowlist), drift incidents: 0

## Cross-Session Patterns

* **CONFIRMED RECURRING (sessions 4-10): dogfood-surfaces-substrate-correctness.** Session 10 added: BTS-237 fix (CREATE-cache skip) proved on every artifact-write during the ship — no manual concurrent-edit retry needed; BTS-236 fix (Subject auto-derivation) proved on PR #138's clean ≤72-char title. 7th consecutive session of dogfood-as-validation.
* **NEW (session 10): substrate-on-substrate composition.** BTS-239's substrate ([module-manifest.sh](<http://module-manifest.sh>)) is built ON the existing substrate (artifact-write for spec/plan/stasis dispatch, ship-finalize for the post-merge flow, idea-pending-replay for capture fallback). All three got their own manifests in the same ship. Self-describing systems describe themselves via the very substrate they describe.
* **No legacy-refs surfaces.** `legacy-refs-scan` returned `[]`.
* **Audit-session: 0 patterns.** No new stochastic-shaped code introduced in the session's diff.
* **Manifest coverage at first measurement: 7/7, drift = 0.** Future sessions can compare deltas — coverage growth as new entries are added, drift incidents as a quality signal.

## Security Review

* **All ship work was substrate + tests + skill-prose changes.** No new auth surfaces, no new secrets paths.
* `module-manifest.sh` reads source files for grep + JSON construction. No write paths beyond `.ccanvil/state/manifests.json` (gitignored).
* No external network calls in the substrate (all bash + jq + awk over local files).
* All 36 new bats tests use temp-dir fixtures or copy-from-source-tree patterns. No live API.
* **Verdict: PASS.**

## Memory Candidates

* **NEW MEMORY:** `feedback_inline_richness_over_drift_minimal_for_self_describing_systems` — when designing self-describing code (manifests, behavioral contracts, machine-readable docs), favor inline richness over drift-minimal terseness; the readers (cold-start Claude, future operators) outweigh the writers, and bidirectional drift-guards convert redundancy into a load-bearing comprehension test. Anchored on operator pushback in session 10 that expanded manifest fields from 6 to 10. **Save as feedback memory.**
* **NEW MEMORY:** `project_layer_2_module_manifests_live` — Dark Code Phase 1 first ship landed (BTS-239, PR #138). Self-describing-systems substrate (`module-manifest.sh`) provides extract/validate/query/index verbs; allowlist-driven drift-guard at 100% on 3 seed primitives + 4 self-application verbs. Format documented at `.ccanvil/templates/manifest.md`. /stasis + /recall integrate. Markdown frontmatter, pre-commit hook, Layer 3 manifest-aware review all defer. **Save as project memory.**
* **REINFORCE:** `feedback_dogfood_probe_as_thesis_test` — 7th consecutive session of dogfood validation. BTS-237 + BTS-236 fixes proved live on this ship's flow.
* **REINFORCE:** `project_stabilization_drain_validated` — clean theme rollover Stabilization → Dark Code held; first Dark Code ship landed without re-stabilization signal (>2 captures/week threshold).
* **No new external references** this session.