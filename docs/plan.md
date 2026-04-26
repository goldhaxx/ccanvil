# Implementation Plan: assert-pr-title substrate primitive

> Feature: bts-178-assert-pr-title
> Work: linear:BTS-178
> Created: 1777217843
> Spec hash: bd786252
> Based on: docs/spec.md

## Objective

Add a deterministic substrate command that asserts the PR title matches the spec-derived expected form, with a force-update path for placeholder titles. Wire it into `/pr` so the squash-merge commit on main never carries a placeholder.

## Sequence

### Step 1: failing test for AC-1 (no-op happy path)
- **Test:** new `hub/tests/assert-pr-title.bats` — fixture creates `docs/spec.md` with feature-id `bts-X` and Summary first-line "Test feature". Stub `gh` on PATH that responds to `pr view --json title --jq .title` with `feat(bts-X): Test feature` (matching expected). Run `assert-pr-title 100`, assert exit 0, JSON `{updated:false, ...}`, stub-log shows `pr view` called and `pr edit` NOT called.
- **Implement:** add `cmd_assert_pr_title()` skeleton + dispatch case. Read PR title via `gh pr view`, compute expected from `docs/spec.md` using the same logic as `cmd_activate`, compare prefix, emit no-op JSON if match.
- **Files:** `.ccanvil/scripts/docs-check.sh`, `hub/tests/assert-pr-title.bats`.
- **Verify:** AC-1 green.

### Step 2: AC-2 force-update on placeholder
- **Test:** stub `gh pr view` returns `feat(auth-system): Auth feature.` Run `assert-pr-title 100`, assert exit 0, JSON `{updated:true, actual:"feat(auth-system): Auth feature.", expected:"feat(bts-X): ..."}`, stub-log shows `pr edit 100 --title "feat(bts-X): ..."` called.
- **Implement:** add placeholder-shape detection regex (`^feat\((auth-system|default)\)` OR doesn't start with `feat(<feature-id>):`). When matched, call `gh pr edit <n> --title "<expected>"` and emit `updated:true` JSON.
- **Files:** `.ccanvil/scripts/docs-check.sh`, `hub/tests/assert-pr-title.bats`.
- **Verify:** AC-2 green; AC-1 still green.

### Step 3: AC-3 no-op when prefix matches but summary diverges
- **Test:** stub `gh pr view` returns `feat(bts-X): user-edited summary text`. Run, assert no edit call (we trust user edits to summary text as long as prefix is correct), JSON `updated:false`.
- **Implement:** prefix-only comparison — match `^feat(<feature-id>):` regardless of trailing text. If matches, no-op.
- **Files:** `hub/tests/assert-pr-title.bats`.
- **Verify:** AC-3 green.

### Step 4: AC-4 post-cleanup spec recovery
- **Test:** fixture has NO `docs/spec.md` but has `docs/specs/bts-X-feature.md`. Branch is set via the test (mock or real-ish — `git init` + `git checkout -b claude/feat/bts-X-feature`). Run `assert-pr-title 100`. Assert it derives feature-id from branch name and reads the archive successfully.
- **Implement:** when `docs/spec.md` absent, read branch via `git branch --show-current`, strip `claude/feat/` prefix to get feature-id, look in `docs/specs/<feature-id>.md`. If found, use; otherwise fall to AC-5.
- **Files:** `.ccanvil/scripts/docs-check.sh`, `hub/tests/assert-pr-title.bats`.
- **Verify:** AC-4 green.

### Step 5: AC-5 + AC-6 error paths
- **Test:** (a) no spec.md, no archive, branch can't recover feature-id → non-zero exit + clear error. (b) `gh` not on PATH (achieved by overriding PATH to a directory without gh) → non-zero exit + clear error.
- **Implement:** guard clauses at the top of `cmd_assert_pr_title` for gh availability and spec-source availability. Each emits the spec'd stderr and exits non-zero.
- **Files:** `.ccanvil/scripts/docs-check.sh`, `hub/tests/assert-pr-title.bats`.
- **Verify:** AC-5, AC-6 green; happy paths still green.

### Step 6: AC-7 skill drift-guard + skill prose update
- **Test:** new `hub/tests/pr-skill-assert-title.bats` — assert `.claude/skills/pr/SKILL.md` contains a literal `assert-pr-title` invocation in the post-`gh pr ready` step (between the "ready" step and the body-update step). Negative assertion: confirms the call is positioned AFTER the ready transition (so the title fix lands before merge).
- **Implement:** edit `.claude/skills/pr/SKILL.md` Step 9 (PR ready section) to call `bash .ccanvil/scripts/docs-check.sh assert-pr-title <PR-N>` after `gh pr ready`. Use the PR number from `gh pr view --json url` parsing or the URL from earlier in the flow.
- **Files:** `.claude/skills/pr/SKILL.md`, `hub/tests/pr-skill-assert-title.bats`.
- **Verify:** AC-7 green.

### Step 7: full suite + docs update
- **Verify:** `bash .ccanvil/scripts/bats-report.sh --parallel` — full suite green (1456 → ~1465).
- **Docs update:** add row to `.ccanvil/guide/command-reference.md` for `docs-check.sh assert-pr-title`.
- **Live-validation gate consideration:** this command depends on `gh` CLI behavior, which is well-documented and stable; no live-API-contract uncertainty flags surfaced. Stub-only tests are sufficient. (BTS-171 gate does not fire.)

## Risks

- **Branch-name parsing.** AC-4's recovery depends on the `claude/feat/<feature-id>` convention. If the user's branch naming differs (e.g. `feat/<id>` without the `claude/` prefix), recovery falls through to AC-5. Mitigation: support both `claude/feat/` AND `feat/` prefixes; accept anything matching `^[^/]+/feat/(.+)$` after the last `/`.
- **`gh pr view` permissions.** The user must be authenticated. Failure to fetch (e.g. `gh auth status` not OK) surfaces as a non-zero exit from `gh` — captured and reported as an error. Test covers the "gh unavailable" case but not the "gh present but unauthenticated" case; the substrate's behavior should be a clean propagation of `gh`'s error.
- **Title comparison edge: trailing whitespace / smart quotes.** Compare via prefix-only regex match; don't require exact equality of the suffix.

## Definition of Done

- [ ] All 7 acceptance criteria from spec pass
- [ ] All 1456+ existing tests still pass via `bats-report.sh --parallel`
- [ ] `command-reference.md` updated with new subcommand
- [ ] `/pr` skill prose updated to call `assert-pr-title`
- [ ] Code reviewed (skip /review per cut-line — small substrate primitive, drift-guards in place)

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
