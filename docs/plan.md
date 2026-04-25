# Implementation Plan: Linear API substrate for bash scripts

> Feature: bts-164-linear-api-substrate
> Work: linear:BTS-164
> Created: 1777141900
> Spec hash: d31cf49c
> Based on: docs/spec.md

## Objective

Land a `linear-query.sh` GraphQL wrapper, add an `http` resolver mechanism, and migrate every Linear-touching read+write verb (`idea.*`, `ticket.*`, `backlog.list`) onto the new substrate so bash scripts and skills share one provider-aware path. Closes the read-path asymmetry where `cmd_idea_count` reports stale local-log data on Linear-routed projects.

## Sequence

Multi-session feature. Eight steps grouped into four arcs. Each step is a meaningful slice that lands green tests; multiple TDD cycles may live inside a step. **Use `bash .ccanvil/scripts/bats-report.sh --parallel` after every step** as the regression baseline (1101 tests at start).

### Arc 1 — Wrapper foundation

#### Step 1: Skeleton + auth gate (AC-1, AC-2)

- **Test:** `hub/tests/linear-query.bats` — `linear-query.sh --help` exits 0 with usage text; `linear-query.sh list-issues` (with `LINEAR_API_KEY` unset) exits 2 with `LINEAR_API_KEY not set` to stderr.
- **Implement:** Create `.ccanvil/scripts/linear-query.sh` with the same dispatcher shape as `permissions-audit.sh` — subcommand parsing, `--help`, exit codes 0/2/3, env-var pre-check at top of every subcommand except `--help`.
- **Files:** `.ccanvil/scripts/linear-query.sh` (new), `hub/tests/linear-query.bats` (new — fixture scaffolding + first 2 tests).
- **Verify:** Both bats tests green; full suite still passes.

#### Step 2: Curl transport + viewer subcommand (AC-3)

- **Test:** Add a stub-endpoint fixture (e.g., `hub/tests/fixtures/linear-stub.sh` — a tiny bash function that emits canned JSON when invoked instead of curl) and an env override so tests inject the stub. Test: `linear-query.sh viewer` against the stub returns `{id, name}` on stdout; sends correct `Authorization` header (intercepted via the stub).
- **Implement:** Add a `_post_graphql` helper inside `linear-query.sh` that wraps `curl -sS -X POST` to `${LINEAR_QUERY_ENDPOINT:-https://api.linear.app/graphql}` with `Authorization: $LINEAR_API_KEY` and `Content-Type: application/json`. Add `viewer` subcommand using `viewer { id name }` GraphQL query.
- **Files:** `.ccanvil/scripts/linear-query.sh`, `hub/tests/linear-query.bats`, `hub/tests/fixtures/linear-stub.sh` (new).
- **Verify:** Stub-endpoint pattern works; auth header reaches the stub; suite green.

### Arc 2 — Read path migration (the user-visible win)

#### Step 3: Read subcommands (AC-1, AC-8)

- **Test:** Bats coverage for each: `list-issues` (with state, label, project filters), `get-issue`, `list-states`, `list-labels`. Each test feeds canned JSON via the stub and asserts the wrapper parses the GraphQL response shape and emits canonical JSON on stdout.
- **Implement:** Add four subcommands. Each constructs a minimal GraphQL query (heredoc inside the function), POSTs via `_post_graphql`, and pipes the response through `jq` to extract the canonical-shape output.
- **Files:** `.ccanvil/scripts/linear-query.sh`, `hub/tests/linear-query.bats`.
- **Verify:** All four subcommands have at least one passing test; suite green.

#### Step 4: Resolver `http` mechanism for `idea.list` / `idea.count` (AC-4)

- **Test:** `hub/tests/operations-resolve-http.bats` (new) — with `routing.idea = linear`, `operations.sh resolve idea.list` and `idea.count` return `{provider:"linear", mechanism:"http", invocation:{endpoint, query, variables, auth_env:"LINEAR_API_KEY"}, contract:{...}}`. With `routing.idea = local`, both still return `mechanism:"bash"`.
- **Implement:** In `operations.sh`, add an `http_adapter` helper alongside the existing `mcp_*` and `local_*` emitters (~line 472–517 area). Route `idea.list` and `idea.count` through it when `routing.idea = linear`. Keep MCP emitters as a parallel option for any caller that explicitly requests `--mechanism mcp` (defer the explicit-mechanism flag to a later ticket; for now, http is the default for Linear).
- **Files:** `.ccanvil/scripts/operations.sh`, `hub/tests/operations-resolve-http.bats` (new).
- **Verify:** Resolver tests green; existing `operations-resolve-*.bats` files still pass.

#### Step 5: `cmd_idea_count` + radar-gather migration (AC-5, AC-6, AC-9)

