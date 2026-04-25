# Feature: Gate `cat` outside `~/projects/` via workspace fence

> Feature: bts-153-gate-cat
> Work: linear:BTS-153
> Created: 1777153767
> Status: In Progress

## Summary

Add `cat` to `guard-workspace.sh`'s gated-verb regex. The fence currently catches mutation verbs (rm/cp/mv/chmod/chown/bash/find/sort) but allows `cat` to read any path the operator can access — including sensitive files like `~/.ssh/id_*`, `~/.aws/credentials`, and `/etc/*`. Same one-line change pattern as BTS-157. Last child of BTS-158 — landing this lets the umbrella close.

## Job To Be Done

**When** an agent or operator runs `cat <path>` where `<path>` is outside `~/projects/` and not whitelisted,
**I want to** have the workspace fence block the read,
**So that** sensitive credentials and configuration outside the workspace cannot be read into Claude's context without explicit operator opt-in.

## Acceptance Criteria

- [ ] **AC-1:** `cat ~/.ssh/id_rsa` exits 2 via guard-workspace; stderr identifies the path.
- [ ] **AC-2:** `cat /etc/passwd` exits 2.
- [ ] **AC-3:** `cat ~/.zshrc` exits 2 (sensitive operator config).
- [ ] **AC-4:** `cat ~/projects/ccanvil/CLAUDE.md` exits 0 (inside workspace).
- [ ] **AC-5:** `cat ./relative/path` exits 0 (relative path; no fence violation).
- [ ] **AC-6:** `cat /tmp/foo` exits 0 (whitelisted system temp).
- [ ] **AC-7:** `cat /dev/null` exits 0 (whitelisted device).
- [ ] **AC-8 (bypass):** `ALLOW_OUTSIDE_WORKSPACE=1 cat ~/.ssh/id_rsa` exits 0.
- [ ] **AC-9 (word anchor):** `xcat /etc/foo` exits 0 — `cat` regex requires word boundary.
- [ ] **AC-10:** Pipelines: `cat /etc/foo | grep x` exits 2 — `/etc/foo` is path-token-fenced.
- [ ] **AC-11:** Heredoc-style: `cat << EOF` (no path arg) exits 0 — no path tokens to fence.
- [ ] **AC-12 (existing gates intact):** Validated by full `bats-report.sh --parallel` run.

## Affected Files

| File | Change |
|------|--------|
| `.claude/hooks/guard-workspace.sh` | Add `cat` to gated-verb regex (line 31), refresh header comment |
| `hub/tests/guard-hooks.bats` | ~10 BTS-153 tests |

## Dependencies

- **Requires:** Nothing.
- **Blocked by:** Nothing.

## Out of Scope

- **`head`, `tail`, `less`, `more`.** Same family per BTS-158 but not in this ticket. Capture follow-ups if they become operationally relevant.
- **Read tool asymmetry.** The Read tool can read any path without any hook check. The bash `cat` gate is intentionally tighter than Read — operators tend to use bash for ad-hoc inspection of system files; Read is reserved for in-codebase reads. If asymmetry becomes a real friction point, addressed via BTS-150 (prompt-and-persist drift) or a parallel Read-side gate.
- **Variable indirection** (`cat $SOMEFILE`). Same caveat as the existing rm/cp/mv set; documented in known-limitations.
- **Pipeline-source masking.** `bash -c "cat /etc/foo"` already trips the fence (because `bash` is gated AND `/etc/foo` is in the literal string). No new logic needed.

## Implementation Notes

- One-line change to `guard-workspace.sh:32`: add `cat` to the alternation.
- Refresh the header comment: `cat` is read-only; the threat model is exfiltration-to-context, not mutation. Note this distinction in the comment so a reader understands why a read verb is in the "mutation" list.
- Tests mirror BTS-157's pattern.
