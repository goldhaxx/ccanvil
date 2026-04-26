# Implementation Plan: BTS-169 — guard-workspace `//` jq operator exemption

> Feature: bts-169-workspace-fence-jq-operator-exemption
> Work: linear:BTS-169
> Created: 1777173200
> Spec hash: 355acd02
> Based on: docs/spec.md

## Objective

Add a one-line skip rule in `guard-workspace.sh`'s path-token scan that exempts pure-slash tokens (`/`, `//`, `///`, etc.), eliminating the recurring false-positive on jq's `//` alternative-default operator while preserving the workspace fence's protection against real outside-workspace paths.

## Sequence

### Step 1: Red — write tests for AC-1 through AC-5

- **Test:** Add a new bats test file `hub/tests/guard-workspace-jq-exemption.bats` (or extend `hub/tests/guard-hooks.bats`) with five tests covering: (1) jq `//` operator passes, (2) real outside-workspace path still blocks, (3) `///` and `////` pass, (4) `//foo/bar` still blocks, (5) bare `/` still passes.
- **Implement:** Test-only commit; tests should fail initially (since the fix isn't applied yet) — specifically AC-1 and AC-3 should fail, AC-2 / AC-4 / AC-5 already pass against current behavior.
- **Files:** `hub/tests/guard-workspace-jq-exemption.bats` (new).
- **Verify:** Run `bats hub/tests/guard-workspace-jq-exemption.bats` — AC-1 and AC-3 fail (with the expected "BLOCKED: path '//' is outside workspace" stderr), AC-2 / AC-4 / AC-5 pass.

### Step 2: Green — apply the one-line fix

- **Test:** AC-1 and AC-3 transition from failing to passing.
- **Implement:** Add `[[ "$token" =~ ^/+$ ]] && continue` inside the `for token in $NORMALIZED` loop in `.claude/hooks/guard-workspace.sh`, immediately before `case "$token" in`. Update the script header's "Known limitations" comment block to reflect the new exemption (one bullet: "BTS-169: pure-slash tokens (`/`, `//`, `///`) are skipped before the path scan to avoid false-positives on jq's `//` alternative-default operator.").
- **Files:** `.claude/hooks/guard-workspace.sh` (modified — one regex line + one comment line).
- **Verify:** Re-run the bats file: all five tests pass. Then run the full suite with `bash .ccanvil/scripts/bats-report.sh --parallel` to confirm no regressions in unrelated tests (existing `guard-hooks.bats` should stay green).

### Step 3: Hub doc update — note the exemption in the hooks guide

- **Test:** N/A — doc step.
- **Implement:** Update the `guard-workspace.sh` row in `.ccanvil/guide/hooks.md` (and `.ccanvil/templates/hooks-reference.md` if the row exists there) to mention the BTS-169 exemption in the "Known limitations" or behavior column. One short clause is sufficient.
- **Files:** `.ccanvil/guide/hooks.md` (modified). `.ccanvil/templates/hooks-reference.md` only if it has a parallel row.
- **Verify:** Read back the diff. Confirm the clause is concise and not redundant with the in-script comment.

## Risks

- **Hidden token cases.** The regex `^/+$` matches *exactly* tokens that are all slashes. If a token is something like `/  /` (with whitespace inside) it wouldn't match — but tokenization splits on whitespace, so such a token can't exist after the `for token in $NORMALIZED` split. Mitigation: covered by AC-3's drift-guard for `///` and `////`.
- **Quote-stripping side effect.** The `tr -d '"'` and `tr -d "'"` in the existing tokenizer could collapse `"/foo bar/"` into the token `/foo bar/`, which then becomes two tokens (`/foo` and `bar/`) after whitespace split. This is pre-existing behavior, not introduced by this fix. Mitigation: not in scope; if it becomes a problem, capture as a separate idea.
- **POSIX `//` paths.** Per spec Out-of-Scope: we explicitly do not handle `//foo/bar`-style POSIX vendor paths. AC-4 enforces this by asserting `//foo/bar` continues to block. If anyone tries to use `//`-prefixed real paths, they prefix `ALLOW_OUTSIDE_WORKSPACE=1`.

## Definition of Done

- [ ] All 6 acceptance criteria from spec pass.
- [ ] Full suite green (`bash .ccanvil/scripts/bats-report.sh --parallel`).
- [ ] Header comment in `guard-workspace.sh` updated with BTS-169 exemption note.
- [ ] Hub guide row in `.ccanvil/guide/hooks.md` updated.
- [ ] /review run on the diff (substrate hook change → /review applies; not pure prose).

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
