# Rule atomicity + content-tiering architecture

> Status: research draft (pre-spec)
> Created: 2026-05-08
> Origin: BTS-384 capture surfaced fleet-wide context-budget pain (165% / 8000-token soft ceiling).
> Sibling input to: BTS-385 (rule-tier audit ticket — to be captured).

## 1. Problem

Every Claude Code turn, on every node in the fleet, the harness auto-loads:

- `~/.claude/CLAUDE.md` (operator-global)
- Project `CLAUDE.md`
- All `.claude/rules/*.md` files
- `.claude/settings.json`
- `.claudeignore`

Hub measurement (2026-05-08):

| File | Tokens | % of 8000-budget |
|---|---|---|
| tdd.md | 2306 | 28.8% |
| settings.json | 1539 | 19.2% |
| provider-integration.md | 1353 | 16.9% |
| evidence-required-for-captures.md | 1323 | 16.5% |
| background-task-discipline.md | 1292 | 16.2% |
| deterministic-first.md | 1127 | 14.1% |
| CLAUDE.md (project) | 1009 | 12.6% |
| self-review.md | 1002 | 12.5% |
| workflow.md | 789 | 9.9% |
| code-quality.md | 754 | 9.4% |
| ~/.claude/CLAUDE.md (global) | 548 | 6.9% |
| .claudeignore | 182 | 2.3% |
| **TOTAL** | **13224** | **165.3%** |

Tour-scheduler (downstream consumer node): 160% — same picture, lighter project-specific CLAUDE.md.

**Root cause:** rule files have grown to ~1000-2300 tokens each. They embed war stories ("Why"), substrate-specific tooling references (bats-report.sh, module-manifest.sh), anti-pattern catalogs, and deep evidence — all auto-loading on every turn, on every node, regardless of relevance.

**Compound effect:** every irrelevant token in a rule is a token stolen from the agent's reasoning budget AND a token stolen from every other turn forever. This is the most expensive context category in the system because it scales as `tokens × turns × nodes × time`.

## 2. First principles

**Attention is zero-sum.** Context consumed by always-on rules is context unavailable for the actual problem. The harness auto-load mechanism was designed when rules were genuinely small directives; ccanvil rules have grown into mini-documents.

**Loading cost should match access frequency.**

- A directive read on every turn (e.g. "spec before code") → cheap auto-load is right.
- A war story explaining WHY the directive exists → almost never accessed; should be on-demand.
- A bats-specific tooling reference → only relevant when running tests in a bats project; should be stack-conditional + on-demand.
- A substrate-developer convention (e.g. provider-integration.md) → only relevant in ccanvil itself or other hubs that develop ccanvil; never relevant on consumer nodes.

The fix is not "smaller rules." The fix is **tiering**: separate WHAT must be ambient (directive) from WHAT must be reachable (reference), and load each at the right time.

## 3. Three-tier model

### Tier 0 — Atoms (rules)

**What:** Behavioral directives. One rule = one behavior the agent applies. <100 tokens per rule. Always-on.

**Characteristics:**
- Imperative voice. ("Run tests after every change.")
- No "Why" inline — link to Tier 2 instead.
- No tool-specific commands inline — link to Tier 1 skill instead.
- One assertion per rule file. Multiple assertions = multiple files.
- Frontmatter declares tier, scope (BTS-384), stack-applicability.

**Example shape:**

```markdown
---
tier: 0
scope: universal
stack: any
anchors:
  - skill: tdd-bats        # how to apply when stack=bats
  - skill: tdd-jest        # how to apply when stack=jest
  - reference: docs/research/tdd-evidence.md
---

# Test-First Discipline

Write a failing test before writing implementation. No exceptions for "small" changes.

When running tests: see the skill that matches the project's test runner.
When questioning the rule: see the reference for evidence and tradeoffs.
```

**Budget target:** all Tier-0 atoms combined ≤ 1500 tokens (≤ ~20% of soft budget).

### Tier 1 — Skills (workflow + tooling reference)

