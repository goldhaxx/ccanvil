# Implementation Plan: Module manifest substrate — first ship (3 seed primitives, drift-guard)

> Feature: bts-239-module-manifest-substrate
> Work: linear:BTS-239
> Created: 1777353137
> Spec hash: e56266cd
> Based on: docs/spec.md

## Objective

Ship the Layer 2 self-describing-systems substrate: kv-comment manifest format, four-verb script (`extract`, `validate`, `query`, `index`), allowlist-driven drift-guard at 100%, three seed primitives covered, format self-applied. No Layer 3 / markdown / pre-commit ramps in this ship.

## Sequence

### Step 1: extract parser (AC-2, AC-10)

* **Test:** `hub/tests/module-manifest-extract.bats` — fixture file with two `# @manifest` blocks → assert JSON array of 2 objects, each carrying `id` field, repeated keys collapsed to arrays. Edge fixture: malformed `failure-mode` line → exit 2 + stderr `MALFORMED:`.
* **Implement:** `.ccanvil/scripts/module-manifest.sh` — `cmd_extract <path>`. Awk-based scanner: identify `# @manifest` blocks, parse `# <key>: <value>` lines until next blank or non-comment line. Function-name detection: scan next non-comment line for `<id>()` pattern. File-level fallback: use basename when no function follows.
* **Files:** `.ccanvil/scripts/module-manifest.sh` (new), `hub/tests/module-manifest-extract.bats` (new), `hub/tests/fixtures/manifest/two-blocks.sh` (new fixture).
* **Verify:** `bash .ccanvil/scripts/bats-report.sh -f module-manifest-extract` → all pass.

### Step 2: index (AC-5)

* **Test:** `hub/tests/module-manifest-index.bats` — fixture set with 3 manifests across 2 files → assert `.ccanvil/state/manifests.json` is a JSON object keyed `<path>:<id>`, sorted lexicographically, deterministic across two runs (byte-identical).
* **Implement:** `cmd_index` walks `.ccanvil/scripts/*.sh`, `.claude/hooks/*.sh`, `.claude/hooks/_lib/*.sh` (per spec scope — `.sh` files only), invokes `cmd_extract` on each, merges into one object, writes atomically via `mktemp + mv`.
* **Files:** `.ccanvil/scripts/module-manifest.sh` (modify), `hub/tests/module-manifest-index.bats` (new), `hub/tests/fixtures/manifest/multi-file/` (new fixtures).
* **Verify:** bats target passes; running twice produces identical output.

### Step 3: query with mtime laziness (AC-6)

* **Test:** `hub/tests/module-manifest-query.bats` — query `depends-on:foo` → JSON array filtered by substring match. Empty match → `[]` exit 0. Stale-index test: touch a source file newer than `manifests.json` → assert query regenerates index before reading.
* **Implement:** `cmd_query <expr>` parses `<key>:<value>` from \`\`, reads index (regenerates if any source mtime > index mtime), filters via jq, emits matching entries.
* **Files:** `.ccanvil/scripts/module-manifest.sh` (modify), `hub/tests/module-manifest-query.bats` (new).
* **Verify:** bats target passes; mtime-stale path exercised.

### Step 4: validate foundation — required-keys + failure-mode shape (AC-3 base)

* **Test:** `hub/tests/module-manifest-validate.bats` (RED phase 1) — empty allowlist → exit 0 + `{coverage:{covered:0,total:0},...}`. Allowlist with valid entry → exit 0. Missing required key (`purpose`) → exit 2 + stderr `DRIFT: <path>:<id> reason=missing-required-key value=purpose`.
* **Implement:** `cmd_validate` reads `.ccanvil/manifest-allowlist.txt`, calls `cmd_extract` per entry, asserts required keys non-empty, asserts each `failure-mode` value parses to schema (`id | exit=N | visible=... | mitigation=...`).
* **Files:** `.ccanvil/scripts/module-manifest.sh` (modify), `.ccanvil/manifest-allowlist.txt` (new, empty + comment header), `hub/tests/module-manifest-validate.bats` (new).
* **Verify:** bats target green; `set -e` strict-mode pattern per BTS-127.

### Step 5: validate deep — bidirectional drift (AC-3 cont., AC-4 all 6 classes)

* **Test:** RED phase 2 in same bats file. Six fixtures, one per drift class: missing-required-key, malformed-failure-mode, caller-not-found, depends-on-not-found, missing-@failure-mode-marker, missing-@side-effect-marker. Each asserts exit 2 + correct `DRIFT:` stderr shape.
* **Implement:** Extend `cmd_validate` with: (a) caller-grep against `.ccanvil/scripts/`, `.claude/hooks/`, `.claude/skills/`, `.claude/agents/`, `.claude/rules/` — word-boundary regex (`\bcmd_X\b`), exclude function definition lines (`^cmd_X\(\)`); (b) depends-on grep against function body lines only; (c) marker validation: every `failure-mode: <id>` and `side-effect: <id>` must have at least one matching `# @failure-mode: <id>` or `# @side-effect: <id>` inside the function body.
* **Files:** `.ccanvil/scripts/module-manifest.sh` (modify), `hub/tests/fixtures/manifest/drift-classes/` (new fixtures).
* **Verify:** all 6 drift classes assert exit 2 with correct stderr.

