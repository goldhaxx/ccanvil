# Implementation Plan: SSOT-Linear — route specs/plans/stasis to Linear Documents

> Feature: bts-204-ssot-linear
> Work: linear:BTS-204
> Created: 1777261768
> Spec hash: d80b9020
> Based on: docs/spec.md

## Objective

Route lifecycle artifacts (spec/plan/stasis) to Linear Documents via the existing operations resolver pattern, preserving local-routed flow unchanged. Substrate-first: build the document substrate and routing layer before touching any skill, then migrate skills phase-by-phase, with concurrent-edit safety + migration tool last.

## Sequence

Each step is one red-green-refactor cycle. Steps are grouped into phases that can ship as separate PRs if scope pressure demands; default is one cohesive PR.

---

### Phase 1 — Document substrate (linear-query.sh)

#### Step 1: `resolve-document-id` deterministic UUID
- **Test:** `linear-query.sh resolve-document-id --kind spec --ticket BTS-204` returns the same uuid5 across two invocations; differs from `--kind plan --ticket BTS-204`.
- **Implement:** Add `cmd_resolve_document_id` with `BTS_NS` namespace UUID constant. Pure compute, no API call.
- **Files:** `.ccanvil/scripts/linear-query.sh`, `hub/tests/ssot-linear.bats` (new).
- **Verify:** Two invocations produce identical UUIDs; per-kind/per-ticket pairs are unique.

#### Step 2: `get-document` — read by id-or-slug
- **Test:** Stub-mode (LINEAR_QUERY_ENDPOINT pointing to fixture) returns `{id, title, content, updatedAt, updatedBy, project, issue}`.
- **Implement:** GraphQL query `document(id: String!) { ... }`. Mirror `get-issue` shape.
- **Files:** `linear-query.sh`, bats fixtures.
- **Verify:** Stub fixture round-trip; ticket reference list-issues fixture pattern.

#### Step 3: `save-document` — create-or-update via `--input-json -`
- **Test:** Stub responds to `documentCreate` for body without `id`, `documentUpdate` for body with `id`. Both round-trip title + content.
- **Implement:** Auto-detect create vs update by `id` field presence in JSON input. Handle both `documentCreate` and `documentUpdate` mutations. Pass `parentId` (issueId or projectId) on create.
- **Files:** `linear-query.sh`.
- **Verify:** Create path emits `documentCreate`; update path emits `documentUpdate`; both return `{id, title, updatedAt, content}`.

#### Step 4: `document-updated-at` cheap projection
- **Test:** Returns `{id, updatedAt, updatedBy}` only — drift-guard verifies projection size for rate-limit hygiene.
- **Implement:** Minimal GraphQL projection.
- **Files:** `linear-query.sh`.
- **Verify:** Stub returns the three fields; no extras.

#### Step 5: `trash-document`, `list-documents`, `document-history`
- **Test:** trash flips `trashed:true`; list filters by `--project` or `--issue`; history returns content snapshots.
- **Implement:** Three mutations/queries; reuse the existing http machinery.
- **Files:** `linear-query.sh`.
- **Verify:** Stub fixtures for each.

---

### Phase 2 — Routing extension (operations.sh)

#### Step 6: Routing schema accepts spec/plan/stasis keys
- **Test:** `operations.sh resolve spec.read --project-dir <fx-linear>` returns `mechanism: "http"`; same call against `<fx-local>` returns `mechanism: "bash"`. Default (no key) → bash.
- **Implement:** Extend the routing-config reader to honor three new keys. Update spec.read/spec.write/plan.read/plan.write/stasis.read/stasis.write resolvers to branch on route.
- **Files:** `operations.sh`.
- **Verify:** bats fixture pair (linear-routed and local-routed); both resolve verbs return correct mechanism.

#### Step 7: http-mechanism resolver bodies for the six verbs
- **Test:** `operations.sh resolve spec.read --feature BTS-204` (http path) returns an `.invocation.command` that, when eval'd against stub, fetches the spec Document content.
- **Implement:** Compose `linear-query.sh get-document` / `save-document` invocations with proper input-json shape.
- **Files:** `operations.sh`.
- **Verify:** Round-trip via stub: write content via spec.write, read back via spec.read, content matches.

---

### Phase 3 — Lifecycle-state storage abstraction

#### Step 8: `_artifact_present?` helper in lifecycle-state
- **Test:** State derivation with `routing.spec="linear"` correctly reports `state: "spec-activated"` when the Linear Document has content, even when no `docs/spec.md` exists locally.
- **Implement:** Introduce a single helper that reads `integrations.routing.<kind>` once per primitive invocation, branches truthmaker. Refactor existing presence checks through it.
- **Files:** `docs-check.sh` (`cmd_lifecycle_state` and helpers).
- **Verify:** Existing local-routed tests pass unchanged (1622 baseline); new linear-routed test transitions correctly.

---

### Phase 4 — Skill migration (provider-aware dispatch)

