# Stasis

> Feature: session-2026-04-28-manifest-rollout-s4-s7-shipped
> Kind: session
> Last updated: 1777435731
> Session: 14
> Boundary: 2026-04-28T15:37:03-07:00
> Session objective: Ship manifest rollout Sessions 4–7 ([ccanvil-sync.sh](<http://ccanvil-sync.sh>) sync-core, [ccanvil-sync.sh](<http://ccanvil-sync.sh>) stack+registry, [linear-query.sh](<http://linear-query.sh>), small mega-scripts batch). Allowlist 59 → 134. After this ship, every ccanvil shell substrate primitive is manifest-covered.

## Accomplished

* **Four rollout sessions shipped in one conversation.** BTS-243 + BTS-244 + BTS-245 + BTS-246 squash-merged via `/ship`. Each followed full lifecycle: capture → /spec → /activate → batched manifests → per-batch validate-fix-commit → /pr → /ship.
* **BTS-243 (PR #142) — **[**ccanvil-sync.sh**](<http://ccanvil-sync.sh>)** sync-core cluster.** 22 cmd\_\* across 5 batches: init+status (5), diff/hash/merge (5), track/classify/pre-check (3), pull cluster (4), push+promote/demote (5). Allowlist 59 → 81. Drift 0.
* **BTS-244 (PR #143) — **[**ccanvil-sync.sh**](<http://ccanvil-sync.sh>)** stack + registry cluster.** 21 cmd\_\* across 5 batches: lockfile primitives (5), scan/migrate/register/relocate (4), stasis-migration + registry/events (3), broadcast + globals (3), stacks + drift-watchdog (6). Allowlist 81 → 102. Drift 0. `ccanvil-sync.sh` is now 100% manifest-covered (43/43 cmd\_\*).
* **BTS-245 (PR #144) — **[**linear-query.sh**](<http://linear-query.sh>)** GraphQL wrappers.** 16 cmd\_\* across 5 batches: viewer + simple listings (5), issue ops + project/doc listings (3), issue mutations (2), document core (3), document mutations (3). Allowlist 102 → 118. Drift 0. `linear-query.sh` is now 100% manifest-covered (16/16 cmd\_\*).
* **BTS-246 (PR #145) — small mega-scripts batch.** 16 cmd\_\* across 3 batches: [permissions-audit.sh](<http://permissions-audit.sh>) (6), [manifest-check.sh](<http://manifest-check.sh>) (7), [operations.sh](<http://operations.sh>) + [context-budget.sh](<http://context-budget.sh>) (3). Allowlist 118 → 134. Drift 0. **All ccanvil shell scripts in** `.ccanvil/scripts/*.sh` are now 100% manifest-covered. Natural rollout pause point.
* **BTS-247 captured.** Operator-driven investigation: `context-budget.sh` model registry (lines 193-203) is missing claude-opus-4-7. Discovered the registry is dead code under current caller patterns (none of `/stasis`, `/radar`, `/ccanvil-pull`, `/ccanvil-audit` pass `--model`). Three forks documented: delete the registry, wire callers to pass --model, or replace with JSON config. Operator triage decides direction.

## Current State

* **Branch:** `main`, fast-forwarded to origin (`0233a65`). Working tree clean.
* **Tests:** **1923 / 1923 passing.** Net delta: 1923 → 1923 (coverage-only ships, no new tests this conversation).
* **Uncommitted changes:** none.
* **Build status:** clean.
* **Manifest coverage: 134 / 134, drift 0** (\~73% of 184-unit codebase; 100% of shell substrate).
* **Backlog: 0 / Triage: 1** (BTS-247) **/ Icebox: 2** (BTS-22 + BTS-21).

## Blocked On

Nothing.

## Next Steps

Per `docs/manifest-rollout.md`, the rollout is now 7/11 sessions complete. Remaining:

1. **Triage BTS-247** — operator decision on [context-budget.sh](<http://context-budget.sh>) model registry (delete vs wire vs JSON config). Cleanest fork is delete; recommendation in body.
2. **Session 8 — File-level shell + hooks** (5 single-purpose scripts + 12 hooks = 17 file-level manifests). Different shape from cmd\_\* — uses path-only allowlist entries. Worth a fresh pattern read before batching.
3. **Session 9 — Markdown skills + rules** (16 frontmatter manifests). YAML frontmatter `manifest:` block per BTS-240 substrate.
4. **Session 10 — Markdown agents + commands** (21 frontmatter manifests).
5. **Session 11 — Layer 3 ramp + close-out** (manifest-aware `/review` integration).

## Context Notes

* **Compounding velocity at substrate maturity.** Four sessions in one conversation. Each session ran tighter than the last as drift-guard taught the operator (and Claude) the canonical caller-resolution rules. Sessions 4 and 5 had 4–5 drift cycles per session; Sessions 6 and 7 each had 1–2. Substrate compounds quality discipline — confirmed across 7 consecutive sessions now.
* **Caller-resolution gotcha sweep.** Persistent failure modes encountered + corrected this conversation: skill:/ name resolves only when `.claude/skills/<name>/SKILL.md` OR `.claude/commands/<name>.md` references the verb word; non-`.claude/` skills (e.g. `global-commands/ccanvil-init.md`) need path-form callers; some primitives are dispatch-only and need NO caller declaration; cross-script callers reference the helper function name (e.g. `_complete_archive_linear`), not the file path; `pure-no-mutations` declarations still require an inline marker; bare-name function deps need word-boundary grep proof.
* **Caller form for global-commands/.** Discovered while shipping BTS-243: `ccanvil-init` lives at `global-commands/ccanvil-init.md`, NOT in `.claude/`. The caller resolver's skill:/ form only checks `.claude/skills/<name>/SKILL.md` or `.claude/commands/<name>.md`. Path-form `global-commands/ccanvil-init.md` resolves correctly (the resolver greps it directly). All cmd_init / cmd_init_preflight / cmd_init_apply / cmd_retrofit_check / cmd_stack_list / cmd_stack_apply manifests use this path form.
* **Linear-query failure-mode pattern.** Every cmd\_\* in [linear-query.sh](<http://linear-query.sh>) shares the same exit/error contract: missing-api-key (exit 2 from \_require_api_key), unknown-flag (exit 2 via \_die 2), graphql-or-http-error (exit 3 from \_post_graphql). The shared shape lets manifests be consistent across the 16 wrappers; only mutations declared additional side-effects (creates-or-updates-issue-on-linear, creates-issue-relation, etc.).
* **Operator question turned investigation.** BTS-247 is a great example of "what is the value of this code?" producing real evidence rather than speculation. The investigation revealed the model registry has been dead code since adoption — none of the active callers pass `--model`. The non-model parts (file measurement, 80-line [CLAUDE.md](<http://CLAUDE.md>) threshold, HEALTHY/WARNING/CRITICAL envelope) are still load-bearing. Documented three forks (delete / wire / JSON config) for triage.
* [**Manifest-rollout.md**](<http://Manifest-rollout.md>)** inventory.** This stasis is the canonical update point per the doc's continuity hooks. Coverage progression: 7 (BTS-239) → 11 → 35 → 59 → 81 → 102 → 118 → 134. Next milestone: Session 8 → 151. Final: Session 11 → 184 + Layer 3.

## Determinism Review

* operations_reviewed: \~250 (4 sessions × 3-5 batches × \~12 manifest-edit ops + per-batch validate-fix-commit cycles)
* candidates_found: 0
* No candidates this session. The rollout work is structured coverage expansion using BTS-239 + BTS-240 substrate. Each batch is read-function → compose-manifest → add-markers → validate-fix-commit. The validate-fix-commit loop IS deterministic; the read-and-compose step is irreducible Claude judgment (semantic accuracy of declared contracts). Drift-guard catches every quality issue structurally — recovery is seconds. No new operations identified that should become deterministic.

## Evidence Gaps

No evidence gaps this session.

## Manifest Coverage

134 / 134 (allowlist), drift incidents: 0

## Cross-Session Patterns

* **CONFIRMED RECURRING (Sessions 4-7 of Dark Code era): drift-guard-as-quality-substrate.** The substrate compounds quality discipline across sessions — pattern recognition of phantom-callers, missing-markers, depends-on validity sharpens monotonically. 9th consecutive session-class with this pattern (Sessions 9-13 prior, now 14).
* **CONFIRMED RECURRING: substrate-on-substrate compounds across phases.** BTS-239 enabled BTS-240; BTS-240 enabled BTS-241/242/243/244/245/246. Each session's manifests describe THEMSELVES (cmd_pull_apply's manifest references its own callers + dependencies; cmd_save_issue's manifest enumerates BTS-228's relation-create follow-up). Self-describing systems describing their own substrate, now at 134/134.
* **NEW (this conversation): operator-led investigation surfaces dead code.** BTS-247 came from the operator asking "what does this do, and is it still necessary?" The act of writing a manifest for cmd_check (BTS-246) didn't catch it — declared the --model flag input as documented. Only the operator's 4.7-missing observation forced the investigation. Lesson: manifests document INTENT (what was the contract supposed to be), not USAGE (what the contract actually delivers). Dead-code discovery still requires usage-side analysis.
* **No legacy-refs surfaces.** `legacy-refs-scan` returned `[]`.
* **Manifest coverage growth: 59 → 81 → 102 → 118 → 134 over four shipments.** Compounding shape: 75 manifests added in one conversation (vs 52 in the prior 3-session conversation). Pace acceleration as substrate maturity compounds.

## Security Review

* **All ship work was inline manifest declarations + minor failure-mode/side-effect markers** — no new auth surfaces, no new secrets paths.
* `ccanvil-sync.sh` extension: pure declarations + markers, no behavior changes.
* `linear-query.sh` extension: pure declarations + markers, no GraphQL wrapper changes.
* `permissions-audit.sh` / `manifest-check.sh` / `operations.sh` / `context-budget.sh` extensions: same shape, no body changes.
* No secrets introduced. No new API surfaces. Production security-audit pre-existing findings unchanged.
* **Verdict: PASS.**

## Memory Candidates

* **NEW MEMORY CANDIDATE:** `feedback_manifests_document_intent_not_usage` — Manifests declare what each primitive's contract IS (input/output/failure modes per the substrate's own definition). They do NOT verify the contract is currently exercised. Dead-code discovery (e.g., BTS-247 — [context-budget.sh](<http://context-budget.sh>) model registry never invoked) still requires usage-side analysis: greppin' callers, checking which flags they actually pass. Manifests + drift-guard catch CONTRACT regressions structurally; dead-code discovery is a different layer. Worth saving as feedback to inform future audit work and avoid over-trusting manifests as a "is this used?" oracle.
* **NEW MEMORY CANDIDATE:** `feedback_caller_resolution_path_form_for_non_dotclause_skills` — Substrates outside `.claude/skills/` and `.claude/commands/` (e.g., `global-commands/ccanvil-init.md`) cannot use `skill:/<name>` caller form — the resolver only searches those two dirs. Use bare path form (`global-commands/ccanvil-init.md`) for path-aware callers; the resolver's BTS-240 path-form branch handles them. Save as feedback to short-circuit the drift-cycle next time someone declares a global-commands/ caller.
* **REINFORCE:** `feedback_drift_guard_compounds_quality_across_sessions` — confirmed across 4 more sessions in this conversation. Pattern recognition tightened monotonically; drift cycles per session went from 4-5 (Sessions 4-5) to 1-2 (Sessions 6-7).
* **No new external references** this session.