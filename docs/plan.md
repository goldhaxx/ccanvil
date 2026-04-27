# Implementation Plan: Batch-read in _complete_archive_linear

> Feature: bts-214-complete-archive-batch-read
> Work: linear:BTS-214
> Created: 1777269303
> Spec hash: 36f86e5f
> Based on: docs/spec.md

## Objective

Cut `/complete`'s Linear-routed read fan-out from 3 calls to 1 by adding
`--with-content` to `list-documents` and refactoring `_complete_archive_linear`
to a single batch read + N targeted trashes.

## Sequence

### Step 1: AC-1 RED — `list-documents --with-content` includes content

- **Test:** `hub/tests/ssot-linear.bats`. Stub returns
  `documents.nodes[0].content = "# stub content"`. Drive
  `linear-query.sh list-documents --issue X --with-content` and assert the
  parsed JSON's first node has `.content == "# stub content"`.
- **Implement:** None yet — confirm test fails with current code.
- **Files:** Test only.
- **Verify:** Test red.

### Step 2: AC-1 GREEN — add `--with-content` flag

- **Implement:** `cmd_list_documents`: parse `--with-content` flag; when
  set, augment the GraphQL query to select `content` and include it in
  the jq projection. When unset, the projection stays exactly as today.
- **Files:** `.ccanvil/scripts/linear-query.sh`.
- **Verify:** Step 1 test passes.

### Step 3: AC-1 backward-compat drift-guard

- **Test:** `list-documents` without `--with-content` returns nodes shaped
  exactly `{id, title, slugId, updatedAt, createdAt}` — no `content` key
  present (asserted via `jq -e '.[0] | has("content") | not'`).
- **Implement:** Already correct from Step 2 (flag-gated).
- **Verify:** Test green.

### Step 4: AC-2 RED — _complete_archive_linear call-count drops to 1+N

- **Test:** Multi-stub fixture counts curl invocations. Run
  `cmd_complete` against a Linear-routed fx with all 3 kinds present.
  Stub responds:
  - call 1 (list-documents): returns 3 nodes (spec, plan, feature-stasis)
    each with content + their deterministic UUIDs.
  - calls 2-4 (trash-document each): success.
  - call 5+: fail-loud.
  Assert: total invocations == 4 AND archive files exist.
- **Implement:** None — current code makes 6 calls (3 get + 3 trash) so
  this test fails today.
- **Verify:** Test red (or current test "Phase 5 Step 14" updated to
  this expectation, with the legacy test removed since the contract
  changes).

### Step 5: AC-2 GREEN — refactor _complete_archive_linear

- **Implement:** Replace the per-kind `get-document` loop with:
  1. Resolve issue UUID once via existing `get-issue` call (already
     happens in `cmd_artifact_write`; here the issue lookup is needed
     once for the list-documents `--issue` filter).
  2. Call `list-documents --issue <uuid> --with-content`.
  3. For each kind in {spec, plan, feature-stasis}: derive the
     expected Document UUID via `resolve-document-id`; look it up in
     the list response by id-equality; if found, write to
     `docs/sessions/<epoch>-<feat>-<kind>.md` and `trash-document <id>`.
- **Files:** `.ccanvil/scripts/docs-check.sh` (`_complete_archive_linear`).
- **Verify:** Step 4 test passes; existing BTS-204 Phase 5 Step 14 test
  passes (with stub adapted to the new call shape).

### Step 6: AC-4 missing-kind tolerance

- **Test:** Stub returns only spec in list-documents (no plan, no
  stasis). Run cmd_complete. Assert: only 1 trash call; only
  `<feat>-spec.md` archive present; no errors logged for plan/stasis.
- **Verify:** Already correct from Step 5 implementation (loop skips
  unmatched kinds); test locks the contract.

### Step 7: AC-5 UUID-match drift-guard

- **Test:** Stub returns 3 documents with **wrong titles** (e.g.,
  "Random Title 1") but **correct deterministic UUIDs**. Assert: archive
  files written for all 3 kinds — title-prefix heuristic isn't relied
  on; UUID equality drives the match.
- **Verify:** Already correct from Step 5; test locks the contract.

### Step 8: AC-6 error fall-through

- **Test:** Stub returns GraphQL error on the list-documents call. Run
  cmd_complete. Assert: cmd_complete exits 0 (the local cleanup +
  status flip succeeds); WARN on stderr; no archive files created.
- **Implement:** `_complete_archive_linear` catches non-zero exit from
  `linear-query.sh list-documents` and emits
  `WARN: list-documents failed; archive step skipped` on stderr, then
  returns 0. The outer `cmd_complete` continues unchanged.

### Step 9: AC-7 local-route fast-path regression

- **Test:** Already covered by existing `BTS-204 Step 8: lifecycle-state
  without any 'linear' routing skips Linear entirely`-style fail-loud-curl
  test. Add a parallel test for `cmd_complete` on a local fx: confirm
  `_has_any_linear_route` returns false → archive helper not invoked →
  curl never fired.

### Step 10: Update command-reference

- **Implement:** `list-documents` entry gains the `--with-content`
  flag in `.ccanvil/guide/command-reference.md`.

### Step 11: Live-validation gate

- **Test:** Manual `linear-query.sh list-documents --issue <real-uuid>
  --with-content` against `api.linear.app/graphql` to confirm:
  - Response includes `content` field.
  - GraphQL query is well-formed (no Linear schema rejection).
- **Verify:** Run once with `LINEAR_API_KEY` set; trash any test artifacts.
  Per `.claude/rules/tdd.md#live-api-validation-gate` — list-documents'
  `content` projection is a NEW field on a known query, so a stub-only
  pass would miss schema-rejection contract bugs.

## Risks

- **Linear rate-limit on `list-documents`** — content adds payload size.
  Mitigation: `--issue` filter limits result to ≤3 docs per query;
  payload stays small.
- **Schema field name mismatch** — Linear's Document content field is
  `content` (string). Mitigation: live-validation gate (Step 11).
- **Existing BTS-204 Phase 5 Step 14 test stub adaptation** — its
  one-shot stub responds the same to every call. After refactor, the
  call shape is different. Mitigation: rewrite that test's stub as a
  call-count-aware multi-response (same pattern as Step 4 test).

## Definition of Done

- [ ] All 7 acceptance criteria pass
- [ ] Total tests: 1692 → ~1700 (≥6 new BTS-214 drift-guards), all green
- [ ] Live-validation gate confirms `content` field projection
- [ ] /review pass with no CRITICAL findings

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
