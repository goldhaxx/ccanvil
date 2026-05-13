# Implementation Plan: Fresh-mode CLAUDE.md template wedge

> Feature: bts-327-fresh-mode-claudemd-template
> Work: linear:BTS-327
> Created: 1778638200
> Spec hash: 22b473d7
> Based on: docs/spec.md

## Objective

Add a `.ccanvil/templates/CLAUDE.md.fresh` template + extend `classify_file` / `cmd_init_apply` with a `hub_source` field so `/ccanvil-init` in `fresh` mode produces a placeholder-bearing `CLAUDE.md` instead of copying the hub's hub-specific operator prose.

## Sequence

### Step 1: AC-7 — Missing-template error path

* **Test:** New `hub/tests/init-fresh-claudemd.bats`. First test: spin up a temp node + a synthetic hub directory that has `CLAUDE.md` but NO `.ccanvil/templates/CLAUDE.md.fresh`; run `init-preflight` against it; assert exit non-zero AND stderr matches `ERROR: fresh-mode CLAUDE.md template not found`.
* **Implement:** In `classify_file` ([ccanvil-sync.sh:737](<http://ccanvil-sync.sh:737>)), add a fresh-mode early-check: when `project_mode == "fresh"` AND `local_file == "CLAUDE.md"`, verify `$dist_root/.ccanvil/templates/CLAUDE.md.fresh` exists; if not, `die "fresh-mode CLAUDE.md template not found at $dist_root/.ccanvil/templates/CLAUDE.md.fresh"`.
* **Files:** `hub/tests/init-fresh-claudemd.bats` (new), `.ccanvil/scripts/ccanvil-sync.sh` (modify `classify_file`).
* **Verify:** Red → green via `bats hub/tests/init-fresh-claudemd.bats`.

### Step 2: AC-1 — Template file with placeholders + hub-managed mirror

* **Test:** Add to `init-fresh-claudemd.bats`: assert `.ccanvil/templates/CLAUDE.md.fresh` exists at hub root; contains each of the 5 placeholders line-leading (`[Project Name]`, `[One-line description.]`, `[Tech Stack TBD]`, `[Commands TBD]`, `[Architecture TBD]`); contains exactly one `<!-- HUB-MANAGED-START -->` line; and the byte range from the delimiter to EOF byte-matches the corresponding range of the hub root `CLAUDE.md`.
* **Implement:** Hand-author `.ccanvil/templates/CLAUDE.md.fresh`. Node section: `# [Project Name]` + `[One-line description.]` paragraph + `## Tech Stack`, `## Commands`, `## Architecture` sections each containing the matching `[... TBD]` placeholder. Below `<!-- HUB-MANAGED-START -->`: copy the hub root `CLAUDE.md`'s bytes from line 46 to EOF verbatim.
* **Files:** `.ccanvil/templates/CLAUDE.md.fresh` (new), `hub/tests/init-fresh-claudemd.bats` (extend).
* **Verify:** Test passes. `diff <(tail -n +46 CLAUDE.md) <(awk '/^<!-- HUB-MANAGED-START -->$/,EOF' .ccanvil/templates/CLAUDE.md.fresh)` returns empty.

### Step 3: AC-2 — Preflight emits `hub_source` field for fresh-mode CLAUDE.md

* **Test:** Add: fresh-mode preflight against the real hub produces a plan entry where `file == "CLAUDE.md"`, `source == "hub-only"`, `recommended_action == "copy"`, AND `hub_source == ".ccanvil/templates/CLAUDE.md.fresh"`.
* **Implement:** In `classify_file`, after the missing-template guard from Step 1, when `project_mode == "fresh"` AND `local_file == "CLAUDE.md"` (i.e., local doesn't exist), emit a plan entry with the new `hub_source` field. Pattern: mirror the existing `hub-only` entry shape, extend with `--arg hs ".ccanvil/templates/CLAUDE.md.fresh"` + `{"hub_source": $hs}` merge in the jq expression.
* **Files:** `.ccanvil/scripts/ccanvil-sync.sh` (extend `classify_file`), `hub/tests/init-fresh-claudemd.bats`.
* **Verify:** Test passes; existing `init-mode-detection.bats` still green.

### Step 4: AC-3 + AC-6 — `cmd_init_apply` consumes `hub_source`; CLAUDE.md emerges with placeholders

* **Test:** End-to-end: bootstrap a fresh node (only `.ccanvil/scripts/ccanvil-sync.sh` present), run `init-preflight` → save plan → `init-apply` against the real hub. Assert: project's `CLAUDE.md` contains `[Project Name]` and `[One-line description.]` literals; does NOT contain `# ccanvil` or `bats hub/tests/`; contains exactly one `<!-- HUB-MANAGED-START -->` line; bytes from that delimiter forward byte-match the hub canonical `CLAUDE.md`'s hub-managed section.
* **Implement:** In `cmd_init_apply` ([ccanvil-sync.sh:921](<http://ccanvil-sync.sh:921>)), inside the source-resolution block (line 959-988), add a `hub_source` override BEFORE the `$dist_root/$file` fallback. New block: `local hub_source_field=$(jq -r "$plan_expr | .[$i].hub_source // empty" "$plan_file"); if [[ -n "$hub_source_field" ]]; then hub_file="$dist_root/$hub_source_field"; fi`. Place after the GitHub-template lookup, before the `$dist_root/$file` fallback.
* **Files:** `.ccanvil/scripts/ccanvil-sync.sh` (extend `cmd_init_apply` source resolution), `hub/tests/init-fresh-claudemd.bats`.
* **Verify:** Test passes; copy/overwrite path still resolves hub source correctly for non-fresh CLAUDE.md cases.

### Step 5: AC-5 — Other modes don't get the fresh-template branch

* **Test:** Three sub-tests: `mature-repo` preflight (existing CLAUDE.md, no delimiter) emits `section-merge-create-delimiters` with NO `hub_source` field. `partial-ccanvil` preflight (existing CLAUDE.md with delimiter) emits `section-merge` with NO `hub_source` field. `already-initialized` short-circuits before any classify_file calls (existing detect_project_mode behavior). Use existing setup patterns from `init-mode-detection.bats`.
* **Implement:** No new code — Step 3's branch gates on `project_mode == "fresh"`. This is regression coverage.
* **Files:** `hub/tests/init-fresh-claudemd.bats` (extend).
* **Verify:** Test passes; full hub/tests/ suite still green.

### Step 6: AC-4 + AC-8 — Step 8 sed surface + already-initialized re-run no-op

* **Test:** Two sub-tests. (a) After Step-4 init-apply, run a literal sed substitution: `sed -i'' "s/\[Project Name\]/MyProject/" CLAUDE.md && sed -i'' "s/\[One-line description.\]/An app./" CLAUDE.md` and assert both placeholders were replaced (file now contains "MyProject" and "An app."). This is the canonical Step 8 substitution shape. (b) After init-apply completes (lockfile now exists), re-run `init-preflight`; assert the resulting plan does NOT contain a plan entry for CLAUDE.md with a fresh-template `hub_source` — the `already-initialized` short-circuit at `detect_project_mode` ([ccanvil-sync.sh:617](<http://ccanvil-sync.sh:617>)) prevents re-fire.
* **Implement:** No new code — regression coverage of existing substrate behavior.
* **Files:** `hub/tests/init-fresh-claudemd.bats` (extend).
* **Verify:** Test passes.

### Step 7: Preset documentation update

* **Test:** Manifest validate must still pass (allowlist coverage check). No bats test for prose alone.
* **Implement:** Update three documentation surfaces:
  1. `global-commands/ccanvil-init.md` Step 8 (line 110-114): add a sentence noting that fresh-mode CLAUDE.md ships placeholder-ready via `.ccanvil/templates/CLAUDE.md.fresh`, so the sed pass operates on real placeholders.
  2. `.ccanvil/guide/sync.md` or `system-overview.md` (whichever covers init flow): note the `hub_source` field convention as a one-line addition.
  3. Add `.ccanvil/templates/CLAUDE.md.fresh` to `.ccanvil/manifest-allowlist.txt` so the substrate tracks it.
* **Files:** `global-commands/ccanvil-init.md`, `.ccanvil/guide/sync.md` (or chosen guide file), `.ccanvil/manifest-allowlist.txt`.
* **Verify:** `bash .ccanvil/scripts/module-manifest.sh validate --json` returns `{"status":"ok"}`.

### Step 8: Full suite + /review

* **Test:** Run `bash .ccanvil/scripts/bats-report.sh --parallel --progress` (BTS-118 single-invocation discipline). All tests pass.
* **Implement:** None — verification only.
* **Files:** None.
* **Verify:** Run `/review` — manifest drift gate passes, code-review agent has no CRITICAL findings.

## Risks

* **Hub-managed mirror drift.** The byte-for-byte mirror of the hub-managed section in `CLAUDE.md.fresh` will silently drift from the canonical hub `CLAUDE.md` whenever a future PR edits the hub-managed section. AC-6 only checks at init time. **Mitigation:** Step 2's test asserts byte-equivalence at every bats run; the test fails the moment drift introduces. If that proves too brittle, follow-up ticket can add a one-line drift-guard primitive. Either way, drift becomes visible immediately.
* `classify_file` **interaction with mature-repo branch.** The mature-repo override (ccanvil-sync.sh:759-781) runs for `CLAUDE.md` when `project_mode` matches. Step 1's fresh-mode check must precede it cleanly and not bleed into other modes. **Mitigation:** Step 5's regression tests cover all four other modes; existing `init-mode-detection.bats` continues to pass.
* `hub_source` **field shape proliferation.** Adding a new optional field to plan entries is a substrate decision that future overrides may depend on. **Mitigation:** Field is scoped narrowly — only fresh-mode CLAUDE.md emits it today. Future use is opt-in. No deprecation path needed since the field is additive.

## Definition of Done

- [ ] All 8 acceptance criteria from spec pass
- [ ] All existing tests still pass (run `bash .ccanvil/scripts/bats-report.sh --parallel --progress`)
- [ ] No type errors (bash — `shellcheck` clean on edited script)
- [ ] Manifest validate clean (`module-manifest.sh validate` exit 0)
- [ ] Code reviewed (run `/review`)

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
