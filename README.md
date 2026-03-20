# Claude Code Development Framework
## Setup Guide & Operating Manual

---

## What This Is

A drop-in scaffold for working with Claude Code on any software project. It encodes three principles grounded in how transformers actually process information:

1. **Specification-driven development** — Define what you want before coding, so the model has clear constraints
2. **Test-driven verification** — Give the model an external oracle (tests) to check itself against
3. **Hierarchical context management** — Right information at the right time, nothing more

The framework works across any tech stack (Node, Python, Go, etc.) — you customize the project-level CLAUDE.md for your specific stack.

---

## Quick Start (5 minutes)

### Step 1: One-time personal setup

This scaffold ships with two files that go in your home directory. You do this once.

```bash
# Create the global Claude Code config directories
mkdir -p ~/.claude
mkdir -p ~/.claude/commands

# Copy your personal preferences file — loads for every project
cp ~/projects/claude-code-scaffold/GLOBAL_CLAUDE.md ~/.claude/CLAUDE.md

# Copy the /init slash command — lets you type /init in any new project
cp ~/projects/claude-code-scaffold/global-commands/init.md ~/.claude/commands/init.md
```

Edit `~/.claude/CLAUDE.md` to match your preferences (name, communication style, workflow defaults).

### Step 2: Initialize a new project

With the global command installed, setup is:

```bash
cd ~/projects/my-new-project
claude
```

Then type **`/init`**.

Claude Code will read the scaffold's README, copy all project files into the current directory, and ask you about your tech stack to customize CLAUDE.md. No pasting required.

> **Alternative (without the command):** If you prefer to paste a prompt manually, copy the contents of `INIT_PROMPT.md` into Claude Code instead. It does the same thing.

### Step 3: Name your project

`/init` copies the scaffold files and then asks you for just two things:

- **Project name**
- **One-line description**

That's it. The directory structure, conventions, workflow, and "do not" rules are all pre-configured with opinionated defaults. The tech stack, commands, and framework choices will be determined organically as you spec and build features — Claude Code updates CLAUDE.md as those decisions are made.

If you want to override any defaults later, edit CLAUDE.md directly or tell Claude Code to update it.

### Step 4: Connect Linear (optional)

If you use Linear for project management, run this in your Claude Code session:
```bash
/mcp
```
This triggers the OAuth flow for Linear. Once connected, you can reference and manage Linear issues directly from the CLI.

### Step 5: Start building

You're set. Use the scaffold workflow:
```
"Spec this feature"  → writes docs/spec.md with acceptance criteria
/plan                → writes docs/plan.md with ordered TDD steps
"Start Step 1"       → enters red-green-refactor cycle
/review              → code review before committing
/catchup             → resume after /clear
```

---

## Complete File Manifest

Every file and directory in this scaffold is listed below, grouped by where it goes. No file is left unexplained.

### Files that go to your home directory (one-time setup)

| File in zip | Copy to | What it does | Customize? |
|---|---|---|---|
| `GLOBAL_CLAUDE.md` | `~/.claude/CLAUDE.md` | Your personal preferences — name, communication style, workflow defaults. Claude Code loads this for every project on your machine. | Yes. Edit after copying to match your preferences. |
| `global-commands/init.md` | `~/.claude/commands/init.md` | The `/init` slash command. Type `/init` in any new project directory and Claude Code reads the scaffold README, copies the files, and asks about your stack to customize. Deterministic — fires exactly when you invoke it, not probabilistically like a skill. | No. Works out of the box as long as the scaffold lives at `~/projects/claude-code-scaffold`. If you store the scaffold elsewhere, update the paths in this file. |

### Files that go to your project root (per-project setup)

| File in zip | Copy to | What it does | Customize? |
|---|---|---|---|
| `CLAUDE.md` | `./CLAUDE.md` | **The core file.** Project identity, tech stack, commands, directory structure, conventions, and the TDD workflow summary. Claude Code reads this at the start of every session. | Minimal at init — just the name and description. Tech stack, commands, and architecture fill in organically as you build. Conventions and do-not rules have sensible defaults. |
| `.claudeignore` | `./.claudeignore` | Tells Claude Code which files and directories to never read. Excludes node_modules, dist, lock files, .env, and other large/irrelevant files. This is the single biggest lever for context management. | Yes. Add any project-specific build artifacts, data directories, or generated files. |
| `.mcp.json` | `./.mcp.json` | Configures MCP (Model Context Protocol) server connections. Pre-configured for Linear's official MCP server. | Yes. Remove Linear if you don't use it. Add other MCP servers (Jira, GitHub, etc.) as needed. |

