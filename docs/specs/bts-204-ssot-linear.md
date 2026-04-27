# Feature: SSOT-Linear — route specs/plans/stasis to Linear Documents (provider-driven)

> Feature: bts-204-ssot-linear
> Work: linear:BTS-204
> Created: 1777261768
> Status: Complete

## Summary

Eliminate twin-source divergence between local lifecycle docs (`docs/spec.md`, `docs/plan.md`, `docs/stasis.md`, `docs/specs/<id>.md`) and Linear ticket bodies by routing each artifact type to Linear **Documents** (not Issue.description) when the project is configured to use Linear as the lifecycle SSOT. Provider-neutral at the verb layer: `spec.read/write`, `plan.read/write`, `stasis.read/write` resolve to `bash` (local file) or `http` (Linear Document) based on per-artifact routing config. Local-only nodes are unchanged; nodes can promote to Linear (or back) at any time via a one-shot migration tool.

## Job To Be Done

**When** I capture or evolve a feature's lifecycle artifacts (spec, plan, stasis) on a project where Linear is the configured lifecycle provider,
**I want to** have those artifacts live in exactly one canonical place — a Linear Document attached to the feature's ticket (or to the project, for session-stasis) — with provider routing decided per-artifact-type at the node level,
**So that** scope changes propagate by construction, the Linear ticket's `documents` connection becomes a complete record of the feature's intent + plan + progress, downstream nodes that start local can promote to Linear later without code changes, and any future provider can be added by implementing one resolver.

## Acceptance Criteria

Each criterion is independently testable. Binary pass/fail.

- [ ] **AC-1: Provider routing extended.** `integrations.routing` accepts new keys `spec`, `plan`, `stasis` with values `"linear" | "local"` (default `"local"` when absent). `operations.sh resolve <verb>` returns `mechanism: "http"` for Linear-routed artifacts and `mechanism: "bash"` for local — same pattern as the existing `idea` route.
- [ ] **AC-2: Local route preserved unchanged.** When all three keys are `"local"` or absent, `/spec /plan /stasis /recall /pr /land` operate identically to today against local files. No file paths change; no skill prose churns; existing tests pass without modification.
- [ ] **AC-3: linear-query.sh document family.** New subcommands `get-document`, `list-documents`, `save-document`, `trash-document`, `document-history`, `document-updated-at` follow the existing `save-issue` HTTP pattern (POST GraphQL, `--input-json -` for create/update, `--id <slug-or-uuid>` for read).
- [ ] **AC-4: Deterministic document IDs.** `linear-query.sh resolve-document-id --kind {spec|plan|feature-stasis|session-stasis} --ticket <BTS-N>` returns a stable uuid5 — no API call. Idempotency for create-or-update writes relies on this.
- [ ] **AC-5: Spec / Plan / Feature-stasis are issue-parented Documents.** One Document per ticket per kind, title `"<Kind>: <BTS-N>"`. /spec creates or updates the spec Document; /plan the plan Document; /stasis (feature-kind) the feature-stasis Document.
- [ ] **AC-6: Session-stasis is a project-parented Document.** Single evergreen Document per project, title `"Session State"`, edited in place each /stasis run. Cross-session history continues to live in `docs/sessions/` archives (BTS-22, unchanged).
- [ ] **AC-7: lifecycle-state abstracts over storage.** `docs-check.sh lifecycle-state` returns the same envelope shape regardless of routing. The truthmaker for "spec exists" / "plan exists" / "stasis exists" branches on the configured route — filesystem presence for local, Document existence-with-non-empty-content for Linear.
- [ ] **AC-8: Concurrent-edit safety.** Every Document write is preceded by an `updatedAt` check against a local cache (`.ccanvil/state/document-cache.json`). Divergence refuses the write and surfaces a `documentContentHistory` diff for operator resolution. After successful write, cache the returned `updatedAt`.
- [ ] **AC-9: Markdown round-trip cache.** After every successful Document write, ccanvil caches **Linear's returned `content`** (not the input markdown). Subsequent diffs use the normalized cache to avoid phantom drift from Yjs round-trip.
- [ ] **AC-10: Archive at /complete (extends BTS-22).** On Linear-routed nodes, `/complete` writes spec + plan + final stasis to `docs/sessions/<epoch>-<feature_id>-{spec,plan,stasis}.md`, then trashes the Linear Documents. Archive is forward-only; never read by live editing.
- [ ] **AC-11: PR body embed.** On Linear-routed nodes, `/pr` reads the canonical spec from the Linear Document at PR-creation time and embeds it as a fenced section in the PR body. One-time render — no sustained twin source.
- [ ] **AC-12: Migration tool — bidirectional + idempotent.** `docs-check.sh ssot-migrate --to {linear|local}` is a one-shot operator-triggered tool. `--to linear` walks active local lifecycle docs, creates corresponding Documents, removes locals on confirmation. `--to local` reverses. Idempotent — re-running on partial state completes the migration. Never auto-triggered.
- [ ] **AC-13: Linear unreachable on Linear-routed node.** Live-editing operations (/spec, /plan, /stasis, /recall) fail fast with a clear, actionable error naming the routing decision and recovery options. /recall enters degraded read-only mode using the most recent /complete archive when one exists for the active branch.