#### Step 9: /spec skill dispatches through resolved verb
- **Test:** Drift-guard: skill prose calls `operations.sh resolve spec.write` and eval's the result, NOT a hardcoded `Write docs/specs/<id>.md` step.
- **Implement:** Update `.claude/skills/spec/SKILL.md` to write through `spec.write`. Local route maps to today's file write; http route maps to `save-document`.
- **Files:** `.claude/skills/spec/SKILL.md`, drift-guard test.
- **Verify:** Local-routed /spec produces a file (existing behavior); linear-routed /spec produces a Document via save-document (stub).

#### Step 10: /plan skill — same shape as Step 9
- **Test/Implement/Files/Verify:** Mirror Step 9 for `plan.write` and `plan.read`. The spec-hash drift-detection (existing stale-plan check) reads via `spec.read` so it works against either source.

#### Step 11: /stasis skill — feature-kind routes to issue-Document
- **Test:** Linear-routed feature-kind /stasis writes a Document with title `"Stasis: <BTS-N>"` parented to the feature's issue.
- **Implement:** Update stasis skill to dispatch via `stasis.write`. Resolve `--kind feature-stasis` parent via `linear-query.sh resolve-document-id`.
- **Files:** `.claude/skills/stasis/SKILL.md`.
- **Verify:** Stub round-trip on linear-routed fixture.

#### Step 12: /stasis skill — session-kind routes to project-Document
- **Test:** Linear-routed session-kind /stasis writes/updates a single Document titled `"Session State"` parented to the project (idempotent — re-running edits in place).
- **Implement:** Branch on stasis kind; session-kind resolves uuid5 with `--kind session-stasis --ticket project:<projectId>`. The same Document is rewritten each session.
- **Files:** `.claude/skills/stasis/SKILL.md`.
- **Verify:** Two consecutive session-stasis writes produce one Document with the latest content; cross-session history preserved in `docs/sessions/` (BTS-22 unchanged).

#### Step 13: /recall skill — read via resolved verbs
- **Test:** Linear-routed /recall reads spec/plan/stasis via http; local-routed /recall reads files. Briefing output identical for equivalent state.
- **Implement:** Dispatch all reads through resolved verbs.
- **Files:** `.claude/skills/recall/SKILL.md`.
- **Verify:** Side-by-side diff of briefings on parallel fixtures.

---

### Phase 5 — Archive at /complete + PR body embed

#### Step 14: `cmd_complete` archives spec + plan in addition to stasis
- **Test:** On Linear-routed node, `complete <feature-id>` writes `docs/sessions/<epoch>-<feature-id>-spec.md` and `-plan.md` alongside the existing `-stasis.md` (BTS-22). Trashes the Linear Documents after archiving.
- **Implement:** Extend `cmd_complete` (and the underlying `archive-stasis` pattern) to emit three archives. Then issue `trash-document` for each.
- **Files:** `docs-check.sh`.
- **Verify:** Archive files exist with correct content; Linear Documents marked `trashed:true` in stub.

#### Step 15: /pr embeds spec excerpt in PR body
- **Test:** On Linear-routed node, `gh pr create` body contains a fenced section with the spec content read via `spec.read`.
- **Implement:** Update `/pr` skill body-builder to fetch spec at PR-creation time and inline as a fenced markdown section.
- **Files:** `.claude/skills/pr/SKILL.md`.
- **Verify:** Stub round-trip → PR body contains the spec text.

---

### Phase 6 — Migration tool

#### Step 16: `docs-check.sh ssot-migrate --to linear` happy path
- **Test:** Fixture with active local `docs/spec.md` + `docs/plan.md`; running ssot-migrate creates Documents with the file contents, then removes the files. Re-running on partial state completes (idempotent).
- **Implement:** New `cmd_ssot_migrate`. Walk artifact set, for each: read local → save-document → verify echo → rm local. Idempotency via `get-document` pre-check.
- **Files:** `docs-check.sh`.
- **Verify:** Partial-failure replay completes cleanly; no double-creates.

#### Step 17: `docs-check.sh ssot-migrate --to local` reverse path
- **Test:** Fixture with Linear Documents but no local files; running ssot-migrate --to local materializes the files from Document content. Idempotent.
- **Implement:** Reverse direction of Step 16. Pulls Document content via `get-document`, writes to canonical local paths.
- **Files:** `docs-check.sh`.
- **Verify:** Files exist with correct content; Documents NOT trashed (operator may want to flip back).

---

### Phase 7 — Concurrent-edit safety + markdown round-trip cache

#### Step 18: document-cache.json read/write helpers
- **Test:** Cache persists `{<doc-id>: {updated_at, content_hash}}` across invocations. Atomic `mktemp + mv` write.
- **Implement:** New helpers in `docs-check.sh` (or sibling primitive). Cache lives at `.ccanvil/state/document-cache.json` (gitignored).
- **Files:** `docs-check.sh`, `.gitignore`.
- **Verify:** Two consecutive cache writes both readable; partial-write torn-state never observed.

