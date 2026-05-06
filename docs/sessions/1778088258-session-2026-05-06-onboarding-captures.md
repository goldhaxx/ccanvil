# Stasis

> Feature: session-2026-05-06-onboarding-captures
> Kind: session
> Last updated: 1778088258
> Session: 23
> Boundary: 2026-05-05T19:14:13-07:00
> Session objective: Surface and capture the onboarding-flow gaps revealed when initializing unifi-toolbox, inbox-toolbox, and microsoft365-toolbox. Five Linear ideas filed; roadmap update + residue cleanup pending operator commit decision.

## Accomplished

**Five Linear ideas captured for the hub/spoke separation cluster.** Operator-flagged "very critical" gaps in `/ccanvil-init` exposed by three recent downstream-node onboardings:

| ID | Title | Strategic role |
| -- | -- | -- |
| **BTS-316** | Modular provider connectivity — interactive activation at init, forklift-heal flow | Umbrella; subsumes 313 + 314 |
| **BTS-315** | `/ccanvil-pull-globals` staleness — user-level skill prose drifts from hub canonical | Cross-cutting prerequisite; gates how every other onboarding fix reaches operators |
| **BTS-312** | Test-runner indirection — generic test-suite verb, per-spoke config dispatch | Smallest pattern-anchor; validates hub-spoke separation pattern |
| **BTS-313** | Linear provider activation — deterministic flow during `/ccanvil-init` | Implementation slice under 316 |
| **BTS-314** | Onboarding repair — Linear-config audit substrate + heal pass for 3 drifted nodes | Implementation slice under 316 |

**Three downstream nodes audited; same root cause confirmed across all:**