**What:** Workflow recipes, tooling catalogs, anti-pattern lists, stack-specific conventions. ~500-2500 tokens per skill. Loaded only on invocation (slash command, agent-recognized trigger, or hook-injected reminder).

**Already-existing substrate.** ccanvil has 18+ skills under `.claude/skills/`. The proposal is to MOVE content out of rules INTO skills, not invent new tier infrastructure.

**Examples (post-migration):**

- `.claude/skills/tdd-bats/SKILL.md` ← strict-mode bats subsection from `tdd.md`, full bats-report.sh tooling reference.
- `.claude/skills/tdd-jest/SKILL.md` ← jest equivalents (when added).
- `.claude/skills/background-tasks/SKILL.md` ← anti-pattern catalog from `background-task-discipline.md`.
- `.claude/skills/provider-integration/SKILL.md` ← full http-vs-MCP reasoning from `provider-integration.md`.
- `.claude/skills/evidence-gate/SKILL.md` ← full evidence-anchor protocol from `evidence-required-for-captures.md` (already partially in `idea` skill).

**Discovery:** Tier-0 atom carries an `anchors:` frontmatter pointing to relevant skill(s). Agent reads atom every turn (cheap), follows pointer when work-context matches.

### Tier 2 — Reference (evidence + research)

**What:** Deep dives, war stories, foundational research, BTS-anchor incident reports. Token cost unbounded. Read only when explicitly fetched.

**Already-existing substrate:** `docs/research/`, `.ccanvil/guide/`, archived `docs/sessions/`. The proposal is to extract "Why" + war stories from rules and route them here.

**Examples (post-migration):**

- `docs/research/tdd-evidence.md` ← Red-Green-Refactor research, Live-API gate incidents (BTS-115, BTS-170).
- `docs/research/background-task-incident.md` ← BTS-383 origin incident, full timeline.
- `docs/research/provider-integration-decision.md` ← BTS-183 + BTS-164 migration decision matrix.
- `docs/research/evidence-gate-incident.md` ← BTS-198 phantom-rule incident.

**Access:** the agent uses `Read` when an atom's reference link is followed, or when the operator asks "why does this rule exist?" Cost is paid once per access, not per turn.

## 4. Atomicity principle

**One rule = one behavior the agent decides about.** If a rule has subsections, it's actually multiple rules masquerading as one.

Counter-example (current `tdd.md`, ~2306 tokens):

| Subsection | Behavior | Should be |
|---|---|---|
| Red-Green-Refactor cycle | "Test first" | Tier-0 atom |
| Live-API validation gate | "When plan flags risk, run live call" | Tier-0 atom |
| Test Structure (file naming, AAA pattern) | Convention catalog | Tier-1 skill |
| What to Test | Heuristic guide | Tier-1 skill |
| When Tests Break | Reactive procedure | Tier-1 skill |
| Hooks Integration | Mechanism note | Tier-2 reference |
| Strict-mode bats tests | Stack-specific lint pattern | Tier-1 skill (`tdd-bats`) |
| Running the suite (BTS-118) | Tooling reference | Tier-1 skill (`tdd-bats`) |
| Test execution discipline (BTS-383) | Cadence directive | Tier-0 atom + Tier-1 skill detail |

**Nine concerns in one rule.** Atomization splits this into 3-4 Tier-0 atoms (~80 tokens each) + 1-2 Tier-1 skills + 1 Tier-2 research doc.

## 5. Stack-profile mechanism

User's exact framing: *"the bats specific verbiage should go somewhere that the hub and node projects which use bats can take advantage of."*

**Proposal:** stack profiles are skills tagged with `stack: <name>` in frontmatter. `ccanvil.json` declares the project's stacks. The harness/agent loads a stack-tagged skill ONLY when the project's stacks include the skill's stack.

```yaml
# .claude/skills/tdd-bats/SKILL.md
---
tier: 1
scope: universal
stack: bats
---
```

