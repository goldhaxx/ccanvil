# Stasis

> Feature: session-2026-04-24-tooling-correctness-batch-ship
> Kind: session
> Last updated: 1777074519
> Session objective: Ship the BTS-133/134/135 tooling-correctness trio queued by prior stasis. Stretched to 6 ships when BTS-141 (deterministic spec-stamping) was captured AND closed mid-session, plus BTS-123 (pending-log integrity) and BTS-117 (remote-presence primitive).

## Accomplished

- **6 features shipped end-to-end this session** plus 2 ideas captured (BTS-141 → shipped same session; BTS-142 → in Triage). Sequenced: BTS-133 → BTS-134 → mid-session capture of BTS-141 → BTS-141 → BTS-135 → BTS-123 → BTS-117. Single-session capture-then-ship loop validated for the first time.
  - **PR #59 / BTS-133** — `cmd_audit_session` emits real `file:line` from git diff hunks. Bug: `local line_num=""` inside the loop body reset the var every iteration, throwing away the hunk header. Fix: hoist `current_line` to function scope, anchor from `@@`, increment per `+` line. 7 bats cases (single-line, multi-hunk, multi-file, commit-message backward-compat, empty diff, numeric-field guard).
  - **PR #60 / BTS-134** — `permissions-audit.sh check` JSON contract. Adds explicit `--json` flag and an `emit_error_envelope` helper that wraps the two `exit 2` paths (missing settings, corrupt log) so stdout is valid JSON `{error, exit}` regardless of exit code. 8 bats cases.
  - **PR #62 / BTS-141** — deterministic spec-epoch stamping. New `docs-check.sh stamp-spec <feature_id>` replaces the inline `date +%s` + sed pattern that silently failed mid-BTS-134 (literal `$stamp` landed in the spec frontmatter). `/spec` SKILL.md step 8 now writes a `PLACEHOLDER` and calls the primitive. 8 bats cases. Self-validated: BTS-123 / BTS-117 specs both used `stamp-spec` cleanly.
  - **PR #61 / BTS-135** — `context-budget.sh check` TTY-aware default + explicit `--json` flag. Tri-state: empty → resolve via `[[ -t 1 ]]` after arg parsing. Pipes/redirects get JSON; humans get text. Standard CLI convention. 8 bats cases.
  - **PR #63 / BTS-123** — pending-log fallback integrity. Two new primitives: `idea-pending-append` covers all 6 ops (add/promote/defer/dismiss/merge/ticket.transition) via `jq -nc`; `idea-pending-validate` counts JSON objects (NOT lines) and reports parseability. `/idea` SKILL.md updated — both fallback paths call the helper, legacy `echo '{"op":...}' >> log` snippets gone. 11 bats cases (lossless body round-tripping with quotes/backticks/dollars/emoji, per-op shape, validator).
  - **PR #64 / BTS-117** — `remote-presence` primitive. Probes origin presence: emits `{has_origin, url, git_repo}` JSON regardless of state. Always exits 0 — callers branch on `has_origin`, not status. 7 bats cases (with origin, without, non-repo, multi-remote, default cwd).
- **18 consecutive dogfood-closes** as of session end: BTS-128 → 119 → 122 → 127 → 118 → 129 → 113 → 138 → 139 → 132 → 137 → 136 → 133 → 134 → 135 → 141 → 123 → 117. Cultural invariant maintained — every primitive-introducing ship closes its driving ticket via the primitive.
- **Test suite grew 975 → 1024** (+49 across 6 ships: 7 audit-line + 8 permissions-json + 8 stamp-spec + 8 context-tty + 11 idea-pending + 7 remote-presence). Full suite green at every phase.
- **2 ideas captured.** BTS-141 (deterministic spec-stamping) was a determinism-first capture in response to a real failure mid-BTS-134; promoted from Triage → Todo → Done in the same session — a first. BTS-142 (permissions-log workflow: gitignore vs commit + audit the 28 DANGER) sits in Triage awaiting Zach's process decision.

## Current State

