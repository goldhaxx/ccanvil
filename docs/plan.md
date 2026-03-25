# Implementation Plan: Activate Commit Sequencing

> Feature: activate-commit-sequencing
> Created: 1774403940
> Spec hash: e18c2570
> Based on: docs/spec.md

## Objective

Make `docs-check.sh activate` auto-commit spec changes on the feature branch so specs never need to be committed to `main`, eliminating post-squash-merge divergence.

## Sequence

### Step 1: Targeted worktree check — allow uncommitted spec files (AC-1, AC-2, AC-3)

- **Test:** Three tests in `feature-lifecycle.bats`:
  1. `activate` succeeds when `docs/specs/<id>.md` is uncommitted (write spec, don't commit, run activate)
  2. `activate` succeeds when both `docs/specs/<id>.md` and `docs/spec.md` are uncommitted
  3. `activate` fails when a non-spec file (e.g., `README.md`) is uncommitted
- **Implement:** Replace the blanket `git status --porcelain` check in `cmd_activate` (lines 683–687) with a targeted check: filter porcelain output, reject only if lines refer to files outside `docs/specs/` and `docs/spec.md`
- **Files:** `scripts/docs-check.sh`, `tests/feature-lifecycle.bats`
- **Verify:** New tests pass; AC-3 confirms safety guard still works

### Step 2: Auto-commit on branch (AC-4, AC-5, AC-6)

- **Test:** Three tests:
  1. After `activate`, branch has one new commit containing the spec files (check `git log --oneline` count and `git diff-tree`)
  2. Commit message is `docs(lifecycle): activate <feature-id>`
  3. After `activate`, `git status --porcelain` is empty (clean worktree)
- **Implement:** After status update and `cp`, add `git add` for the specific spec file and `docs/spec.md`, then `git commit` with convention message. Handle both untracked (new) and modified spec files.
- **Files:** `scripts/docs-check.sh` (after current line 711)
- **Verify:** New tests pass; worktree is clean after activate

### Step 3: Update existing tests for new behavior (AC-7, AC-8, AC-9)

- **Test:** Update the four existing activate tests:
  1. `creates branch with correct naming convention` — leave spec uncommitted instead of pre-committing
  2. `copies spec to docs/spec.md` — same; verify spec.md exists with In Progress status
  3. `updates spec status to In Progress` — same; check committed file
  4. `fails if another spec is In Progress` — blocking spec still needs to be committed (prior activation); target spec can be uncommitted
  5. `fails if feature-id not found` — no change needed
- **Implement:** Remove `git add -A && git commit` lines from tests where the activated spec no longer needs pre-committing
- **Files:** `tests/feature-lifecycle.bats` (lines 143–233)
- **Verify:** `bats tests/feature-lifecycle.bats` — all pass

### Step 4: Squash-merge simulation test (AC-10)

- **Test:** One integration test simulating the full lifecycle:
  1. Create spec in `docs/specs/` (uncommitted)
  2. Run `activate` → branch created, spec auto-committed on branch
  3. Add an implementation commit on the branch
  4. Switch to `main`, `git merge --squash`, commit
  5. Verify: `main` has clean linear history — spec changes only in the squash commit, not in a separate pre-branch commit
- **Implement:** Pure test — no code changes
- **Files:** `tests/feature-lifecycle.bats`
- **Verify:** Test passes; confirms the divergence fix

### Step 5: Full suite verification

- **Test:** Run `bats tests/` — all tests pass
- **Implement:** Fix any breakage from the worktree-check change in other tests
- **Files:** Any test files that break
- **Verify:** `bats tests/` exits 0

## Risks

- **Untracked vs modified spec files:** `git status --porcelain` shows `??` for untracked and ` M`/`M ` for modified. The targeted filter must handle both prefixes. Mitigation: AC-1 tests untracked, AC-2 tests modified `docs/spec.md` alongside untracked spec.
- **Blocking spec detection with dirty worktree:** The "another spec is In Progress" check reads `docs/specs/` files. If a new spec is untracked, `parse_metadata` still works on the file (it reads from disk, not git). No risk here.
- **Tests that commit specs before activate:** Existing tests follow the old pattern. Step 3 updates them — but must verify the blocking-spec test still works (the *blocking* spec is a pre-existing committed spec, not the one being activated).

## Definition of Done

- [ ] All acceptance criteria from spec pass (AC-1 through AC-10)
- [ ] All existing tests still pass
- [ ] Code reviewed (run /review)

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /scaffold-pull. -->
