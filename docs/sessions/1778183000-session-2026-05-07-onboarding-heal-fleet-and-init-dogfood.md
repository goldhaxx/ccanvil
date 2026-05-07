# Stasis

> Feature: session-2026-05-07-onboarding-heal-fleet-and-init-dogfood
> Kind: session
> Last updated: 1778183000
> Session: 25
> Boundary: 2026-05-06T11:18:30-07:00
> Session objective: Ship the provider-heal trio + capstone (BTS-319/320/321/326) — collapsing the manual heal flow into one operator-facing verb — then dogfood it across all 10 registered downstream nodes, then validate BTS-318's lifecycle-doc-seeding fix end-to-end via a fresh /ccanvil-init on web-browser-toolbox.

## Accomplished

**Six ships through full lifecycle** (capture → spec → activate → plan → implement → PR → ship):

| Ship | PR | Theme |
| -- | -- | -- |
| BTS-318 | #161 | /ccanvil-init Step 6 simplified (drop per-feature lifecycle-doc seeding) + cmd_artifact_read --project-dir honor (scope-up surfaced live during impl) |
| BTS-319 Phase 1 | #162 | provider-resolve-ids substrate (live ID resolution: team_id, project_id, state_ids\[8\], label_ids\[idea\]) |
| BTS-325 (chore) | #163 | Roadmap Phase 2 SHIPPED markup + checkpoint→stasis residue cleanup |
| BTS-320 Phase 2 | #164 | provider-heal-preflight (read-only substrate-drift gate) |
| BTS-321 Phase 3 | #165 | provider-heal-auth (LINEAR_API_KEY chain + viewer smoke-test) |
| BTS-326 Capstone | #166 | provider-heal umbrella (composes Phase 1+2+3 with fail-fast halt-and-remediate) |

**Fleet heal across 11 downstream nodes** (10 pre-existing + 1 new web-browser-toolbox initialized this session):

* 11/11 healed via provider-heal — every registered node now Linear-routed with full IDs block + label, auth verified, substrate at hub-current.
* 4 Linear projects created via mcp__claude_ai_Linear__save_project: docint, microsoft365-toolbox, web-browser-toolbox (and the prior unifi-toolbox manual heal commit `19af207` was ff-merged from its chore branch).
* Mid-flow friction handled: section-merge on caffeine-calculator's tdd.md and whoop-toolbox's CLAUDE.md, take-hub on taxes' settings.json conflict, routing.ticket → routing.idea rename on inbox-toolbox.

**BTS-318 fix validated end-to-end via dogfood.** Initialized \~/projects/web-browser-toolbox from scratch (project_mode=fresh, 93 files copied, 0 errors); first lifecycle-state query returned `state: no-active-spec` (NOT blocked) — proving BTS-318's primary AC live. Provider-heal worked first-try post-init.

**8 new captures.** From the heal dogfood: BTS-320–324 (substrate-drift gate, auth preflight, pull-auto-with-new, ccanvil-sync self-update crash hardening, routing.ticket rename). From the web-browser-toolbox dogfood: BTS-327 (CLAUDE.md hub-content leak in fresh init), BTS-328 (pull-globals requires lock-file in cwd), BTS-329 (guard-workspace ALLOW_OUTSIDE_WORKSPACE bypass undocumented in skill prose). Plus the umbrella capture itself, BTS-326.

**All 17 Triage items promoted to Backlog with priorities** — Backlog now 18 items, Triage 3 (the post-promotion captures from the web-browser-toolbox dogfood — BTS-327/328/329).

## Current State

* **Branch:** main, clean working tree.
* **Tests:** 2023/2023 passing (BTS-326 ship verified post-merge).
* **Build status:** clean.
* **Manifest coverage:** 193/193, drift 0.
* **Idea queue:** Triage 3 (BTS-327/328/329 — captured this session, not yet promoted) / Backlog 18 / Icebox 2.

## Blocked On

Nothing.

## Next Steps