- **Branch:** `main` at `78be6f8` (post-BTS-117 merge, FF'd via `/land`).
- **Tests:** **1024 / 1024 green** via `bats-report.sh --parallel`.
- **Uncommitted changes:** none (working tree clean).
- **Build status:** clean.
- **Context budget:** WARNING at 74.9% (5989/8000). **Unchanged** from prior session. Six ships didn't move the budget — none of them edited the always-loaded files (CLAUDE.md, .claude/rules/*, settings.json, .claudeignore). Confirms that script + skill-prose work has zero context cost at session start.
- **Permissions audit:** 28 DANGER + 171 UNREVIEWED + 0 REVIEWED. **Same as session start** (we ran `init` mid-session to materialize the stub log, then deleted it pending the BTS-142 workflow decision — the audit results pre/post are identical because no rationale was added).
- **Specs archive:** **61 Complete** (was 55 entering session; +6: 133, 134, 141, 135, 123, 117). Linear backlog: ~6 items remaining.

## Blocked On

- **BTS-142 needs Zach's decision: should `.claude/permissions-log.json` be gitignored (per-node local state) or committed (team-shared review provenance)?** Either way, the underlying audit work — review the 28 DANGER + 171 UNREVIEWED entries and write rationales — is a deliberate human pass, not an autonomous ship.

## Next Steps

1. **Triage BTS-142** (permissions-log workflow + audit). Likely splits into a fast process/docs ticket and a slower audit pass.
2. **Ship the recurring `cmd_activate --auto-push-main` candidate.** This is now the SECOND consecutive stasis flagging "N redundant `git push origin main` invocations per spec-on-main commit" (4 last session, 6 this session). Small surface: `cmd_activate` accepts `--push-main-first` (or simply auto-pushes if main is ahead and HEAD ≡ origin/main is impossible because of the unpushed commits). Promote to must-ship next session.
3. **BTS-115** (determinism candidates → captured as ideas, not memories) — the process meta-fix. This session was actually a partial dogfood of the principle (BTS-141 was captured as a Linear idea mid-session, not just stored as a memory). Codify in skill prose / rules.
4. **BTS-125** (Linear `save_issue` markdown truncation) — P4 finisher; needs reproduction.
5. **BTS-72** (`/merge` for local-only repos) — bigger scope; activate when ready.
6. **BTS-116** (broadcast-resolve-auto algorithmic conflict resolution) — judgment-call work.
7. **BTS-22** (Docs directory strategy) — research-level horizon item.

## Context Notes

- **Trust-but-verify on file mutations is the lesson the user reinforced.** Mid-BTS-134, I ran `stamp=$(date +%s) && sed -i '' "s/.../$stamp/"` and the variable didn't expand — `$stamp` literal landed in the spec frontmatter. The identical-shape command worked seconds earlier for BTS-133. I cannot deterministically explain why one expansion succeeded and the next failed. Zach caught it ("are we certain we want to put a $stamp in there?"). The deeper lesson — captured as BTS-141 and shipped same-session — was that any computable derivation surviving in skill prose as "Claude does X then Y" is a future bug. The fix moves the derivation into a script primitive with no inter-step shell-variable interpolation.
- **The same-session capture→ship pattern for determinism candidates is now validated.** BTS-141 went idea (Triage) → Todo → In Progress → Done in roughly an hour, prevented by the spec → activate → TDD → /pr → merge → /land cycle staying tight. This is the template for "we just hit a bug that proves a determinism-first principle — fix the principle in code, not memory" workflow. BTS-115 should formalize this in skill prose.
- **`docs-check.sh stamp-spec` self-validated immediately.** Used cleanly for BTS-123 and BTS-117 specs after shipping. JSON envelope `{feature_id, stamped_epoch, file}` makes downstream consumption straightforward.
- **`idea-pending-append` covers all six op types in one helper.** Slightly more surface than the smallest possible fix, but matches the existing dispatch table 1:1 — refactor cost is zero now, integration cost would be high if added piecemeal.
- **TTY-aware default mode** for `context-budget.sh` is the right shape for any future stdout-mode question. Tri-state default (`""` resolved via `[[ -t 1 ]]` after arg parsing) cleanly separates "user didn't say" from "user said json/text". Apply to other scripts (e.g., `permissions-audit.sh`) if/when they need the same treatment.
- **`remote-presence` primitive is consciously narrow-scope.** Only checks `origin` per the ticket. Skill prose adoption is a follow-on; the primitive exists so future skill updates can branch on `has_origin` without each rebuilding the probe.
- **Audit-session findings (49) are nearly all test-fixture jq/git-C calls.** Expected, not signal — 30 git-C in `audit-session-line-numbers.bats` and `remote-presence.bats` (test setup), 18 jq in `idea-pending-helpers.bats` (test assertions). One real signal: the `git-C` in BTS-117's spec note (justified — the script genuinely uses `git -C`). Extending the legacy-refs allowlist to include `hub/tests/*.bats` would silence this category — small follow-on. (Note: legacy-refs-scan is separate from audit-session — the scan with allowlist returned 0 cleanly.)

## Determinism Review

- **operations_reviewed:** ~70 (across 6 ships + idea capture + permissions-log investigation)
- **candidates_found:** 2 new, 1 carryover (RESOLVED via capture)
- **NEW (recurring): redundant `git push origin main` per spec-on-main commit.** This is now the SECOND consecutive stasis flagging this. 6 invocations this session (one per spec activate). The pattern is: write spec on main → commit on main → activate fails (main ahead of origin) → push main → re-activate. Should be `cmd_activate --auto-push-main` (push if main is ahead AND HEAD is on main) OR a `cmd_spec --activate` shortcut that combines. **Action: promote to must-ship in next session's first batch.** Impact: medium (recurs every spec ship; saves ~1 step per cycle).
- **NEW: audit-session reports 49 false-positives in test fixtures.** All 49 findings this session are jq/git-C inside `hub/tests/*.bats` test setup or assertions. Real source-code patterns are 0. The legacy-refs-scan got an allowlist (BTS-132); audit-session should get the same treatment — extend `cmd_audit_session` to skip `hub/tests/*.bats` (the way it already skips `.ccanvil/scripts/*.sh`). Impact: low (noise, not correctness), but recurring.
- **CARRYOVER → RESOLVED (via capture): permissions-audit log re-init.** Investigated mid-session. Running `permissions-audit.sh init` materialized the log with 199 stubs (28 DANGER, 171 UNREVIEWED, 0 REVIEWED). Underlying question — gitignore vs commit — is workflow not script. Captured as BTS-142 in Triage. **Resolved at the candidate level**; the work survives in BTS-142 as a process-decision item.

## Cross-Session Patterns

- **RESOLVED (via capture): permissions-log re-init.** Was the prior stasis's #1 next-step. Investigated; shifted to BTS-142 (workflow decision). Won't recur as a determinism candidate.
- **RECURRING (must-ship next session): redundant `git push origin main`.** Flagged in last stasis (4 invocations); flagged again this session (6 invocations). Two-stasis pattern justifies the small ship now.
- **NEW: audit-session noise floor.** 49 findings this session, ~all in test fixtures. Last session's audit-session also surfaced jq/git-C noise. Extending the allowlist matches the BTS-132 pattern that already worked for legacy-refs-scan.
- **VALIDATED: same-session capture→ship loop.** BTS-141 was the first idea captured AND shipped within one session. Proves the spec→activate→TDD→merge→land cycle is fast enough that a determinism-first capture is actionable, not just journaled. This is the BTS-115 process-fix's empirical evidence.
- **VALIDATED: dogfood-close cultural invariant.** 18 consecutive ships have closed their driving Linear ticket via the primitive being added in that ship. Last session was 12; this session adds 6 more. Robust pattern.
- **CONFIRMED: legacy-refs-scan stays clean with `--respect-allowlist`** — 0 matches this session, 0 last session. BTS-132 allowlist mechanism is the right shape.
- **CONFIRMED: skip-`/plan` for tight specs.** All 6 ships this session had no `/plan` — ACs mapped 1:1 to bats cases. Same as last session's pattern. Default approach for spec-driven work where AC → test is direct.
- **CONFIRMED: context budget stable at 74.9%.** Same as last session. Six ships didn't move it because none touched the always-loaded files. The earlier "trending up 73 → 74.9" panic was a one-time climb from BTS-139's cascade across operations.sh + skills, not a runaway pattern.

## Security Review

- No `security-audit.sh --files-only` invocation this session (none of the 6 ships introduced sensitive surfaces — all script/skill-prose work).
- Manual diff review across PRs #59-64: no secrets, tokens, PII, or credentials introduced. Test fixtures use literal placeholder UUIDs and example.com URLs.
- BTS-142 capture description references the 28 DANGER permissions count — not the underlying permission strings (those live in `.claude/settings*.json`, already committed).
- BTS-117 added `git remote get-url origin` calls, but only as a probe — no remote URLs exfiltrated, no network calls.
- Verdict: **PASS**.

## Memory Candidates

- **Same-session capture→ship loop is now the canonical pattern for determinism candidates** (project/feedback). When a bug exposes a deterministic-first principle violation: capture as Linear idea, promote to Todo, ship within the session. BTS-141 is the proof-of-concept. Reusable workflow.
- **Trust-but-verify on file mutations is mandatory** (feedback) — Zach corrected the `$stamp` no-expand bug that would have shipped silently. After any sed/awk/jq mutation that produces side effects, read the result before moving on. The harness does NOT track post-Bash file state for verification.
- **`docs-check.sh stamp-spec <feature_id>` is the canonical primitive for spec frontmatter epoch stamping** (project) — never use inline `date +%s` + sed in skill prose. Self-dogfooded twice this session (BTS-123, BTS-117 specs).
- **`idea-pending-append` covers all 6 fallback ops** (project) — single helper for add/promote/defer/dismiss/merge/ticket.transition. Skill prose now references it from both `/idea` capture-on-MCP-failure and triage-on-MCP-failure paths.
- **`remote-presence` primitive emits `{has_origin, url, git_repo}` for any repo state** (project/reference) — always exits 0; callers branch on `has_origin`. Use before suggesting `git push origin main` to any node where origin presence is uncertain.
- **TTY-aware default mode pattern** (feedback) — for any script that emits both human and machine output, the right default is `[[ -t 1 ]]`-resolved at startup. Pipes get JSON; humans get text. `--json` and `--text` override. Apply to future script designs.
- **Permissions-log workflow is genuinely undecided** (project) — `.claude/permissions-log.json` has never been committed and isn't gitignored. BTS-142 captures the decision. Whatever path Zach chooses (commit vs gitignore), the audit of 28 DANGER + 171 UNREVIEWED is the substantive work.
- **`Triage` Linear stateId for Blocktech Solutions: `53b10a02-ce3c-4990-aebc-e105c7229a37`** (reference) — used directly in BTS-141 + BTS-142 captures this session. Stable identifier; BTS-141 confirmed via dogfood.
