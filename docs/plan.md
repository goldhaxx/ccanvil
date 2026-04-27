# Implementation Plan: Session-boundary counter + ISO local timestamp

> Feature: bts-206-session-boundary-counter
> Work: linear:BTS-206
> Created: 1777254424
> Spec hash: a221fd70
> Based on: docs/spec.md

## Objective

Wire a SessionStart hook that bumps a persistent counter and stamps an ISO-8601 local boundary, expose the pair via a `session-info` substrate primitive, and surface both in /stasis metadata + /recall briefing.

## Sequence

### Step 1: bats test for `session-info` primitive — fresh-node case (AC-3)
- **Test:** `hub/tests/session-boundary.bats` — `@test "AC-3: session-info on fresh node returns counter=0 and null fields"` builds a fixture with no `.ccanvil/state/session-counter` or `.ccanvil/state/session-boundary`, runs `docs-check.sh session-info`, asserts JSON `{counter:0, epoch:null, iso:null, tz:null}` and exit 0.
- **Implement:** stub `cmd_session_info` in `docs-check.sh` returning the empty envelope. Add dispatcher entry `session-info)`.
- **Files:** `hub/tests/session-boundary.bats` (new), `.ccanvil/scripts/docs-check.sh` (new function + dispatcher).
- **Verify:** `bash .ccanvil/scripts/bats-report.sh -f "session-info on fresh"` passes; existing 1605 tests unaffected.

### Step 2: bats test for `session-info` primitive — populated case (AC-3 cont.)
- **Test:** `@test "AC-3: session-info reads counter + boundary state files"` — fixture writes `.ccanvil/state/session-counter` containing `47` and `.ccanvil/state/session-boundary` containing `{"epoch":1777254400,"iso":"2026-04-26T18:44:36-07:00","tz":"America/Los_Angeles"}`. Asserts `session-info` returns those fields verbatim.
- **Implement:** flesh out `cmd_session_info` to read counter file (default 0 if missing) and boundary JSON (default nulls if missing or malformed). Use `jq -n` to assemble envelope.
- **Files:** same as Step 1.
- **Verify:** test passes.

### Step 3: bats test for `cmd_session_info` corruption tolerance (edge of AC-8)
- **Test:** `@test "session-info: corrupted counter file returns counter=0 + warns"` — fixture writes `not-a-number` into the counter file; asserts `session-info` returns counter=0, exit 0 (reading is fault-tolerant; the hook is what resets to 1).
- **Implement:** in `cmd_session_info`, validate counter is integer with `[[ "$val" =~ ^[0-9]+$ ]]`; fallback to 0 with a stderr WARN otherwise.
- **Files:** same.
- **Verify:** test passes.

### Step 4: bats test for SessionStart hook — first-run init (AC-1)
- **Test:** `@test "AC-1: hook initializes counter to 1 on fresh node"` — fixture has no counter file, runs `bash .claude/hooks/session-boundary.sh` with `CLAUDE_PROJECT_DIR=$fx`, asserts `.ccanvil/state/session-counter` now contains `1`.
- **Implement:** create `.claude/hooks/session-boundary.sh` mirroring `post-compact-marker.sh` shape — read counter (default 0), bump, atomic write via `mktemp + mv`. Mark executable.
- **Files:** `.claude/hooks/session-boundary.sh` (new, chmod 755).
- **Verify:** test passes.

### Step 5: bats test for SessionStart hook — monotonic across invocations (AC-6)
- **Test:** `@test "AC-6: counter is monotonic across two SessionStart invocations"` — runs the hook twice, asserts counter goes from 1 → 2 (or N → N+1 starting from a seeded value).
- **Implement:** counter logic already present from Step 4; this just adds the drift-guard.
- **Files:** test only.
- **Verify:** test passes.

