# Background Task Discipline

## The Rule

Background bash tasks are an expensive resource — each one consumes a shell, file-descriptor allocation, and operator-visible UI tracking. Treat them with budget discipline:

1. **No `until <ps-grep>; do sleep N; done` wait-loops.** Use the harness's task-completion notification instead.
2. **No multiple parallel runs of the same long command.** One bats run, one manifest validate — never stack them.
3. **Buffered output is not a hung process.** `bats-report.sh --parallel` and `module-manifest.sh validate` both fully buffer their stdout — output file shows 0 bytes for the full duration, then dumps everything at completion. Do not assume hang and start more.

## Why

Anchored on BTS-383 (origin incident, 2026-05-08): a single feature session accumulated 50+ background task IDs across ~6 hours of work. At peak, 10+ shells were running simultaneously — 3 parallel bats runs + 5+ wait-loops + multiple manifest validates — oversubscribing the operator's CPU and producing 1-2 hours of operator-idle time watching tests appear-to-hang. A 40-minute zombie `until [[ -s <file> ]]; do sleep 2; done` was still alive when the operator surfaced the problem.

Three failure modes compounded:

- **Premature wait-loop firing.** `until ! ps aux | grep "bats" | grep -v grep > /dev/null; do sleep N; done` has a race against subprocess startup. The grep sometimes runs before bats has spawned its workers, fires immediately, and the loop exits successfully thinking bats finished. The agent then re-launches bats. Result: stacked invocations.
- **Output buffering misread as hang.** Buffered tools' output files stay at 0 bytes for the full run. Indistinguishable from a hung process via `ls -la`. The agent assumes hang and starts another run.
- **Wait-loops are themselves background tasks.** Each `until ...; do sleep ...; done` queued via `run_in_background: true` becomes a phantom in the harness UI that may persist past the watched-for condition (especially when the loop's exit-condition was already met before the loop spawned).

## How to apply

### Waiting on a long-running command
- **Foreground first.** Run the command in the foreground (no `run_in_background`). The harness blocks on it; when it completes (or times out into background), you get a task-completion notification automatically. No polling needed.
- **If you need to keep working while it runs:** use `run_in_background: true`. The harness will notify you when it completes. Do not write a separate wait-loop to monitor it — the notification IS the wait mechanism.

### When buffered output looks hung
- Look at the running PID with `ps aux | grep <command>`. If CPU is non-zero or process state is `R`/`S`, it's working — buffering is the cause of empty output. Wait.
- Do not start a second invocation "to compare" or "find failures faster." Parallel runs of the same long command compete for the same resources and slow every run.

### Cleaning up zombies
- Use `TaskStop <task-id>` to terminate a specific background task by ID.
- Use `pkill -9 -f "<pattern>"` only when TaskStop fails and the process is genuinely orphaned. Verify after with `ps aux | grep <pattern>` returns 0.

### Anti-pattern catalog (forged from BTS-383)

| Anti-pattern | Replace with |
|---|---|
| `bash bats-report.sh --parallel &; until ! ps aux \| grep bats; do sleep 5; done` | `bash bats-report.sh --parallel` (foreground; let harness notify on completion) |
| `bash <cmd>; bash <cmd>; bash <cmd>` (three parallel duplicates "to find failures") | One invocation. Block. Read result. |
| `until [[ -s <file> ]]; do sleep 2; done; cat <file>` | Foreground the producing command, OR use `run_in_background: true` and wait for the notification |
| Running manifest validate after every Edit | Run after a logical commit boundary (3-5 edits typically) |

## Out of scope

- Eliminating buffering at the substrate level (covered by BTS-383's substrate ACs — `bats-report.sh --progress`, `module-manifest.sh --changed-only`).
- Harness-level limits on max concurrent background tasks (would require harness changes).

## Related

- `.claude/rules/tdd.md` (test execution discipline — full-suite only at /pr)
- `.claude/rules/deterministic-first.md` (parent principle: minimize subprocess work)
- BTS-383 (origin incident + substrate audit ticket)
- BTS-118 (`bats-report.sh` substrate origin)

<!-- NODE-SPECIFIC-START -->
<!-- Add project-specific content below this line. -->
<!-- Hub content above is updated via /ccanvil-pull. -->
