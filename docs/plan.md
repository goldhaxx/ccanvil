# Implementation Plan: Add cat to guard-workspace verb regex

> Feature: bts-153-gate-cat
> Work: linear:BTS-153
> Created: 1777153800
> Spec hash: 6253bcc2
> Based on: docs/spec.md

## Objective

One-line change to `guard-workspace.sh` — add `cat` to the gated-verb regex. Same shape as BTS-157.

## Sequence

### Step 1: Tests (red)
- **Test:** New BTS-153 block in `guard-hooks.bats` after BTS-157: blocked (`cat ~/.ssh/id_rsa`, `cat /etc/passwd`, `cat ~/.zshrc`, pipe with `/etc/foo`), allowed (workspace path, relative, `/tmp/foo`, `/dev/null`, plain heredoc, `xcat /etc/foo`), bypass.
- **Files:** `hub/tests/guard-hooks.bats`.
- **Verify:** Blocked-case tests fail (verb regex misses cat).

### Step 2: Add cat to verb regex
- **Implement:** Add `cat` to alternation in `guard-workspace.sh:32`. Update header comment to note cat is read-only with exfiltration threat model.
- **Files:** `.claude/hooks/guard-workspace.sh`.
- **Verify:** All BTS-153 tests green.

### Step 3: Regression sweep + lint
- **Verify:** `bats-report.sh --parallel`: 1206 / 1206 green. `bats-lint.sh hub/tests/guard-hooks.bats` clean.

## Risks

- **Operator friction.** `cat ~/.zshrc` is a common ad-hoc inspection. The bypass envelope mitigates; the hook stderr makes it discoverable.
- **Read-tool asymmetry.** Acknowledged in spec Out of Scope; not addressed here.

## Definition of Done

- [ ] All 11 named ACs pass via bats (AC-12 = full suite)
- [ ] Lint clean
- [ ] Code reviewed via `/review`
