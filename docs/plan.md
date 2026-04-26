# Implementation Plan: /idea --parent flag for capture-time parentId

> Feature: bts-162-idea-parent-flag
> Work: linear:BTS-162
> Created: 1777176703
> Spec hash: 23209d02
> Based on: docs/spec.md

## Objective

Stamp `parent_id` at capture time in `/idea` so multi-capture sessions don't need a follow-up `parentId`-update pass per child. Two surfaces touched: `cmd_idea_add` (local JSONL) and the skill prose (Linear http-dispatch hand-off). One drift-guard test file.

## Sequence

### Step 1: Local-path `--parent` arg parsing + JSONL stamping (AC-2, AC-4)

- **Test:** New `hub/tests/idea-parent-flag.bats`. AC-2 — `cmd_idea_add --parent idea-7 "body"` produces a JSONL line with `parent_id == "idea-7"`. Drift-guard — `cmd_idea_add "body"` (no flag) produces a JSONL line WITHOUT a `parent_id` key (jq `has("parent_id") == false`). AC-4 — empty value exits 2 with the documented message; whitespace value exits 2 with the documented message.
- **Implement:** Extend `cmd_idea_add` in `.ccanvil/scripts/docs-check.sh`:
  - Add `--parent <val>` to the arg loop.
  - Validate non-empty + no-whitespace at parse time. Match error messages exactly to AC-4.
  - When `parent` is set, augment the JSONL via `jq -cn ... | jq -c --arg p "$parent" '. + {parent_id:$p}'` OR conditionally include the field via `if env.PARENT then ...` (avoid emitting `parent_id: null` when unset).
- **Files:** `.ccanvil/scripts/docs-check.sh` (cmd_idea_add); `hub/tests/idea-parent-flag.bats` (NEW).
- **Verify:** Run `bats hub/tests/idea-parent-flag.bats -f "AC-2|AC-4|drift-guard local"`. All green.

### Step 2: Pending-log `--op add --parent` support (AC-5 enqueue side)

- **Test:** AC-5 — `cmd_idea_pending_append --op add --parent BTS-158 --title T --body B` writes a JSONL entry where `args.parent_id == "BTS-158"`. No-`--parent` form still works and `args` lacks the key.
- **Implement:** Extend `cmd_idea_pending_append`'s arg loop with `--parent <val>` and the `add` op-branch with conditional `parent_id` field via the same merge pattern as Step 1.
- **Files:** `.ccanvil/scripts/docs-check.sh` (cmd_idea_pending_append); `hub/tests/idea-parent-flag.bats` (extend).
- **Verify:** Bats green. AC-5's enqueue side covered; replay side is exercised by skill prose (no script-level test).

### Step 3: Skill prose update (AC-1, AC-3)

- **Test:** Drift-guard test — assert `.claude/skills/idea/SKILL.md` contains the literal phrase `--parent <ref>` in the Capture section, and the `--parent-id` append shape in the Linear path. (Pure content drift-guard; the actual dispatch is exercised by AC-1 below as a string-construction test.)
- **Test for AC-1:** Synthesize the resolver output, run the documented append shape, assert the resulting command string contains `--parent-id 'BTS-158'`. Done as a bats integration test that mirrors the skill's eval'd-string construction (no live Linear call).
- **Test for AC-3:** Position-agnostic parsing — assert that the skill's documented arg-parse pattern handles `--parent X "body"` and `"body" --parent X` identically. Implemented as a small bash function ported from skill prose into a test helper, validated for both forms.
- **Implement:** Update `.claude/skills/idea/SKILL.md`:
  - In Capture intro, add: "If the input contains `--parent <ref>`, extract it before title generation and route it through to dispatch."
  - In Step 3a (Linear path), document the append shape: ``cmd="$cmd --parent-id $(printf '%s' "$parent" | jq -R @sh)"`` before the eval.
  - In Step 3b (local path), pass `--parent "$parent"` through to `docs-check.sh idea-add`.
  - On Linear-failure pending-log fallback, document the `--parent "$parent"` flag on `idea-pending-append`.
- **Files:** `.claude/skills/idea/SKILL.md`; `hub/tests/idea-parent-flag.bats` (extend).
- **Verify:** Drift-guard tests + AC-1/AC-3 string-shape tests green.

### Step 4: Full-suite verification + commit

- **Test:** `bash .ccanvil/scripts/bats-report.sh --parallel`. Confirm 1350 → 1356 (or however many AC tests we add) green.
- **Implement:** No code change. Single commit per logical group:
  - `feat(bts-162): --parent flag in /idea — local + pending-log + skill prose`
- **Files:** N/A.
- **Verify:** Tests green; lifecycle still aligned via `docs-check.sh validate`.

### Step 5: Doc routing (skill is hub-shared)

- The `.claude/skills/idea/SKILL.md` change is hub-shared (every node gets the same skill via `ccanvil-pull`). Already covered by Step 3's hub-section edits — no separate `.ccanvil/guide/` update needed because the command-reference is auto-generated from skill metadata. (Validate this assumption during Step 3 via `grep -n "idea" .ccanvil/guide/command-reference.md`; if a manual entry exists, update it.)

## Risks

- **Skill drift-guard fragility.** Asserting literal phrases in skill prose can break on benign rephrasing. Mitigation: anchor on the most stable substrings (`--parent <ref>`, `--parent-id`) rather than full sentences.
- **JSONL field-omission cleanliness.** If the `if-present` jq merge isn't careful, `parent_id: null` could leak into the log. Mitigation: explicit drift-guard test asserts `has("parent_id") == false` for the no-flag form.
- **Live-API risk: NONE.** The plan touches only `linear-query.sh save-issue --parent-id`, which already exists (per `linear-query.sh` line 38) and was exercised in the BTS-149 walk-through. No live-API gate triggered.

## Definition of Done

- [ ] All acceptance criteria from spec pass (AC-1 through AC-6)
- [ ] All existing tests still pass (1350 → 1350+N green)
- [ ] No type errors (bash -n on touched scripts)
- [ ] Code reviewed (run /review)

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
