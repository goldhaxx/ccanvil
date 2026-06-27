# Implementation Plan: Relocate rule manifests to discoverable sidecars

> Feature: bts-666-rule-manifest-sidecars
> Work: linear:BTS-666
> Created: 1782514596
> Spec hash: 2639a996
> Based on: docs/spec.md

## Objective

Relocate each manifest-carrying rule's `manifest:` block from `.claude/rules/<id>.md` frontmatter into a co-located `.claude/rules/<id>.manifest.yaml` sidecar — cutting always-loaded budget to HEALTHY while preserving Layer-2 validation via new bijection / back-ref / malformed-sidecar guards.

## Sequence

Each step is one red-green-refactor cycle on `hub/tests/rule-manifest-sidecar.bats` unless noted. Targeted test file only per cycle; full suite is the pre-merge gate.

### Step 1: `_extract_markdown` reads the sidecar

* **Test:** Fixture rule `.md` with `manifest_ref: <id>.manifest.yaml` + co-located sidecar carrying the manifest keys. Assert `cmd_extract <rule>.md` emits JSON byte-identical to extracting the same block inline (golden comparison).
* **Implement:** In `_extract_markdown` ([module-manifest.sh](<http://module-manifest.sh>) ~L183), after parsing frontmatter, if a `manifest_ref` key resolves to an existing sidecar, parse the manifest keys from the sidecar instead of the inline `manifest:` subtree. Keep `tier/scope/stack/anchors` parsing on the `.md`. Sidecar format: top-level `manifest:` mapping (mirrors the relocated block — minimal new parse logic).
* **Files:** `.ccanvil/scripts/module-manifest.sh`, `hub/tests/rule-manifest-sidecar.bats`
* **Verify:** Golden JSON equality; `cmd_extract` on an inline-only fixture still works (back-compat).

### Step 2: Back-reference integrity guard (AC-2)

* **Test:** Three red cases → block-shape drift exit 2: (a) `manifest_ref` missing on a manifest-carrying rule, (b) points to nonexistent file, (c) sidecar `manifest.id` ≠ rule id.
* **Implement:** Extend the rule scan (~L859-960) to validate `manifest_ref` resolution + id match; emit `rule-manifest-ref-broken` to `drift[]`.
* **Files:** [module-manifest.sh](<http://module-manifest.sh>), bats
* **Verify:** Each red case exits 2 with a named drift entry; valid pairing stays exit 0.

### Step 3: Bijection guard (AC-3)

* **Test:** (a) orphan sidecar with no matching rule → drift exit 2; (b) manifest-carrying rule missing its sidecar → drift exit 2; (c) manifest-less tier-0 rule (`background-task-discipline.md`) → NOT drift.
* **Implement:** Compute manifest-carrying-rule set (rules whose `.md` still declares `manifest_ref`, or are allowlisted) and sidecar set; assert bijection. Emit `rule-manifest-sidecar-orphan` / `rule-manifest-sidecar-missing` to `drift[]`. Exempt manifest-less rules explicitly.
* **Files:** [module-manifest.sh](<http://module-manifest.sh>), bats
* **Verify:** All three cases; clean state exits 0.

### Step 4: Malformed-sidecar guard (AC-8)

* **Test:** Sidecar with invalid YAML and sidecar that is a non-mapping → `rule-manifest-sidecar-malformed` block drift exit 2, naming the file.
* **Implement:** Wrap sidecar parse in the python yaml try/except already used for frontmatter; route failure to `drift[]`.
* **Files:** [module-manifest.sh](<http://module-manifest.sh>), bats
* **Verify:** Both malformed shapes exit 2; valid sidecar unaffected.

### Step 5: Preserved structural validation (AC-4)

* **Test:** Fixture sidecar declaring a `caller` that does NOT call the rule → same `caller-not-found`-class drift as the inline path produced pre-relocation; required-key omission still drifts.
* **Implement:** Likely no new code — the allowlist loop calls `cmd_extract` (now sidecar-aware from Step 1). This step proves the existing caller/depends-on/required-key machinery flows through the sidecar unchanged.
* **Files:** bats (verification); [module-manifest.sh](<http://module-manifest.sh>) only if a gap surfaces
* **Verify:** Drift verdict identical to a captured pre-relocation baseline.

### Step 6: Migrate the 8 real rules (mechanical)

* **Implement:** For each allowlisted rule (tdd, code-quality, deterministic-first, evidence-required-for-captures, provider-integration, self-review, workflow, test-discipline): move the `manifest:` block verbatim into `.claude/rules/<id>.manifest.yaml`, strip it from the `.md` frontmatter, add `manifest_ref: <id>.manifest.yaml`. Leave `background-task-discipline.md` untouched (no manifest block).
* **Files:** 8 `.md` + 8 new `.manifest.yaml`
* **Verify:** `module-manifest.sh validate --json` → status ok, coverage unchanged (205/205), bijection clean, exit 0.

### Step 7: code-quality body atomization (AC-7)

* **Implement:** Create `docs/research/code-quality-foundations.md`, move the catalog prose there, reduce `code-quality.md` body to atomic directives + anchor pointer. Add the anchor to its frontmatter `anchors.evidence`.
* **Files:** `docs/research/code-quality-foundations.md` (new), `.claude/rules/code-quality.md`
* **Verify:** body token count drops; vocabulary-leak scan stays clean.

### Step 8: Budget HEALTHY + context-budget test (AC-5)

* **Test:** Add a `hub/tests/context-budget.bats` case asserting `.claude/rules/*.manifest.yaml` files are NOT in the measured `files[]` (glob stays `*.md`).
* **Implement:** No code change expected (glob already `*.md`); test pins the invariant.
* **Files:** `hub/tests/context-budget.bats`
* **Verify:** `context-budget.sh check --json` total yields HEALTHY or WARNING (not CRITICAL).

### Step 9: Documentation (AC-6)

* **Implement:** Document the sidecar convention (`.claude/rules/<id>.manifest.yaml` + `manifest_ref`) in `CLAUDE.md` (hub-managed section) and the relevant `.ccanvil/guide/` section.
* **Files:** `CLAUDE.md`, `.ccanvil/guide/*`
* **Verify:** Convention is greppable; CLAUDE.md line-count guard (≤80 hub lines) not tripped.

### Step 10: Harness live-probe — LIVE-API GATE (Implementation Notes)

* **Verify (LIVE, before commit):** Confirm the Claude Code harness auto-loads ONLY `.claude/rules/*.md`, not the sibling `.yaml` sidecars. Probe: place a uniquely-tokened sidecar, start a fresh context read path, confirm the token does NOT appear in loaded context. **This contract cannot be stubbed** — per `.claude/rules/tdd.md` live-API gate, run it before commit and before `/review`. If the harness globs more broadly, fall back to a `.claude/rules/manifests/` subdir (re-point Step 1/6 paths).

### Step 11: Downstream sync safety (AC-10)

* **Implement:** Regenerate the lockfile so the new sidecars are tracked; confirm allowlist entries stay pointed at `.md` (rule is the primitive; sidecar is its manifest). State the back-compat path: a node that has not pulled still has inline blocks and validates via the unchanged inline branch.
* **Files:** lockfile (via sync substrate), `.ccanvil/manifest-allowlist.txt` (verify no change needed)
* **Verify:** `ccanvil-sync.sh` status / a dry pull shows sidecars tracked, no broken-rule state.

## Risks

* **Harness auto-loads** `.yaml` **too** → relocation wouldn't cut budget. Mitigated by the Step 10 live probe + subdir fallback.
* **Sidecar parse divergence** from inline parser → golden-equality test (Step 1) + AC-4 baseline catch it.
* **Downstream nodes mid-migration** carry inline blocks → keep the inline branch as the back-compat path; do not delete it.
* **bijection set mis-scoped** (the critic's AC-3 finding) → resolved: domain is manifest-carrying rules only; Step 3(c) pins the exemption.

## Definition of Done

- [ ] All 10 acceptance criteria from spec pass
- [ ] All existing tests still pass (full suite — pre-merge gate)
- [ ] `module-manifest.sh validate` clean (bijection + back-ref + structural)
- [ ] `context-budget.sh check` → not CRITICAL
- [ ] Harness live-probe confirmed (Step 10)
- [ ] Code reviewed (run /review)