### Step 6: seed manifest — cmd_artifact_write (AC-7 part 1)

* **Test:** `hub/tests/module-manifest-seed-artifact-write.bats` — `cmd_extract` on `docs-check.sh` returns a manifest object for `cmd_artifact_write` with all required keys non-empty; `cmd_validate` (with allowlist containing only this entry) exits 0.
* **Implement:** Add `# @manifest` block above `cmd_artifact_write()` (line 5235). Insert `# @failure-mode: concurrent-edit`, `# @failure-mode: missing-LINEAR_API_KEY`, `# @failure-mode: cache-staleness` markers near the relevant `exit 3`/retry sites. Insert `# @side-effect: write-local-doc`, `# @side-effect: upsert-linear-document`, `# @side-effect: append-failure-log` markers near the actual writes.
* **Files:** `.ccanvil/scripts/docs-check.sh` (modify), `.ccanvil/manifest-allowlist.txt` (add entry), `hub/tests/module-manifest-seed-artifact-write.bats` (new).
* **Verify:** bats target green; full `validate` exits 0 with this single entry.

### Step 7: seed manifest — cmd_ship_finalize (AC-7 part 2)

* **Test:** Same shape as Step 6 — `hub/tests/module-manifest-seed-ship-finalize.bats`.
* **Implement:** Add `# @manifest` above `cmd_ship_finalize()` (line 3136). Cover preflight failure, title-fix failure, ready failure, AUTO-CLOSE marker emission. Markers near each.
* **Files:** `.ccanvil/scripts/docs-check.sh` (modify), allowlist (add), bats (new).
* **Verify:** bats target green; allowlist has 2 entries; validate exits 0.

### Step 8: seed manifest — cmd_idea_pending_replay (AC-7 part 3)

* **Test:** `hub/tests/module-manifest-seed-pending-replay.bats`.
* **Implement:** Add `# @manifest` above `cmd_idea_pending_replay()` (line 3387). Cover BTS-233 dual-log drainage, idempotency caveat, `emergency_pending` field. Markers near.
* **Files:** `.ccanvil/scripts/docs-check.sh` (modify), allowlist (add), bats (new).
* **Verify:** allowlist has 3 entries; validate exits 0.

### Step 9: self-application — [module-manifest.sh](<http://module-manifest.sh>)'s own 4 verbs (AC-7 part 4, AC-8)

* **Test:** `hub/tests/module-manifest-self-application.bats` — `cmd_extract` on `module-manifest.sh` returns 4 manifests (one per verb); `cmd_validate` over the full 7-entry allowlist exits 0.
* **Implement:** Author manifests above `cmd_extract`, `cmd_validate`, `cmd_query`, `cmd_index` in `module-manifest.sh`. Add the 4 entries to the allowlist.
* **Files:** `.ccanvil/scripts/module-manifest.sh` (modify), allowlist (add 4), bats (new).
* **Verify:** allowlist has 7 entries; `cmd_validate` exits 0.

### Step 10: drift-guard bats with mutation tests (AC-8)

