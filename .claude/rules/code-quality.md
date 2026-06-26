---
tier: 0
scope: universal
stack: any
anchors:
  evidence:
    - docs/research/code-quality-foundations.md
manifest_ref: code-quality.manifest.yaml
---

# Code Quality Rules

- **Patterns over descriptions:** follow an established pattern exactly; name the file to copy ("same as [file]") rather than describing it. If none exists, establish + document one.
- **Error handling:** every fallible function has an explicit error path; never swallow errors (log or propagate); use typed errors, not strings; external calls get try/catch with meaningful context.
- **Dependencies:** justify each before adding (what it does / why not native / maintenance status); prefer stdlib + built-ins; pin versions — no `^` or `~`.
- **Organization:** one concept per file (~200 lines is a split signal); imports top, exports bottom, logic middle; no circular deps; constants/config at top.
- **Naming:** reveal intent (`getUserById` not `getData`, `isExpired` not `check`); booleans start is/has/can/should; promise-returning functions are verbs (`fetchUser`); avoid non-universal abbreviations.

`.ccanvil/guide/foundations.md` is protected research source — never modify without explicit user approval.

For the full per-category catalog and rationale: see evidence anchor `docs/research/code-quality-foundations.md`.
