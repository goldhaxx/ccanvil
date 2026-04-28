# Roadmap

<!-- This is your project's strategic source of truth.
     Update it when direction changes, not every session.
     The /radar command reads this to contextualize tactical work. -->

## Vision

ccanvil makes AI-assisted development fast, reliable, and consistent across projects — by turning Claude Code from a capable but undirected tool into a disciplined development partner with guardrails, workflows, and shared practices that sync automatically. It is an operational layer: Claude Code is the compiler, ccanvil is the build system.

## Goals

1. **Near-zero approval overhead** — Claude works autonomously on routine operations; the operator only intervenes on genuinely consequential actions
2. **Frictionless sync** — hub changes propagate to downstream nodes with minimal manual effort; drift is detected automatically (drift-watchdog active)
3. **Reliable bootstrap** — `/init` works flawlessly on new and mature projects, every time
4. **Self-stabilizing system** — the determinism review loop, evidence-required-for-captures protocol, and dual-capture of candidates to Linear keep pushing stochastic operations and quality gaps into deterministic substrate

## Active Theme

**Stabilization & Maturation** — drain the backlog to zero, prove the system stays there, then evaluate the next theme. The substrate-maturity arc (SSOT-Linear, http resolver, dual-capture resilience, ship-finalize) has converged enough that the marginal capability is now smaller than the marginal stabilization gap. We've reached the point where **substrate maturation surfaces previously-invisible bugs faster than they can be closed** — a defect-discovery-rate-exceeds-defect-closure-rate condition. The cure is bounded: cap capture velocity, drain to zero, hold there.

*Started: 2026-04-27 (session 9, mid-conversation).* Reason: 4 ships per session at substrate maturity has produced a steady drip of dogfood-surfaced gaps that outruns closure throughput. Auto mode + Claude Code shipping is working well; the bottleneck is no longer impl velocity, it's discovery cadence. Rather than ship more capability, ship *less*, drain what's open, harden discoverability.

**Capture rules during stabilization** — strict, agent-enforced where possible:

- New captures allowed ONLY if (a) evidence-backed bug blocking active work, or (b) security-critical.
- Speculative ideas, optimization candidates, refactors, and "nice-to-have" determinism candidates → straight to **Icebox**, not Triage. Re-evaluate at theme exit.
- No new substrate primitives. Bugs in existing substrate are in scope; new capability work is not.
- Determinism candidates surfaced by `/stasis` Determinism Review continue to dual-capture, but auto-route to Icebox during stabilization (not Triage).
- WIP-limit: one active spec at a time. No theme work, no exploratory architecture.

**Exit criteria** — all four must hold simultaneously for 14 consecutive days:

1. **Backlog ≤ 5** (allowing one or two long-tail tickets to persist as ambient horizon items).
2. **Triage = 0** at the end of every session.
3. **Icebox not growing** — captures during the phase route there but don't compound; rate decays.
4. **No new captures for 7 consecutive days** by the end of the phase.

When all four hold, the system has converged. Then evaluate the next theme.

**Reconnection mechanism** — the operator has noted the autonomous-shipping flow has created a code-intuition disconnect (real concern, not a bug). Rather than hand-shipping (the operator has explicitly chosen full-autonomous), the antidote is **substrate transparency**: the next theme will likely lean on Nate B Jones' Dark Code framework (self-describing systems with module manifests, failure modes, behavioral contracts) to keep the operator connected to the substrate without forcing manual labor. Dark Code feels prescient here — flagged as the prime next-theme candidate.

## Maturity Signal (theme-agnostic)

A separate, durable measure of system maturity: **opening the project shows triage = 0, backlog = 0, icebox = 0 — and stays there.** New bugs, determinism candidates, and self-improvement requests stop arriving at a steady cadence because the substrate has converged. Today: 0 triage, 9 backlog, 2 icebox. The Stabilization & Maturation theme drives toward this signal directly.

## Up Next — Stabilization Drain Order

**Phase 1: Small ships** (mechanical, located, low design-ambiguity):

