# Feature: /stasis dual-captures determinism candidates as Linear ideas

> Feature: bts-115-stasis-captures-determinism-as-ideas
> Work: linear:BTS-115
> Created: 1777165172
> Status: In Progress

## Summary

Determinism candidates currently land in `docs/stasis.md`'s `## Determinism Review` section but never reach the shared backlog. They're invisible across sessions — to triage, prioritize, or even rediscover them, an operator has to grep prior stasis files. Linear ideas are the right surface for cross-session work. Amend the `/stasis` skill so each determinism candidate is simultaneously written to `docs/stasis.md` AND captured as a Linear idea via the BTS-166 http substrate. Dedup against existing ideas by title-slug match so recurring candidates don't multiply.

## Job To Be Done

**When** I run `/stasis` at the end of a session and the determinism review surfaces N candidates,
**I want to** have each candidate captured as a Linear idea (with dedup against prior captures),
**So that** the candidates are visible in `/idea triage`, `/radar`, and the cross-session backlog without me having to remember to capture them by hand.

## Acceptance Criteria

Each criterion is independently testable. Binary pass/fail.

- [ ] **AC-1:** `/stasis` skill prose contains a step (after the Determinism Review section is written) that, for each candidate, captures it as a Linear idea via the BTS-166 http substrate (`operations.sh resolve idea.add` + stdin-JSON). The step runs only when `candidates_found > 0` and only when the resolved provider is Linear (no-op on local-routed projects).
- [ ] **AC-2:** Title format is deterministic: `Determinism: <candidate-name>`. The `<candidate-name>` is the bolded operation name from the bullet (e.g., `chained git add+commit`) — slug-trimmed to ≤80 chars per `/idea`'s short-text fast path. Stable input → stable title (no Claude-generated variation across sessions for the same candidate).
- [ ] **AC-3:** Body format includes the bullet's full text (operation, what happened, deterministic replacement, impact) verbatim. The body provides enough context that the idea is actionable without the operator opening the originating stasis.
- [ ] **AC-4 (dedup):** Before capturing, the skill calls `operations.sh resolve idea.list` to enumerate existing ideas (label `idea`), filters locally by title prefix `Determinism:` and substring-match on the candidate slug. If any match, skip the capture (with a one-line note in the skill's stdout: `dedup: skipped <candidate> — existing idea <ID>`).
- [ ] **AC-5 (label):** Captured ideas land with the standard `idea` label (already enforced by `operations.sh resolve idea.add`'s emitted command). No additional label/tag plumbing required for v1.
- [ ] **AC-6 (failure modes):** Capture failure (network, missing `LINEAR_API_KEY`, GraphQL error) does NOT abort the stasis flow. Falls back to the existing pending-log path (`docs-check.sh idea-pending-append --op add ...`) so `/idea sync` replays it later. Stasis continues writing other sections and committing the snapshot.
- [ ] **AC-7 (no-candidates):** When the Determinism Review section reports "No candidates this session.", the capture step is a no-op — no Linear queries, no idea creation.
- [ ] **AC-8 (local provider):** On a local-routed project (no Linear), the capture step is a no-op. Determinism candidates still land in `docs/stasis.md` (existing behavior preserved); no errors.
- [ ] **AC-9 (drift-guard test):** A bats test asserts the `/stasis` skill prose contains the determinism-capture step (positive grep for the literal phrase `Determinism:` and a reference to `idea.add`).
- [ ] **AC-10 (rule update):** `.claude/rules/self-review.md` documents that flagged candidates are dual-captured by `/stasis` — operator doesn't need to manually `/idea` them.

## Affected Files

| File | Change |
|------|--------|
| `.claude/skills/stasis/SKILL.md` | Modified — add the capture step after the Determinism Review section description |
| `.claude/rules/self-review.md` | Modified — note the dual-capture behavior |
| `hub/tests/stasis-recall.bats` (or new file) | Modified — drift-guard test asserting skill prose contains the capture step |

## Dependencies

- **Requires:** BTS-166 substrate (`idea.add` http path, stdin-JSON capture). Shipped 2026-04-25.
- **Blocked by:** none.

## Out of Scope

- Building a `idea.find-by-title` resolver verb. The skill performs dedup via `idea.list` + local jq filtering — fewer moving parts than introducing a new substrate verb. Revisit if dedup latency surfaces as a real problem.
- Auto-converting "candidates_found" to a backlog priority. Captured ideas land in Triage; operator triages them later via `/idea triage`.
- Removing the `## Determinism Review` section from stasis. The section stays — stasis is the in-session record; Linear ideas are the cross-session backlog.
- Updating already-shipped `docs/stasis.md` files retroactively. The change applies to future stases only.

## Implementation Notes

- **Title slug derivation:** strip the markdown `**bold**` markers from the bullet's leading operation name; trim to first 80 chars; collapse whitespace. Stable across sessions because the operation name is the operator's chosen wording, not Claude's.
- **Dedup logic:** `operations.sh resolve idea.list` returns a JSON array. Filter via `jq '.[] | select(.title | startswith("Determinism: ") and contains("<slug>"))'`. If any element returned, skip; else capture.
- **Capture command:** mirror BTS-166 capture pattern from the `/idea` skill — resolve `idea.add`, build stdin-JSON via `jq -n --arg title --arg description`, eval `"$cmd --input-json -"`. On failure, call `docs-check.sh idea-pending-append --op add --title "$T" --body "$B"`.
- **No-op gates:** check `candidates_found` from the synthesis context AND check `operations.sh resolve idea.add | jq -r .provider` to decide whether to attempt capture. Skip silently on local-routed projects.
- **BTS-127 compliance:** any new `@test` with ≥2 `jq -e` assertions opens with `set -e`. Most assertions here are `grep -q` on skill prose, so BTS-127 may not apply broadly.
- **Family pattern:** matches the existing `/idea sync` and `/permissions-review` decision-append flows — substrate-via-resolver, agent-driven dispatch, pending-log fallback. No new patterns introduced.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
