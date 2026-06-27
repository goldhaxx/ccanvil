# Feature: Relocate rule manifests to discoverable sidecars

> Feature: bts-666-rule-manifest-sidecars
> Work: linear:BTS-666
> Created: 1782512847
> Subject: Relocate rule manifests to discoverable sidecars
> Status: Complete

## Summary

Session-start always-loaded context is ~9,026t against an 8,000t ceiling (~113%, CRITICAL). The `.claude/rules/*.md` set is the largest slice (5,661t), and **49% of that (2,758t) is the embedded `manifest:` frontmatter block** — Layer-2 self-describing metadata whose only reader is the `module-manifest.sh` drift-guard, yet the agent re-reads it every turn and never acts on it. The rule *bodies* were already atomized (BTS-387); the frontmatter is the remaining lever. This feature relocates each rule's `manifest:` block to a co-located sidecar (`.claude/rules/<id>.manifest.yaml`), shrinking the always-loaded surface to ~6,400t (HEALTHY) **without regressing Layer-2 coverage** — the manifest still exists and is still validated, just where the machine reads it rather than where the agent does. Decoupling is made safe by a bijection guard, a discoverable back-reference, and preservation of all existing structural drift checks.

## Job To Be Done

**When** a session starts and the harness auto-loads every `.claude/rules/*.md`,
**I want to** keep only the agent-actionable directive + a pointer to its machine-readable contract in the always-loaded file,
**So that** the context budget opens HEALTHY and per-turn decision budget is reserved for the work — while AI systems and humans can still locate, trust, and keep current the rule's manifest with no new drift surface.

## Acceptance Criteria

Each criterion is independently testable. Binary pass/fail. Applies ONLY to `.claude/rules/*.md` (the always-loaded set); script `# @manifest` blocks are explicitly unchanged.

- [ ] **AC-1 (relocation):** Each `.claude/rules/<id>.md` with a `manifest:` frontmatter block has that block moved verbatim (semantically equivalent) into `.claude/rules/<id>.manifest.yaml`. The rule `.md` retains only `tier`, `scope`, `stack`, `anchors`, and a new `manifest_ref` key.
- [ ] **AC-2 (discoverable back-reference):** Each rule `.md` frontmatter carries `manifest_ref: <id>.manifest.yaml`. `module-manifest.sh validate` emits block-shape drift (exit 2) when `manifest_ref` is missing, points to a nonexistent file, or the sidecar's `manifest.id` does not equal the rule id.
- [ ] **AC-3 (bijection guard):** **Given** the set of manifest-carrying rules (the 8 rules with a `manifest:` block per AC-1 — NOT all tier-0 rules), **when** `validate` runs, **then** every manifest-carrying rule has exactly one sidecar and every `.claude/rules/*.manifest.yaml` maps to an existing manifest-carrying rule; an orphan sidecar (no matching rule) or a manifest-carrying rule missing its sidecar is block-shape drift (exit 2). Tier-0 rules with NO `manifest:` block (e.g. `background-task-discipline.md`) are explicitly exempt — no sidecar required, and sidecar-absence is never drift.
- [ ] **AC-4 (preserved structural validation):** The pre-existing manifest checks (required-keys, declared `caller` resolution, `depends-on` existence, source-marker drift) run against the relocated sidecar and produce identical drift verdicts to the pre-relocation inline state for an unchanged manifest.
- [ ] **AC-5 (budget HEALTHY):** After relocation, `context-budget.sh check --json` reports total estimated_tokens that yield status `HEALTHY` or `WARNING` (not `CRITICAL`); sidecars are NOT counted (the glob remains `*.md`).
- [ ] **AC-6 (discoverability documented):** The canonical sidecar convention (`.claude/rules/<id>.manifest.yaml` + `manifest_ref` pointer) is documented in `CLAUDE.md` (hub-managed section) and `.ccanvil/guide/`, so an agent can resolve a rule's contract location deterministically.
- [ ] **AC-7 (code-quality body win):** `code-quality.md` (494t body, 0 anchors today) has its catalog prose moved to a new `docs/research/code-quality-foundations.md` anchor, leaving the rule body atomic with an anchor pointer.
- [ ] **AC-8 (error — malformed sidecar):** When a sidecar is not valid YAML, or is not a mapping, `validate` emits `rule-manifest-sidecar-malformed` block-shape drift (exit 2) naming the offending file.
- [ ] **AC-9 (tier-budget reachable):** With the manifest block relocated, each tier-0 rule `.md` whole-file token count is at/under the existing 150t tier-0 budget OR the residual over-budget set is explicitly enumerated in the plan with rationale (no silent miss).
- [ ] **AC-10 (downstream sync safe):** The new sidecars + edited rules + parser change propagate through the existing hub→node sync (lockfile/allowlist) with no broken-rule or missing-manifest state on a pull; a node that has not yet pulled still validates against its own inline-or-sidecar shape (back-compat path stated in plan).

