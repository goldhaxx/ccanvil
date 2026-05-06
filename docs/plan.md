# Implementation Plan: Init drops per-feature lifecycle-doc seeding

> Feature: bts-318-init-drop-lifecycle-doc-seeding
> Work: linear:BTS-318
> Created: 1778092662
> Spec hash: d22cc6b8
> Based on: docs/spec.md

## Objective

Stop /ccanvil-init from seeding `docs/spec.md`/`docs/plan.md`/`docs/stasis.md` placeholder files into fresh projects, leaving only `docs/roadmap.md` (project-strategic) and `mkdir -p docs/specs`. This fixes the lifecycle invariant violation that causes the very first /stasis to halt on `state: blocked` due to bracketed `Work:` placeholders being read as non-matching references.

Two-file surgical change: skill prose at `global-commands/ccanvil-init.md` Step 6 + bats test rewrite at `hub/tests/ccanvil-init-skill.bats` AC-10 + new drift-guard test.

## Steps

### Step 1 — Red: rewrite AC-10 test to assert new (post-fix) shape

Edit `hub/tests/ccanvil-init-skill.bats`:

- Rename `AC-10: skill names the four lifecycle docs by path` → `AC-10: skill seeds only docs/roadmap.md at init`.
- Rewrite assertions: confirm `docs/roadmap.md` IS named in Step 6; assert `docs/spec.md`, `docs/plan.md`, `docs/stasis.md` are NOT in the Step 6 seed loop region.
- Add new test `AC-10b: drift-guard — Step 6 seed loop excludes per-feature lifecycle docs` that extracts the Step 6 region (between `## Step 6` and `## Step 7` headers) and runs `grep -cE 'docs/(spec|plan|stasis)\.md'` returning 0 on the loop body.
- Run `bats hub/tests/ccanvil-init-skill.bats -f 'AC-10'`. Confirm the new tests FAIL against the still-unfixed skill (red phase verified).

Test run: `bash .ccanvil/scripts/bats-report.sh -f 'AC-10' --json | jq '.summary'`

### Step 2 — Green: edit ccanvil-init.md Step 6

Edit `global-commands/ccanvil-init.md` lines 56-67:

- Replace the for-loop `for f in docs/spec.md docs/plan.md docs/stasis.md docs/roadmap.md; do ... done` with a direct one-file conditional: `[[ -s docs/roadmap.md ]] && echo "PRESERVED: docs/roadmap.md" || cp "$HUB/.ccanvil/templates/roadmap.md" docs/roadmap.md`.
- Update the leading prose `For each of \`docs/spec.md\`, \`docs/plan.md\`, \`docs/stasis.md\`, \`docs/roadmap.md\`:` → `Seed the strategic roadmap (the only project-wide doc; per-feature lifecycle artifacts are created on demand by /spec, /plan, /stasis):`.
- Keep `mkdir -p docs/specs` line.
- Update or remove the Step 6 trailing paragraph "If `docs/stasis.md` was preserved..." — the in-progress-feature detection logic now only fires for retrofitted projects that ALREADY have stasis.md (mature-repo / partial-ccanvil mode); reword to clarify this only triggers when stasis.md was found pre-init in mature/partial flow, not when freshly seeded.

Re-run AC-10 tests: should now pass.

### Step 3 — Verify drive-by tests still pass

Existing tests with subtle dependencies on the three files:

- `AC-11: skill surfaces in-progress feature when stasis is preserved` — greps for `in-progress feature|> Feature:` in skill content; the reworded paragraph in Step 2 should still satisfy this regex. Confirm with `bats -f 'AC-11'`.
- `drive-by: skill refers to docs/stasis.md, not docs/checkpoint.md` — still requires the skill to mention `docs/stasis.md` somewhere; the reworded paragraph keeps the reference. Confirm with `bats -f 'drive-by'`.

If either fails, restore the necessary mentions in the rewritten paragraph (the reference still has to exist for in-progress detection on retrofitted nodes).

### Step 4 — Full bats suite verification

Run `bash .ccanvil/scripts/bats-report.sh --parallel`. Confirm pass count ≥ baseline (1992/1992 from session 21). No regressions.

If anything else breaks, the surface area for ripple is narrow: `init-skill.bats` covers most of the seeding contract, but cross-cutting tests (e.g., `legacy-refs-scan`, allowlist coverage) might be sensitive — surface findings, fix forward.

### Step 5 — Hub guide doc sweep

Skill prose at `global-commands/ccanvil-init.md` is hub-shared infra, so per the project's `/plan` Step 7 rule:

- Check `.ccanvil/guide/` for sections describing init's lifecycle-doc seeding behavior. If found, update to reflect the new "only roadmap.md" reality.
- Likely candidates: `.ccanvil/guide/lifecycle.md` (if it exists) or `.ccanvil/guide/index.md`. Skim and amend if drift is present.

If no doc references the four-file seed list, skip — no doc to update.

### Step 6 — Commit + ship

- `git add` modified files.
- Commit on `claude/feat/bts-318-init-drop-lifecycle-doc-seeding` with message `feat(bts-318): drop per-feature lifecycle docs from /ccanvil-init Step 6 seed loop`.
- Push.
- Run `/pr --skip-review` (drift-guard tests are the safety net; pure prose change with paired test coverage; per `feedback_skip_review_on_trivial_diffs`).
- Run `/ship 161` to merge + auto-close BTS-318.

## Constraints

- No behavioral change to existing nodes — they're past init and have moved on.
- No change to `.ccanvil/templates/spec.md`/`plan.md`/`stasis.md` — they remain valid for /spec/plan/stasis to copy on demand.
- No change to `/spec`, `/plan`, `/stasis` skills — they continue writing to the lifecycle paths.
- Drift-guard test (Step 1's AC-10b) prevents future re-introduction.

## Risks

- AC-11's in-progress-feature detection still requires `docs/stasis.md` to be mentioned — Step 2's rewording must preserve that reference. Mitigation: explicit AC-11 verification in Step 3.
- Retrofitted nodes (mature-repo / partial-ccanvil mode) that already have placeholder lifecycle docs from prior init runs are NOT auto-healed by this change — that's BTS-314 territory and out of scope per spec. Mitigation: spec already documents this boundary.