### Step 6: bats test for SessionStart hook — boundary file written with ISO + tz (AC-2)
- **Test:** `@test "AC-2: hook writes session-boundary JSON with epoch, iso, tz"` — runs hook, asserts `.ccanvil/state/session-boundary` is parseable JSON with non-null `epoch`, `iso` (matches `^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{2}:[0-9]{2}$`), and `tz` non-empty.
- **Implement:** in `session-boundary.sh`, compute `epoch=$(date +%s)`, `iso=$(date '+%Y-%m-%dT%H:%M:%S%z' | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')`, `tz="${TZ:-$(readlink /etc/localtime 2>/dev/null | sed -E 's|.*/zoneinfo/||' || echo UTC)}"`. Atomic write of `{epoch, iso, tz}` JSON via `jq -n`.
- **Files:** `.claude/hooks/session-boundary.sh` (extended).
- **Verify:** test passes.

### Step 7: bats test for SessionStart hook — TZ env override (AC-7)
- **Test:** `@test "AC-7: TZ=UTC produces iso ending in +00:00"` — runs `TZ=UTC bash session-boundary.sh`, asserts iso field ends in `+00:00`.
- **Implement:** confirm Step 6 logic respects `TZ` env (it does — `date` reads TZ natively).
- **Files:** test only.
- **Verify:** test passes.

### Step 8: bats test for SessionStart hook — counter corruption resets to 1 (AC-8)
- **Test:** `@test "AC-8: hook resets corrupted counter to 1 + warns"` — fixture seeds counter file with `garbage`. Hook runs, asserts counter is now `1` and a WARN appeared on stderr.
- **Implement:** in `session-boundary.sh`, guard counter read with `[[ =~ ^[0-9]+$ ]]`; fallback to 0 (then bump to 1). Echo `WARN: session-counter contained non-integer; resetting to 1` to stderr.
- **Files:** `.claude/hooks/session-boundary.sh` (extended).
- **Verify:** test passes.

### Step 9: bats test for SessionStart hook — non-blocking on failure (AC-9)
- **Test:** `@test "AC-9: hook exits 0 even when state dir is unwritable"` — fixture makes `.ccanvil/state` read-only (`chmod 555`), runs hook, asserts exit 0 + a WARN appeared.
- **Implement:** in `session-boundary.sh`, wrap fs writes in `2>/dev/null || { echo "WARN: ..." >&2; exit 0; }`. Top-level `set +e` for the write block, never `set -e` past the write.
- **Files:** `.claude/hooks/session-boundary.sh` (extended).
- **Verify:** test passes. (Note: skip on CI if running as root, since chmod 555 is bypassed. Use `[[ "$EUID" -ne 0 ]]` skip-guard.)

### Step 10: register SessionStart hook in `.claude/settings.json`
- **Test:** new bats test `@test "settings.json registers SessionStart hook"` greps `.claude/settings.json` for `"SessionStart"` and `session-boundary.sh`.
- **Implement:** add a `"SessionStart"` array to the `hooks` object alongside `PreCompact`, with one entry pointing at `.claude/hooks/session-boundary.sh`.
- **Files:** `.claude/settings.json`, `hub/tests/session-boundary.bats`.
- **Verify:** test passes; `jq '.hooks.SessionStart' .claude/settings.json` parses cleanly.

### Step 11: extend stasis template + skill to surface Session + Boundary metadata (AC-4)
- **Test:** modify existing `hub/tests/stasis-skill.bats` (or extend existing recall/stasis suite) — assert the stasis template contains `> Session:` and `> Boundary:` lines, and the stasis skill prose mentions calling `docs-check.sh session-info`.
- **Implement:** add `> Session: [N]` and `> Boundary: [ISO]` lines to `.ccanvil/templates/stasis.md` immediately after `> Last updated:`. Update `.claude/skills/stasis/SKILL.md` data-gathering section to call `session-info` and substitute the values into metadata.
- **Files:** `.ccanvil/templates/stasis.md`, `.claude/skills/stasis/SKILL.md`, `hub/tests/stasis-skill.bats` (modified or new file if absent — confirm at step time).
- **Verify:** drift-guards green; manual visual check on the template.

