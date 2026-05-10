# Feature: Carve out template suffixes from dangerous-file scan

> Feature: bts-394-env-example-dangerous-file-carveout
> Work: linear:BTS-394
> Created: 1778377368
> Subject: Carve out template suffixes from dangerous-file scan
> Status: In Progress

## Summary

`security-audit.sh`'s `scan_dangerous_files` flags `.env.example` as a tracked dangerous file because the `\.env\.` regex catches it alongside genuinely sensitive `.env.local` / `.env.production` patterns. `.env.example` is the canonical environment-variable template — committed by design with placeholder values — and every downstream node tracking one currently has to add a `.env.example::dangerous-file::` allowlist entry to silence the false positive. Carve out template suffixes (`.example`, `.template`, `.sample`) at the upstream so this workaround disappears across the fleet.

## Job To Be Done

**When** a downstream node tracks the canonical `.env.example` template,
**I want to** run `bash .ccanvil/scripts/security-audit.sh` without it firing CRITICAL on the template,
**So that** CI stays green without per-node allowlist boilerplate while real `.env*` files keep getting flagged.

## Acceptance Criteria

- [ ] **AC-1:** **Given** a git repo with `.env.example` tracked and otherwise clean, **when** `bash .ccanvil/scripts/security-audit.sh` runs, **then** no `dangerous-file` finding is emitted for `.env.example` and the exit code is 0.
- [ ] **AC-2:** When `.env.template` or `.env.sample` is tracked, same result as AC-1 — no `dangerous-file` finding. The carve-out covers the three conventional template-suffix names.
- [ ] **AC-3 (no regression on real env files):** When `.env`, `.env.local`, `.env.production`, or `.env.development.local` is tracked, the audit STILL emits CRITICAL `dangerous-file` for that file. The carve-out applies only when the basename ends in `.example`, `.template`, or `.sample`.
- [ ] **AC-4 (no regression on other dangerous extensions):** When `id_rsa`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `*.jks`, `*.keystore`, `*.credentials` are tracked, they STILL flag CRITICAL — the suffix carve-out is scoped to the `\.env\.` pattern's false-positive surface and does not exempt other dangerous extensions even if they happen to end in `.example` (e.g., `id_rsa.example` still flags).
- [ ] **AC-5 (defense-in-depth preserved):** When `.env.example` contains a real GitHub PAT or other secret pattern, the secret-scan still emits CRITICAL on the content (the carve-out is per-category — only `dangerous-file` for the file-extension match is suppressed; secret content scanning is untouched).
- [ ] **AC-6 (forward-compat):** Existing downstream nodes whose `.security-audit-allowlist` carries `.env.example::dangerous-file::` (the pre-fix workaround) remain functional — the entry becomes redundant but harmless. No new error or warn surfaces from the unused allowlist line.

## Affected Files

| File | Change |
| -- | -- |
| `.ccanvil/scripts/security-audit.sh` (`scan_dangerous_files` \~L255) | Modified — post-filter on basename suffix |
| `hub/tests/security-audit.bats` | Modified — add 4-6 regression tests covering AC-1/2/3/4/5 |

## Dependencies

* **Requires:** none — self-contained substrate fix.
* **Blocked by:** none.

## Out of Scope

* Other false-positive surfaces in `security-audit.sh` (BTS-395 — email regex on URI strings — handled separately).
* Generalizing the template-suffix carve-out beyond `.env.*` (e.g., to a global "skip files ending in `.example`/`.template`/`.sample`" filter). Keep the carve-out narrow to the `\.env\.` pattern's documented false-positive surface; broader generalization can be a follow-up if more cases surface.
* Removing existing downstream `.env.example::dangerous-file::` allowlist entries from individual nodes — out-of-scope coordination work; the entries are harmless after the fix and can be cleaned up at each node's discretion.

## Implementation Notes

* Implementation pattern: post-filter in `scan_dangerous_files` after the `grep -E "$pattern"` matches arrive. Per the ticket's analysis, `grep -E` does not support negative lookahead, so a regex-only fix isn't viable; the post-filter is simpler and easier to test.
* Suggested shape: after `grep -E "$pattern"` returns a candidate `$file`, apply `case "$file" in *.example|*.template|*.sample) continue ;; esac` before the `is_allowlisted` / `add_finding` block. Keeps the dangerous-extensions list intact (still authoritative) and adds one cheap basename-suffix check per match.
* Manifest impact: `scan_dangerous_files` already has a `# @manifest` block at the function level (verify); update its `purpose:` line if the carve-out behavior is documented there. No new entry-point or side-effect to declare.
* Test design: add fixtures under existing `# Sensitive files` section in `security-audit.bats`. Mirror the shape of "detects tracked .env file" test (line 101) — create the fixture file, `git add && commit`, run audit, assert exit code + grep output. RED-then-GREEN: each test must FAIL on the unmodified script before the carve-out lands.
