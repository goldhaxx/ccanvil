# Plan: spec dispatch + activate concurrent-edit race fix

> Feature: bts-237-spec-activate-concurrent-edit-race
> Created: 1777341282
> Spec hash: 9acc05ff

## Strategy

Skip `_doc_cache_set_updated_at` on the CREATE path in `cmd_artifact_write`. Add `LINEAR_QUERY_OVERRIDE` support to the cmd_artifact_write callsites so tests can stub linear-query.sh responses (small testability refactor — no behavior change in live use; the env var simply lets tests substitute a script that returns canned values).

## TDD steps

### Step 1 — RED: failing tests for cache behavior

Create `hub/tests/artifact-write-concurrent-edit.bats` with:
- AC-2: stubbed linear-query.sh where `document-updated-at` returns FAIL the first time (signaling "doc doesn't exist") and SUCCESS with T2 the second time. First cmd_artifact_write call (CREATE) succeeds. Second call (UPDATE) does NOT trip pre-flight check (because cache wasn't populated by CREATE). Pre-fix: second call fails with `concurrent edit detected`.
- AC-3: after a successful UPDATE, cache file `.ccanvil/state/document-cache.json` contains entry for the doc_id with the response's updatedAt.
- AC-4: with cache populated (simulated direct call to `_doc_cache_set_updated_at`), and stubbed `document-updated-at` returning T2 > cached T1, cmd_artifact_write refuses with exit 4.
- Drift-guard: BTS-237 inline.

Run RED. Confirm AC-2 fails (current code caches after create), AC-3 passes (cache works on update — already does), AC-4 passes (existing behavior).

### Step 2 — Add LINEAR_QUERY_OVERRIDE to cmd_artifact_write

At the top of cmd_artifact_write, after arg parsing:

```bash
local lq="${LINEAR_QUERY_OVERRIDE:-$script_dir/linear-query.sh}"
```

Replace `bash "$script_dir/linear-query.sh"` calls inside cmd_artifact_write with `bash "$lq"` (lines ~5249, 5257, 5280, 5283, 5286).

Same for `_doc_concurrent_edit_check` at line 4955 — but since this helper is called from cmd_artifact_write, plumb the override via env (it's already `LINEAR_QUERY_OVERRIDE` — env var visibility is automatic in the process tree). Easier: add `local lq` at the top of `_doc_concurrent_edit_check` mirroring cmd_artifact_write's pattern.

### Step 3 — GREEN: skip cache after CREATE

Wrap the post-write `_doc_cache_set_updated_at` block in a conditional:

```bash
local was_create=0
local result
if bash "$lq" document-updated-at "$doc_id" >/dev/null 2>&1; then
  # Update path
  result=$(...)
else
  # Create path with caller-supplied UUID
  was_create=1
  result=$(... --create-with-id ...)
fi
echo "$result"
# BTS-237: skip cache on CREATE — caching the create-response timestamp
# produces a self-stale baseline that the very next UPDATE writer
# trips against. Subsequent UPDATEs cache normally.
if (( was_create == 0 )); then
  local new_ts
  new_ts=$(printf '%s' "$result" | jq -r '.updatedAt // empty')
  if [[ -n "$new_ts" ]]; then
    _doc_cache_set_updated_at "$doc_id" "$new_ts" "$project_dir"
  fi
fi
```

Run tests. Confirm GREEN. Run full suite — confirm 1837+4 = 1841 passing.

### Step 4 — Live-API gate (AC-5)

The very next `/spec` → activate run on this node MUST complete without `ALLOW_CONCURRENT_EDIT_OVERRIDE=1`. Test by:
- This ship's own activate already paid the cost (pre-fix) — that's expected.
- The NEXT ship after this one merges (the next small-ship in the drainage queue) will dogfood the fix on its activate. If it succeeds without the override, AC-5 is proven.

This is the live-API gate per `.claude/rules/tdd.md` — stub-only verification is necessary but not sufficient.

### Step 5 — commit, /pr-cleanup, /ship

## Affected files

- `.ccanvil/scripts/docs-check.sh` — three coordinated changes:
  1. Add `local lq=...` to cmd_artifact_write (testability).
  2. Replace bash invocations of linear-query.sh with `bash "$lq"`.
  3. Wrap post-write cache-set in `was_create == 0` conditional.
- `hub/tests/artifact-write-concurrent-edit.bats` — new file with 3 ACs + drift-guard.

## Risks

- **LINEAR_QUERY_OVERRIDE refactor scope creep:** the existing override pattern is per-function. cmd_artifact_write currently doesn't use it. Adding it here is a small, additive refactor — not changing live behavior, just making tests reachable. Low risk.
- **`_doc_concurrent_edit_check` independent path:** the helper at line 4949-4961 is called from cmd_artifact_write and elsewhere. If we plumb the override to it, the change touches all call sites. Mitigation: instead of adding a parameter, use `local lq="${LINEAR_QUERY_OVERRIDE:-...}"` at the top of the helper itself.
- **Cache-set unreachable on CREATE may break a future code path:** if any future caller relies on cache being populated after CREATE (e.g., a downstream pre-flight that expects T1 to be cached), it would break. Audit: no current callers rely on this. The cache is consumed only by `_doc_concurrent_edit_check`, which has the empty-cache → safe semantics.
- **Multi-actor concurrent CREATE (impossible by save-document --create-with-id contract):** Linear rejects duplicate UUIDs at the GraphQL level. Two simultaneous creates can't both succeed. No new race window introduced.
