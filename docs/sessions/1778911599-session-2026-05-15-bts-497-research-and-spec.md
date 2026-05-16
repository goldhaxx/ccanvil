# Stasis: session-2026-05-15-bts-497-research-and-spec

> Feature: session-2026-05-15-bts-497-research-and-spec
> Kind: session
> Last updated: 1778911599
> Session: 55
> Boundary: 2026-05-15T19:18:14-07:00
> Session objective: Take BTS-497 (test perf observability) end-to-end from research lap → 4-stream open-market deep-research scan → operator-decision (Path 2 full OTel stack) → spec drafted + dispatched to Linear → sub-issues captured for out-of-scope work → memory anchors saved so spec session inherits direction without re-deriving.

## Accomplished

Session 55 was a research-and-spec-shape session. No code commits, no /pr; the deliverable was the structural foundation for the next ship and the surrounding decision-set. Notable: this session validated BTS-496's layman-summary thesis in real-time — the operator explicitly approved the multi-day implementation direction on the strength of a single \~1,000-word layman overview, then asked that overview be preserved as a worked example on BTS-496.

* **BTS-497 research lap completed.** Four parallel deep-research agents scoured the OSS landscape independently and converged on the same answer: OpenTelemetry + Grafana LGTM stack as the runner-neutral, free, self-hostable architecture for persistent per-test telemetry + visualization. Full doc at `docs/research/test-performance-research.md` (\~30 KB, 11 sections — end-to-end inventory + terminology glossary + market scan + reference architecture + live snapshot).
* **Live --timings capture, first-ever per-test history preserved.** `.ccanvil/state/bts-497-timings-snapshot-1778897.json` (251 KB, 2,335 timed tests). Surfaced THE finding: one test (`drift-guard production allowlist clean` in `hub/tests/module-manifest-drift-guard.bats`) takes 329.6 s — 35% of serial-equivalent CPU. Single-handedly sets the parallel-12 wall-time floor at \~330 s; without it, suite wall would drop to \~80 s (\~6× win).
* **Operator-validated layman overview format.** Delivered as response to "I need a layman's overview of all of this." Operator response: "This landed perfectly. Gave me precisely the level of detail I needed to feel informed and have opinions on what we're doing here." Then approved Path 2 (full OTel stack) on the strength of that overview alone. Preserved verbatim on BTS-496 as a "Validated Example" section + saved as `feedback_layman_overview_format_validated` memory.
* **Path 2 decision locked: full OTel + Grafana LGTM stack** (operator declined Path 1 SQLite-first warm-up and Path 3 defer). Captured as `project_bts_497_path_2_decision` memory so spec session doesn't re-derive.
* **Five new Linear tickets captured (BTS-498 to BTS-502).** **BTS-498** — drift-guard optimization (independent ship, 4 mitigation paths enumerated, 5.5-min wall fix). **BTS-499** — Stage-2 distillation to downstream nodes via OTel exporters per-runner (pytest/vitest/jest/go/cargo). **BTS-500/501/502** — sub-issues of BTS-497 for the out-of-scope items (metrics layer Mimir/Prometheus, logs layer Loki + trace-to-log correlation, regression alert rules + dead-man-switch). All carry layman summaries per the BTS-496 thesis being dogfooded same-session.
* **BTS-497 spec drafted, dispatched, transitioned.** `docs/specs/bts-497-test-otel-stack.md` (12 ACs, 14 affected files, machine-agnostic AC-3, AC-11 surfaces parallelization in human stdout, standalone Grafana port 3001 per operator decision via AskUserQuestion). Linear Document `4e15e4ae-30cd-4170-8bc8-74dbc40aef68` carries the canonical body. BTS-497 auto-transitioned Triage → Todo.
* **Parallelization investigation closed.** M4 Max = 16 cores (12 perf + 4 efficiency). `--jobs 12` configured via `sysctl -n hw.perflevel0.physicalcpu` per BTS-277 benchmark 2026-05-02. 54 full-suite runs in `bats-runs.jsonl` all at jobs=12. Spec phrased machine-agnostic so AC-3 holds on Intel / Linux / CI runners (which fall back to `max(2, hw.logicalcpu/2)`).
* **Grafana deployment strategy: standalone on port 3001.** Operator-decision via AskUserQuestion preview comparison. ccanvil docker-compose ships its own Grafana so downstream-node distribution (BTS-499) has a turnkey stack. Operator's existing Grafana on port 3000 unaffected. \~150 MB RAM cost accepted. Tempo 3200, OTel Collector OTLP gRPC 4317, healthcheckv2 13133.
* **Six memory writes** so future sessions inherit context: `feedback_test_framework_two_paradigm`, `reference_test_observability_stack`, `feedback_layman_overview_format_validated`, `project_bts_497_path_2_decision`, `project_bts_497_spec_decisions`.

