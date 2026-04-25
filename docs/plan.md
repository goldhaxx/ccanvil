# Implementation Plan: permissions-audit promote-review

> Feature: bts-144-permissions-audit-promote-review
> Work: linear:BTS-144
> Created: 1777086458
> Spec hash: e7659c5f
> Based on: docs/spec.md

## Objective

Add a new `promote-review` subcommand to `permissions-audit.sh` that lists `settings.local.json` entries not in `settings.json` and classifies each deterministically (DELETE / TRIAGE) for review. JSON + text output modes per BTS-134 conventions.

## Sequence

### Step 1: Tests (RED)
- **Test:** Add a BTS-144 block to `hub/tests/permissions-audit.bats` covering AC-1 through AC-9. Use temp `$FIXTURE` dir per existing test pattern. Cases:
  - AC-7: empty local file → empty output, exit 0
  - AC-2: local has `Bash(git status:*)`, main has `Bash(other:*)` (no overlap) → 1 candidate
  - AC-3: main has `Bash(git:*)`, local has `Bash(git status:*)` → DELETE redundant
  - AC-4: local has `Bash(bash preset/old/script.sh)` → DELETE dead path
  - AC-5: main has `Bash(bash:*)`, local has `Bash(ALLOW_OUTSIDE_WORKSPACE=1 bash ./x.sh)` → DELETE one-shot bypass
  - AC-6: local has `Bash(custom-tool:*)`, main has nothing → TRIAGE
  - AC-1 (JSON shape): output has `candidates`, `counts.delete`, `counts.promote`, `counts.triage`, `counts.total`
  - AC-8: text mode shows `--- DELETE` and `--- TRIAGE` group headers
  - AC-9: counts.promote always 0
- **Implement:** No code yet.
- **Files:** `hub/tests/permissions-audit.bats`
- **Verify:** All BTS-144 cases fail (subcommand doesn't exist).

### Step 2: Wire up the subcommand (GREEN)
- **Test:** AC-1 (JSON shape) and AC-7 (empty input) — minimum viable.
- **Implement:**
  1. Add `promote-review` to the CMD parser case in `permissions-audit.sh` (around line 41).
  2. Add `promote-review) cmd_promote_review ;;` to the dispatch case (around line 421).
  3. Implement `cmd_promote_review` skeleton: handle missing/empty local file by emitting `{candidates: [], counts: {delete: 0, promote: 0, triage: 0, total: 0}}`. Exit 0.
- **Files:** `.ccanvil/scripts/permissions-audit.sh`
- **Verify:** AC-1, AC-7 pass.

### Step 3: Candidate set (AC-2) and TRIAGE fallback (AC-6)
- **Test:** AC-2, AC-6.
- **Implement:** Parse both files via `parse_settings_file`. Filter local entries to those not present (string-equal) in main. For each, default classification = TRIAGE with reason "manual review required".
- **Files:** `.ccanvil/scripts/permissions-audit.sh`
- **Verify:** AC-2, AC-6 pass.

### Step 4: Redundancy classifier (AC-3)
- **Test:** AC-3.
- **Implement:** For each candidate, scan main entries matching `Bash(<word>:*)` regex. If candidate starts with `Bash(<word> ` or `Bash(<word>:`, classify DELETE with reason `"redundant: covered by '<broader>' in settings.json"`.
- **Files:** `.ccanvil/scripts/permissions-audit.sh`
- **Verify:** AC-3 passes.

### Step 5: Dead-path classifier (AC-4)
- **Test:** AC-4.
- **Implement:** If candidate string contains `preset/`, classify DELETE with reason `"dead path: pre-BTS-67 preset/ structure removed"`.
- **Files:** `.ccanvil/scripts/permissions-audit.sh`
- **Verify:** AC-4 passes.

### Step 6: Env-prefix one-shot classifier (AC-5)
- **Test:** AC-5.
- **Implement:** Bash regex match on `^Bash\(ALLOW_[A-Z_]+=1 (bash|rm|cp|mv|chmod|chown) `. Extract underlying verb. If `Bash(<verb>:*)` exists in main, classify DELETE with reason `"one-shot bypass: underlying command now broadly allowed"`.
- **Files:** `.ccanvil/scripts/permissions-audit.sh`
- **Verify:** AC-5 passes.

### Step 7: Text-mode rendering (AC-8)
- **Test:** AC-8.
- **Implement:** When `TEXT_MODE=true`, emit grouped sections by recommendation (`--- DELETE (redundant) ---`, `--- DELETE (dead path) ---`, `--- DELETE (one-shot) ---`, `--- TRIAGE ---`), each row showing `permission  <reason>`. Summary footer: `Summary: N DELETE, M TRIAGE`.
- **Files:** `.ccanvil/scripts/permissions-audit.sh`
- **Verify:** AC-8 passes.

### Step 8: Documentation
- **Test:** None.
- **Implement:** Update `.ccanvil/guide/command-reference.md` permissions-audit row block with the new subcommand and contract.
- **Files:** `.ccanvil/guide/command-reference.md`
- **Verify:** Read once for fidelity.

### Step 9: Dogfood
- **Test:** None (manual).
- **Implement:** Run `permissions-audit.sh promote-review` against the actual `.claude/settings.local.json` containing the two `ALLOW_OUTSIDE_WORKSPACE=1 bash ...` entries. Both should classify as DELETE (one-shot bypass, underlying `bash` now broadly allowed).
- **Files:** None.
- **Verify:** Two DELETE candidates surface as expected.

## Risks

- **Order-of-rules matters.** The classifier evaluates redundancy first, then dead path, then env-prefix. An entry that satisfies multiple rules takes the first match. Tests should hit each rule in isolation to lock the order.
- **Glob-vs-string-equality false negatives in AC-3.** `Bash(git:*)` in main covers `Bash(git status:--porcelain)` in local. The `Bash(<word> ` check requires a literal space; some entries might use `:` (e.g., `Bash(git:status)`). The two-pattern check (`Bash(<word> ` OR `Bash(<word>:`) covers both forms.
- **Env-prefix regex anchoring.** The pattern must anchor at the start of the inner permission (right after `Bash(`). Without anchoring, `Bash(echo ALLOW_X=1 bash)` would falsely match — but that's pathological; anchoring is the safe play.

## Definition of Done

- [ ] All 9 acceptance criteria from spec pass
- [ ] All existing tests still pass (1071 baseline → ~1080 expected)
- [ ] Dogfood: real settings.local.json shows expected classification
- [ ] Code reviewed (run /review)

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