### The `.claude/` directory (copy entire directory to project root)

Copy the whole directory with `cp -r .claude ./.claude`. Here's what's inside:

| File in zip | Copy to | What it does | Customize? |
|---|---|---|---|
| `.claude/settings.json` | `./.claude/settings.json` | Permissions (which shell commands Claude can run) and hooks (deterministic automation that fires on every file write). Pre-configured with a Prettier auto-format hook (commented out) and a security hook that blocks writes to `.env` files. | Later. When a formatter is chosen during development, uncomment and update the formatter hook. Adjust permission allow/deny lists as the project's toolchain takes shape. |
| `.claude/rules/tdd.md` | `./.claude/rules/tdd.md` | TDD enforcement rules. Defines the red-green-refactor cycle, test naming conventions, and what to do when tests break. Loaded alongside CLAUDE.md at launch. | Rarely. These rules are tech-stack-agnostic. Modify only if your project has unusual testing requirements. |
| `.claude/rules/workflow.md` | `./.claude/rules/workflow.md` | Session discipline and context management rules. Defines session objectives, context preservation via checkpoints, commit practices, when to use sub-agents, and error recovery (stop after 2 failed attempts). Loaded alongside CLAUDE.md at launch. | Rarely. These are general best practices. Modify if your team has specific workflow requirements. |
| `.claude/rules/code-quality.md` | `./.claude/rules/code-quality.md` | Code standards rules. Covers pattern-following, error handling, dependency management, code organization, and naming conventions. Loaded alongside CLAUDE.md at launch. | Sometimes. Adjust naming conventions or error handling patterns to match your project's standards. |
| `.claude/skills/tdd/SKILL.md` | `./.claude/skills/tdd/SKILL.md` | The full TDD workflow skill. When triggered (by saying "tdd" or "test first"), Claude follows a structured specification → red → green → refactor → commit procedure. Skills load on-demand, not at startup, so they don't consume context when unused. | Sometimes. Replace `$TEST_COMMAND` references if you want the skill to reference your exact test command. |
| `.claude/agents/code-reviewer.md` | `./.claude/agents/code-reviewer.md` | A sub-agent that reviews uncommitted changes for correctness, test coverage, security issues, performance, and convention adherence. Runs in its own isolated context window. Invoked by the `/review` command. | Rarely. Modify if you want to add project-specific review criteria. |
| `.claude/agents/spec-writer.md` | `./.claude/agents/spec-writer.md` | A sub-agent that analyzes feature requests and produces structured specifications with testable acceptance criteria. Runs in its own isolated context window. Writes output to `docs/spec.md`. | Rarely. Modify if your team uses a different specification format. |
| `.claude/commands/catchup.md` | `./.claude/commands/catchup.md` | Defines the `/catchup` slash command. When invoked, reads `docs/checkpoint.md`, recent git history, and current diff to orient after a `/clear` reset. Does NOT implement anything — it only reports status. | No. This is workflow infrastructure. |
| `.claude/commands/plan.md` | `./.claude/commands/plan.md` | Defines the `/plan` slash command. When invoked, reads the spec and codebase, then writes an ordered implementation plan to `docs/plan.md`. Each step is sized for one TDD cycle. Does NOT implement anything — it only plans. | No. This is workflow infrastructure. |
| `.claude/commands/review.md` | `./.claude/commands/review.md` | Defines the `/review` slash command. When invoked, delegates to the code-reviewer sub-agent to review all uncommitted changes. | No. This is workflow infrastructure. |

### The `docs/` directory (copy entire directory to project root)

Copy the whole directory with `cp -r docs ./docs`. These are templates that get overwritten during use:

