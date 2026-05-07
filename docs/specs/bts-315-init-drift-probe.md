# Feature: Init-time global-skill drift probe

> Feature: bts-315-init-drift-probe
> Work: linear:BTS-315
> Created: 1778184076
> Subject: Init-time global-skill drift probe
> Status: Draft

## Summary

`/ccanvil-init` and other operator entrypoints currently never check whether the user's `~/.claude/commands/ccanvil-*.md` files are stale relative to the hub canonical at `~/projects/ccanvil/global-commands/`. The user-level prose silently drifts (last evidence: microsoft365-toolbox 2026-05-05, where stale prose referenced `.ccanvil/templates/checkpoint.md` — a path that has never existed in the hub). This spec adds a deterministic drift probe that surfaces staleness at session entry and prompts the operator to refresh via `/ccanvil-pull-globals` — explicit operator action, never auto-mutating user-level files.

## Job To Be Done

**When** I run `/ccanvil-init` or open a fresh session against the ccanvil hub,
**I want to** be told if my user-level `ccanvil-*` skill prose has drifted from the hub canonical,
**So that** I refresh before relying on stale instructions that reference paths or substrate that no longer exists.

## Acceptance Criteria

Each criterion is independently testable. Binary pass/fail.

- [ ] **AC-1:** `bash .ccanvil/scripts/ccanvil-sync.sh pull-globals --check` runs from any cwd (no lock-file requirement) and exits 0 emitting `{stale: <bool>, files: [{name, hub_hash, local_hash, status}]}` JSON. Read-only — no filesystem writes. *(Resolves BTS-328 substrate dependency.)*
- [ ] **AC-2:** When all `~/.claude/commands/ccanvil-*.md` files match the hub canonical by SHA-256, `pull-globals --check` reports `stale: false` and an empty `files: []` array.
- [ ] **AC-3:** When at least one user-level file diverges, `pull-globals --check` reports `stale: true` with one entry per drifted file (`status: "drift"` for hash-mismatch, `status: "missing-local"` when hub has a file the user does not).
- [ ] **AC-4:** `/ccanvil-init` Step 1 (Bootstrap and preflight) probes drift via `pull-globals --check`. When `stale: true`, the skill stops executing subsequent init steps, surfaces the drifted file list, and prints the explicit nudge: `Run /ccanvil-pull-globals to refresh, then re-run /ccanvil-init.` "Stop" is skill-prose-level (the agent does not run the next preflight/init-apply steps); there is no non-zero exit code — `/ccanvil-init` is a slash-command skill, not a substrate primitive, so its halt is a clean handoff to the operator who decides next action. The substrate's own non-zero exits (AC-7's unreadable-hub path) are a separate concern propagated by `pull-globals --check` itself, not by the skill.
- [ ] **AC-5:** When `pull-globals --check` reports `stale: false`, `/ccanvil-init` proceeds silently — no operator-visible noise on the happy path.
- [ ] **AC-6:** The `/ccanvil-pull-globals` skill prose (at `.claude/skills/ccanvil-pull-globals/SKILL.md` and the corresponding `global-commands/ccanvil-pull-globals.md` if added) documents the `ALLOW_OUTSIDE_WORKSPACE=1` env-var bypass as a one-time opt-in for the user-level write — surfacing the guard-workspace.sh hook before it blocks the first-time invoker. *(Resolves BTS-329.)*
- [ ] **AC-7 (error):** If the hub path resolved by `get_hub_source` (or its lock-free equivalent) is unreadable, `pull-globals --check` exits non-zero with a clear stderr message (`hub source not found at <path>`) and JSON is NOT emitted. Init halts and surfaces the error verbatim.
- [ ] **AC-8 (edge):** When `~/.claude/commands/` does not exist (truly fresh user environment), `pull-globals --check` reports every hub `ccanvil-*.md` file under `status: "missing-local"` and `stale: true`. Init surfaces the same nudge as AC-4.
- [ ] **AC-9:** bats coverage at `hub/tests/pull-globals-check.bats` exercises AC-1 through AC-8 using a stub HUB directory + stub HOME, with no writes to the real `~/.claude/commands/`. The test injects via the same fake-HOME pattern as `provider-heal-umbrella.bats`.