* **inbox-toolbox** — `routing.ticket = "linear"` (non-canonical key); `/idea` silently routes to local logging despite full Linear IDs being present; 3 ticket.transition ops stuck in `.ccanvil/ideas-pending.log` (operator's BTS-302 cutover ticket existed but was reframed as agent-driven recovery, NOT operator intent).
* **unifi-toolbox** — `routing.idea = "linear"` (correct key) but provider config has only `team`+`project` strings; missing team_id/project_id/state_ids\[8\]/label_ids; [linear-query.sh](<http://linear-query.sh>) dispatches non-zero on first call.
* **microsoft365-toolbox** — initialized 2026-05-05; `.claude/ccanvil.local.json` contains only `{"node_uuid":"..."}`; Linear not configured at all despite operator intent.

**Three different agent decisions from the same init flow** — root cause: no canonical interactive provider-selection step. This is BTS-316's framing.

**Operator-visible checkpoint reference incident:** during microsoft365-toolbox init, the operator's user-level `~/.claude/commands/ccanvil-init.md` (stale skill prose) referenced `.ccanvil/templates/checkpoint.md` (a path that's never existed in the hub). Hub canonical at `global-commands/ccanvil-init.md` is clean — the staleness is user-side, fixed by `/ccanvil-pull-globals --force`. Filed as BTS-315.

**Hub-side checkpoint sweep COMPLETE.** `legacy-refs-scan --respect-allowlist hub/tests/legacy-refs-allowlist.txt` returns `[]` (clean). Two real residues outside the scanner's regex were rectified locally (uncommitted; awaiting operator commit decision):

* `.claude/rules/workflow.md:62` — verb usage `Checkpoint` → `Run \`/stasis\`\` (propagates to spokes via /ccanvil-pull)
* `hub/tests/docs-check.bats:83/652/690/717` — 4 fixture heredoc titles `# Checkpoint` → `# Stasis` (cosmetic; substrate is title-agnostic)

**Verification:** docs-check.bats 72/72, stasis-recall.bats 47/47 (including AC-29 grep guard for stray refs outside allowlist). legacy-refs-scan still returns `[]` post-edit.

## Current State

* **Branch:** `main`. Working tree has **5-line residue cleanup uncommitted** (workflow.md + docs-check.bats — see Accomplished §Hub-side sweep).
* **Tests:** Targeted runs verified post-edit (docs-check 72/72, stasis-recall 47/47). Full suite NOT re-run this session (no implementation work; baseline 1992/1992 from session 21).
* **Build status:** clean.
* **Manifest coverage:** 189 / 189 (allowlist), drift 0.
* **Backlog:** 1 (BTS-247 carry-over) / **Triage:** 12 (BTS-247 + 5 captures from this session + 6 carry-forward including determinism candidates BTS-263/264/278) / **Icebox:** 2.

## Blocked On

Nothing (operator pause was for software update, not blocker).

## Next Steps

**Operator-flagged terminal directive:** "permanently capture everything that was discussed here so that the next time I open the session, we can get to work and do some really good work and hit the ground running." Stasis IS that capture. After /compact, /recall reads this snapshot + Linear backlog for cold start.

**Concrete next-session order:**

1. **Apply pending roadmap update** — three edits proposed but NOT yet applied to `docs/roadmap.md`. Operator should approve (`go` / `adjust` / `branch`):
   * **Edit A:** Mark Phase 2 Dark Code candidates as SHIPPED (Layer 3 deterministic ramp = BTS-265+266; query helpers = BTS-270; cohesion graph = BTS-269; plus substrate-perf chain BTS-277/281/282/293/296).
   * **Edit B:** Add new section `## Up Next — Onboarding & Hub/Spoke Separation (uncommitted; staged 2026-05-05)` enumerating BTS-312/313/314/315/316 with strategic frame.
   * **Edit C:** Demote "Next Theme — Direction" personality-packs entry one heading level so onboarding-hardening sits as a peer candidate to it.
2. **Commit residue + roadmap update** — proposed bundle: `chore: roadmap update + checkpoint→stasis residue cleanup` direct-to-main with `ALLOW_MAIN=1` (no logic changes; drift-guard tests are the safety net).
3. **Run** `/idea triage` — promote 12 untriaged to Backlog with priorities. Recommended: BTS-315=P1 (urgent gate), BTS-316=P2 umbrella, BTS-312=P2 pattern-anchor, BTS-313=P3, BTS-314=P3 (fold under 316).
4. **Theme rollover decision** — Dark Code Phase 2 effectively complete. Two competing directions for next theme:
   * **Onboarding hardening / hub-spoke separation** (this session's captures; operator-bite-frequency rated; multiplicative leverage per onboarding)
   * **"Simplicity through leverage" / personality packs** (existing roadmap direction, line 75-97; exploration-rated)
   * Recommendation: onboarding hardening — the bites are concrete; packs are speculation.
5. **Spec the lead-in** — once theme committed, start with `/spec BTS-315` (smallest, gates everything else) or `/spec BTS-312` (smallest pattern-anchor). Both are 1-PR scope.

**Carry-over:**

* `.ccanvil/ideas-pending.log` in inbox-toolbox has 3 stuck transitions (BTS-275/285/297). Drainable when LINEAR_API_KEY is sourced. Cosmetic — Linear ticket states slightly out of sync with code reality.

## Context Notes

* **Inbox-toolbox is the best-case downstream node.** 8 PRs through full lifecycle, manifest substrate intact, 410/411 vitest passing. The "issues" the operator remembered are working-as-substrate-permits, not failures. Operator's BTS-302 (their own cutover ticket) is the spoke-side framing of what BTS-316 fixes hub-side.
* **Operator-corrected interpretation of inbox-toolbox routing.** I initially read `routing.ticket = "linear"` as intentional partial-state pending BTS-302. Operator clarified: this was an **agent's stochastic decision during init**, not operator intent. The cutover-ticket framing was the spoke-agent's recovery plan, not a deliberate phasing. Same root cause as unifi-toolbox + microsoft365-toolbox: no canonical activation flow.
* **Provider-selection at init is the meta-pattern.** Three nodes, three different agent decisions, same init flow → "agents make provider decisions stochastically because no canonical activation flow exists" (BTS-316 problem statement). This is a HUB/SPOKE CONTRACT GAP, not three separate bugs.
* **Test-runner indirection precedent already exists.** `.claude/skills/tdd/SKILL.md:64` uses `$TEST_COMMAND` env var pattern. The bats hardcoding in [pr.md/stasis.md/ccanvil-audit.md](<http://pr.md/stasis.md/ccanvil-audit.md>) is the gap; the PATTERN is already canonical. BTS-312 is propagation, not invention.
* **Hub canonical IS clean for legacy-refs.** The operator's concern about residual checkpoint references was triggered by user-level skill staleness (BTS-315), not hub residue. The scanner returns `[]`. The two cosmetic residues found (workflow.md verb + bats fixture titles) are outside the regex pattern; they're true legacy-leak surfaces but don't propagate behavior.
* **Auto-mode discipline held.** Per safety guidance, did NOT auto-commit the residue cleanup or the roadmap edit; surfaced both as proposals awaiting operator decision. Editing hub-managed files that propagate to spokes counts as "modifying shared production" per the safety boundary.
* **Time-pressured close.** Operator interrupted by forced software update. Stasis written without full bats re-run (no implementation work this session; targeted verification + baseline from session 21 sufficient).

## Determinism Review

* operations_reviewed: \~25 (10 captures × \~2 ops each + sweep + verification + composition)
* candidates_found: 0

No candidates this session. The work was capture + investigation + verification — operations were already deterministic substrate calls ([operations.sh](<http://operations.sh>) resolve, [docs-check.sh](<http://docs-check.sh>) subcommands, jq filters, grep, git). No stochastic-orchestration patterns surfaced.

## Evidence Gaps

No evidence gaps this session.

## Manifest Coverage

189 / 189 (allowlist), drift incidents: 0

## Cross-Session Patterns

* **CONFIRMED RECURRING (5 sessions of Dark Code era + this one): substrate-driven discovery loops compound across sessions.** This session's captures (BTS-312/313/314/315/316) are the natural follow-on after Dark Code Phase 2 closure — substrate maturity surfaces the next gap-cluster. Same pattern as BTS-282 → BTS-281 → BTS-293 → BTS-296 chain in Session 21.
* **NEW PATTERN: cross-node audit reveals stochastic agent-decision divergence.** Three downstream nodes audited this session, three different agent-driven config divergences from the same init flow. Provides concrete evidence that "interactive operator decision points must be substrate-encoded, not left to agent interpretation." This is the BTS-316 thesis.
* **No legacy-refs surfaces.** legacy-refs-scan returns `[]`.
* **No recurring determinism candidates** (none flagged this session; carry-forward BTS-263/264/278 still in Triage from prior sessions).

## Security Review

* **Session diffs touched only:** `.claude/rules/workflow.md` (1 line, prose), `hub/tests/docs-check.bats` (4 lines, fixture heredoc title swap). NO secrets, NO PII, NO credentials.
* [security-audit.sh](<http://security-audit.sh>) found 8 PII/email findings — all pre-existing in committed files (`hub/meta/operations.md` absolute-path artifacts, `docs/sessions/`/`docs/specs/` historical archives). None introduced this session.
* Verdict: **PASS**.

## Memory Candidates

* **NEW PROJECT MEMORY candidate** — `project_onboarding_hardening_theme_emerging` — Five captures (BTS-312/313/314/315/316) staged 2026-05-05 reveal a hub/spoke separation theme as the natural Dark Code follow-on. Operator-bite-frequency rated. Decision pending at next theme rollover.
* **NEW FEEDBACK candidate** — `feedback_provider_decisions_must_be_substrate_encoded` — When init exposes operator decision points (provider selection, test-runner choice, secrets verification), the substrate must encode them as deterministic flow steps. Without this, agents make stochastic choices that diverge across sessions. Three-node audit (inbox/unifi/microsoft365-toolbox) is the empirical anchor. Why: operator's "very critical" framing of init-onboarding gaps confirms this is a load-bearing invariant.
* **NEW FEEDBACK candidate** — `feedback_strategic_capture_via_umbrella_plus_slices` — When multiple captures share a root cause, capture the umbrella separately (as a strategic anchor) and link the implementation slices via Family sections. Triage then has both: the strategic decision (umbrella) and the concrete first-ship (smallest slice). Validated this session: BTS-316 umbrella + BTS-312/313/314/315 slices.
* **REINFORCE** — `feedback_research_before_architectural_commit` — operator's question "tell me about inbox-toolbox" surfaced the operator-corrected interpretation that reframed the entire BTS-316 problem statement. Investigation BEFORE capture is load-bearing.