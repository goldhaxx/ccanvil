---
tier: 0
scope: substrate
stack: any
anchors:
  evidence:
    - docs/research/provider-migration-decision.md
manifest_ref: provider-integration.manifest.yaml
---

# Provider Integration

Substrate uses **http (shell-to-API)**. MCP is reserved for ad-hoc operator queries inside interactive Claude sessions.

When integrating ccanvil substrate (anything reachable from `.ccanvil/scripts/operations.sh`) with an external provider that exposes both an MCP server AND a shell-to-API surface (REST/GraphQL/CLI), **always use the shell-to-API surface — never MCP**. New verbs land as wrapper subcommands first (e.g., `linear-query.sh save-issue`), then the operations.sh resolver references them.

**When adding a new operation to `operations.sh`:** never add a `mechanism: "mcp"` branch for a new verb. If the provider isn't yet wrapper-integrated, write the wrapper FIRST. Test via the OVERRIDE pattern (`LINEAR_QUERY_OVERRIDE`, etc.) — env var swap to stubbed script, mirrors BTS-203.

For the full http-vs-MCP tradeoff matrix, BTS-183 dead-code sweep context, and how-to-apply detail: see evidence anchor `docs/research/provider-migration-decision.md`.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
