---
manifest:
  id: ccanvil-promote
  purpose: Promote a local-only file to hub-tracked status — copy to the hub, register in lockfile, commit. Workflow is mostly deterministic; Claude's only judgment call is checking for project-specific content (hardcoded paths, project names, specific APIs) before promoting.
  routes-by: /ccanvil-promote
  input:
    - "positional: <file-path>"
  output:
    - "side-effect: file copied to hub, lockfile updated, hub commit pushed"
  depends-on:
    - ccanvil-sync.sh
  side-effect:
    - copies-file-to-hub
    - mutates-lockfile
    - commits-on-hub
  failure-mode:
    - "file-has-project-specific-content | exit=non-zero | visible=warn-with-flagged-substrings | mitigation=edit-file-to-genericize-then-retry"
  contract:
    - judgment-call-on-project-specificity
    - confirmation-prompted-before-mutation
  anchor:
    - BTS-256 (manifest seed)
---

Promote a local-only file to the hub.

Most of this workflow is deterministic. Claude's ONLY judgment call: checking for project-specific content.

## Steps

1. The user provides a file path as an argument: `/ccanvil-promote .claude/rules/my-rule.md`

2. **(JUDGMENT CALL)** Read the file content. Check for project-specific references (project names, specific APIs, hardcoded paths). If found, warn the user and suggest editing first.

3. Show the file content and ask the user to confirm promotion.

4. **(DETERMINISTIC)** Run the full promote workflow:
```bash
./.ccanvil/scripts/ccanvil-sync.sh promote <file>
```

This handles: status verification, copy to hub, lockfile update, logging, git commit, version bump — all in one call.

5. Report what was promoted.

## Rules
- NEVER run `cp`, `lock-update`, `git -C`, or `changelog` manually. The `promote` command handles everything.
- If the file status is not `local-only`, the script will error with a clear message.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
