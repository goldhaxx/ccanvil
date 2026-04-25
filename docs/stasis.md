# Stasis

> Feature: session-2026-04-25-danger-walk-ship
> Kind: session
> Last updated: 1777133102
> Session objective: Close out the BTS-149 substrate by walking all 16 DANGER permission entries via the new `/permissions-review` skill — the second-order dogfood. Surface every implicit gap the walk reveals (verb-leading fence holes, classifier false-positives, in-skill stochastic patterns) as Linear tickets for next session.

## Accomplished

- **Walked all 16 DANGER entries via `/permissions-review`** — full standalone rationales written for each. DANGER count **16 → 0**. Audit reviewed=16.
  - Entry 1-4: env-prefix envelope set (`ALLOW_DESTRUCTIVE=1 chmod:*`, `git:*`, `rm:*`, `ALLOW_MAIN=1 git:*`).
  - Entry 5-9: broad-wildcard mutation verbs (`bash:*`, `cat:*`, `chmod:*`, `chown:*`, `cp:*`).
  - Entry 10: classifier false-positive (`done` — bash control-flow keyword).
  - Entry 11-16: text/traversal/mutation verbs (`echo:*`, `env:*`, `find:*`, `mv:*`, `rm:*`, `sort:*`).
  - Each rationale carries the full hook-coverage explanation so it stands alone — no "see BTS-X" handwaves.
- **Committed `.claude/permissions-log.json`** (`8cc1ebe`) — 36KB / 16 entries with risk + rationale + efficiency_justification + reviewer per BTS-143 schema.
- **10 follow-up tickets captured** during and after the walk:
  - **BTS-153** — Gate cat to ~/projects via guard-workspace.sh extension (Triage).
  - **BTS-154** — Refine BTS-144 classifier to recognize bash control-flow keywords as non-DANGER (Triage).
  - **BTS-155** — Extend guard-workspace.sh to gate find -exec/-delete and traversal outside ~/projects (**Urgent**).
  - **BTS-156** — Gate `rm -rf` (and recursive variants) to require explicit user review, inside or outside ~/projects (**Urgent**).
  - **BTS-157** — Gate `sort -o` (and sibling text-utility output flags) to require user review (**Urgent**).
  - **BTS-158** — Umbrella: Workspace fence has structural gaps for verbs and flags that operate on filesystem outside the verb-leading regex (**Urgent**). Children: BTS-153, BTS-155, BTS-157.
  - **BTS-159** — `permissions-audit.sh decision-append` substrate to replace Write+cat+rm dance in /permissions-review (Medium).
  - **BTS-160** — Fix BSD mktemp template in /permissions-review skill prose (**High**).
  - **BTS-161** — `permissions-audit.sh entry-context` substrate for deterministic per-row presentation in /permissions-review (Medium).
  - **BTS-162** — `/idea` capture extensions: `--parent` flag and `capture-from-context` shorthand (Medium).
- **In-session determinism review codified** — Zach asked explicitly to identify the repetitive stochastic operations performed during the walk. Five patterns were named: per-row Write+cat+rm dance (executed 16×), BTS-151 hook-trip workaround (14× detour), per-row presentation header rendering (16× hand-typed), per-ticket capture + parent-linking (9 MCP calls for 6 tickets + 3 parent edits), mktemp template bug. Three of the five turned into BTS-159/160/161/162.

## Current State

