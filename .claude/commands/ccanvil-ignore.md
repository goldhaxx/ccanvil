---
manifest:
  id: ccanvil-ignore
  purpose: Mark a hub-tracked file as node-only — permanently excluding it from /ccanvil-pull and /ccanvil-push. Use when the file is intentionally project-specific. Reversible via `ccanvil-sync.sh track <file>`.
  routes-by: /ccanvil-ignore
  input:
    - "positional: <file-path>"
  output:
    - "side-effect: lockfile entry flipped to node-only; future /ccanvil-pull and /ccanvil-push skip this file entirely"
  depends-on:
    - ccanvil-sync.sh
  side-effect:
    - mutates-lockfile
  failure-mode:
    - "file-not-tracked | exit=non-zero | visible=stderr-error | mitigation=verify-file-is-in-lockfile"
  contract:
    - deterministic-no-claude-judgment
    - confirmation-prompted-before-mutation
    - reversible-via-track-subcommand
  anchor:
    - BTS-256 (manifest seed)
---

Mark a hub-tracked file as node-only, permanently excluding it from sync.

Use when a file is intentionally project-specific and should never be pulled, pushed, or shown as a conflict again.

This is a fully deterministic operation. No Claude judgment needed.

## Steps

1. The user provides a file path as an argument: `/ccanvil-ignore .claude/rules/sketches.md`

2. Confirm with the user: "This will mark `<file>` as node-only. It will be permanently excluded from `/ccanvil-pull` and `/ccanvil-push`. You can undo this with `./.ccanvil/scripts/ccanvil-sync.sh track <file>`. Proceed?"

3. **(DETERMINISTIC)** Run:
```bash
./.ccanvil/scripts/ccanvil-sync.sh node-only <file>
```

4. Report the result.

## Rules
- If the file is not in the lockfile, the script will error with a clear message.
- If the file is already node-only, the script will skip with a message.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