1. **BTS-215** — `docs-check.sh` usage string sync with dispatch table (P4, mechanical sweep)
2. **BTS-238** — `stasis-carry-forward` regex-escape gsub fix (P3, located at line 4602, one-character replacement-string change)
3. **BTS-237** — spec dispatch + activate concurrent-edit race (P3, foundational — every spec ship pays the cost; either content-hash skip or single-writer pattern)
4. **BTS-207** — `cmd_session_info` jq forks reduction (P4, single-jq rewrite)
5. **BTS-211** — `operations.sh exec` http-mechanism dispatch fix (P3, dispatch-shape change)
6. **BTS-236** — `derive-pr-title` structural pivot to `> Subject:` spec metadata field (P3, light design choice)

**Phase 2: Operator-decision** (small but require design call on instrumentation shape):

7. **BTS-209** — Canonize hook failure-handling pattern (loud, never-block, never-snuff)
8. **BTS-208** — Hook + skill execution timing instrumentation

**Phase 3: Architectural review** (last — these may inform the next theme's framing):

9. **BTS-183** — Provider integration strategy: end-to-end http-or-MCP cohesion review
10. **BTS-217** — SSOT-Linear routing-flip dogfood (closes the BTS-204 arc; demand-side validation step)

**Then evaluate next theme.** Working candidates:

- **Dark Code / Three-Layer Solution** — Nate B Jones' framework. Three layers: (1) Spec-Driven Development (already partially implemented), (2) Self-Describing Systems (biggest gap today — module manifests with structural + semantic context, failure modes, behavioral contracts readable by humans and AI), (3) Comprehension Gate (review step where senior engineers + AI pose critical questions about design). Source: https://www.youtube.com/watch?v=E1idsrv79tI. The operator flagged this as prescient relative to the autonomy/disconnection tension. Strong candidate for next theme — would directly address the "I'm no longer connected to the code underneath" concern surfaced in session 9.
- **"Simplicity through leverage" / Raptor v1→v3** — modular personality packs (see Next Theme — Direction below). Less directly tied to current pain; better as a Phase-2 theme.

## Next Theme — Direction (not yet committed)

**Working idea: "Simplicity through leverage" — Raptor v1 → v3.** The visual: maximal efficiency, fewer parts, cleaner lines, an order-of-magnitude upgrade arrived at by removing the wrong things, not adding more.

Mechanism under exploration: **modular personality packs.** ccanvil supports pluggable frameworks — Musk, Bezos, Jobs, Lin-Manuel Miranda, etc. — each curated to encode an operator's worldview into ccanvil's behavior. A pack measurably affects:

- **Performance** — how aggressively the system optimizes for throughput vs. caution
- **Functionality** — which skills, hooks, and rules are active
- **Cadence** — pacing of work, batch size, ship rhythm
- **Decision-making** — defaults for tradeoffs (speed vs. correctness, scope vs. simplicity, etc.)
- **Operations** — gating, review thresholds, what gets challenged vs. accepted

Packs are **configurable at the node level**: the hub runs one personality, each downstream node selects its own. The first pack to curate: **Elon Musk** — distilled from *The Book of Elon* (essence, system, leverage, worldview).

Open questions for the future spec session:

- What's the canonical pack format? File layout, manifest, override mechanics?
- How do packs compose with the existing rules / skills / settings layers?
- Does a pack ship as a `.ccanvil/packs/<name>/` directory, or as a switchable bundle in `hub/packs/`?
- How is pack effect measured — does ccanvil track behavioral deltas before/after activation?
- What does "default ccanvil" become when no pack is active — neutral, or implicitly the operator's own pack?

Decide formally at theme rollover. Until then, this is direction, not commitment.

## Horizon

- **BTS-22: Docs directory strategy** — multi-file specs/plans/stasis to reduce write friction and enable parallel features. Likely subsumed or reshaped by SSOT-Linear; revisit after BTS-204. (Medium, needs-research)
- **Open-source packaging** — documentation, onboarding UX, multi-tool support. Conditions ("until tool stabilizes for personal use") approaching met; defer formal decision until next theme is named.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