1. **Triage the 3 fresh dogfood captures.** BTS-327 (CLAUDE.md hub-leak — operator-facing init friction, recommend P2), BTS-328 (pull-globals lock-required — small substrate fix, recommend P3), BTS-329 (skill-prose doc — recommend P3). Run `/idea triage`.
2. **Decide next ship.** P1 backlog item is BTS-315 (`/ccanvil-pull-globals` staleness — partially mitigated this session by the manual force-sync, but the substrate gap remains). Other P2 candidates: BTS-312 (test-runner indirection — smallest pattern-anchor), BTS-313 (Linear provider activation deterministic flow during init — broader BTS-326 follow-on), BTS-324 (routing.ticket rename — already partially fixed via the manual heal in this session, substrate primitive still pending).
3. **Theme rollover decision.** Onboarding & Hub/Spoke Separation theme has shipped 6 PRs this session and the heal flow is now end-to-end. Either continue draining the onboarding cluster (BTS-312/313/315 remain) or rotate to a new theme. Operator-decision.
4. **Substrate gap clusters.** Two natural follow-on ships from today's friction: (a) `pull-auto-with-new` (BTS-322) — fold accept-new loop into pull-auto; (b) `ccanvil-sync.sh` self-update crash hardening (BTS-323) — re-exec under new script after self-modify. Both surfaced repeatedly during the fleet heal.

## Context Notes

* **Provider-heal umbrella shape locked in.** Fail-fast Phase 3 → Phase 2 → Phase 1 order; --json envelope for skill composition; never-invokes-pull-auto-or-pull-apply contract preserved (operator drives drift remediation explicitly).
* **CCANVIL_SYNC_OVERRIDE introduced this session** as a sibling test-injection point to LINEAR_QUERY_OVERRIDE (BTS-203). Used in BTS-320/326 bats coverage. Now part of the substrate test-injection vocabulary.
* **JSON-mode stdout discipline.** Two stub-related fixes during impl: BTS-320 + BTS-321 + BTS-326 all needed `if (( json_out )); then JSON; else text; fi` form to prevent text-mode messages contaminating JSON envelopes. Pattern is now well-established.
* **Operator's "no-work-on-main" rule applies to ccanvil hub specifically.** Downstream nodes use chore branches + ff-merge. Sandbox enforcement caught and corrected an early misstep this session.
* **BTS-318 dogfood result is a notable validation moment.** Shipping the fix and same-session dogfooding it on a freshly-initialized real project (web-browser-toolbox) is the textbook `feedback_same_session_dogfood_validates_thesis` pattern.
* **Fleet-heal pattern is now an established workflow.** Looped over 11 nodes with stash → branch → pull-auto → accept-new → section-merge → provider-heal → commit → ff-merge → pop-stash. Should ultimately become a substrate primitive (`provider-heal-fleet` or `ccanvil-broadcast --heal`).

## Determinism Review

* operations_reviewed: \~40 (6 ship lifecycles × \~5 ops each + 11-node fleet heal sweep + 1 init walkthrough + \~10 substrate verifications)
* candidates_found: 1


* **fleet-heal-orchestration**: For each of the 11 registered downstream nodes, I manually composed the same sequence (stash → branch → pull-auto-twice → accept-new-loop → section-merge → take-hub-on-conflict → provider-heal → git-add scoped to .ccanvil/.claude/CLAUDE.md → commit → ff-merge → pop-stash). 11 iterations of identical substrate composition. Should be a single substrate verb: `bash .ccanvil/scripts/docs-check.sh provider-heal-fleet [--filter <pattern>]` that reads `.ccanvil/registry.json`, iterates each node, runs the pull+heal sequence with operator-visible per-node status, and reports `N/M healed`. Impact: high — this is the operator's natural follow-on workflow now that the per-node umbrella exists. Alternative shape: extend `ccanvil-broadcast` (existing primitive) with a `--heal` flag.

## Evidence Gaps

No evidence gaps this session.

## Manifest Coverage

193 / 193 (allowlist), drift incidents: 0

## Cross-Session Patterns