| File in zip | Copy to | What it does | Customize? |
|---|---|---|---|
| `docs/spec.md` | `./docs/spec.md` | Template for feature specifications. Includes sections for JTBD statement, acceptance criteria, affected files, dependencies, and out-of-scope boundaries. Gets overwritten each time you spec a new feature. | No. This is a template. The spec-writer agent and `/plan` command fill it in for each feature. |
| `docs/checkpoint.md` | `./docs/checkpoint.md` | Template for session continuity. Captures what was accomplished, current state, blockers, and next steps. Gets overwritten when Claude checkpoints progress. The `/catchup` command reads this to resume. | No. This is a template. Claude fills it in when you say "checkpoint." |

### Files that stay outside your project (reference materials only)

These files are for you and for LLMs you ask to customize the scaffold. Do NOT copy them into projects.

| File in zip | What to do with it | What it does |
|---|---|---|
| `README.md` | Keep wherever you store reference documentation. | Setup guide and file manifest — how to install and configure the scaffold. |
| `HOW_TO_USE.md` | Read this first after running `/init`. Keep in the scaffold directory for reference. | User manual for the scaffold — how to describe features, what the iteration cycle looks like, when to use commands vs. natural language, and what you're responsible for vs. what Claude Code handles. |
| `SCAFFOLD_SYSTEM_PROMPT.md` | Keep wherever you store reference documentation. Feed it to any LLM when asking it to customize the scaffold for a new project. | A meta-prompt that teaches LLMs the scaffold's architecture, constraints, and customization procedure. Paste or reference it when you want Claude (or any AI) to set up or modify the scaffold for a specific project. |
| `INIT_PROMPT.md` | Keep in the scaffold directory. | Fallback for project initialization if the global `/init` command isn't installed. Paste its contents into Claude Code after opening it in an empty project directory. Does the same thing as `/init` — tells Claude Code where the scaffold lives and to follow the README's setup instructions. |

---

## The Daily Workflow

### Starting a new feature

```
You:  "I need to add user authentication with JWT tokens"

         ↓ Claude runs /spec-writer agent

Claude: "I've written the spec to docs/spec.md with 6 acceptance criteria.
         Review it and let me know if anything should change."

You:  "AC-3 should also handle expired refresh tokens. Otherwise looks good."

         ↓ Claude updates spec

You:  "/plan"

         ↓ Claude creates implementation plan in docs/plan.md

You:  "Looks good. Let's start with Step 1."

         ↓ Claude enters TDD cycle:
         1. Writes failing test
         2. Runs test → confirms failure
         3. Implements minimal code
         4. Runs tests → all pass
         5. Commits
         6. Moves to next step
```

### Resuming after a break

```
You:  /clear
You:  /catchup

Claude: "Last session completed Steps 1-3 of the auth feature.
         All tests passing. Step 4 (refresh token rotation) is next.
         There are no uncommitted changes."

You:  "Continue with Step 4."
```

### Before committing significant changes

```
You:  /review

         ↓ Claude spawns code-reviewer sub-agent

Claude: "Review complete.
         PASS: Auth service changes look solid.
         CONCERN: The token expiry check in middleware.ts
           doesn't handle clock skew. Add a 30-second buffer.
         No blocking issues."
```

### Switching between tasks

```
You:  "I need to pause auth and fix a critical bug in billing."

         ↓ Claude writes checkpoint

Claude: "Checkpointed auth progress to docs/checkpoint.md.
         Committed current work. Ready for /clear."

You:  /clear
You:  "Fix the billing calculation bug: invoice totals are off by 1 cent
       on orders with 3+ line items."

         ↓ Fresh session, full context budget for the bug fix
```

---

## Key Commands Reference

| Command | What it does |
|---------|-------------|
| `/init` | Initialize current directory from the scaffold (global command) |
| `/catchup` | Read checkpoint + git state, orient without implementing |
| `/plan` | Create an implementation plan from a spec |
| `/review` | Spawn code-reviewer agent on uncommitted changes |
| `/clear` | Reset context (built-in). Use between tasks. |
| `/compact` | Summarize context to free space (built-in). Use proactively at ~60%. |
| `/cost` | Show token usage (built-in). Monitor your burn rate. |
| `/context` | Show what's consuming context (built-in). |

