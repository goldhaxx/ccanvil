# Implementation Plan: Carve out template suffixes from dangerous-file scan

> Feature: bts-394-env-example-dangerous-file-carveout
> Work: linear:BTS-394
> Created: 1778377368
> Spec hash: d9891192
> Based on: docs/spec.md

## Objective

Stop `scan_dangerous_files` from flagging `.env.example` (and `.env.template`/`.env.sample`) by post-filtering basename-suffix matches, while preserving real-`.env*` flagging, secret-content scanning, and the existing allowlist surface.

## Sequence

Each step is one red-green-refactor cycle. Tests precede implementation.

### Step 1: AC-1 — `.env.example` no longer flags as dangerous-file

* **Test:** In `hub/tests/security-audit.bats`, add `@test "BTS-394 AC-1: .env.example does not flag as dangerous-file"`. Fixture: `echo 'API_KEY=YOUR_KEY' > .env.example; git add -A && git commit -q -m "add template"`. Run `bash "$SCRIPT" --files-only`; assert `[ "$status" -eq 0 ]` and `! echo "$output" | grep -q "dangerous-file"`.
* **Implement:** In `.ccanvil/scripts/security-audit.sh`'s `scan_dangerous_files` (\~L255), add `case "$file" in *.example|*.template|*.sample) continue ;; esac` immediately after the `while IFS= read -r file; do` line and before the `local detail=` line.
* **Files:** `.ccanvil/scripts/security-audit.sh`, `hub/tests/security-audit.bats`.
* **Verify:** Run `bats hub/tests/security-audit.bats --filter 'BTS-394 AC-1'`. Confirm RED on pre-impl, GREEN post-impl.

### Step 2: AC-2 — `.env.template` and `.env.sample` likewise carved

* **Test:** Add `@test "BTS-394 AC-2: .env.template and .env.sample do not flag as dangerous-file"`. One bats test, two fixtures (commit both); assert no `dangerous-file` lines and exit 0.
* **Implement:** No code change expected — Step 1's case statement already covers `*.template` and `*.sample`. This step exists to FAIL if Step 1's pattern was typoed (e.g., only `.example`).
* **Files:** `hub/tests/security-audit.bats`.
* **Verify:** `bats hub/tests/security-audit.bats --filter 'BTS-394 AC-2'` GREEN.

### Step 3: AC-3 — real `.env*` files still flag (regression guard)

* **Test:** Add `@test "BTS-394 AC-3: .env / .env.local / .env.production / .env.development.local still flag CRITICAL"`. Fixture: commit each filename (one per test, or four in a single test asserting four findings). Assert `[ "$status" -eq 1 ]` and `output` contains `dangerous-file` for each.
* **Implement:** No code change — case statement only matches the three template suffixes; `.env`, `.env.local`, etc. fall through to `add_finding`.
* **Files:** `hub/tests/security-audit.bats`.
* **Verify:** `bats … --filter 'BTS-394 AC-3'` GREEN. Existing test "detects tracked .env file" (line 101) must also still pass.

### Step 4: AC-4 — other dangerous extensions still flag even with `.example` suffix

* **Test:** Add `@test "BTS-394 AC-4: id_rsa.example still flags as dangerous-file"`. Fixture: `echo 'fake-rsa-key' > id_rsa.example`. Assert exit 1 and `dangerous-file` finding for the file.
* **Implement:** This requires the case statement to be conditional — only skip when the file matched the `\.env\.` pattern, NOT when it matched `id_rsa$`. Re-think Step 1's shape: instead of a global `continue` after read, check whether the matched `$pattern` is the `\.env\.` family. Implementation refinement: gate the suffix carve-out on `[[ "$pattern" == "\\.env\\."* ]]` so it only applies when the broad `\.env\.` regex was the matcher.
* **Files:** `.ccanvil/scripts/security-audit.sh`, `hub/tests/security-audit.bats`.
* **Verify:** `bats … --filter 'BTS-394 AC-4'` GREEN. Step 1/2/3 still GREEN — refined gate must not regress them.

### Step 5: AC-5 — secret-scan still fires on `.env.example` content

* **Test:** Add `@test "BTS-394 AC-5: .env.example with real GitHub PAT still triggers secret CRITICAL"`. Fixture: commit `.env.example` with `token = ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefgh1234`. Assert exit 1 and `secret` (not `dangerous-file`) finding.
* **Implement:** No code change expected — the carve-out only suppresses the `dangerous-file` category; secret-content scanning runs independently.
* **Files:** `hub/tests/security-audit.bats`.
* **Verify:** `bats … --filter 'BTS-394 AC-5'` GREEN.

### Step 6: AC-6 — legacy downstream allowlist entry stays harmless

* **Test:** Add `@test "BTS-394 AC-6: legacy .env.example::dangerous-file:: allowlist entry parses without error"`. Fixture: commit `.env.example` AND a `.security-audit-allowlist` containing `.env.example::dangerous-file::`. Assert exit 0 and no `WARN` / `ERROR` / `malformed` on stderr.
* **Implement:** No code change — allowlist parser already accepts the triple form; the carve-out runs before allowlist matching, making the entry redundant but legal.
* **Files:** `hub/tests/security-audit.bats`.
* **Verify:** `bats … --filter 'BTS-394 AC-6'` GREEN with `--separate-stderr`.

### Step 7: Manifest update

* **Test:** Run `bash .ccanvil/scripts/module-manifest.sh validate --json`. Confirm `drift == []`, `coverage.covered == coverage.total`, `status == "ok"`.
* **Implement:** Update the `scan_dangerous_files` `# @manifest` `purpose:` line in `security-audit.sh` to note the template-suffix carve-out (one short clause). No new entry-points or side-effects to declare.
* **Files:** `.ccanvil/scripts/security-audit.sh`.
* **Verify:** Manifest validate clean. Run full bats suite via `bash .ccanvil/scripts/bats-report.sh --parallel --progress` to confirm no broader regressions.

## Risks

* **Over-correction (Step 4 risk):** A naive `*.example` global skip would silently exempt `id_rsa.example`, `aws-credentials.sample`, etc. — files a malicious or sloppy contributor might commit thinking the suffix grants safety. Mitigation: gate the carve-out on the `\.env\.` pattern match specifically (Step 4's refined impl).
* **Subtle regex anchoring:** The `\.env\.` pattern matches `.env.example` because `\.env\.` only requires `.env.` somewhere in the path; if the suffix check uses the wrong shape (e.g., `*.example*`), real `.env.example.local` would slip through. Mitigation: case statement uses bash-glob `*.example|*.template|*.sample` which matches the suffix exactly.
* **Test fixture cross-contamination:** Each bats test uses its own `mktemp -d` repo via `setup()` — no cross-test pollution. But fixtures must `git add -A && commit` because some scans operate on `git ls-files`, not the working tree. Verified by mirroring the existing "detects tracked .env file" test pattern.

## Definition of Done

- [ ] AC-1 through AC-6 each have a passing bats test
- [ ] Existing security-audit.bats tests (28 — including BTS-152 + 7c474b2 regression cases) still pass
- [ ] Full bats suite passes (`bash .ccanvil/scripts/bats-report.sh --parallel --progress`)
- [ ] `module-manifest.sh validate` clean: 194/194, drift 0
- [ ] `/review` clean (run before `/pr`)
- [ ] PR title `feat(bts-394-env-example-dangerous-file-carveout): Carve out template suffixes from dangerous-file scan`