```jsonc
// project's .claude/ccanvil.json
{
  "stacks": ["bats"]              // hub uses bats
}

// or
{
  "stacks": ["jest", "playwright"] // a frontend node
}

// or
{
  "stacks": ["pytest"]            // a python node
}
```

**Composition:** a node can declare multiple stacks. Skills tagged `stack: any` always load; skills tagged `stack: <X>` only load when X is in the project's stacks list.

**Benefit:** ccanvil's bats-specific skill IS available to bats-using downstream nodes (the user's exact ask) — but invisible on jest/pytest nodes. Single hub-curated source of truth, multi-stack-aware distribution.

**Future:** stack profiles can extend beyond test runners — `stack: typescript`, `stack: rust`, `stack: linear-routed`, etc. Becomes a generic conditional-load mechanism.

## 6. Composition with BTS-384 (scope tags)

The two tickets are orthogonal layers. They compose:

| Frontmatter field | Controls | Source ticket |
|---|---|---|
| `tier:` | Loading strategy (always-on vs on-invocation vs on-demand) | this research → BTS-385 (sibling) |
| `scope:` | Distribution (which nodes receive the file) | BTS-384 |
| `stack:` | Conditional loading by tech stack | this research → BTS-385 |

**Example combinations:**

```yaml
tier: 0          # always-on atom
scope: universal # all nodes get it
stack: any       # not stack-specific
# → ships everywhere, loads every turn. The bare directives.
```

```yaml
tier: 1          # on-invocation skill
scope: substrate # only ccanvil-substrate-developer nodes
stack: any
# → only ccanvil + similar hub-developer projects get it. Loads when invoked.
```

```yaml
tier: 1
scope: universal
stack: bats
# → ships everywhere, loads only when project declares stack=bats.
```

```yaml
tier: 2          # reference doc
scope: hub-only  # never distributes
stack: any
# → lives in hub only; nodes pull links from anchor frontmatter but don't carry the file.
```

**Implementation order:** sibling (atomization + tiering) ships BEFORE BTS-384 (scope tags). Reason: scope tags assume rules are correctly-shaped atoms; classifying a multi-section rule as "universal" vs "substrate" is muddy when the rule itself contains both kinds of content. Atomize first, then tag.

## 7. Per-rule transformation map

Audit pass over the 8 current rule files. Token estimates approximate.

| Current rule | Tier-0 atom(s) | Tier-1 skill(s) | Tier-2 reference(s) | Token reduction |
|---|---|---|---|---|
| `tdd.md` (2306) | "Test-first discipline" + "Live-API gate" | `tdd-bats` (strict-mode + suite tooling + execution discipline) | `tdd-evidence.md` (R-G-R research, BTS-115/170 incidents) | 2306 → ~150 |
| `provider-integration.md` (1353) | "Substrate uses http; MCP for ad-hoc only" | `provider-integration` (full reasoning) | `provider-migration-decision.md` (BTS-183/164 matrix) | 1353 → ~50 (substrate scope) → 0 on consumer nodes |
| `evidence-required-for-captures.md` (1323) | "Bug captures need anchors or DIAGNOSE: prefix" | folded into existing `idea` skill | `evidence-gate-incident.md` (BTS-198) | 1323 → ~80 |
| `background-task-discipline.md` (1292) | "No wait-loop grep; no parallel duplicates; buffered ≠ hung" | `background-tasks` skill (anti-pattern catalog) | `background-task-incident.md` (BTS-383 timeline) | 1292 → ~100 |
| `deterministic-first.md` (1127) | "Hook → script → command → reasoning" hierarchy | folded into `code-review` skill | `deterministic-first-foundations.md` (full essay) | 1127 → ~120 |
| `self-review.md` (1002) | "Stasis Determinism Review is mandatory" | already in `stasis` skill | — | 1002 → ~50 |
| `workflow.md` (789) | "Feature lifecycle: Spec → Activate → Plan → Implement → /pr → /ship" | already in lifecycle skills | — | 789 → ~80 |
| `code-quality.md` (754) | Mostly atomic already; trim 20% | minor reorg | — | 754 → ~600 |