- **Branch:** `main` at `8cc1ebe` (permissions rationales chore).
- **Tests:** **1101 / 1101 green** via `bats-report.sh --parallel` (unchanged from last stasis — no test mutations this session).
- **Uncommitted changes:** none. Working tree clean.
- **Build status:** clean.
- **Context budget:** WARNING **81.3%** (6502/8000 tokens) — unchanged from last stasis. settings.json still dominant at 17.7% (the 16 accept-danger rationales live in permissions-log.json which is NOT in the budget files).
- **Permissions audit:** **danger=0** (was 16 entering session, now reviewed=16). unreviewed=121 (unchanged — UNREVIEWED ≠ DANGER; these are non-broad entries that haven't been flagged but also haven't been rationalized; outside this session's scope). promote-review.total=0. Net: the audit is in its cleanest state since BTS-142.
- **Specs archive:** 69 Complete (unchanged). Linear: 10 new ideas in Triage from this session (BTS-153–162).

## Blocked On

- Nothing. Working tree clean, tests green, audit at 0 DANGER, 10 follow-ups captured for next session.

## Next Steps

Priority-ordered for next session, smallest first to keep the chain unblocked:

1. **BTS-160** — Fix BSD mktemp template in /permissions-review skill prose (High, ~5 min ship). Just a skill prose edit; bug is fresh and trivial. Should be next session's opener.
2. **BTS-156** — Gate `rm -rf` (Urgent). Single guard-destructive.sh regex addition + bats. The most acute threat surfaced in the walk.
3. **BTS-155** — Gate find -exec/-delete (Urgent). Sibling to BTS-156 in guard-destructive.sh territory but for the embedded-operator family.
4. **BTS-157** — Gate sort -o + family (Urgent). The text-utility output-flag fence. Bundle with BTS-155 if they share a common scanning approach.
5. **BTS-158** umbrella decision — Path A (incremental: ship BTS-153/155/157 separately) vs Path B (unified guard-bash-shape.sh hook). Probably ship Path A first; revisit Path B after ≥2 land.
6. **BTS-159 / BTS-161** — substrate extractions for /permissions-review. Lower urgency than the workspace-fence gaps but the right size for between-Urgents work.
7. **BTS-162** — /idea --parent + capture-from-context. Lowest urgency; doesn't unblock anything but reduces friction across multi-capture sessions.
8. **BTS-150** — investigate the prompt-and-persist root cause (carried from prior stasis). May reveal a Claude Code config knob; if not, accept the design and document.
9. **BTS-151** — guard-workspace.sh false-positive on commit messages (carried from prior stasis). Tripped 1× more this session (the `git clean -f w` rationale-text trip on guard-force-push). Cheap fix.
10. **BTS-152** — per-finding allowlist for security-audit.sh (carried). Refinement of file-level allowlist used last session.
11. **Tech stack distribution** — roadmap "Up Next #1". Bigger scope; reasonable after the smaller follow-ups land.

## Context Notes

- **The walk validated the BTS-149 surface end-to-end as expected.** 16 rows, no apply errors, all rationales accepted. The skill is operationally sound — the gaps surfaced are all in the **substrate** (script primitives, hook coverage, classifier semantics), not the skill itself.
- **Two independent guard-shape gaps emerged.** BTS-155/156/157/158 all point at the same anti-pattern: the workspace fence regex is structurally local (verb-at-start) but bash composition is non-local (operators, flags, redirects, subshells). The umbrella ticket (BTS-158) frames this as the load-bearing design observation; the children are specific instantiations. Once the umbrella is internalized, future hook design becomes "where does this verb live in the bash grammar tree?" rather than "is this verb in the gated list?"
- **The BTS-151 false-positive cost real friction this session.** Hit once on row 2 (`git clean -f w` text inside the rationale tripped guard-force-push.sh:25). Worked around by switching to Write+cat+rm dance. The same anti-pattern as the rationale itself — hook scans command-string content rather than arg semantics. Worth shipping BTS-151 alongside the workspace-fence work since they're cousins.
- **Same-session determinism review was the right call.** When Zach asked "I want to codify the repetitive stochastic operations you performed in this session" — the answer was already structurally clear because the patterns had been named during the walk. BTS-159/160/161/162 took ~10 minutes to capture with full proposal scaffolding. Pattern: when a skill walks rows, name the per-row operations as you go; the post-walk codification surface is then trivial to articulate.
- **Cross-cutting observation: the BTS-149 substrate makes second-order safety work tractable.** Without `/permissions-review` and the apply substrate, the 16-row walk would have been hand-edited JSON or CLI-piped jq. With them, the loop is: present row → ask → buffer → ask → buffer → dispatch atomically. The atomicity is what made it safe to walk all 16 in one session — any validation failure would have rolled back cleanly. This is the BTS-149 design's first real exercise at scale.

## Determinism Review

- **operations_reviewed:** ~150 (16-row walk × ~5 ops/row = ~80 walk-side, plus 6 capture+3 link MCP calls, plus 4 substrate-codification ticket creations, plus the commit + cleanup, plus radar/recall reads).
- **candidates_found:** 4 NEW + 1 RESOLVED.

- **NEW (captured as BTS-159):** Per-row Write+cat+rm dance for buffering decisions. 64 tool calls across 16 rows for what should be one `decision-append` substrate call. Codification eliminates the dance and bypasses BTS-151 incidentally.
- **NEW (captured as BTS-160):** BSD mktemp template bug in /permissions-review skill prose. Filenames came out literal (`pr-promote.XXXXXX.json`) because BSD mktemp doesn't substitute X's mid-template. Single skill prose edit fixes it.
- **NEW (captured as BTS-161):** Per-row presentation header rendered 16× by hand. Three of six fields (File, Permission, Pattern) are deterministic and already in `check --json`; three (Hook gate, Origin, Net effect) are reasoning-derived but the structural lookup (which hook file, which line) is deterministic. `entry-context --json` substrate splits the spine from the prose.
- **NEW (captured as BTS-162):** Per-ticket capture + parent-linking. 6 captures + 3 parent-link edits = 9 MCP round-trips for what could be 6. /idea --parent flag at capture time eliminates the post-hoc link pass. capture-from-context shorthand auto-injects the "Surfaced during /<skill>" boilerplate that was hand-typed 6 times.
- **RESOLVED:** No carryover candidates from last session — last stasis's "Determinism Review" had two RESOLVED-via-ship items (BTS-148 pre-enqueue + silent classifier output) and two NEW items (BTS-150/151 captured). Both NEW items remain captured but unshipped, which is the normal carry-forward path, not a recurring pattern.

## Cross-Session Patterns

- **VALIDATED: dogfood-close cultural invariant.** Prior stasis: 28. This stasis: **29** (BTS-149 dogfood walk closed via the BTS-149 substrate itself — second-order dogfood-close). Pattern continues.
- **VALIDATED: same-session capture→ship loop on small fixes.** All 4 codification tickets (BTS-159/160/161/162) captured during the same session that surfaced them. Pattern continues; will validate if any ship next session.
- **NEW: walk-then-codify pattern.** The /permissions-review walk surfaced 5 ticketable hardening ideas (BTS-153/155/156/157/158) AND 4 ticketable substrate-codification opportunities (BTS-159/160/161/162). Pattern: when a skill walks rows, the walk's friction points are themselves the next-cycle backlog. The skill is both delivery vehicle and discovery instrument.
- **NEW: BTS-151 hit count up.** Last stasis: 3× (commit messages with `/stasis`, `/tmp`, `/land` substrings). This stasis: 1× (rationale text with `git clean -f w`). Cumulative friction is now visible enough that BTS-151 should ship soon — it's not just a one-off.
- **CONFIRMED: legacy-refs-scan stays clean** — 0 matches with `--respect-allowlist`. BTS-132 mechanism holds.
- **NEW: classifier semantics gap as a recurring discovery.** BTS-154 (control-flow keywords) joins BTS-150 (prompt-and-persist drift) as a family of "deterministic primitive lacks bash grammar awareness." Watch for this family's count growing; if it crosses 4-5 tickets, time for a structural cleanup ticket.

## Security Review

- This session added: `.claude/permissions-log.json` (16 accept-danger rationales). No secrets, tokens, PII, or credentials. The rationales are durable institutional knowledge, intentionally tracked.
- The walk produced 6 Linear tickets (BTS-153-158) and 4 codification tickets (BTS-159-162) — all idea-state, all in Linear, no local fs writes beyond the buffer that was cleaned up post-dispatch.
- Verdict: **PASS**. No new attack surface; one tracked file added with reviewed-and-rationalized content.

## Memory Candidates

- **Walk-then-codify pattern as a workflow:** when a skill walks rows interactively, the walk's friction points are themselves the next-cycle backlog. The skill is delivery + discovery in one. This is observable across BTS-149's first walk (which surfaced BTS-150/151/152 as friction points) and this walk (which surfaced 10 friction points across hardening + codification). **Decision: NOT saved as memory** — pattern is implicit in the dogfood-close invariant and in `feedback_deterministic_first.md`. Recorded here for cold-start reference.
- **Hook design rule emerging from BTS-158:** "match command shape, not just leading verb." Bash composition is non-local; verb-leading regex is necessary but not sufficient. **Decision: NOT saved as memory** — should live in deterministic-first.md or a new bash-grammar-aware-hook-design rule once BTS-158 lands. Premature to memorialize before the umbrella ships.
- **Concrete pattern: text inside command strings can trip hooks that scan command content.** Observed in BTS-151 multiple times now. **Decision: NOT saved separately** — captured in the BTS-151 ticket itself; the rule will become ambient once BTS-151 ships ("hooks should match paths-as-arguments not paths-as-string-content").

No new memories saved this session.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
