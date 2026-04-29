# Manifest Rollout Plan — Codebase-Wide Coverage

> **Status:** ✅ COMPLETE — all 11 sessions shipped 2026-04-29; Layer 2 at 100% coverage (184/184); Layer 3 prose ramp landed via BTS-257; doc preserved as historical record.
> **Origin:** BTS-239 (Layer 2 first ship — substrate + 7 seed manifests)
> **Goal:** 100% allowlist-enforced manifest coverage across all ccanvil substrate
> **Anchored in:** `docs/research/dark-code-mapping.md` (Layer 2 — Self-Describing Systems)

## Why this is a multi-session program

BTS-239's stasis recorded the explicit decision to defer full coverage:

> Rejected option (b) (~159 manifests in one ship) as too big to hold quality.

Quality means **semantic accuracy** of every manifest field — not just structural validity that drift-guard can verify. A manifest is only load-bearing for cold-start comprehension when its `purpose`, `failure-mode`, `contract`, and `caller` claims are *actually true* about the code. That requires per-unit reading + grep + return-path enumeration. ~5–10 minutes focused work per manifest done well; 177 units = a sustained program, not one ship.

This document sequences the program so each session has a tight, completable objective and the allowlist + drift-guard substrate makes every increment safe to land.

## Inventory (snapshot, 2026-04-28)

| Container | Units | Done | Remaining |
|---|---:|---:|---:|
| Shell function-level (`cmd_*` in mega-scripts) | 130 | 130 | 0 |
| Shell file-level (single-purpose scripts) | 5 | 5 | 0 |
| Hooks (file-level) | 12 | 12 | 0 |
| Markdown — skills | 9 | 9 | 0 |
| Markdown — rules | 7 | 7 | 0 |
| Markdown — agents | 5 | 5 | 0 |
| Markdown — commands | 16 | 16 | 0 |
| **Total** | **184** | **184** | **0** |

**Last updated:** 2026-04-29 — BTS-256 Session 10 shipped (19 markdown frontmatter manifests: 4 agents + 15 commands). **Manifest coverage is now 100% (184/184) across the entire ccanvil substrate** — every operator-callable cmd_*, file-level shell, hook, skill, rule, agent, and command is self-describing. Session 11 remains for Layer 3 ramp (manifest-aware /review integration) + close-out of this rollout doc.

Per-mega-script breakdown (function-level):
| Script | cmd_* | Done |
|---|---:|---:|
| `docs-check.sh` | 51 | 3 |
| `ccanvil-sync.sh` | 43 | 0 |
| `linear-query.sh` | 16 | 0 |
| `manifest-check.sh` | 7 | 0 |
| `permissions-audit.sh` | 6 | 0 |
| `module-manifest.sh` | 4 | 4 ✓ |
| `operations.sh` | 2 | 0 |
| `context-budget.sh` | 1 | 0 |

## Session program

Each row = one shippable Linear ticket, one feature branch, one PR, one stasis. Numbers are sequential session indexes from this rollout's start (not global session counter — that continues from 13).