## Affected Files

| File | Change |
|------|--------|
| `.claude/rules/*.md` (9) | Modified — strip `manifest:` block, add `manifest_ref` |
| `.claude/rules/*.manifest.yaml` (9) | New — relocated manifest blocks |
| `.ccanvil/scripts/module-manifest.sh` | Modified — read manifest from sidecar; add bijection + back-ref + malformed-sidecar guards |
| `docs/research/code-quality-foundations.md` | New — anchor for code-quality prose (AC-7) |
| `.claude/rules/code-quality.md` | Modified — body atomization |
| `hub/tests/rule-manifest-sidecar.bats` | New — AC-2/3/4/8 guard tests |
| `hub/tests/context-budget.bats` | Modified — assert sidecars not counted (AC-5) |
| `CLAUDE.md`, `.ccanvil/guide/` | Modified — document sidecar convention (AC-6) |

## Dependencies

- **Requires:** BTS-386 (tier-budget guard + frontmatter parser), BTS-384 (scope/vocab scan), BTS-387 (prior body atomization) — all shipped.
- **Blocked by:** none.

## Out of Scope

- Stripping manifests entirely (would regress Layer-2 — rejected option C).
- Relocating script/command `# @manifest` blocks — those are not auto-loaded; inline richness stays.
- Changing the 150t tier-0 threshold or the budget ceiling.

## Implementation Notes

- **Harness-contract uncertainty (live-validation gate):** the design assumes the Claude Code harness auto-loads ONLY `.claude/rules/*.md`, not sibling `.yaml`. This MUST be live-verified before commit (place a probe sidecar, confirm it does not enter session context) — if the harness globs more broadly, fall back to a `.claude/rules/manifests/` subdir. This is the one contract that stubs cannot confirm.
- **Sidecar location default:** co-located (`<id>.manifest.yaml` beside `<id>.md`) for maximum adjacency/discoverability; subdir is the fallback only if the harness probe fails.
- **Parser change shape:** `cmd_validate`'s rule scan (`module-manifest.sh` ~line 860) currently parses frontmatter inline; redirect manifest-block extraction to the sidecar while keeping `tier/scope/stack` parsing on the `.md`. Mirror `cmd_rule_resolve` in `docs-check.sh` if it also reads the inline block.
- **Drift-safety rationale to encode in tests:** the bijection + back-ref guards are what replace the old "you'll see the manifest while editing the rule" co-location nudge — they must make orphan/missing/mismatch a hard failure, not a warning.
- **AC-9 residual (enumerated per the no-silent-miss clause):** after relocation, all 9 tier-0 rule `.md` files remain over the 150t advisory tier-0 budget — `test-discipline.md` 462t, `code-quality.md`/`evidence-required-for-captures.md` ~370–420t, the rest 254–360t. This is expected and accepted: BTS-387 already atomized the rule *bodies*, so the residual is irreducible directive text, not relocatable metadata. The 150t-per-rule target is a separate, later per-rule-tightening effort; BTS-666's lever was the frontmatter manifest block (now in sidecars), which moves the *total* budget from CRITICAL ~113% to WARNING ~82%. `module-manifest.sh validate` continues to surface each over-budget rule as an advisory `info[].rule-tier-budget-exceeded` entry, so none is silently dropped.
