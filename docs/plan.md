# Implementation Plan: deterministic activate→in_progress transition dispatch

> Feature: bts-148-deterministic-activate-transition
> Work: linear:BTS-148
> Created: 1777084057
> Spec hash: cfbe7adb
> Based on: docs/spec.md

## Objective

Make `cmd_auto_transition_emit` enqueue a `ticket.transition` entry to `.ccanvil/ideas-pending.log` (deterministic backup) AND add an `/activate` skill that consumes the AUTO-TRANSITION marker and dispatches MCP (immediate execution). Both layers mirror the BTS-119 AUTO-CLOSE precedent already in production.

## Pre-existing infrastructure (no code change required)

- `cmd_idea_pending_append --op ticket.transition --id <ID> --role <ROLE>` (line 2761) already exists from BTS-123. The op variant we need is wired.
- `/idea sync` skill prose already dispatches `ticket.transition` entries (re-resolves via `operations.sh`, calls `save_issue`). Originally added for BTS-119 retry; works for any role including `in_progress`. AC-2 is satisfied by existing skill prose; no behavior change needed there.

## Sequence

### Step 1: Test the script-side enqueue (RED)
- **Test:** New file `hub/tests/activate-auto-transition.bats`. Cases for AC-1, AC-6, AC-7, AC-8:
  - AC-1: After `cmd_auto_transition_emit <branch> in_progress <docs-dir>` on a fixture spec with `Work: linear:BTS-X`, `.ccanvil/ideas-pending.log` contains exactly one `{op: "ticket.transition", args: {id: "BTS-X", role: "in_progress"}, ...}` entry.
  - AC-6: When fixture spec has `Work: local:idea-29`, no enqueue happens (silent).
  - AC-7: When fixture spec has no `Work:` line (legacy), no enqueue happens (silent).
  - AC-8: Two consecutive calls produce two entries — `/idea sync` handles dedup at dispatch time (idempotent against Linear state). Verify two entries present.
- **Implement:** No code change yet.
- **Files:** `hub/tests/activate-auto-transition.bats`
- **Verify:** Run `bash .ccanvil/scripts/bats-report.sh -f 'activate-auto-transition'`. AC-1 fails (no enqueue happens), AC-6/AC-7/AC-8 outcome irrelevant pre-fix.

### Step 2: Add the enqueue to cmd_auto_transition_emit (GREEN)
- **Test:** Step 1 cases, plus full BTS-136 regression (existing AUTO-TRANSITION marker tests).
- **Implement:** In `cmd_auto_transition_emit` (line 1161), after the `linear)` branch's marker emission (or before — see spec note), add:
  ```bash
  cmd_idea_pending_append --op ticket.transition --id "$id" --role "$role" --project-dir "$project_dir"
  ```
  Resolve `project_dir` from `docs_dir` (one level up from `docs/`).
- **Files:** `.ccanvil/scripts/docs-check.sh`
- **Verify:** Step 1 cases pass; full suite still green.

### Step 3: Create the `/activate` skill (AC-3, AC-4, AC-5)
- **Test:** Manual end-to-end. Hard to bats-test the skill directly since it's prose for the agent. The bats coverage in Step 1 covers the deterministic substrate; the skill prose covers the agentic glue. Out-of-band validation: re-running activate on a fresh ticket post-ship should auto-transition.
- **Implement:**
  1. Create `.claude/skills/activate/SKILL.md` with the wrapper-skill prose: run the script, capture stdout, parse the marker, call `operations.sh resolve ticket.transition`, dispatch `save_issue`, ack the pending entry on success, leave it for retry on failure.
  2. Create `.claude/commands/activate.md` slash-command pointer (matches existing `/land`, `/spec`, `/plan` patterns).
- **Files:** `.claude/skills/activate/SKILL.md`, `.claude/commands/activate.md`
- **Verify:** `/activate` is reachable via slash-command; skill prose is clear about the dispatch contract.

### Step 4: Documentation
- **Test:** None.
- **Implement:** Update `.ccanvil/guide/command-reference.md` with `/activate` in the slash-command table, and document `idea-pending-append --op ticket.transition` consumers (now `/land` failures + `cmd_activate`).
- **Files:** `.ccanvil/guide/command-reference.md`
- **Verify:** Read once for fidelity.

### Step 5: Dogfood
- **Test:** Pick one Triage idea (BTS-143 or BTS-144 — both are coherent next-ups). Run `/activate <id>` after the BTS-148 PR merges. Confirm Linear shows `In Progress` without manual MCP dispatch.
- **Implement:** No code. Manual.
- **Files:** None.
- **Verify:** Linear `statusType: started` post-activate, no `ALLOW_OUTSIDE_WORKSPACE=1`-style workaround needed.

## Risks

- **Script-side enqueue races with skill dispatch.** If both fire (skill consumes marker → dispatches → acks AND script enqueues), we'd want exactly one outcome. Mitigation: skill acks the pending entry on success, so only one survives. If skill dispatch fails, entry stays for sync retry. If skill never runs (ad-hoc activate path), sync drains it on next /idea sync.
- **`docs_dir` to `project_dir` coercion.** The existing function signature uses `docs_dir`. We need `project_dir = dirname(docs_dir)` for the pending-log path. Minor refactor.
- **Test fixture noise.** `activate-auto-transition.bats` will fork a temp project_dir and write to its `.ccanvil/ideas-pending.log`. Per BTS-127, use `set -e` for assertion strictness.

## Definition of Done

- [ ] All 8 acceptance criteria from spec pass
- [ ] All existing tests still pass (1062 baseline → ~1066 expected)
- [ ] `/activate` slash-command is invocable
- [ ] Code reviewed (run /review)
- [ ] Dogfood validated post-merge with one real Triage activation

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
