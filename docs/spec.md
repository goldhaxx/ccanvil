# Feature: Investigate suppressing redundant settings.local.json persistence

> Feature: bts-150-suppress-redundant-permission-persistence
> Work: linear:BTS-150
> Created: 1777171760
> Status: In Progress

## Summary

When Claude Code encounters a novel exact-form command for the first time, it prompts the user even if a broader allow pattern in `settings.json` already covers the command. After approval, the specific exact-form entry is auto-persisted to `settings.local.json` — creating drift that BTS-144 / BTS-149 then have to clean up periodically. This investigation determines whether a Claude Code configuration knob (settings field, hook, env var) can suppress the redundant prompt-and-persist at the source, eliminating the upstream cause of drift. Either we configure the knob and validate it, or we explicitly accept periodic cleanup as the permanent design.

## Job To Be Done

**When** Claude Code matches a novel command shape against existing broader allow patterns,
**I want to** suppress the redundant approval prompt and the auto-persistence to `settings.local.json`,
**So that** BTS-144's `promote-review` classifier never has to re-classify the same drift in subsequent sessions, and the substrate-level loop closes at the source rather than via periodic interactive triage.

## Acceptance Criteria

Each criterion is independently testable. Binary pass/fail.

- [ ] **AC-1:** Investigation summary committed to `docs/specs/bts-150-suppress-redundant-permission-persistence.md` (the archived completion document) explicitly answering: *"Is there a Claude Code mechanism — settings field, hook, env var, or other — that suppresses redundant prompt-and-persist when a broader allow already covers?"* The answer is one of three verdicts: `configurable` / `not-configurable` / `partial`.
- [ ] **AC-2:** If verdict is `configurable`: the configuration is applied to this project (in `.claude/settings.json` or equivalent), AND a validation step is documented in the spec showing a deliberately-introduced novel `bash <script>` invocation that matches `Bash(bash:*)` in `settings.json` produced **no** new entry in `settings.local.json` after approval. Evidence: a before/after diff of `settings.local.json` over the validation window.
- [ ] **AC-3:** If verdict is `not-configurable`: a one-paragraph "accepted-design" note is added to `.ccanvil/guide/command-reference.md` under the `permissions-audit.sh` section, stating that periodic `/permissions-review` is the permanent loop and explaining why source-level suppression is unavailable (linking back to BTS-150 and citing whichever Claude Code surface confirmed the gap — docs URL, source link, or "no documented knob exists as of $DATE").
- [ ] **AC-4:** If verdict is `partial`: both AC-2 and AC-3 fire — the partial configuration is applied AND validated for the cases it covers, AND the residual gap is documented in `command-reference.md` so operators know which drift classes still require periodic cleanup.
- [ ] **AC-5:** Investigation evidence (the search trail — Claude Code docs queried, settings fields tested, hooks attempted) is captured in the spec's "Investigation Notes" section so future-Zach can re-validate without re-running the search from scratch. Minimum 3 distinct sources cited (Claude Code official docs, hook reference, settings reference, or empirical config-test results).
- [ ] **AC-6:** Drift-guard: after the spec is archived to `docs/specs/`, running `bash .ccanvil/scripts/permissions-audit.sh promote-review --json | jq '.counts.total'` against this same project still returns a deterministic value (i.e., the cleanup substrate continues to function whether or not the suppression knob exists — this ticket doesn't break BTS-144).

## Affected Files

| File | Change |
|------|--------|
| `docs/specs/bts-150-suppress-redundant-permission-persistence.md` | Modified — investigation findings appended |
| `.claude/settings.json` | **Maybe modified** — only if AC-2 fires (a configurable knob is found and applied) |
| `.ccanvil/guide/command-reference.md` | **Maybe modified** — only if AC-3 or AC-4 fires (accepted-design note or partial-coverage note added) |

## Dependencies

- **Requires:** BTS-149 (`permissions-audit.sh promote-review` substrate) — already shipped. AC-6 drift-guard relies on it.
- **Blocked by:** none.

## Out of Scope

- **Modifying Claude Code itself.** This is an investigation into existing surfaces, not a feature request to Anthropic. If a knob doesn't exist, we accept the design — we don't propose upstream changes here.
- **Changing the BTS-144 classifier or the BTS-149 review skill.** Those substrates stay as-is regardless of verdict.
- **Bulk-cleaning existing `settings.local.json` drift.** That's `/permissions-review`'s job, not this ticket's. AC-6 only confirms the cleanup substrate still runs; it doesn't enumerate or fix specific entries.
- **Cross-project propagation of the configuration.** If a knob is found and applied here, downstream nodes adopt it via the normal `ccanvil-sync.sh` flow — out of scope for this ticket.

## Implementation Notes

- **Investigation methodology.** Use the `claude-code-guide` agent for the literature-search phase — it has WebFetch + WebSearch and is designed for "Does Claude Code support X?" questions. Specifically search for: settings.json field that controls auto-persistence, hooks that fire pre-/post-prompt-approval, env vars governing permission-resolution behavior, MCP-level interception of permission events. Pass the agent the BTS-150 description verbatim so it can frame the search.
- **Empirical validation pattern.** If a candidate knob is found, the validation step is a single deliberately-novel command. Pick a `Bash(bash <script>)` shape that's not currently in `settings.local.json`. Run a Claude Code interaction that triggers it. Inspect the diff of `settings.local.json` before vs. after. Zero new entries == AC-2 satisfied.
- **Document hygiene.** Investigation Notes section should follow this structure: (1) sources consulted, (2) candidate knobs found, (3) verdict per knob (configurable / no-effect / partial), (4) final verdict. Keep it audit-ready — future-Zach should be able to re-verify in <10 minutes.
- **Time budget.** Investigation tickets balloon. Hard-cap the search at 30 minutes. If no knob surfaces in that window, default to verdict=`not-configurable` and ship the accepted-design note. The cost of a wrong "not-configurable" verdict is one revisit when a future Claude Code release adds the knob — cheap.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
