# Feature: Batch-read in _complete_archive_linear (6→4 API calls)

> Feature: bts-214-complete-archive-batch-read
> Work: linear:BTS-214
> Created: 1777269303
> Status: In Progress

## Summary

Cut `/complete` Linear-routed latency by replacing the 3 sequential
`get-document` calls inside `_complete_archive_linear` with one
`list-documents --issue <issueId> --with-content` call. The 3 `trash-document`
mutations stay serial (Linear's GraphQL doesn't expose mutation batching).
Net: 4 API calls instead of 6 per `/complete`. Same archive output bytes;
zero behavior change on local-routed nodes.

## Job To Be Done

**When** I run `/complete` (or `/pr`'s `pr-cleanup`) on a Linear-routed node,
**I want** the archive step to fan out fewer serial Linear API calls,
**So that** the cleanup phase doesn't add ~600ms of avoidable network time per shipped feature.

## Acceptance Criteria

- [ ] **AC-1:** `linear-query.sh list-documents` accepts a new optional
      `--with-content` flag. When set, the GraphQL projection includes the
      `content` field on each Document; the JSON shape gains a `content`
      key per node. Without the flag, the existing shape (`{id, title,
      slugId, updatedAt, createdAt}`) is byte-identical.
- [ ] **AC-2:** `_complete_archive_linear` makes exactly 1 read API call
      regardless of how many lifecycle artifact kinds are routed to Linear.
      Verified via stub-counter assertion: a `/complete` flow on a fixture
      with all three kinds (spec/plan/stasis) routed to Linear and all
      three Documents present results in 4 curl invocations total
      (1 list + 3 trash), not 6.
- [ ] **AC-3:** When `_complete_archive_linear` runs against the existing
      stub fixture (BTS-204 Phase 5 Step 14), the resulting archive files
      under `docs/sessions/<epoch>-<feat>-{spec,plan,stasis}.md` have the
      same content bytes as before the refactor (modulo the per-run epoch
      timestamp in the filename).
- [ ] **AC-4 (missing-kind):** When only a subset of the 3 kinds has a
      Linear Document (e.g., only spec exists), the list-documents result
      contains 1 item; the archive loop iterates 1 time and trashes 1
      Document. No errors raised for the absent kinds.
- [ ] **AC-5 (filter robustness):** Documents in the list-documents
      response are matched to kinds by **deterministic UUID equality**
      (the `resolve-document-id` derived UUID), NOT by title prefix. This
      makes the matcher robust against operator-renamed Document titles.
- [ ] **AC-6 (error):** When `list-documents --issue` returns a non-200
      response or a GraphQL error, `_complete_archive_linear` exits with a
      WARN on stderr and the local archive step is skipped. The local
      `cmd_complete` flow (status flip, lifecycle-doc removal, commit)
      still completes. This preserves BTS-204's "Linear-failure-never-blocks-/complete"
      contract.
- [ ] **AC-7 (local-route no-op):** On pure-local nodes (no
      `routing.spec=linear` etc.) `_complete_archive_linear` is never
      invoked — the existing `_has_any_linear_route` fast-path gate is
      preserved. Stub-fail-loud regression test: curl is never invoked on
      local-routed `/complete`.

## Affected Files

| File | Change |
|------|--------|
| `.ccanvil/scripts/linear-query.sh` | `cmd_list_documents`: add `--with-content` flag |
| `.ccanvil/scripts/docs-check.sh` | `_complete_archive_linear`: refactor to 1 list-documents + N trash |
| `hub/tests/ssot-linear.bats` | New BTS-214 drift-guards (AC-1/2/3/4/5/6/7) |
| `.ccanvil/guide/command-reference.md` | Update `list-documents` entry for `--with-content` |

## Dependencies

- **Requires:** BTS-204 substrate (`list-documents`, `_has_any_linear_route`,
  `resolve-document-id`, `_complete_archive_linear`) — already shipped.

## Out of Scope

- Bulk-trash via batch GraphQL — Linear's API doesn't expose mutation batching.
- Parallelizing the 3 `trash-document` mutations via background bash jobs —
  separate concern (introduces ordering / partial-failure complexity).
- Wider use of `list-documents --with-content` outside `_complete_archive_linear`
  — keep this ship narrow; other callers can adopt later if useful.

## Implementation Notes

- The deterministic-UUID matcher: for each kind in {spec, plan,
  feature-stasis}, derive the expected Document UUID via
  `resolve-document-id --kind <k> --ticket <feat>`, then look up that
  UUID in the list-documents response. Constant-time match per kind; no
  string-prefix heuristics.
- AC-6 fall-through: same shape as the existing fall-through inside
  `cmd_complete` — the function returns silently with a stderr WARN; the
  caller's `git commit` and PR-ready steps are unaffected.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