## Affected Files

| File | Change |
|------|--------|
| `.ccanvil/scripts/linear-query.sh` | New: 6 document subcommands |
| `.ccanvil/scripts/operations.sh` | Modified: spec.read/write, plan.read/write, stasis.read/write resolvers branch on routing config |
| `.ccanvil/scripts/docs-check.sh` | Modified: `lifecycle-state` storage abstraction; new `ssot-migrate` subcommand; `cmd_complete` writes spec+plan archives in addition to the existing stasis archive |
| `.claude/ccanvil.json` / `.claude/ccanvil.local.json` | Routing schema docs updated; defaults remain local |
| `.claude/skills/{spec,plan,stasis,recall,pr,land}/SKILL.md` | Modified: dispatch through resolved verbs instead of hardcoded file reads/writes |
| `.ccanvil/state/document-cache.json` | New (gitignored): updatedAt + normalized content cache for concurrent-edit safety |
| `hub/tests/ssot-linear.bats` | New: drift-guards for routing, document substrate, migration tool, concurrent-edit detection, archive-at-complete |

## Dependencies

- **Requires:** `linear-query.sh` http substrate (BTS-164), operations resolver (BTS-128), routing config schema (existing), BTS-22 archive pattern (existing), `lifecycle-state` primitive (BTS-20).
- **Blocked by:** Nothing.

## Out of Scope

- Replacing Linear with another provider in this ship. Provider-neutral verb contract is preserved; only the Linear http resolver is implemented. Notion / GitHub Projects / etc. are future work behind the same verb layer.
- Folder hierarchy for Documents. Linear's public API has no `parentDocumentId`; specs/plans/stasis are root Documents with one parent each (issue or project). No "specs/" subfolder pattern.
- Auto-migration on Linear config detection. Operator runs `ssot-migrate` explicitly.
- Multi-agent coordination, always-on orchestrator, or webhook-driven invalidation. Polling-on-write via `updatedAt` is sufficient for solo-operator use; multi-agent safety is a future ticket.
- Hard-deletion of trashed Documents. Linear's API only soft-deletes; vacuum is a future ops concern.
- Content search across spec Documents. `DocumentFilter` is title-only; client-side fetch+grep is the workaround until backlog scale demands otherwise.

## Implementation Notes

- Decompose into phases at /plan time: (1) Foundation — http resolvers + linear-query.sh document subcommands + lifecycle-state abstraction; (2) Spec routing end-to-end; (3) Plan + Feature-stasis routing; (4) Session-stasis Document; (5) Archive-at-complete + PR body embed; (6) Migration tool; (7) Concurrent-edit safety + markdown cache. Each phase is its own TDD cycle.
- Pattern for document subcommands mirrors `save-issue`: GraphQL mutation via `linear-query.sh`'s existing http machinery, JSON via `--input-json -` to dodge shell-injection on body content. BTS-125 markdown normalization caveat applies — Linear's Yjs round-trip mutates some constructs; cache the *returned* content.
- Caller-supplied UUID via `DocumentCreateInput.id` enables stable idempotent create-or-update without an extra read. uuid5 namespace constant should live in `linear-query.sh` as `BTS_NS=<uuid>`.
- `lifecycle-state` storage abstraction: introduce a `_artifact_present?(kind, route)` helper; `route` is read from `integrations.routing.<kind>` once per primitive invocation. Avoid scattering route checks across every state-derivation case.
- Concurrent-edit cache file is gitignored — not a twin source. It only memoizes "what Linear returned us last" to detect external edits before the next write.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