### Step 12: validator grandfathers absence of Session/Boundary metadata (AC-4 cont.)
- **Test:** new bats test `@test "validate: stasis without > Session: passes (legacy-grandfathered)"` — fixture writes a stasis without the new fields; asserts validate result is `aligned` (or whatever the pre-existing pass state is for that fixture shape).
- **Implement:** confirm `cmd_validate` does not require the new fields. If it would fail, gate the new lines behind a "if present, parse; else skip" check. Likely no change needed since validator currently reads only `> Feature:`, `> Last updated:`, `> Plan hash:`, `> Kind:`.
- **Files:** `.ccanvil/scripts/docs-check.sh` if a guard is needed; otherwise test-only.
- **Verify:** test passes; existing stasis tests unaffected.

### Step 13: extend recall skill to surface Session + Boundary in briefing (AC-5)
- **Test:** modify `hub/tests/recall-skill.bats` — assert recall skill prose calls `docs-check.sh session-info` and that the briefing rendering includes "Session" and "Boundary" terms guarded by a counter>0 conditional.
- **Implement:** add a new step in `.claude/skills/recall/SKILL.md` data-gathering: call `session-info`, then in the briefing render a one-line `**Session N** — boundary <iso>` near the top when `counter > 0`. Omit when 0.
- **Files:** `.claude/skills/recall/SKILL.md`, `hub/tests/recall-skill.bats`.
- **Verify:** drift-guards green.

### Step 14: documentation sweep
- **Implement:** update `.ccanvil/guide/command-reference.md` (above NODE-SPECIFIC-START) to document the `docs-check.sh session-info` subcommand and the new `session-boundary.sh` SessionStart hook. Update `.ccanvil/guide/hooks.md` (or whichever guide file owns hook docs) with the new hook's purpose, fire pattern, and state files written.
- **Files:** `.ccanvil/guide/command-reference.md`, `.ccanvil/guide/hooks.md` (read first to confirm structure).
- **Verify:** docs-check.sh `legacy-refs-scan` (run via `bats-report.sh`) returns clean; full bats suite green.

### Step 15: full suite + /review
- **Verify:** `bash .ccanvil/scripts/bats-report.sh --parallel` emits PASS for all tests including new drift-guards. Run `/review` for code quality + security audit. No new test should be longer than the smallest existing AC test for parity.

## Risks

- **macOS vs Linux `date` format differences.** macOS BSD `date` formats `+%z` as `-0700` (no colon); Linux GNU `date` accepts `--iso-8601=seconds` natively but BSD doesn't. Mitigation: use the portable `+%z` format and `sed`-insert the colon manually (Step 6).
- **TZ env unset and `/etc/localtime` not a symlink.** Some Docker images strip `/etc/localtime`. Mitigation: fallback to `UTC` literal if both `TZ` and the symlink are absent. Tested explicitly in Step 6.
- **AC-9 unwritable-fs test on root.** The `chmod 555` test bypasses for root users (CI). Skip-guard via `[[ "$EUID" -ne 0 ]] || skip "running as root"`. Documented in Step 9.
- **Hook collision with future SessionStart consumers.** Only one SessionStart hook exists today (the new one). Future hooks register in the same array and run sequentially; no compose risk.
- **Session counter monotonicity vs git clones.** Cloning a node copies `.ccanvil/state/` only if not gitignored. Confirm `.ccanvil/state/session-counter` is gitignored (per existing `.ccanvil/state/last-compact-ts` precedent — verify in Step 4 fixture). Counter is per-node by design.

## Definition of Done

- [ ] All 9 acceptance criteria pass (drift-guards green)
- [ ] All existing 1605 tests still pass
- [ ] No type errors (bash; we have shellcheck implicit via existing CI patterns — verify clean)
- [ ] Code reviewed (run /review)
- [ ] PR #111 ready for merge

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