- **Test:** `hub/tests/idea-count-resolver.bats` (new). Three cases: (a) local-routed project still reads the JSONL log (`mechanism:bash` path unchanged), (b) Linear-routed project with stub endpoint returns Linear-derived counts, (c) `radar-gather` JSON for a Linear-routed project shows the Linear-derived `ideas.triage` count.
- **Implement:** In `docs-check.sh`, modify `cmd_idea_count` (line ~1841): call `operations.sh resolve idea.count`, branch on `mechanism`. On `bash`, retain the current local-log path. On `http`, shell out to `linear-query.sh list-issues --label idea` and aggregate counts by status. `radar-gather` already calls `cmd_idea_count` (line ~1658), so it inherits the fix; just add a smoke test asserting the propagation.
- **Files:** `.ccanvil/scripts/docs-check.sh`, `hub/tests/idea-count-resolver.bats` (new).
- **Verify:** `/recall` and `/radar` would now report correct counts on this project (manual smoke after implementation: run them and observe Linear state, not the fossil log).

### Arc 3 — Write path migration

#### Step 6: Write subcommands (AC-7)

- **Test:** Bats coverage against the stub endpoint: `save-issue` create (sends `issueCreate` mutation, parses `{issue: {id}}` response), `save-issue` update with `--id --state` (sends `issueUpdate` mutation), `save-issue` update with `--id --priority` and `--id --labels`. Verify mutation shape via stub interception.
- **Implement:** Add `save-issue` subcommand to `linear-query.sh` accepting flags: `--id`, `--title`, `--description`, `--state`, `--priority`, `--labels` (CSV), `--project`, `--team`, `--parent-id`, `--duplicate-of`. When `--id` is absent, use `issueCreate`; when present, use `issueUpdate`. Single subcommand handles both paths to mirror the existing `mcp__claude_ai_Linear__save_issue` shape.
- **Files:** `.ccanvil/scripts/linear-query.sh`, `hub/tests/linear-query.bats`.
- **Verify:** Suite green.

#### Step 7: Resolver `http` for remaining verbs (AC-4 completion)

- **Test:** Extend `operations-resolve-http.bats` to cover `idea.add`, `idea.triage`, `ticket.transition`, `ticket.get`, `backlog.list`. Each returns `mechanism:http` with appropriate invocation shape on Linear-routed projects, and `mechanism:bash` (or `mcp` for skill-only verbs) on local-routed.
- **Implement:** Wire each verb through `http_adapter`. For verbs whose contract maps onto `linear-query.sh save-issue` (idea.add, idea.triage, ticket.transition), the resolver returns the wrapper invocation directly; for read verbs (ticket.get, backlog.list), wires to list-issues / get-issue.
- **Files:** `.ccanvil/scripts/operations.sh`, `hub/tests/operations-resolve-http.bats`.
- **Verify:** Full resolver coverage matches AC-10 (uniform output shape).

### Arc 4 — Docs + close

#### Step 8: Guide update + final review

- **Test:** No code test. Read `.ccanvil/guide/command-reference.md` and confirm the new `linear-query.sh` table entry exists with subcommand descriptions; confirm the `http` mechanism is named in the resolver-output documentation.
- **Implement:** Update `.ccanvil/guide/command-reference.md` (hub section, above `<!-- NODE-SPECIFIC-START -->`) to document `linear-query.sh` (subcommands, env vars, exit codes) and add `http` to the resolver mechanism list. No CLAUDE.md changes — this is substrate, not project-architecture.
- **Files:** `.ccanvil/guide/command-reference.md`.
- **Verify:** Final `bats-report.sh --parallel` shows green; all 10 ACs from spec.md tick. Run `/review` for code-reviewer agent + security-audit + self-review pass.

## Risks

- **Stub endpoint design.** The bats stub has to intercept curl without making real network calls. A bash-function override (e.g., shadowing `curl` in the test environment) is the simplest path; a localhost `nc` listener is more realistic but flakier. Default to function-shadow; revisit if it can't capture headers cleanly.
- **GraphQL schema drift.** Linear's API evolves. v1 hand-writes queries against current schema; if Linear breaks a field, the wrapper breaks. Mitigation: keep queries minimal (only the fields we use), and the bats suite will surface drift in CI before it hits production.
- **Resolver migration touches a hot path.** `operations.sh resolve idea.*` is called by every `/idea` invocation. A regression here breaks capture flow. Mitigation: existing `operations-resolve-*.bats` tests provide backstop; new tests run alongside; Step 4 adds the `http` path without removing `mcp` wiring (additive).
- **`LINEAR_API_KEY` not set in the dev environment.** Implementation can proceed against the stub end-to-end. Real-API verification (smoke run of `linear-query.sh viewer` against `api.linear.app`) needs the env var. Operator (Zach) is gathering the key in parallel; if not ready by Arc 2 close, smoke test is deferred to PR finalization.
- **Multi-session scope.** This plan is realistically 2 sessions. If session 1 lands Arcs 1–2 (read path, user-visible win), session 2 can land Arcs 3–4 (write path + docs). Mid-feature `/stasis` between arcs is an option.

## Definition of Done

- [ ] All 10 acceptance criteria from `docs/spec.md` pass (verified via bats + manual smoke for AC-5/AC-6).
- [ ] All existing tests still pass (`bash .ccanvil/scripts/bats-report.sh --parallel`).
- [ ] No type errors (N/A — bash).
- [ ] `bats-lint.sh` clean (no leaky-jq-e tests in new files per BTS-127).
- [ ] Code reviewed (run `/review`).
- [ ] `.ccanvil/guide/command-reference.md` updated.
- [ ] Manual smoke: `/recall` on this project reports the live Linear count, not stale fossil.

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