#### Step 19: Pre-write updatedAt check refuses on divergence
- **Test:** Test fixture caches `updatedAt=T1`; stub returns `updatedAt=T2 > T1`; save-document attempt is refused with a structured error pointing to `document-history`. After the operator manually accepts the divergence (via flag or explicit re-fetch), write succeeds.
- **Implement:** Wrap `save-document` invocations in a pre-check that fetches `document-updated-at` and compares to cache. On divergence, exit non-zero with structured stderr.
- **Files:** Compound substrate (probably new `linear-doc-sync.sh` orchestrator).
- **Verify:** Refuse path emits the documented error; happy path writes cache after success.

#### Step 20: Cache Linear's returned content (markdown round-trip safety)
- **Test:** Write content `**A**\n` → Linear stub normalizes to `*A*\n` → next read should diff against `*A*\n`, not `**A**\n` (no phantom drift).
- **Implement:** After every successful write, store the response `content` in cache (BTS-125 generalization).
- **Files:** Same as Step 19.
- **Verify:** Round-trip diff is empty when no edit occurred; non-empty only when content actually changed.

#### Step 21: Linear-unreachable degraded mode (/recall only)
- **Test:** With Linear endpoint unreachable, /recall on a Linear-routed node falls back to reading the most recent `docs/sessions/<...>-spec.md` archive for the active branch and surfaces a clear "DEGRADED MODE" banner.
- **Implement:** In /recall skill, catch http resolution failures and check archive presence as a read-only fallback. Live-editing operations continue to fail-fast (no fallback).
- **Files:** `.claude/skills/recall/SKILL.md`.
- **Verify:** Stub-down test reproduces the degraded path; banner contains the fallback artifact path.

---

### Phase 8 — Documentation + drift-guards

#### Step 22: Update preset guides + skill prose
- **Test:** Drift-guard scans `.ccanvil/guide/` for stale references to `docs/spec.md`-as-canonical when SSOT is documented as the new model. Doc-only step.
- **Implement:** Update `.ccanvil/guide/command-reference.md`, `.ccanvil/guide/architecture.md` (or equivalent), and any skill prose that asserts file-only flow.
- **Files:** Multiple under `.ccanvil/guide/`, all six lifecycle skills.
- **Verify:** legacy-refs-scan passes; manual diff review.

#### Step 23: Full bats suite + /review
- **Test:** `bats-report.sh --parallel` returns 0; `/review` (code-reviewer + security-audit + self-review) emits no CRITICAL findings.
- **Implement:** Address WARN/INFO findings inline per `feedback_review_findings_need_why_it_matters.md`.
- **Files:** As required by review.
- **Verify:** Test count grew from 1622 baseline by the drift-guards added across Phases 1-7.

## Risks

- **Markdown round-trip lossiness (BTS-125 generalization).** Documented mitigation in AC-9 (cache returned content), drift-guarded in Step 20. Live-validation gate per `.claude/rules/tdd.md`: at least one Phase 1 step must run a live API call against a real Linear Document before commit, since stubs accept any markdown shape.
- **Concurrent-edit race window.** Application-side updatedAt check is not atomic with the write — a millisecond-window race remains. Acceptable for solo-operator use; flagged in spec as out-of-scope for this ship.
- **Lifecycle-state abstraction blast radius.** State-derivation logic touches many call paths in `cmd_lifecycle_state`. Step 8 isolates the change behind one helper; risk is regression in local-route behavior. Mitigation: existing tests must pass unchanged (Step 8 acceptance gate).
- **Migration tool partial state.** Network failure mid-migration leaves some artifacts on Linear and some locally. Idempotency (Step 16) is the recovery path — re-running completes the migration cleanly.
- **Document title required.** No empty-title Documents creatable. All artifact creation paths derive title from kind+ticket; Step 1's resolve-document-id must produce both id and title.
- **Phase pressure.** 23 steps spanning ~7 phases is large for one PR. If complexity compounds beyond ~Step 12, consider splitting Phases 1-3 (substrate) into PR-A and Phases 4-8 (skills + migration) into PR-B. Decision deferred until mid-implementation review.

## Definition of Done

- [ ] All 13 acceptance criteria from spec pass
- [ ] All 1622 existing tests still pass + new drift-guards added
- [ ] No type errors / shellcheck warnings on new scripts
- [ ] Live-validation gate satisfied: at least one Phase 1 step run against live Linear API before commit (per `.claude/rules/tdd.md` and `feedback_validate_plan_flagged_live_api.md`)
- [ ] /review (code-reviewer + security-audit + self-review) emits no CRITICAL findings; WARN/INFO addressed inline or captured as triage tickets with "why this matters" articulation per `feedback_review_findings_need_why_it_matters.md`
- [ ] PR body embeds spec excerpt (AC-11 manual verification)
- [ ] Documentation refreshed in `.ccanvil/guide/`

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