**Net Tier-0 budget after atomization:** ~1230 tokens (down from 9946 in rules alone). Plus settings.json + CLAUDE.md + global CLAUDE.md = ~4400 tokens auto-load total. **55% of 8000 budget.** Safe headroom restored.

**Skills bloat does NOT count against context budget** — skills load on invocation. Move-not-shrink is the optimization.

## 8. Anchor / pointer mechanism

How does an agent find Tier-1 / Tier-2 content from a Tier-0 atom?

**Frontmatter `anchors:` field.** The atom declares where deeper context lives:

```yaml
---
tier: 0
anchors:
  apply:
    - skill: tdd-bats         # when stack=bats
    - skill: tdd-jest         # when stack=jest
  evidence:
    - reference: docs/research/tdd-evidence.md
  related-rules:
    - .claude/rules/atom-deterministic-first.md
---
```

**Agent behavior:** when applying the rule, the agent checks the project's `stacks` and reads the matching `apply` skill. When questioning the rule, the agent reads the `evidence` reference. When debugging conflicts, the agent reads `related-rules`. The pointer mechanism is read-on-demand; the atom itself stays cheap.

**Operator UX:** `bash docs-check.sh rule-resolve <rule-id>` returns the atom + skill + ref bundle as a structured envelope, mirrors the existing `operations.sh resolve` shape.

## 9. Migration plan

Multi-session ramp. Suggested sequencing:

### Session A — Substrate (BTS-385)

Build the substrate that supports tiering before migrating any rule.

- Frontmatter spec: `tier:`, `scope:`, `stack:`, `anchors:` schema.
- `module-manifest.sh` extension: validate frontmatter on rule files (detect missing tier/scope/stack).
- New primitive `cmd_rule_resolve <rule-id>` returns the atom + skill + ref bundle.
- Stack-aware skill loader logic in skill-discovery substrate (TBD how harness exposes this; might be skill prose convention rather than substrate code).
- Drift-guard: `validate` exits non-zero if a Tier-0 atom exceeds N tokens (lint).
- Bats coverage for all the above.

### Session B — Atomization audit (substrate-driven, deterministic)

Walk the per-rule transformation map. For each current rule:

1. Extract Tier-0 atom(s) into one-behavior-per-file shape.
2. Move Tier-1 content to existing or new skill.
3. Move Tier-2 content to `docs/research/` reference.
4. Link via `anchors:` frontmatter.
5. Bats fixture verifies the atom+skill+ref triple loads correctly.

Per-rule effort: ~30-45 min. Total: ~6 hours across 2 sessions.

### Session C — BTS-384 scope tags (downstream of atomization)

Add `scope:` distribution filter to ccanvil-sync.sh. Audit-pass on the now-atomized rules to assign correct scope.

### Session D — CLAUDE.md trim + settings.json review

Project-level CLAUDE.md is 1009 tokens; trim to ~500. Global CLAUDE.md trim to ~300. Settings.json review — pre-allowed commands could be shrunk via grouped wildcards.

**Rollout cadence:** Session A unblocks B. B unblocks C. D is parallelizable. Total: 4-5 sessions.

## 10. Open questions for spec session

