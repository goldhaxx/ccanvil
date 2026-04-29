---
manifest:
  id: review
  purpose: Three-layer review of uncommitted changes — (1) spawns the code-reviewer sub-agent for INFO/WARN/CRITICAL findings, (2) runs the deterministic security-audit substrate (--files-only), (3) lightweight self-review per `.claude/rules/self-review.md` for stochastic-op candidates. Recommends commit-or-fix-first.
  routes-by: /review
  input:
    - "no positional args (synthesizes from current uncommitted diff)"
  output:
    - "stdout: combined review + security audit + self-review summary with recommendation"
  depends-on:
    - security-audit.sh
  side-effect:
    - reads-only-no-mutations
  failure-mode:
    - "no-uncommitted-changes | exit=0 | visible=stdout-clean-message | mitigation=run-after-edits"
    - "critical-finding | exit=non-zero | visible=critical-list-with-rationale | mitigation=fix-before-commit"
  contract:
    - read-only
    - three-layer-coverage
  anchor:
    - BTS-256 (manifest seed)
---

Review the current uncommitted changes using the code-reviewer sub-agent.

## Step 0: Manifest pre-flight (BTS-257 Layer 3 ramp)

Before spawning the code-reviewer agent, run the deterministic manifest pre-flight:

```bash
bash .ccanvil/scripts/module-manifest.sh validate --json 2>/dev/null
```

When `.ccanvil/manifest-allowlist.txt` exists, parse the JSON envelope and surface the result before the review proceeds:

- If `coverage.covered == coverage.total` AND `drift == []` → silent pass (no extra section).
- If `(.drift | length) > 0` → render `## Manifest drift` with one bullet per drifted entry (`<path>:<id> — <reason> [value]`). The reviewer agent uses this as the starting list for Layer 3 manifest-aware checks; the operator decides whether to clear drift first or proceed with review.

Skip this step silently when the allowlist is missing (downstream nodes that haven't adopted Layer 2 yet).

## Step 1: Code review

Delegate to the `code-reviewer` agent with this task:
"Review all uncommitted changes in this repository. Check for correctness, test coverage, security issues, performance concerns, manifest drift (BTS-257 Layer 3), and adherence to project conventions defined in CLAUDE.md."

## Step 2: Security audit

After the code review completes, run the security audit (deterministic):

```bash
bash .ccanvil/scripts/security-audit.sh --files-only
```

## Step 3: Self-review

Then do a quick self-review per `.claude/rules/self-review.md`: were there any stochastic operations in this session that should become deterministic? If so, note them briefly.

Summarize all three checks (code review, security audit, self-review) and recommend whether to commit or what to fix first.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
