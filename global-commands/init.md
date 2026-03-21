Initialize a new project using the Claude Code development scaffold located at ~/projects/claude-code-scaffold.

1. Read ~/projects/claude-code-scaffold/README.md — it contains the complete file manifest and setup instructions.
2. Read ~/projects/claude-code-scaffold/SCAFFOLD_SYSTEM_PROMPT.md for the full specification of constraints and formatting rules.
3. Copy all project files from the scaffold into the current working directory following the Quick Start instructions. Skip Step 1 (global setup is already done). Make sure to copy `docs/templates/` as well — these are persistent format guides used by agents and commands.
4. Ask me only two things:
   - Project name
   - One-line description of what it does
5. Replace the placeholders in CLAUDE.md with my answers. Leave everything else as the scaffold defaults — the directory structure, conventions, do-not-touch rules, and workflow are all pre-configured.
6. The tech stack, commands, and architecture will be determined later as we spec and build features. Do not ask me to choose a stack now.
7. Generate the scaffold lockfile by running: `./scripts/scaffold-sync.sh init ~/projects/claude-code-scaffold`
   This creates `.claude/scaffold.lock` which tracks the sync state between this project and the scaffold hub.
8. Validate: CLAUDE.md is under 80 lines. Commit the initialized scaffold with `git init && git add -A && git commit -m "chore: initialize project scaffold"`.
