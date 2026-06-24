#!/usr/bin/env bash
# ci-status-check.sh — PostToolUse hook for Bash.
# After a successful `git push`, when the repo has CI configured (GitHub Actions)
# and `gh` is authenticated, briefly waits for the run(s) triggered by the push
# and surfaces the result — so a red build is caught in-session instead of only
# via a GitHub failure email. Fully self-gating: silent no-op for repos with no
# CI, no `gh`, or a non-GitHub remote, so it costs nothing on nodes without CI.
# Advisory philosophy: exit 0 on pass / in-progress / not-applicable; exit 2
# (stderr fed back to Claude) ONLY on a confirmed failed run, so the agent can
# fix it before it reaches the user.

# @manifest
# purpose: PostToolUse Bash advisory that, after a `git push`, polls GitHub Actions (via `gh run list`, bounded by CI_STATUS_CHECK_BUDGET seconds) for the run(s) whose headSha matches the just-pushed HEAD and reports their state — exit 2 with a red-build summary (workflow names + URLs) on any failed/timed-out/startup-failure conclusion so Claude can react, exit 0 (quiet stderr note) on all-passed or still-running. Self-gates to a no-op unless `.github/workflows/*.y{a,}ml` exists, `gh` is installed + authenticated, and `origin` is a github.com remote. Mirrors the never-block-on-not-applicable philosophy of commit-msg-lint / branch-name-lint.
# input: stdin JSON envelope `{tool_input:{command}, tool_response?}` from Claude Code's PostToolUse contract
# input: env CI_STATUS_CHECK_BUDGET (max seconds to wait for runs to conclude; default 20; 0 = report immediately, no wait)
# input: env CI_STATUS_CHECK_INTERVAL (poll interval seconds; default 5)
# input: env CI_STATUS_CHECK_DISABLE (any non-empty value short-circuits to a silent no-op)
# output: exit-code 0 on pass / in-progress / not-applicable (gates unmet); exit-code 2 on a confirmed failed run
# output: stderr: red-build summary (workflow + URL per failed run) on failure; a one-line pass / still-running note otherwise
# caller: .claude/settings.json
# depends-on: jq
# depends-on: git
# depends-on: gh
# side-effect: writes-stderr-on-report
# side-effect: network-read-only
# failure-mode: gh-unauth-or-absent | exit=0 | visible=none | mitigation=silent-no-op-by-design
# failure-mode: no-ci-config | exit=0 | visible=none | mitigation=silent-no-op-by-design
# failure-mode: ci-run-failed | exit=2 | visible=stderr-red-build-summary | mitigation=gh-run-view-log-failed-then-fix
# contract: never-blocks-on-success-or-not-applicable
# contract: only-acts-on-git-push-commands
# contract: bounded-wait-never-exceeds-budget-plus-one-interval
# anchor: ci-status-check (hub hook)

set -uo pipefail

[[ -n "${CI_STATUS_CHECK_DISABLE:-}" ]] && exit 0

command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$COMMAND" ]] && exit 0

# --- Only react to a real `git ... push` invocation ------------------------
# Require a standalone `git` token AND a standalone `push` token (so `git
# pushups` or `npm push` don't trip it). Cheap pre-filter before any I/O.
[[ "$COMMAND" =~ (^|[^[:alnum:]_./-])git([[:space:]]|$) ]] || exit 0
[[ "$COMMAND" =~ (^|[[:space:]])push([[:space:]]|$) ]]     || exit 0

# --- Self-gating: only meaningful for a GitHub-Actions repo with gh ---------
# @failure-mode: no-ci-config
compgen -G ".github/workflows/*.yml" >/dev/null 2>&1 \
  || compgen -G ".github/workflows/*.yaml" >/dev/null 2>&1 \
  || exit 0
# @failure-mode: gh-unauth-or-absent
command -v gh >/dev/null 2>&1 || exit 0
gh auth status >/dev/null 2>&1 || exit 0
git remote get-url origin 2>/dev/null | grep -qiE 'github\.com' || exit 0

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
HEAD_SHA=$(git rev-parse HEAD 2>/dev/null || true)
[[ -z "$BRANCH" || -z "$HEAD_SHA" || "$BRANCH" == "HEAD" ]] && exit 0

BUDGET="${CI_STATUS_CHECK_BUDGET:-20}"
INTERVAL="${CI_STATUS_CHECK_INTERVAL:-5}"
[[ "$BUDGET"   =~ ^[0-9]+$ ]] || BUDGET=20
[[ "$INTERVAL" =~ ^[0-9]+$ && "$INTERVAL" -gt 0 ]] || INTERVAL=5

# --- Poll for the run(s) triggered by this push ----------------------------
# Match by headSha so we report THIS push's runs, not a stale prior run.
# @side-effect: network-read-only
runs_for_head() {
  gh run list --branch "$BRANCH" --limit 15 \
     --json databaseId,headSha,status,conclusion,workflowName,url 2>/dev/null \
    | jq -c --arg sha "$HEAD_SHA" '[.[] | select(.headSha == $sha)]' 2>/dev/null \
    || printf '[]'
}

elapsed=0
runs='[]'
while :; do
  runs=$(runs_for_head); [[ -n "$runs" ]] || runs='[]'
  count=$(printf '%s' "$runs" | jq 'length' 2>/dev/null || printf '0')
  if [[ "$count" -gt 0 ]]; then
    # Surface a failure the moment one appears — don't wait for siblings.
    nfail=$(printf '%s' "$runs" \
      | jq '[.[] | select(.conclusion=="failure" or .conclusion=="timed_out" or .conclusion=="startup_failure")] | length' 2>/dev/null || printf '0')
    [[ "$nfail" -gt 0 ]] && break
    npending=$(printf '%s' "$runs" | jq '[.[] | select(.status != "completed")] | length' 2>/dev/null || printf '0')
    [[ "$npending" -eq 0 ]] && break
  fi
  [[ "$elapsed" -ge "$BUDGET" ]] && break
  sleep "$INTERVAL"
  elapsed=$((elapsed + INTERVAL))
done

count=$(printf '%s' "$runs" | jq 'length' 2>/dev/null || printf '0')
# No run ever appeared for this commit (path-filtered workflow, or none) — quiet.
[[ "$count" -eq 0 ]] && exit 0

failed=$(printf '%s' "$runs" \
  | jq -c '[.[] | select(.conclusion=="failure" or .conclusion=="timed_out" or .conclusion=="startup_failure")]' 2>/dev/null || printf '[]')
nfailed=$(printf '%s' "$failed" | jq 'length' 2>/dev/null || printf '0')
npending=$(printf '%s' "$runs" | jq '[.[] | select(.status != "completed")] | length' 2>/dev/null || printf '0')

if [[ "$nfailed" -gt 0 ]]; then
  # @side-effect: writes-stderr-on-report
  echo "⚠️  CI FAILED for ${BRANCH} @ ${HEAD_SHA:0:7}:" >&2
  printf '%s' "$failed" | jq -r '.[] | "   ✗ \(.workflowName) — \(.url)"' >&2
  echo "   Inspect: gh run view <id> --log-failed   (fix before it lands / emails)" >&2
  # @failure-mode: ci-run-failed
  exit 2
fi

if [[ "$npending" -gt 0 ]]; then
  echo "ℹ️  CI still running for ${BRANCH} @ ${HEAD_SHA:0:7} after ${elapsed}s — watch: gh run watch" >&2
  exit 0
fi

echo "✓ CI passed for ${BRANCH} @ ${HEAD_SHA:0:7}." >&2
exit 0