| # | Theme | Scope | Units | Effort |
|---|---|---|---:|---|
| 1 | **Substrate — markdown frontmatter parser** | Extend `cmd_extract` to parse YAML frontmatter `# manifest:` block (or HTML-comment shape — decide in spec). Verify cross-file caller/depends-on resolution still works at scale. Add 1 reference manifest per markdown sub-shape (1 skill + 1 rule + 1 agent + 1 command). | 0 + substrate | Comparable to BTS-239 |
| 2 | **`docs-check.sh` Part 1 — lifecycle cluster** | Spec/activate/plan/PR/land/ship/complete primitives + their internal helpers. Cohesive cluster, all routes-by `/spec` `/activate` `/plan` `/pr` `/ship` `/land`. | 24 fn | Heavy |
| 3 | **`docs-check.sh` Part 2 — capture + audit cluster** | idea/triage/artifact-read/artifact-write/audit/lifecycle-state/sessions/operations resolvers. | 24 fn | Heavy |
| 4 | **`ccanvil-sync.sh` Part 1 — sync core** | scaffold-pull, push, promote, demote, conflict-resolve. | 22 fn | Heavy |
| 5 | **`ccanvil-sync.sh` Part 2 — stack + registry** | Stack apply/list, registry, lockfile, broadcast, manifest-check integrations. | 21 fn | Heavy |
| 6 | **`linear-query.sh` — provider substrate** | All 16 GraphQL wrappers. Each manifest captures the GraphQL operation name, expected fields, mutation/query, and rate-limit failure paths. | 16 fn | Medium-heavy (GraphQL semantics) |
| 7 | **Small mega-scripts batch** | `permissions-audit.sh` (6) + `manifest-check.sh` (7) + `operations.sh` (2) + `context-budget.sh` (1). One session, four files. | 16 fn | Medium |
| 8 | **File-level shell + hooks** | `bats-lint.sh`, `bats-report.sh`, `fetch-license.sh`, `fix-cloudflare-certs.sh`, `security-audit.sh` + 12 hooks. All file-level. | 17 file | Medium |
| 9 | **Markdown — skills + rules** | 9 skills + 7 rules. YAML frontmatter `manifest:` block. | 16 file | Medium |
| 10 | **Markdown — agents + commands** | 5 agents + 16 commands. Same shape. | 21 file | Medium |
| 11 | **Layer 3 ramp + close-out** | Augment `code-reviewer` agent + `/review` skill with manifest-aware checks: PR adds new caller of cmd_X not declared → flag as architecture-shaped change. Close `docs/manifest-rollout.md` as fully shipped; update `roadmap.md` Dark Code section. | 0 (integration) | Medium |

**11 sessions.** Every cell ≤25 units (the "too big to hold quality" line). Estimated wall time: 11 sessions over ~3–6 weeks at typical cadence.

## Locked-in conventions (decided in BTS-239, do not revisit)

These conventions stay constant across all 11 sessions. Re-litigating them mid-rollout breaks consistency.

- **Field set (10 keys):** `id`, `purpose`, `routes-by`, `input`, `output`, `caller`, `depends-on`, `side-effect`, `failure-mode`, `contract`, `anchor`. `purpose`, `input`, `output`, `side-effect`, `failure-mode`, `contract`, `anchor` are required (drift-guard fails on missing). Others are conditional.
- **Failure-mode line:** `<id> | exit=N | visible=<phrase> | mitigation=<phrase>`. `exit=` accepts numeric codes OR special tokens (`passthrough`, `propagate`, `*`).
- **Inline source markers:** every declared `failure-mode` MUST have a matching `# @failure-mode: <id>` comment at the failing line; same for `side-effect`. Drift-guard enforces.
- **Allowlist semantics:** `<path>:<fn>` for function-level, `<path>` alone for file-level (falls back to `basename`). 100% drift-guard enforcement, never partial.
- **Granularity by container:** function-level for shell mega-scripts, file-level for single-purpose scripts and hooks, frontmatter for markdown.
- **Inline richness > drift-minimal terseness** (per `feedback_inline_richness_over_drift_minimal_for_self_describing_systems`).

## Continuity hooks (cross-session machinery)

These are the mechanisms that keep sessions consistent without needing a human to remember:

