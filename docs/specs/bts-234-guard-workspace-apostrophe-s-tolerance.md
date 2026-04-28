# Feature: guard-workspace tolerates apostrophe-s on slash-command tokens

> Feature: bts-234-guard-workspace-apostrophe-s-tolerance
> Work: linear:BTS-234
> Created: 1777335556
> Status: Complete

## Summary

`guard-workspace.sh`'s pre-tokenization `tr -d '"' | tr -d "'"` strips apostrophes BEFORE the BTS-173 slash-command allowlist sees the token. So a possessive form like `/recall's` becomes `/recalls`, which doesn't match the allowlist (only `/recall` is registered). The token then falls through to path-shape detection and gets blocked — even after BTS-210's trailing-punct tolerance, because the apostrophe is gone before the regex runs.

This ship combines the ticket's recommended option (c) (don't globally strip apostrophes) with option (b) (extend the BTS-173 regex to tolerate trailing `'s`) plus a per-token strip so single-quoted absolute paths like `'/etc/passwd'` continue to trip the workspace fence (security parity preservation).

## Job To Be Done

**When** I run a bash command (most commonly `git commit -m "..."` with `-c` flags that bypass the BTS-151 git-commit skip, or any command with a gated verb like `cat`/`bash`) whose argument string contains `/<known-slash-command>'s` (apostrophe-s possessive),
**I want to** have the workspace fence allow the token through without requiring `ALLOW_OUTSIDE_WORKSPACE=1`,
**So that** prose narrative containing slash-command possessives (commit messages, echo args, log lines) is no longer a recurring friction surface.

## Acceptance Criteria

Each criterion is independently testable. Binary pass/fail.

- [ ] **AC-1:** `bash -c 'echo "during /recall'\''s wrap"'` no longer trips the fence — the `/recall's` token is recognized as a slash-command possessive and skipped. Exit 0.

- [ ] **AC-2:** `bash -c 'echo "wrap /recall'\''s."'` (apostrophe-s followed by trailing period) is also tolerated. The trailing punct rule (BTS-210) applies AFTER the optional `'s`. Exit 0.

- [ ] **AC-3:** `cat /tmp/note-/idea-clean` (no apostrophe, just slash-command name) still works — no regression on the BTS-210 baseline. Exit 0.

- [ ] **AC-4:** `bash -c "rm '/etc/passwd'"` (single-quoted absolute outside-workspace path) STILL blocks. Exit 2. The per-token apostrophe strip preserves the security fence for quoted-path attacks; only the global strip is removed.

- [ ] **AC-5:** `bash -c 'echo "/unknown'\''s thing"'` (apostrophe-s on a NAME that isn't a known slash-command) still blocks. Exit 2 — the allowlist still gates which possessives are tolerated, not arbitrary slash-prefixed-`'s` tokens.

- [ ] **AC-6:** `bash -c "echo /etc"` (bare unknown path, no apostrophe) still blocks. Exit 2 — pure regression check on the existing path-shape gate.

- [ ] **AC-7:** New bats `hub/tests/guard-workspace-apostrophe-tolerance.bats` covers AC-1 through AC-6 plus a drift-guard for `BTS-234` inline in `guard-workspace.sh`.

- [ ] **AC-8:** Full bats suite remains green at ≥ 1805 (post-BTS-233 baseline). Existing `guard-workspace-prose-tolerance.bats` (BTS-210, 17 tests) continues to pass — apostrophe-s tolerance is additive.

## Affected Files

| File | Change |
|------|--------|
| `.claude/hooks/guard-workspace.sh` | (1) Remove `\| tr -d "'"` from the global `NORMALIZED=` line. (2) Extend the BTS-173 slash-command regex to include an optional `('\''s)?` group between the captured name and the trailing-punct run. (3) Inside the path-shape check, strip leading/trailing single quotes from the token first to preserve security parity for `'/etc/passwd'`-style attacks. |
| `hub/tests/guard-workspace-apostrophe-tolerance.bats` | New bats covering AC-1 through AC-7. Mirrors the BTS-210 test structure. |

## Dependencies

- **Requires:** BTS-173 (slash-command allowlist substrate); BTS-210 (trailing-punct tolerance — sibling concern). Both shipped.
- **Blocked by:** Nothing.

## Out of Scope

- **Generalized possessive tolerance for other languages.** ASCII apostrophe (`'`, U+0027) only. Curly apostrophes (`'`) and other Unicode possessives are not covered.
- **Apostrophe-s tolerance for non-slash-command tokens.** Random possessives like `Sam's_dir` are not slash-commands; they pass through pre-existing tokenization unchanged.
- **Refactoring the quote-strip into a tokenizer.** That's the larger guard-workspace rewrite (separate concern). This ship is a surgical regex-and-strip change.
- **Tolerating `'s` on slash-command-like tokens that AREN'T in the allowlist.** AC-5 explicitly verifies this stays blocked.

## Implementation Notes

- **Regex update:** the BTS-210 regex currently is `^/([a-zA-Z][a-zA-Z0-9_-]{0,29})[${slash_command_trailing_punct}]*$`. Insert an optional `('\''s)?` group between the capture and the trailing punct: `^/([a-zA-Z][a-zA-Z0-9_-]{0,29})('\''s)?[${slash_command_trailing_punct}]*$`. Bash regex needs the apostrophe escaped via concatenation since the regex literal is in a `[[ ... =~ ... ]]` context.
- **Why `('s)?` and not `(['"'"']s)?`:** ASCII apostrophe only (per Out of Scope). The simple form is clearer and the test coverage is precise.
- **Per-token apostrophe strip for security:** after the slash-command allowlist check (which uses the unstripped `$token`), strip leading/trailing `'` to compute `path_token` for the path-shape `case`. This preserves the existing fence for `'/etc/passwd'` attacks.
- **Test fixture pattern:** mirror `guard-workspace-prose-tolerance.bats` (BTS-210). Build a minimal `.claude/skills/recall/` directory inside `BATS_TEST_TMPDIR` so the allowlist resolver finds it; pipe the `tool_input.command` JSON to the hook; assert exit code.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