* **CONFIRMED RECURRING (sessions 23 + 24 + 25): substrate-driven discovery loops compound.** Session 23 surfaced the BTS-316 onboarding theme. Session 25 shipped the heal trio + capstone + dogfooded across the entire fleet, then surfaced 3 more init-flow gaps (BTS-327/328/329) via the fresh-init dogfood. Each layer of substrate maturity reveals the next gap-cluster.
* **NEW PATTERN: dogfood-by-fleet validates substrate at scale.** Running provider-heal across 11 different downstream nodes (varying ages, varying drift states, mixed dirty-tree conditions) exercised every Phase of the umbrella under realistic conditions. Two halt-and-remediate cycles fired (caffeine-calculator's tdd.md section-merge, taxes' settings.json conflict) — each was the right behavior, and the operator-facing remediation was clear. Validates the fail-fast halt-with-remediation design.
* **NEW PATTERN: same-session ship + dogfood = thesis validation.** BTS-318 shipped at the start of session and was dogfooded at the end of session via a real fresh-init. The end-to-end loop took \~6 hours; the validation moment was unambiguous. Reinforces `feedback_same_session_dogfood_validates_thesis`.
* **No recurring legacy-refs.** legacy-refs-scan returns `[]`.

## Security Review

* Session diffs touched substrate (.ccanvil/scripts/docs-check.sh) + tests + manifest-allowlist + roadmap + 11 downstream node configs. NO secrets, NO PII, NO credentials in any committed change.
* [security-audit.sh](<http://security-audit.sh>): 0 critical, 5 high, 3 medium — all pre-existing findings in `docs/sessions/` and `docs/specs/` historical archives. None introduced this session.
* LINEAR_API_KEY was sourced from `~/projects/ccanvil/.env` for substrate dispatch; never logged, never committed.
* Verdict: **PASS**.

## Memory Candidates

* **NEW PROJECT MEMORY candidate** — `project_provider_heal_complete` — Provider-heal flow shipped end-to-end (BTS-319 Phase 1 + BTS-320 Phase 2 + BTS-321 Phase 3 + BTS-326 Capstone). Single operator command `provider-heal --provider linear --team X --project Y --project-dir <path>` collapses \~12 substrate operations into one fail-fast verb. Read-only by composition where possible (only Phase 1 writes config). Live-validated across 11 nodes 2026-05-07.
* **NEW PROJECT MEMORY candidate** — `project_fleet_heal_pattern_established` — All 11 registered downstream nodes are now Linear-routed and at hub-current. Future fleet-heal workflow is a natural substrate candidate (see Determinism Review's fleet-heal-orchestration). When a new BTS-X umbrella ships, the dogfood-by-fleet pattern should be the validation step.
* **NEW FEEDBACK candidate** — `feedback_create_linear_projects_via_mcp_for_dogfood` — When operator says "create projects for these" referring to fleet-heal targets, use mcp__claude_ai_Linear__save_project (not the API wrapper). MCP path is direct, lower-friction, and pre-authenticated via the user-level [claude.ai](<http://claude.ai>) connector. Confirmed 2026-05-07 for docint, microsoft365-toolbox, web-browser-toolbox.
* **REINFORCE** — `feedback_same_session_dogfood_validates_thesis` — BTS-318 fix shipped and same-session dogfooded via fresh /ccanvil-init on web-browser-toolbox. Lifecycle-state correctly returned `no-active-spec` instead of `blocked` — primary AC validated live, not just by bats.
* **REINFORCE** — `feedback_lightweight_pattern_dogfoods_substrate_design` — Provider-heal trio shipped as three small phases first, then composed into the umbrella. Each Phase shipped independently with 7 ACs each + bats coverage. The umbrella ship was \~150 LOC because the work was already done.
* **NEW REFERENCE** — `reference_node_registry` — Hub registry at `.ccanvil/registry.json` carries 11 nodes after this session: taxes, fieldnation-toolbox, caffeine-calculator, luxlook, whoop-toolbox, fucina, unifi-toolbox, docint, inbox-toolbox, microsoft365-toolbox, web-browser-toolbox. UUID-keyed; path is `~/projects/<name>` for all current entries. registry.json is the canonical fleet-heal target list.