- **Skill discovery mechanism.** Today, slash-commands trigger skills. For the agent to lazy-load a `tdd-bats` skill upon recognizing it's writing a bats test, either: (a) a hook injects a system-reminder pointing at the skill, (b) the harness exposes a "discover skills by tag" API, or (c) the agent reads a registry index file. Path-of-least-resistance: (a) — hook on file-edit.
- **Migration backward-compat.** Existing nodes pull rules via `ccanvil-pull`. After atomization, the rule-file count grows (~10 atoms vs 8 multi-section files). Is the diff manageable, or does it break operator mental model?
- **Atom file naming.** `atom-test-first.md` vs `tdd-test-first.md` vs flat `test-first.md`. Convention TBD.
- **Threshold for "atom too long."** ≤100 tokens? ≤150? Lint enforcement at PR time.
- **Should `stack:` support inheritance?** A `tdd-bats` skill might want to inherit a `tdd-base` skill's content. Probably no — keep flat for v1.
- **Reference docs as Linear documents?** SSOT-Linear (BTS-204) suggests artifacts can route to Linear. Reference docs could be Linear Documents linked from anchors. Probably out-of-scope for v1; revisit after adoption.
- **Stacks declaration UX.** Agent inferring stack from `package.json` / `Cargo.toml` / etc. vs operator declaring in `ccanvil.json`. Probably explicit declaration in v1; auto-detect later.
- **Personality packs theme** (next-theme working idea, per roadmap). Personality packs likely COMPOSE with this tier model — packs would be collections of atoms + skills + refs. Don't pre-design for them, but ensure tier model isn't pack-hostile.

## 11. Decision dependencies

- **Sibling (BTS-385) ships BEFORE BTS-384.** Atomization first, distribution-filter second. Reasoning in §6.
- **Sibling (BTS-385) shares spec session with this research doc as input.** Spec session reads §3, §4, §5, §7 as ACs source.
- **Onboarding theme reorder:** sibling becomes the next active spec, displacing BTS-314. Justification: fleet-wide context-bloat is a higher-impact problem than the inbox/microsoft365 heal pass — it benefits every node, including the heal-pass targets when they get re-pulled.

## 12. Anti-patterns to avoid in implementation

- **Atom inflation.** Resist the urge to add "context" to atoms. If you feel the atom needs explanation, move the explanation to Tier-2 ref. Atom stays sparse.
- **Skill duplication.** Don't create `tdd-bats-strict-mode` AND `tdd-bats-suite-tooling` AND `tdd-bats-execution-discipline`. One `tdd-bats` skill carries the bats discipline; sub-headers do the organization.
- **Reference doc proliferation.** Per-incident reference docs are valuable; per-decision reference docs less so. Keep refs to substantive evidence (war stories, research), not commentary.
- **Frontmatter creep.** Resist adding fields beyond `tier`, `scope`, `stack`, `anchors`. Each new field increases tax on every author.
- **Over-conditional loading.** Stack-profile composition is good; per-feature-flag composition is bad. Stacks are stable categorical; feature flags are operational ephemera. Don't conflate.

## 13. Related substrate

- **BTS-239** (module-manifest substrate) — frontmatter parsing precedent. Drift-guard for tier compliance reuses this.
- **BTS-310** (research-tier doc precedent) — `docs/research/dark-code-mapping.md` shows the research-doc cadence.
- **BTS-204** (artifact routing) — atomization could extend artifact concept to rule artifacts (rule = atom + skill links + ref links).
- **BTS-235** (`/ship` substrate composition) — example of moving multi-step work out of the agent's prose into a single substrate verb. Same compression pattern.
- **`.ccanvil/guide/foundations.md`** — already a Tier-2 reference (research source material). Pattern precedent: "rules cite, foundations elaborate."
- **`.claude/hooks/`** — hooks are zero-context-cost enforcement. Some atoms can become hooks instead. (E.g., "don't commit to main" is already `protect-main.sh` — the rule and the hook coexist as defense-in-depth, but the rule could be a 1-liner because the hook does the actual work.)

## 14. Validation thesis

The proposed architecture succeeds iff:

- **Hub context-budget** drops from 165% to ≤80% of 8000 (target: 4400 tokens auto-load).
- **Consumer-node context-budget** drops to ≤60% (target: 3500 tokens — they don't carry substrate-scope rules).
- **Rule discoverability** preserved — operator can still run "what rule applies to X?" and get a concrete answer (via `cmd_rule_resolve`).
- **Migration cost** ≤5 sessions (per §9).
- **No regressions** — all existing skills + rules continue to function during migration (atomized rule + extracted skill = same behavior).

If any of these fail at audit-time, halt and re-evaluate.

---

*End of research draft. Spec session input ready.*