1. **Allowlist as authoritative state.** `.ccanvil/manifest-allowlist.txt` grows monotonically. Each session's PR appends N lines and ships their manifests. `/recall` step 11 (BTS-239) surfaces `Manifest coverage: X / Y, drift: N` automatically — every session's cold-start sees the live progress count.
2. **Per-session spec references this doc.** Each ticket's spec body says "per `docs/manifest-rollout.md` Session N." No re-derivation of conventions.
3. **Per-session stasis updates this doc.** The session's stasis writeup includes a one-line update to the inventory table (`Done` column) plus any anomalies (e.g., "found cmd_X has no callers — flagged as removal candidate"). This doc itself becomes a running status board.
4. **Drift count is a hard gate.** If `module-manifest.sh validate --json` reports `(.drift | length) > 0` at any point during a session, the session does NOT ship until drift is cleared. Quality > velocity.
5. **One ticket per session.** Each rollout session is exactly one Linear ticket. Spec → branch → PR → ship → stasis. No interleaving with non-rollout work in the same branch (avoids review confusion).
6. **Optional pause windows.** After Session 3 (docs-check.sh complete) and Session 7 (all shell complete), the operator may pause the rollout for unrelated work without losing continuity — coverage state is persistent in the allowlist + drift-guard.

## Quality bar (per manifest)

Drift-guard catches structural gaps. Semantic shallowness slips through. Each manifest must satisfy:

- **`purpose`** — one sentence answering "what does this do that no other primitive does?" Not "wraps X" — that's mechanism, not purpose.
- **`input`** — every CLI flag, positional arg, and env var the function reads. Not just the documented ones.
- **`output`** — what's emitted on stdout (JSON shape, plain text format) AND what's written to disk (paths, formats).
- **`caller`** — verified by `grep -rn '<fn_name>' <relevant_paths>`; declared callers must exist.
- **`depends-on`** — every helper function called from within the body. Verified by grep within the function's body lines.
- **`side-effect`** — every mutation outside the function's stack: file writes, network calls, env var mutations, subprocess spawns, stdin/stderr writes.
- **`failure-mode`** — every non-zero `return` and `exit` path enumerated. One entry per distinct failure semantics.
- **`contract`** — invariants the caller can rely on (idempotency, atomicity, never-partial-write, returns-empty-on-empty-input, etc.). Not just postconditions.
- **`anchor`** — origin BTS ticket plus any subsequent BTS that materially shaped the function.

If any of the above are missing or "best guess," the manifest is not ready to land.

## Open decisions (resolve in Session 1)

