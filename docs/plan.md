# Implementation Plan: Live-API diagnostic surfacing — WARN-on-failure + safe JSON pipe

> Feature: bts-219-live-api-diagnostic-surfacing
> Work: linear:BTS-219
> Created: 1777318789
> Spec hash: 0c0d07e9
> Based on: docs/spec.md

## Objective

Add structured WARN-on-failure diagnostics to `cmd_artifact_read`'s linear branch (closes BTS-219), and replace the broken `echo "$VAR" | jq` pattern with `jq <<< "$VAR"` in drift-watchdog's verification block (closes BTS-227).

## Sequence

Each step is one red-green-refactor cycle. Steps 1-2 are research/scaffolding; 3-5 are AC-1/2/3 (BTS-219 core); 6-7 are AC-4/5 (BTS-227); 8 is the gate.

### Step 1: Inspect existing failure paths in `cmd_artifact_read`

- **Test:** None — research.
- **Implement:** Read `cmd_artifact_read` linear branch (lines ~4670-4710 of `docs-check.sh`). Identify exit points:
  - L4685: `[[ -z "$ticket" ]] && { echo "ERROR: ..." >&2; return 2; }` — input-validation, not Linear-API
  - L4689: `bash linear-query.sh resolve-document-id ...` — silent on failure
  - L4694: `bash linear-query.sh get-document "$doc_id" 2>"$err"` — captures stderr
  - L4699: `if [[ $rc -ne 0 ]]` — error branch where WARN should land
  - L4702-L4703: distinguishes "Entity not found" → return 2 from other → return 3