---

## Principles to Internalize

### 1. Context is the scarce resource
Everything in this framework exists to manage Claude Code's ~200K token context window. File reads consume 80% of context. The model's accuracy degrades as context fills. So: read only what's needed, commit progress externally, reset often.

### 2. Tests are the external oracle
Without tests, Claude's only verification is its own judgment — which degrades as context fills. Tests provide ground truth that survives context compaction and session resets. A failing test is unambiguous; a prompt is always open to interpretation.

### 3. Specifications collapse ambiguity upfront
LLMs perform best with clear, constrained objectives. A spec with binary acceptance criteria transforms a vague request into a concrete implementation target. The spec-first approach front-loads the thinking, which is the part humans do best.

### 4. Small sessions beat long sessions
A fresh 30-minute session with clear context outperforms a degraded 3-hour session every time. Commit early, checkpoint often, /clear aggressively. Each session should have ONE objective.

### 5. Hooks for determinism, rules for judgment
Use hooks (settings.json) for things that must ALWAYS happen — formatting, security blocks, lint checks. Use rules and CLAUDE.md for things that require judgment — coding patterns, architectural decisions, naming conventions.

---

## Customization Guide

### Adding a new sub-agent
Create a file in `.claude/agents/your-agent.md`:
```yaml
---
name: your-agent-name
description: "When to use this agent"
tools:
  - Read
  - Grep
  - Glob
model: sonnet  # or opus for complex tasks, haiku for simple ones
---

Your agent instructions here.
```

### Adding a new slash command
Create a file in `.claude/commands/your-command.md`:
```markdown
Description of what this command does when invoked with /your-command.

Step-by-step instructions for Claude to follow.
```

### Adding a new skill
Create `.claude/skills/your-skill/SKILL.md`:
```yaml
---
name: your-skill-name
description: "Trigger conditions for this skill"
---

# Skill instructions
Detailed workflow for this skill.
```

### Adding rules for specific file types
Create `.claude/rules/your-domain.md`:
```markdown
# Rules for [domain]
Rules that apply when working in this area of the codebase.
```

### Stack-specific CLAUDE.md adjustments

**Python projects:** Change commands to `pytest`, `ruff`, `mypy`. Update architecture to match your package structure.

**Go projects:** Change commands to `go test ./...`, `golangci-lint run`. Conventions around error handling, interface design.

**Monorepos:** Keep root CLAUDE.md minimal (under 25 lines). Add subdirectory CLAUDE.md files for each package/service that load only when Claude works in that directory.

---

## Troubleshooting

**Claude isn't following CLAUDE.md instructions:**
- Check file length — over 200 lines and instructions get deprioritized
- Put the most important instructions at the TOP
- Reiterate critical constraints at the bottom (exploits U-shaped attention)
- Remove anything Claude already does correctly without being told

**Context filling too fast:**
- Run `/cost` to see where tokens are going
- Use `.claudeignore` to exclude large files
- Ask Claude to `grep` for patterns instead of reading whole files
- Use sub-agents for research tasks
- `/compact` proactively at 60% usage, don't wait for auto-compact

**Tests pass but code is wrong:**
- Tests may not cover the actual requirement — review acceptance criteria
- Add more specific assertions, especially for error cases
- Use property-based testing for complex logic

**Claude keeps making the same mistake:**
- After 2 failed attempts, `/clear` and write a better initial prompt
- Add the mistake as a "Do Not" rule in CLAUDE.md
- Check if a hook could prevent the mistake deterministically

---

## What to Git Commit

```
✅ Commit (shared with team):
  CLAUDE.md
  .claude/settings.json
  .claude/rules/*
  .claude/skills/*
  .claude/agents/*
  .claude/commands/*
  .claudeignore
  .mcp.json
  docs/spec.md
  docs/plan.md

❌ Gitignore (personal):
  .claude/settings.local.json
  .claude/local/CLAUDE.md
  docs/checkpoint.md (ephemeral session state)
```

Add to your `.gitignore`:
```
.claude/settings.local.json
.claude/local/
docs/checkpoint.md
```