- **Markdown container shape.** YAML frontmatter (semantic alignment with skills' existing `name`/`description`/`type` frontmatter — preferred) OR HTML comment block (`<!-- @manifest -->`) (more uniform with shell `# @manifest`). Decide in Session 1's spec.
- **Cross-file caller resolution at scale.** BTS-239 drift-guard greps from the project root. Confirm this scales when callers span 10+ files (e.g., a primitive called from 4 different scripts + 2 skills + 1 hook). If grep is insufficient, may need a manifest-author helper that pre-derives the caller set.
- **Per-session ticket naming.** Suggest `BTS-MAN-N` style (e.g., `BTS-XXX: Manifest rollout — Session N (docs-check.sh Part 1)`) for backlog grouping. Decide on first session.

## What success looks like

When Session 11 ships:

- `Manifest coverage: 184 / 184, drift: 0` on every `/recall`
- Every operator-callable substrate primitive carries inline `purpose`, `input`, `output`, `side-effect`, `failure-mode`, `contract`, `anchor`
- `code-reviewer` agent automatically flags PRs that introduce new callers of manifested primitives without updating the manifest
- `docs/research/dark-code-mapping.md` Layer 2 status updates from `~10%` to `~100%`
- This document closes; the rollout becomes a one-time historical record

## Anchors

- BTS-239 (origin substrate + 7 seed manifests, this rollout's prerequisite)
- `docs/research/dark-code-mapping.md` (Layer 2 mapping)
- `.ccanvil/templates/manifest.md` (format reference — locked)
- `.ccanvil/manifest-allowlist.txt` (live state)
- `feedback_inline_richness_over_drift_minimal_for_self_describing_systems` (memory)

## Status: COMPLETE

The rollout shipped end-to-end across 11 sessions, all on 2026-04-27 → 2026-04-29.

**Final coverage: 184 / 184 (100%), drift 0** on every `/recall`.

### Per-session ledger

| # | Ticket | Theme | Manifests added | Allowlist after | PR |
|---|---|---|---:|---:|---|
| 1 | BTS-239 | Substrate + 7 seed manifests | 7 | 7 | (origin) |
| 2 | BTS-241 | docs-check.sh Part 1 — lifecycle cluster | 24 | 31 | — |
| 3 | BTS-242 | docs-check.sh Part 2 — capture + audit | 24 | 55 | — |
| 4 | BTS-240 | Markdown frontmatter substrate + 4 ref manifests | 4 | 59 | — |
| 5 | BTS-243 | ccanvil-sync.sh Part 1 — sync core (22 cmd_*) | 22 | 81 | #142 |
| 6 | BTS-244 | ccanvil-sync.sh Part 2 — stack + registry (21 cmd_*) | 21 | 102 | #143 |
| 7 | BTS-245 | linear-query.sh — provider substrate (16 GraphQL wrappers) | 16 | 118 | #144 |
| 8 | BTS-246 | Small mega-scripts batch — permissions-audit / manifest-check / operations / context-budget | 16 | 134 | #145 |
| 9 | BTS-251 | File-level shell + hooks (5 scripts + 12 hooks) + substrate fallback for file-level | 17 | 151 | #146 |
| 10 | BTS-252 | Markdown skills + rules (8 skills + 6 rules) + SIGPIPE-resistant `_target_body_grep` | 14 | 165 | #147 |
| 11 | BTS-256 | Markdown agents + commands (4 agents + 15 commands) | 19 | 184 | #148 |
| close-out | BTS-257 | Layer 3 ramp + close-out (no new manifests) | 0 | 184 | #149 |

### Substrate fixes shipped alongside

- **BTS-251** — `_function_body_grep` file-level fallback. When no `${fn_id}()` decl is found in the file, fall back to whole-file grep. Required to make file-level shell (single-purpose scripts + hooks) drift-guard-checkable, since basename-derived IDs have no fn() boundary.
- **BTS-252** — SIGPIPE-resistant `_target_body_grep`. Original `awk | grep -qE` pipeline trips under `set -o pipefail` when grep -q matches early and SIGPIPEs awk; falsely reported depends-on-not-found on large markdown bodies (305-line idea SKILL.md was the canary). Fix: capture awk output to a var first, then grep. Regression test under `hub/tests/module-manifest-markdown-validate.bats`.

### Layer 2 outcome

Every operator-callable substrate primitive — across 130 cmd_* in 8 mega-scripts, 5 single-purpose scripts, 12 hooks, 9 skills, 7 rules, 5 agents, and 16 commands — now carries inline `purpose`, `input`, `output`, `side-effect`, `failure-mode`, `contract`, and `anchor` fields. Bidirectional drift-guard catches structural regression on every `/recall` and on every `/review` (via the BTS-257 Layer 3 ramp).

### Layer 3 status

The `code-reviewer` agent + `/review` skill now run a manifest-aware pre-flight (`module-manifest.sh validate --json`) and flag four classes of manifest drift in PR diffs:

- New caller of `cmd_X` not in declared `caller:` list.
- New helper or script invocation not in `depends-on:`.
- New `return N` / `exit N` (N != 0) path not enumerated in `failure-mode:`.
- New file write / network call / env mutation / subprocess not in `side-effect:`.

This is a **prose-layer ramp** — Claude reads the manifest as the canonical contract during review, surfaces drift as `manifest-drift / architecture-shaped change` findings. A future Phase 2 ticket can convert this to a deterministic check (e.g., a `module-manifest.sh diff-vs-manifest --diff <git-diff>` primitive). For now, prose nudge + drift-guard validate covers the Comprehension Gate footprint.

### Doc lifecycle

This document is preserved as a **one-time historical record** of the 11-session program. Future Layer 2 maintenance is per-substrate — each new `cmd_*` or markdown skill/rule/agent/command lands with its manifest co-located in the same PR. The allowlist is the authoritative state going forward; this doc is no longer load-bearing.