## Current State

* **Branch:** `main` (clean, fast-forwarded through `30e8948`)
* **Tests:** 2338 / 2338 PASS, wall 402 s, parallel-12 — last invocation 2026-05-15T23:22Z (the BTS-497 --timings live capture). NOT re-run for this stasis (no code changes since last full run; previous session's bats-runs.jsonl row is the canonical state).
* **Uncommitted changes:** none in tracked files. **Untracked artifacts ride with BTS-497 ship:** `docs/research/test-performance-research.md` (the research doc), `docs/specs/bts-497-test-otel-stack.md` (the spec — picked up at `/activate`), and `.ccanvil/state/bts-497-timings-snapshot-1778897.json` (the preserved timings — gitignored). Live `docs/stasis.md` is session 54's, also untracked (linear-routed; archive is the durable record).
* **Build status:** clean. Manifest 197/197, drift 0.
* **Backlog:** 41 Backlog-state + 9 Triage. Added this session: BTS-497 (Todo), BTS-498, BTS-499, BTS-500, BTS-501, BTS-502 (5 Triage). Removed: BTS-497 left Triage.

## Blocked On

Nothing technically. Two operator-decisions are queued for the next session:

1. Whether to run `/spec --review bts-497-test-otel-stack` (critic-mode pre-flight) before `/activate`.
2. Whether to commit `docs/research/test-performance-research.md` to main standalone now, vs ride with the BTS-497 PR.

## Next Steps

1. `/spec --review bts-497-test-otel-stack` (recommended) — critic-mode pass on the 12-AC infra spec catches semantic ambiguity that validate-spec missed. Spec is substantive (14 affected files, live-API risk, 159-file blast radius for the bats helper sourcing). One critic pass is well-spent here per `feedback_critic_mode_finds_real_findings_on_validated_specs`.
2. `/activate bts-497-test-otel-stack` — creates branch + draft PR, copies spec to `docs/spec.md`. After critic-mode passes OR if the operator chooses to skip.
3. **BTS-498 — drift-guard optimization** is an independent ship; could run in parallel with BTS-497 implementation or after. Highest single-test wall-time win in the suite (5.5 min → \~80s). Four mitigation paths in BTS-498 body.
4. `/idea triage` — 9 items in Triage. Five are this session's captures (BTS-498/499/500/501/502); four are older carry-forwards from session 52 (BTS-486/487/491 et al). Worth a triage pass before the next deep work session.
5. **Roadmap freshness** — Active theme on roadmap is still "Dark Code / Three-Layer Solution" but recent ships have all been Onboarding/Hub-Spoke (BTS-460/482/488/493/494) and the next theme is shaping up as **test observability** via BTS-497 cluster. Worth a roadmap re-anchor next session.

## Context Notes

* **The convergence of four parallel research streams on OpenTelemetry was the load-bearing signal of the session.** No external research stream was briefed to favor OTel; each was asked open-ended ("what's the OSS landscape for X"). They independently named the same components — `otel-cli` (bash), `junit2otlp` (XML bridge), Tempo (traces), Mimir/Prometheus (metrics), Grafana OSS (dashboards), Chrome Trace Event Format + perfetto.dev (one-off swimlanes). When four independent research lanes converge, that's the answer.
* **Stage 1 / Stage 2 framing is non-negotiable from this point.** Operator-explicit: "We are solving this problem first for ccanvil itself, as a project. But subsequently, we need to distill our learnings into a shareable test framework that can/will distribute down to node projects." Schema neutrality, runner-agnostic naming, dispatcher-as-abstraction-layer — all in `feedback_test_framework_two_paradigm`. Litmus for any Stage 1 decision: "would this work byte-identically if the runner were pytest?"
* **The BTS-496 thesis dogfood worked.** The session captured 5 new tickets (BTS-498/499/500/501/502) — every one carries a `## Layman summary` section because the operator validated the format mid-session. When the BTS-496 spec session opens, it has three concrete worked examples to study (the BTS-496 ticket body itself + the five new captures) — an unusually rich corpus.
* **AC structure choice: prose, not GWT markup.** validate-spec flagged `missing-given-when-then` (drift, non-blocking). Operator chose to leave natural prose ("Given X, when Y") rather than restructure to explicit `**Given:** / **When:** / **Then:**` markers. Each AC still binary/testable. Save for future spec validators: this is a stylistic decision, not a correctness issue.
* **Parallelization investigation revealed the spec's own machine-dependence.** Original AC-3 hardcoded "12 parallel jobs" — corrected to "N parallel jobs where N = resolved perf-core count." Anchored in BTS-277 benchmark (2026-05-02) that established jobs=12 as optimal on M4 Max (saves 1:14 vs jobs=8, no further gains past 12 — fork/IO bound at \~790% CPU). New AC-11 surfaces `parallel: jobs=N cpus=M wall=Ts` config line in human stdout — was previously only in `--json` mode and `bats-runs.jsonl`.
* **Standalone Grafana — operator decided via AskUserQuestion.** Considered three options: standalone port 3001, share-existing, hybrid. Operator picked standalone. Anchors: BTS-499 downstream distribution needs turnkey stack; dashboard provenance lives entirely in `.ccanvil/observability/`; \~150 MB RAM cost trivial on M4 Max. Lifecycle decoupled from any other project's Grafana.
* **Auto-mode classifier blocked the third concurrent-edit override on the spec Linear Document.** Correctly — three sequential force-writes during the same session should require operator authorization. Used AskUserQuestion to get explicit approval, then `ALLOW_CONCURRENT_EDIT_OVERRIDE=1` succeeded. Pattern: in long spec-iteration sessions on Linear-routed nodes, expect concurrent-edit gate to fire at the third+ write; pre-authorize via AskUserQuestion early.
* `--parent-id` **on** `linear-query.sh save-issue` **requires team-id (create mode), not just parent.** First three sub-issue capture attempts failed with `save-issue create requires --team-id`. Fix: route through `operations.sh resolve idea.add` instead — the resolver pre-injects team/project/labels; append `--parent-id` to the resolved command. Captured as a determinism candidate (see review below).

## Determinism Review

operations_reviewed: 18
candidates_found: 2

* **subissue-capture-via-idea-add-with-parent-id**: Claude needed to create three sub-issues parented to BTS-497. First attempt called `linear-query.sh save-issue --parent-id ... --input-json -` directly; failed because save-issue create mode requires `--team-id` (sub-issues are creates, not updates). Worked around by routing through `operations.sh resolve idea.add` (which pre-injects team/project/labels) and appending `--parent-id` to the resolved command. This is friction every time an agent needs to capture a child ticket — should be a dedicated verb `operations.sh resolve idea.add-sub --parent <BTS-N>` or a sub-issue flag on the existing `idea.add` resolver. Impact: medium — three sub-issues this session, will recur on any future sub-issue capture.
* **stasis-carry-forward-slug-fuzzy-matching**: The `stasis-carry-forward` primitive (BTS-232) does literal title-matching looking for `Determinism: <slug>`. Last session's bullet was bolded as `bidirectional-caller-graph-validation`, captured as BTS-495 titled `Determinism: helper-caller-list-auto-update` — semantically equivalent, lexically different. Primitive returns has_idea=false → recurring false-positive flag in /recall briefings. Either (a) extend matching to fuzzy/synonym slugs, or (b) require the captured idea's title to use the bolded-bullet slug verbatim. Impact: low-medium — flagged in last session's stasis review too; recurring noise rather than a bug.

## Evidence Gaps

No evidence gaps this session.

## Manifest Coverage

197 / 197 (allowlist), drift incidents: 0

## Cross-Session Patterns

Session 54 (BTS-493+494 ship + BTS-497 capture) → Session 55 (this: BTS-497 research lap → spec → sub-issues). The BTS-497 lifecycle continues across sessions per design — research-then-spec on separate session boundaries was the recommended pattern from session 54's stasis and was followed.

Recurring patterns:

* **stasis-carry-forward slug-matching false-positive** — same primitive false-positive flagged in session 54 (BTS-495 title doesn't match `Determinism: bidirectional-caller-graph-validation` slug). Now confirmed recurring across two consecutive sessions. Promoted to determinism candidate above this session.
* **layman-summary-on-captures** — emerged in session 54 (operator-stated need, captured as BTS-496), validated and applied this session (5 new captures all carry `## Layman summary`). The thesis is holding empirically.
* **auto-mode-classifier-blocks-multi-write-overrides** — first emerged session 54 on Linear ticket merge dispatches; recurred this session on artifact-write force-writes. Pattern: in long sessions with multi-write workflows on shared external state, expect the classifier to gate; pre-authorize via AskUserQuestion when the pattern is foreseeable. Worth a memory if it recurs a third time.

`legacy-refs-scan`: 19 hits — ALL inside `.ccanvil/state/bts-497-timings-snapshot-1778897.json` (the preserved bats `--timings` artifact). False-positives — the matches are bats test NAMES that contain `docs/checkpoint.md` and `/catchup` substrings, not active substrate refs. The file is gitignored (state dir); doesn't propagate. No action needed.

`audit-session`: 0 findings (no commits since last stasis; clean).

## Security Review

PASS. No code commits this session. The new artifacts (`docs/research/test-performance-research.md`, `docs/specs/bts-497-test-otel-stack.md`) and the 6 memory files were grep-checked for secret/PII patterns: no tokens, no API keys, no credentials, no email addresses outside the operator's own. The BTS-497 spec mentions `LINEAR_API_KEY` as an env-var name (zero risk) and `${CCANVIL_TELEMETRY_URL}` as a placeholder (zero risk). The 5 Linear sub-issues (BTS-498–502) inherited the same review (composed by Claude this session). Clean.

## Memory Candidates

* `feedback_test_framework_two_paradigm` — **saved.** Test-perf substrate serves 2 paradigms in order (ccanvil-self first, framework distillation second). Schema neutrality + runner-agnostic naming from Stage 1. Litmus: "byte-identical if pytest?"
* `reference_test_observability_stack` — **saved.** OSS components: otel-cli + junit2otlp + Tempo + Mimir + Grafana + Chrome Trace Event Format + perfetto.dev. bats worker-id via `PARALLEL_JOBSLOT`.
* `feedback_layman_overview_format_validated` — **saved.** Operator-validated format (\~1000 words prose, problem→discovery→desired→market→recommendation→tradeoffs→decision-request, conversational tone, explicit 3-path close). Validating instance on BTS-496.
* `project_bts_497_path_2_decision` — **saved.** Operator picked Path 2 (full OTel stack). Spec session inherits direction.
* `project_bts_497_spec_decisions` — **saved.** Standalone Grafana port 3001, machine-agnostic AC-3, AC-11 surfaces config in stdout, prose AC structure, sub-issue chain (BTS-500/501/502).
* `auto-mode-classifier-multi-write-pattern` — **candidate.** Pattern is becoming recurring (sessions 54 + 55). Worth a memory if it fires a third time. Hold for now; promote on next occurrence.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->