## Affected Files

| File | Change |
|------|--------|
| `.ccanvil/scripts/ccanvil-sync.sh` | Modified — `cmd_pull_globals` gains `--check` flag (read-only mode); `pull-globals` and `pull-globals --check` no longer require `.ccanvil/ccanvil.lock` in cwd (BTS-328) |
| `global-commands/ccanvil-init.md` | Modified — Step 1 inserts drift-probe call between bootstrap and preflight |
| `.claude/skills/ccanvil-pull-globals/SKILL.md` | Modified — document `ALLOW_OUTSIDE_WORKSPACE=1` bypass (BTS-329) |
| `global-commands/ccanvil-pull-globals.md` | Modified (if exists) — same prose update as the skill |
| `hub/tests/pull-globals.bats` | Modified — extend with `--check` AC coverage (or split into a new file `pull-globals-check.bats`, decided in /plan) |
| `.ccanvil/manifest-allowlist.txt` | Modified — register the new test file if split |

## Dependencies

- **Requires:** Active read access to `~/projects/ccanvil/global-commands/` (the hub canonical source). The hub-source lookup must work without a `.ccanvil/ccanvil.lock` file in cwd — see AC-1.
- **Blocked by:** Nothing.

## Out of Scope

- **BTS-327** (`/ccanvil-init` fresh-mode CLAUDE.md template wedge) — different file, different mechanism (CLAUDE.md is not a `ccanvil-*` global skill).
- **Auto-pull-on-stale.** This spec deliberately surfaces a nudge and HALTS; it does not auto-mutate user-level files. Auto-pull semantics are out-of-scope and left for a follow-up if explicit-prompt fatigue emerges.
- **Periodic drift-probe in `/radar`** or other entrypoints. This spec wires only `/ccanvil-init`. Other entrypoints are follow-ons.
- **Hub-version-pin staleness** (semver-style). Hash-compare is sufficient signal; version-pin is over-engineering for the current substrate.
- **Probing non-`ccanvil-*` user-level files** (user-owned namespace is sacrosanct, per `cmd_pull_globals`'s existing `ccanvil-*.md` glob).

## Implementation Notes

- Same shape as session 25's `provider-heal-preflight` (BTS-320): substrate emits a JSON envelope, the skill consumes it and decides whether to halt or proceed. Read-only by composition.
- `cmd_pull_globals` already iterates `ccanvil-*.md` and computes per-file SHA-256. Add a `check_only` boolean; when set, skip the `cp` calls, accumulate per-file `{name, hub_hash, local_hash, status}` entries, emit the JSON envelope, exit.
- Lock-file gate removal: `require_lockfile` is unconditionally called at the top of `cmd_pull_globals`. The function only reads `$HOME/.claude/commands/` and the hub source — neither path depends on lockfile state. Replace with a defensive resolver: prefer `--hub-path` arg → `~/projects/ccanvil` default → error if nonexistent. (See `get_hub_source` for the existing lock-driven path; the lock-free equivalent should mirror its other branch logic.)
- Bats stub pattern: `provider-heal-umbrella.bats` already establishes the `FAKE_HOME` + `unset LINEAR_API_KEY` pattern under a temp dir. Copy that shape; substitute `$FAKE_HOME/.claude/commands/` for the user-level write target and a temp `hub-stub/global-commands/` for the canonical source.
- AC-4's halt is structurally equivalent to `provider-heal`'s `DRIFT DETECTED` halt — fail-fast, explicit-remediation, no auto-action.

## Open Questions

- **Q1: Should AC-7 (unreadable hub) halt init or warn-and-continue?** Spec defaults to halt because a non-resolvable hub means the rest of init will also fail, but operator may prefer warn for resilience.
- **Q2: Skill-file proliferation.** `/ccanvil-pull-globals` currently lives only in `.claude/skills/ccanvil-pull-globals/SKILL.md` (hub-internal); the symmetric file at `global-commands/ccanvil-pull-globals.md` does not exist. AC-6 may need to add it OR be scoped to just the hub-internal skill — decide in /plan based on whether `pull-globals --check`-from-init needs the global-commands variant for other downstream-node sessions.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