- **Files:** Read-only inspection.
- **Verify:** Confirm the four failure classes can be detected via stderr-grep:
  - `auth-missing`: stderr matches `LINEAR_API_KEY` or `Authentication required`
  - `not-found`: stderr matches `Entity not found`
  - `network-error`: stderr matches `curl:` or `Connection refused` or `Could not resolve`
  - `parse-error`: stderr matches `parse error` (jq's class) or `Unexpected token`

### Step 2: Determine the WARN format + retry recipes

- **Test:** None — design.
- **Implement:** Lock the WARN line shape:
  ```
  WARN: artifact-read: <class> — <one-line context>
  Retry: <copy-pasteable command>
  ```
  Where `<class>` is one of `auth-missing | not-found | network-error | parse-error`. The retry recipe is class-specific:
  - `auth-missing`: `Set LINEAR_API_KEY in env or source .env from project root`
  - `not-found`: `Verify ticket BTS-N has a parented Document of kind=<kind>; check at <linear-url>`
  - `network-error`: `Check network connectivity; retry: bash docs-check.sh artifact-read --kind <k> --feature <f>`
  - `parse-error`: `bash linear-query.sh get-document <doc-id> > /tmp/x.json; inspect`
- **Files:** None — locks design before implementation.

### Step 3 (RED): Write the WARN-on-failure bats test

- **Test:** Create `hub/tests/artifact-read-warn.bats`. Stub `linear-query.sh` per the existing pattern in `hub/tests/ssot-linear.bats` (mock script in `$BATS_TEST_TMPDIR/scripts/`, prepended to PATH). Four test blocks:
  - `auth-missing`: stub emits `ERROR: LINEAR_API_KEY not set` to stderr + exit 1
  - `not-found`: stub emits `Entity not found: Document` to stderr + exit 1
  - `network-error`: stub emits `curl: (6) Could not resolve host` to stderr + exit 6
  - `parse-error`: stub emits non-JSON to stdout + exit 0; cmd_artifact_read's downstream jq fails
  Each test asserts: stderr contains `^WARN: artifact-read: <class>`, exit code matches spec semantics (2 for not-found, 3 otherwise), retry recipe present.
- **Implement:** New bats file with stubbed `linear-query.sh` + 4 test blocks.
- **Files:** `hub/tests/artifact-read-warn.bats` (new).
- **Verify:** `bash .ccanvil/scripts/bats-report.sh -f artifact-read-warn` reports 4 failures (no WARN block exists yet).

### Step 4 (GREEN): Add WARN classification block to `cmd_artifact_read`

- **Test:** Re-run `bats-report.sh -f artifact-read-warn` after each class added.
- **Implement:** In `cmd_artifact_read`'s linear branch (line ~4699 area), before the `cat "$err" >&2 + return` branch, add classification logic:
  ```bash
  if [[ $rc -ne 0 ]]; then
    cat "$err" >&2
    local warn_class="parse-error"
    if grep -qE 'LINEAR_API_KEY|Authentication required' "$err"; then
      warn_class="auth-missing"
      echo "WARN: artifact-read: auth-missing — Linear API key missing or invalid" >&2
      echo "Retry: Set LINEAR_API_KEY in env or source .env from project root" >&2
    elif grep -qE 'Entity not found' "$err"; then
      warn_class="not-found"
      echo "WARN: artifact-read: not-found — Document for kind=$kind ticket=$ticket does not exist" >&2
      echo "Retry: Verify ticket has a parented Document of kind=$kind" >&2
    elif grep -qE 'curl:|Connection refused|Could not resolve' "$err"; then
      warn_class="network-error"
      echo "WARN: artifact-read: network-error — Could not reach Linear API" >&2
      echo "Retry: Check network; bash docs-check.sh artifact-read --kind $kind --feature $feature" >&2
    else
      echo "WARN: artifact-read: parse-error — Unexpected response from Linear API" >&2
      echo "Retry: bash linear-query.sh get-document $doc_id > /tmp/x.json; inspect" >&2
    fi
    rm -f "$err"
    [[ "$warn_class" == "not-found" ]] && return 2
    return 3
  fi
  ```
- **Files:** `.ccanvil/scripts/docs-check.sh`.
- **Verify:** All 4 `artifact-read-warn` tests pass.

### Step 5: Verify exit-code semantics preserved

- **Test:** Add an assertion to each test in `artifact-read-warn.bats`: `not-found` → exit 2, all others → exit 3. Plus integration check: existing tests in `ssot-linear.bats` that depend on artifact-read's existing exit codes still pass.
- **Implement:** None — already in step 4.
- **Files:** `hub/tests/artifact-read-warn.bats` (refine assertions).
- **Verify:** `bats-report.sh -f 'artifact-read|ssot-linear'` reports green.

### Step 6 (AC-4): Fix drift-watchdog `echo "$VERIFY" | jq`

- **Test:** Existing drift-watchdog tests should not regress. Add a new round-trip bats test (Step 7) BEFORE this fix to lock in the safe pattern.
- **Implement:** In `.claude/skills/drift-watchdog/SKILL.md` line ~116, change:
  ```bash
  if ! echo "$VERIFY" | jq -e '.labels | index("drift-watchdog")' >/dev/null 2>&1; then
  ```
  to:
  ```bash
  if ! jq -e '.labels | index("drift-watchdog")' <<< "$VERIFY" >/dev/null 2>&1; then
  ```
- **Files:** `.claude/skills/drift-watchdog/SKILL.md`.
- **Verify:** Existing drift-watchdog skill tests still pass. Manual: capture a real `get-issue` response with description containing `\n` escapes; verify the new pipe parses cleanly.

### Step 7 (AC-5 audit): Sweep other skills for the broken pattern

- **Test:** Manual audit + `grep -rn 'echo "\$[A-Z_]*" | jq'` across `.claude/skills/`. Cross-reference against the variable's source — if the variable is captured from a Linear-API call that returns description-rich content, fix it. If it's a resolver output (short JSON, no descriptions), leave it.
- **Implement:** Targeted replacements only. Document the audit findings in the commit message — which patterns were CHANGED vs LEFT and why.
- **Files:** Whichever `.claude/skills/*/SKILL.md` files have description-rich captures + `echo` pipes.
- **Verify:** Sweep complete; grep shows zero remaining `echo "$VAR" | jq` patterns where `$VAR` carries description-rich JSON.

### Step 8 (drift-guard): Round-trip JSON-pipe-safety bats test

- **Test:** Create `hub/tests/json-pipe-safety.bats`. Test setup:
  1. Write a fixture JSON file to `$BATS_TEST_TMPDIR/issue.json` containing `{"description": "line1\\nline2", "labels": ["drift-watchdog"]}` (with REAL `\n` escape in the JSON, simulating the live API response).
  2. Capture into bash variable: `VAR=$(cat "$BATS_TEST_TMPDIR/issue.json")`.
  3. Test the SAFE pattern: `jq -e '.labels | index("drift-watchdog")' <<< "$VAR"` — assert exit 0.
  4. Test the BROKEN pattern: `echo "$VAR" | jq -e '.labels | index("drift-watchdog")'` — assert it FAILS (parse-error).
- **Implement:** New bats file demonstrating the safe-vs-broken pattern; locks in the lesson for future regression catching.
- **Files:** `hub/tests/json-pipe-safety.bats` (new).
- **Verify:** Test passes (safe pattern works, broken pattern correctly identified as broken).

### Step 9 (GATE): Full suite green

- **Test:** `bash .ccanvil/scripts/bats-report.sh --parallel`.
- **Implement:** None.
- **Verify:** `PASS: <count>, FAIL: 0, TOTAL: <count>` with `<count>` ≥ 1715.

### Step 10: Documentation propagation

- **Test:** None.
- **Implement:** Update `.ccanvil/guide/command-reference.md` if `cmd_artifact_read`'s exit-code/stderr contract is documented (likely under the SSOT-Linear section). Note the WARN-on-failure addition. Skip CLAUDE.md (no convention change).
- **Files:** `.ccanvil/guide/command-reference.md` (if relevant entry exists).
- **Verify:** Skim diff; no contradiction.

## Risks

- **Stub-pattern divergence:** `hub/tests/ssot-linear.bats` already establishes the linear-query.sh stubbing convention. Reuse that pattern verbatim; don't reinvent. If the stub doesn't expose stderr in the way `cat "$err" >&2` expects, adjust the stub helper rather than the substrate.
- **The four failure classes may not exhaustively partition the actual error surface.** Real Linear API errors could include rate-limit (429), server-error (5xx), or auth-revoked variants that fall through to `parse-error`. Mitigation: `parse-error` is the catch-all class — over-classification is acceptable; the WARN line still names the substrate as the source.
- **AC-5 audit subjectivity:** "description-rich content" is a judgment call. Mitigation: err on the side of fixing (replacing `echo` with `<<<` is a no-op when the content is escape-clean; cost of fixing extra cases is zero, cost of missing one is a future repro of BTS-227).
- **Live-API gate not applicable.** No live-API contract risk in this work — the WARN behavior is local stderr emission; the JSON-pipe fix is bash-pipe semantics. Both validated locally during the spec-research phase.
- **drift-watchdog skill change is prose, not code.** SKILL.md edits don't compile or run in CI — they only affect what Claude does at next skill invocation. Mitigation: the round-trip bats test (Step 8) locks the SAFE pattern in code, so even if SKILL.md drifts, tests catch regressions in any script that uses the pattern. Future ramp could include a lint that scans `.claude/skills/**/*.md` for the broken pattern.

## Definition of Done

- [ ] All AC-1 through AC-7 from spec pass.
- [ ] `cmd_artifact_read` emits structured WARN-on-failure across the four classes.
- [ ] drift-watchdog skill verification block uses `jq <<< "$VERIFY"`.
- [ ] AC-5 audit complete; no remaining `echo "$VAR" | jq` patterns where `$VAR` carries description-rich JSON.
- [ ] Bats suite green (≥1715 baseline).
- [ ] Code reviewed (run `/review`).
- [ ] BTS-227 included in PR body so it auto-closes alongside BTS-219 (per the operator-decision pending in BTS-231 — manual transition will be needed at /land time until BTS-231 is implemented).

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