* **Test:** `hub/tests/module-manifest-drift-guard.bats` — clean state asserts `validate` exit 0; mutation tests temporarily corrupt one seed's `caller:` field via `sed` on a copy → assert exit 2 + `DRIFT:` stderr; revert copy and reassert exit 0. Use bats `setup`/`teardown` for cleanup.
* **Implement:** No new substrate. Pure test file.
* **Files:** `hub/tests/module-manifest-drift-guard.bats` (new).
* **Verify:** mutation cycle is reliably reproducible across runs.

### Step 11: manifest format documentation (AC-1)

* **Test:** Doc-only step. Drift-guard test in Step 10 implicitly enforces format-of-record.
* **Implement:** Write `.ccanvil/templates/manifest.md` documenting block syntax, required/optional keys, `failure-mode` schema, examples (one function-level, one file-level), drift-guard semantics, source-marker conventions.
* **Files:** `.ccanvil/templates/manifest.md` (new).
* **Verify:** Manifest format describes itself — Step 9 self-application verbs' manifests serve as the worked examples.

### Step 12: stasis coverage section (AC-9)

* **Test:** `hub/tests/stasis-template-manifest-coverage.bats` (or extend existing stasis-template test) — assert `## Manifest Coverage` heading present in `.ccanvil/templates/stasis.md`; running `/stasis` produces a populated section with the `covered/total + drift incidents` literal.
* **Implement:** Add `## Manifest Coverage` template line to `.ccanvil/templates/stasis.md`. Update `.claude/skills/stasis/SKILL.md` data-gathering steps with `module-manifest.sh validate --json | jq -r '"\(.coverage.covered) / \(.coverage.total) (allowlist), drift incidents: \(.drift | length)"'`. Empty-allowlist literal: `Manifest coverage: N/A (no allowlist yet).`
* **Files:** `.ccanvil/templates/stasis.md` (modify), `.claude/skills/stasis/SKILL.md` (modify), bats (new or extend).
* **Verify:** template + skill prose updated; bats target green.

### Step 13: gitignore + suite-wide verification (AC-11 prep)

* **Test:** `bash .ccanvil/scripts/bats-report.sh --parallel` — assert all existing tests still pass + new ones pass. Net delta: +6 new bats files; expect \~+30-50 tests added.
* **Implement:** Add `.ccanvil/state/manifests.json` to `.gitignore`. Final suite run.
* **Files:** `.gitignore` (modify).
* **Verify:** PASS / FAIL / TOTAL line clean; no regressions.

### Step 14: command-reference doc + skill update sweep

* **Test:** Doc-only.
* **Implement:** Update `.ccanvil/guide/command-reference.md` with `module-manifest.sh` verbs (under a new section). Update `CLAUDE.md` Architecture block if needed (likely add a one-line reference to `module-manifest.sh`). Per the rule "if any step adds preset infrastructure, update docs" (this step IS that final doc step).
* **Files:** `.ccanvil/guide/command-reference.md` (modify), `CLAUDE.md` (modify if needed).
* **Verify:** `docs-check.sh validate` clean.

## Risks

* **Caller-grep false positives:** `cmd_X` substring match could hit `cmd_X_helper`. Mitigate via word-boundary regex (`\bcmd_X\b`) + exclude-self pattern (skip lines matching `^cmd_X\(\)`).
* **Skill/rule/agent caller refs not greppable in** `.sh`: Manifests can declare `caller: skill:/spec`. Validate by checking `.claude/skills/spec/SKILL.md` exists AND contains a reference to the named primitive. Substring match across markdown sources.
* **awk parser complexity for repeated keys:** Pattern is BTS-215 dispatch-extraction-shaped; reuse the same idiom (case-statement-driven block accumulator).
* **mtime regeneration race in fast tests:** Sub-second mtime ties on some filesystems. Mitigate by sleeping 1s between source-touch and query in the stale-index test.
* **No live-API risk** — substrate is bash + jq + awk over local files only. Skip the BTS-171 live-validation gate.

## Definition of Done

- [ ] All 11 acceptance criteria from spec pass (AC-11 holds across to next ship)
- [ ] All existing 1839 tests still pass
- [ ] 6+ new bats files green; full suite parallel run clean
- [ ] No type errors (bash `shellcheck` advisory only — not a hard gate)
- [ ] Code reviewed (run /review)
- [ ] `.ccanvil/manifest-allowlist.txt` contains exactly 7 entries; `cmd_validate` exits 0

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
