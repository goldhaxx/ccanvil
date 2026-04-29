---
manifest:
  id: ccanvil-status
  purpose: Report the current sync state between the project and the hub — clean / modified / hub-ahead / local-only / hub-only / ignored counts. Read-only; suggests follow-up commands like /ccanvil-pull or /ccanvil-push when relevant.
  routes-by: /ccanvil-status
  input:
    - "no positional args"
  output:
    - "stdout: human-readable status summary; recommended follow-up commands when state is non-clean"
  depends-on:
    - ccanvil-sync.sh
  side-effect:
    - reads-only-no-mutations
  contract:
    - read-only
    - never-mutates-anything
  failure-mode:
    - "uninitialized-tree | exit=non-zero | visible=stderr-error | mitigation=run-/init-first"
  anchor:
    - BTS-256 (manifest seed)
---

Show the current sync state between this project and the hub.

1. Run `./.ccanvil/scripts/ccanvil-sync.sh status` and present the output.
2. If any files show MODIFIED* (changed since last sync but not yet recorded), mention these are local changes that haven't been synced.
3. If the hub has new commits since last sync, suggest running `/ccanvil-pull` to review updates.
4. If there are HUB-ONLY files, suggest running `/ccanvil-pull` to add them.
5. If there are LOCAL files, mention they can be promoted to the hub with `/ccanvil-push`.

Do NOT make any changes. Report only.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
