---
name: claude-code
description: Delegate coding tasks to Claude Code CLI. Use when user says "have Claude Code do this", "delegate to CC", "run this in Claude Code", or when the task involves editing files, git operations, searching codebases, creating PRs, or debugging that benefits from Claude Code's specialized tools.
metadata:
  {
    "openclaw":
      {
        "emoji": "🔧",
        "requires": { "bins": ["claude"] },
      },
  }
---

# Claude Code

Run Claude Code (Anthropic's coding CLI) for tasks that need file editing, code search, git operations, or development work. Claude Code has specialized tools (Read, Edit, Write, Glob, Grep, Bash) that make it excellent at code-level work.

## When to Use

- **File editing** — create, modify, or refactor code files
- **Git operations** — commits, branches, PRs, diffs
- **Code search** — find functions, trace dependencies, understand codebases
- **Debugging** — investigate errors, read logs, test fixes
- **Project scaffolding** — initialize projects, install deps, configure build tools

## How to Invoke

### One-shot task (simple, fast)

```bash
bash pty:true command:"claude -p --output-format text 'Your task description here'"
```

### With a specific working directory

```bash
bash pty:true command:"claude -p --output-format text --add-dir /path/to/project 'task description'"
```

### Background execution (long tasks)

```bash
bash pty:true background:true command:"claude -p --output-format text --add-dir /path/to/project 'task description'"
```

### Multi-turn session (complex tasks)

First invocation:
```bash
bash pty:true command:"claude -p --output-format json 'task description'"
```

Parse the JSON output for the `session_id`, then follow up:
```bash
bash pty:true command:"claude -p --session-id SESSION_ID --continue 'follow-up instructions'"
```

## Passing Context

When delegating a task, include relevant context in the prompt. Prepend with:

```
Context from Lesa's memory:
- [relevant memory excerpt]
- [current state or background]

Task:
[what Claude Code should do]
```

## Working Directories

Common project locations:

| Project | Path |
|---------|------|
| OpenClaw config | `~/.openclaw/` |
| op-secrets plugin | `~/Documents/wipcomputer--mac-mini-01/staff/Parker/Claude Code - Mini/repos/openclaw-1password/` |
| context-embeddings plugin | `~/Documents/wipcomputer--mac-mini-01/staff/Parker/Claude Code - Mini/repos/openclaw-context-embeddings/` |
| Upgrade runbook | `~/Documents/wipcomputer--mac-mini-01/staff/Parker/Claude Code - Mini/repos/open-claw-upgrade/` |
| Lesa bridge (this) | `~/Documents/wipcomputer--mac-mini-01/staff/Parker/Claude Code - Mini/repos/lesa-bridge/` |

## Capturing Results

After Claude Code completes a task:

1. **Read the output** — the response contains what was done
2. **Write to daily log** — append a summary to `memory/YYYY-MM-DD.md`:
   ```
   ## [HH:MM] Claude Code task: <summary>
   - What was done
   - Files changed
   - Any follow-up needed
   ```
3. **For code changes** — verify with `git status` / `git diff` in a follow-up invocation

## Model Selection

Claude Code defaults to the model configured in `~/.claude/settings.json`. To specify:

```bash
bash pty:true command:"claude -p --model opus 'complex task'"
bash pty:true command:"claude -p --model sonnet 'quick task'"
```

## Permission Control

Claude Code prompts for permissions interactively. When running headlessly from Lesa's context, use `--dangerously-skip-permissions` or `--permission-mode bypassPermissions` to avoid hanging.

Restrict what Claude Code can do:

```bash
# Read-only (safe for exploration)
bash pty:true command:"claude -p --dangerously-skip-permissions --allowed-tools 'Read Glob Grep' 'explore this codebase'"

# Standard coding (read + write + shell)
bash pty:true command:"claude -p --dangerously-skip-permissions --allowed-tools 'Bash Edit Read Write Glob Grep' 'fix the bug'"
```

## Tips

- Claude Code reads `CLAUDE.md` in the working directory for project context
- `~/.openclaw/CLAUDE.md` gives Claude Code full context about Lesa's system
- For large tasks, use background execution and check back later
- Always specify `--add-dir` to set the project context
- Use `--output-format json` when you need to parse structured results
