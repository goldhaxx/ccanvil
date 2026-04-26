# Stasis

> Feature: session-2026-04-26-backlog-annihilation-batch-1
> Kind: session
> Last updated: 1777166000
> Session objective: backlog annihilation mode — ship as many priority-3 items from the Linear backlog as the substrate sustains, push the count toward zero.

## Accomplished

**Six tickets shipped in one session, all squash-merged + auto-closed via the BTS-128/164 substrate:**

- **BTS-166 (High, PR #81).** Phase 2 Linear API substrate migration — `idea.{add,list,triage,review-icebox}` resolver verbs migrated from MCP to http. `linear-query.sh save-issue` gained `--input-json -` (stdin-JSON merge) and name-based create flags (`--team`/`--project`/`--labels` with internal NAME→ID resolution via new `list-teams` + `list-projects` subcommands). `/idea` skill prose rewritten to dispatch via `eval` of the resolved command — no MCP indirection on the linear capture/list/triage paths. Closes the BTS-164 substrate seam: bash callers can now capture/list ideas without going through Claude. 35 new tests across `linear-query.bats` + `operations-resolve-http.bats` + drift-guards.
- **BTS-154 (Low→Normal, PR #82).** Bash control-flow keyword classifier exemption. `permissions-audit.sh` `check_danger` now short-circuits to REVIEWED (with built-in rationale "bash control-flow keyword (BTS-154 grammar exemption)") for `Bash(<keyword>)` and `Bash(<keyword>:*)` shapes across the 16 POSIX shell reserved words. Word-anchored to prevent substring auto-exemption. Eliminates the false-positive review noise pattern documented in BTS-149's accept_danger entry for `Bash(done)`. 7 AC tests.
- **BTS-152 (Normal, PR #83).** Per-finding security-audit allowlist. Extended `.security-audit-allowlist` to support `<file>::<category>::<detail-substring>` triples while preserving file-only entries. Pipe-guard added to internal delimiter; load-time validation rejects malformed triples (≠3 segments) and pipes in any segment. Tightened the `.claude/settings.json` entry from coarse file-only to a triple targeting only `pii` findings matching `Read(//Users/`. 11 AC tests; history scan triple-gap documented.
- **BTS-159 (Normal, PR #84).** `permissions-audit.sh decision-append` substrate. Replaces the per-row Write+cat+rm dance in `/permissions-review` (4 tool calls per decision → 1) with a typed-flag invocation that validates against the same pre-flight schema as `apply --decisions` and atomically appends one jq-emitted JSON line. `/permissions-review` skill prose rewritten to use it. 13 AC tests.
- **BTS-168 (Normal, PR #85).** Gitignore Claude Code's `/loop`/`/schedule` artifacts (`.claude/scheduled_tasks*`). Documented the boundary: ccanvil does not provide a durable cron substrate; recurring work belongs in Linear. Closed the 3-stasis recurring observation that had drifted across multiple sessions. 4 AC tests using `git check-ignore` (the right primitive — porcelain output collapses untracked dirs).
- **BTS-115 (Normal, PR #86).** `/stasis` dual-captures determinism candidates as Linear ideas. After writing the Determinism Review section, each candidate is captured (when Linear-routed and `candidates_found > 0`) via the BTS-166 http substrate with title `Determinism: <slug>`. Dedup by exact title match against the existing idea list; pending-log fallback on capture failure. Local-routed projects: no-op. 2 drift-guard tests.

Bookended by:

- `/recall` + `/radar` — clean post-compact briefing; 0 untriaged ideas, 10 backlog items at start (now 5 after the 6 ships).
- `/idea` capture for BTS-168 (cron-machinery) before specing it — closing the 3-stasis carry-over the same way the substrate is supposed to be used.

Cumulative pattern count: ~36+ tickets shipped. Six consecutive ships in one session.

## Current State

- **Branch:** `main` at `149965e`, in sync with origin/main.
- **Tests:** **1276 / 1276 green** via `bats-report.sh --parallel`.
- **Uncommitted changes:** none.
- **Build status:** clean.
- **Active spec:** none — between features.
- **Permissions audit:** `danger=0`, `promote-review.total=0`. Clean.
- **Linear:** 0 in Triage, 5 in Backlog (was 10 at session start; six ships including one same-session capture-then-ship).
- **Context budget:** WARNING — 6642 / 8000 (83%). Crept up slightly from prior stasis (was 81.3%). Not blocking; settings.json (1417) + tdd.md (1151) + CLAUDE.md (966) remain heavy hitters. Stack distribution work is the right lever to move it.

## Blocked On

- Nothing. Six ships clean; auto-mode through `/stasis` ready for `/compact` and resume.

## Next Steps

Backlog annihilation mode continues next session. **Remaining priority-3 backlog items (target zero):**

1. **BTS-161** — `permissions-audit.sh entry-context` substrate. Sibling of BTS-159; same skill (`/permissions-review`); different stochastic pattern (per-row context rendering). Moderate complexity — needs hook introspection (parse guard-*.sh files for matched rules) + git log archeology (find introduction commit per permission). Plan to scope down at spec time: ship the deterministic spine (file/permission/pattern fields from existing JSON contract) first; defer the "matched_hooks" archeology if needed.
2. **BTS-162** — `/idea --parent` + `capture-from-context`. Two-part proposal in the ticket; biggest remaining item. Could ship Part 1 (`--parent` flag) tight and defer Part 2 to a follow-up.
3. **BTS-116** — `broadcast-resolve-auto`: algorithmic ccanvil.json conflict resolution. Untouched scope; need to read the ticket cold next session.
4. **BTS-150** (P4, investigation-only) — could be closed with a documentation entry rather than a code change. Read the ticket; if a doc-update is sufficient, ship it as a 10-minute close.

After backlog reaches zero on the priority-3 tier, drop to priority-4 (BTS-125 MCP truncation wrapper, BTS-150 if not already closed) — these are smaller-leverage items, but counted toward the zero target.

**Backlog total currently: 5 items. Realistic single-session pace: 4-6 ships at this substrate maturity.** One more session at this velocity should clear or near-clear the priority-3 tier.

## Context Notes

- **Six consecutive `feat → review → fix → pr → land` cycles in one session.** Pattern continues to scale with the substrate. Each ticket landed in ~30-45 min including code review (skipped /review on the trivial gitignore + skill-prose-only ships, kept it on the substrate-changing ones). Total session wall time: ~4 hours.
- **Auto mode held throughout.** The "go" / "keep going" / "yes" pattern from the user kept the loop tight; no friction at lifecycle boundaries.
- **Same-session capture-then-ship.** BTS-168 was captured via `/idea` AND shipped in the same session — the cron-machinery 3-stasis carry-over closed in <30 minutes from idea-create to land. This is what the BTS-128/164/166 substrate enables: capture → triage-via-promote → spec → activate → TDD → review → pr → merge → land → auto-close runs as a smooth pipeline.
- **Code review hit rate.** 4 of the 6 tickets ran /review; concerns were caught and fixed in each:
  - BTS-166: 3 CONCERN + 2 NIT (label-scoping, empty-string guard, structural assertion, comment, apostrophe regression)
  - BTS-154: 3 CONCERN + 1 NIT (REVIEWED classification, AC-7 test, fixture realignment, status-guard tightening)
  - BTS-152: 3 CONCERN (pipe guard, segment-count test, bats version)
  - BTS-159: 3 NIT (drift-guard pattern accuracy, comment accuracy, missing-buffer test)
  - BTS-168 + BTS-115: skipped /review (gitignore + skill-prose-only diffs).
  Reviewer continues to earn its keep — every review found a real defect or coverage gap.
- **BTS-115's dual-capture is in effect on this very stasis.** The `/stasis` skill prose now captures determinism candidates as Linear ideas. The "Determinism Review" section below is the first stasis to test that path live.
- **Substrate compounding.** BTS-166's http substrate (shipped first this session) made every subsequent ship's interactions with Linear faster and cheaper. The `linear-query.sh get-issue BTS-X` calls during ticket-scope-investigation were direct, no MCP roundtrip overhead.
- **Workspace fence false-positives during the session.** The `//` jq alternative-default operator (`.priority // null`) tripped `guard-workspace.sh`'s path scan twice — known quirk of using `//` in shell with the workspace fence. Workaround: write to tmpfile then jq-process, avoiding inline `//` in command tokens. Worth a follow-up ticket if it recurs once more (currently a 2-instance pattern).

## Determinism Review

- **operations_reviewed:** ~25 (6 ticket lifecycles × ~4 lifecycle ops each, plus permissions checks, recall, radar, idea triage).
- **candidates_found:** 1.

- **Workspace-fence `//` false-positive.** The `guard-workspace.sh` path scan tokenizes commands and treats any token starting with `/` as an absolute-path candidate. The `//` jq alternative-default operator (`.priority // null`, `// "?"`) is a literal token starting with `/` — the fence flags it as outside-workspace and blocks the command. Hit twice this session; workaround was either tmpfile-then-process or restructuring the jq filter to use `if/then/else` syntax. Should be either (a) a guard-workspace exemption for `//` standalone tokens, or (b) a jq-style path tokenizer that excludes the `//` operator. Captured for the BTS-115 dual-capture system to surface as a Linear idea.

## Permissions Review Pending (BTS-149)

Section omitted — `danger=0`, `promote-review.total=0`. No candidates pending.

## Cross-Session Patterns

- **CONFIRMED RECURRING (now CLOSED): Cron-machinery durability gap.** Flagged in three consecutive prior stases. Captured this session as BTS-168, shipped in the same session. Pattern: when a recurring observation accumulates across 3+ stases without becoming a Linear ticket, ticket-and-ship within the next session is the right move (BTS-115 will now capture this kind of drift automatically going forward).
- **CONFIRMED RECURRING: Workspace-fence false-positives on `//` tokens.** Hit twice this session (during list-issues + during reviewing failures); not yet captured as a ticket. If it surfaces a third time next session, that's the trigger to ticket-and-ship.
- **CONFIRMED: legacy-refs-scan stays clean** (0 matches with allowlist). BTS-132 mechanism continues to hold.
- **CONFIRMED: dogfood-close cultural invariant.** All six tickets closed via the BTS-128/164 substrate. Auto-close fired on every `land`.
- **CONFIRMED: code-review CRITICAL/CONCERN hit rate.** Four reviews this session, each caught real defects (label-scoping, classification semantics, allowlist pipe corruption, drift-guard accuracy). Hub-layer changes continue to benefit from /review even when the diff looks small.
- **CONFIRMED RECURRING: shape-gate / narrative-string false-positive cascade.** Already in memory. Hit again this session via the workspace fence + `//` tokens (a different facet of the same meta-pattern — regex-based fences over string content). The cascade pattern is worth treating as a meta-rule when adding new path/shape gates.

## Security Review

- **Six ships, all hub-layer changes.** No new attack surface introduced.
- BTS-152 added per-finding allowlist machinery; the new code path validates input at load time (rejects pipes, malformed triples, empty file-substring) and uses `jq -n --arg` for safe construction. No injection surface.
- BTS-166 stdin-JSON path uses jq for all escaping; tested round-trip across special characters (newline, quotes, backticks, `$VAR`, multi-byte UTF-8). No data-loss path.
- BTS-159 decision-append validates against the same schema as `apply --decisions`; round-trip test (AC-7) confirms zero validation drift between writer and reader.
- BTS-115 capture path uses the BTS-166 substrate (already audited).
- `security-audit.sh --files-only`: PASS (with the new tightened triple entry for `.claude/settings.json::pii::Read(//Users/`).
- Verdict: **PASS**.

## Memory Candidates

- **NEW project memory candidate: backlog annihilation cadence works.** The substrate (BTS-128/164/166/167) plus auto-mode plus discipline around skipping /review on trivial diffs sustains 6 ships in 4 hours. Worth memorizing as evidence that "annihilation mode" is achievable on this stack. Capture as a project memory: `project_backlog_annihilation_validated.md` — references the six tickets and the substrate that enabled the cadence.
- **NEW feedback memory candidate: skip /review on trivial diffs.** Skipped /review on BTS-168 (gitignore + 4-test bats file) and BTS-115 (skill-prose + rule-prose only). Both shipped clean. The decision criterion: if the diff has no logic changes (only prose or single-line config), drift-guard tests are sufficient; full /review is overhead. Worth capturing if it recurs as a deliberate pattern next session.
- **Reinforce: capture-then-ship-same-session pattern.** BTS-168 went idea → spec → ship in <30 min once the ticket was captured. The path is live. Worth surfacing in radar/recall briefings.

Memories to save in this stasis: yes — both candidates above are non-obvious and validated by this session's evidence.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
