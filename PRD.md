# Plan: Lesa <-> Claude Code Integration

## Context

Parker has two AI systems on his Mac mini:
- **Lesa** — an OpenClaw agent (Claude Sonnet/Opus via OpenClaw platform). Communicates via iMessage, has 1Password access, memory system, workspace files, autonomy framework. Runs 24/7 via gateway on `localhost:18789`.
- **Claude Code** — Anthropic's CLI tool (`claude` v2.1.37). Specialized for code editing, git ops, file management, shell commands. Parker invokes it manually in terminals.

These two systems don't know about each other. Parker wants full bidirectional integration:
1. Lesa can delegate coding tasks to Claude Code
2. Claude Code has context about Lesa's system when working in `~/.openclaw/`
3. Lesa can "drop in" to Claude Code sessions
4. Parker can switch between iMessage (Lesa) and terminal (Claude Code) with shared context

**Goal:** Build a bridge so Lesa and Claude Code share memory, context, and can hand off work to each other.

---

## Architecture Overview

```
Parker
  ├── iMessage → Lesa (OpenClaw agent)
  │     ├── workspace memory, daily logs, MEMORY.md
  │     ├── context-embeddings SQLite (2,673 chunks)
  │     └── NEW: claude-code skill → invokes claude -p
  │
  └── Terminal → Claude Code (claude CLI)
        ├── CLAUDE.md in ~/.openclaw/ (system context)
        ├── NEW: .mcp.json → lesa-bridge MCP server
        │     ├── lesa_conversation_search (query embeddings DB)
        │     ├── lesa_memory_search (search workspace .md files)
        │     └── lesa_read_workspace (read specific files)
        └── Session history in ~/.claude/projects/
```

---

## Step 1: Create `~/.openclaw/CLAUDE.md`

**Purpose:** When Claude Code is invoked in `~/.openclaw/` (or any project that references it), it immediately understands Lesa's system.

**Content:** Condensed version of SYSTEM.md focused on what Claude Code needs:
- Who Lesa is and how she operates
- Config architecture (the doctor gotcha)
- Plugin system (op-secrets, context-embeddings)
- Memory system and where things live
- How to read/write Lesa's workspace memory files
- Convention: if Claude Code does work that Lesa should know about, write a note to `workspace/memory/YYYY-MM-DD.md`
- Reference to SYSTEM.md for full details

**Key difference from SYSTEM.md:** CLAUDE.md is instructions *for Claude Code specifically*. SYSTEM.md is reference documentation for anyone.

---

## Step 2: Create `lesa-bridge` MCP Server

**Purpose:** Give Claude Code tools to search Lesa's memory and read her workspace — so when Parker says "what did Lesa and I discuss about X?", Claude Code can actually find it.

**Location:** `~/Documents/Projects/Claude Code/lesa-bridge/` (new project)

**Type:** stdio-based MCP server (Node.js), configured in `~/.openclaw/.mcp.json`

### MCP Server Tools

**`lesa_conversation_search`**
- Input: `{ query: string, limit?: number }`
- Searches `~/.openclaw/memory/context-embeddings.sqlite` using OpenAI embeddings
- Returns top-N conversation chunks with session key, timestamp, text
- Reuses the same cosine similarity approach from the context-embeddings plugin

**`lesa_memory_search`**
- Input: `{ query: string }`
- Searches `.md` files in `~/.openclaw/workspace/` (memory/, notes/, MEMORY.md, daily logs)
- Simple text/keyword search (grep-style) — no embeddings needed for structured markdown
- Returns matching file paths and relevant excerpts

**`lesa_read_workspace`**
- Input: `{ path: string }` (relative to `~/.openclaw/workspace/`)
- Reads and returns the contents of a workspace file
- Paths restricted to `workspace/` for safety

### Implementation

```
lesa-bridge/
├── package.json
├── src/
│   └── index.ts          # MCP server (stdio transport)
├── tsconfig.json
└── README.md
```

Dependencies:
- `@modelcontextprotocol/sdk` — MCP server framework
- `openai` — for embedding queries (conversation_search)
- `better-sqlite3` — read the context-embeddings database (read-only)

The server reads `OP_SERVICE_ACCOUNT_TOKEN` or `OPENAI_API_KEY` from env for embedding queries. Can resolve via 1Password at startup.

### MCP Config

File: `~/.openclaw/.mcp.json`

```json
{
  "lesa-bridge": {
    "command": "node",
    "args": ["/Users/lesa/Documents/Projects/Claude Code/lesa-bridge/dist/index.js"],
    "env": {
      "OPENCLAW_DIR": "/Users/lesa/.openclaw",
      "OPENAI_API_KEY": "${OPENAI_API_KEY}"
    }
  }
}
```

The OpenAI API key needs to be in the environment. Options:
- Set in shell profile (`~/.zshrc`)
- Or have the MCP server resolve from 1Password at startup (read `op-sa-token`, call `op read`)

---

## Step 3: Create `claude-code` OpenClaw Skill

**Purpose:** Let Lesa invoke Claude Code for coding tasks and capture results.

**Location:** `~/.openclaw/extensions/context-embeddings/skills/claude-code/SKILL.md`
(Or create as a standalone extension — TBD based on complexity)

Actually, simpler: create as a **new standalone skill directory** in an existing extension, or better yet, as part of the lesa-bridge project.

**Location:** `~/Documents/Projects/Claude Code/lesa-bridge/skills/claude-code/SKILL.md`

This skill instructs Lesa how to:

1. **Invoke Claude Code for a task:**
   ```bash
   claude -p --output-format json --model sonnet \
     --allowed-tools "Bash Edit Read Write Glob Grep" \
     --workdir /path/to/project \
     "task description with context"
   ```

2. **Pass context from Lesa's memory** into the prompt (prepend relevant memory excerpts)

3. **Use session persistence** for multi-step tasks:
   ```bash
   claude -p --session-id <uuid> --continue "follow-up prompt"
   ```

4. **Capture results** — parse JSON output, write summary to daily log

5. **Background execution** for long tasks:
   ```bash
   bash pty:true background:true command:"claude -p --workdir ... 'task'"
   ```

### Skill Metadata

```yaml
---
name: claude-code
description: Use Claude Code CLI for coding tasks like editing files, running git, searching code. Use when Lesa needs to make code changes, create PRs, debug, or do development work.
metadata:
  openclaw:
    emoji: "🔧"
    requires:
      bins: ["claude"]
---
```

---

## Step 4: Deploy and Wire Up

### 4a. Build lesa-bridge MCP server
```bash
cd ~/Documents/Projects/Claude\ Code/lesa-bridge
npm install && npm run build
```

### 4b. Create `.mcp.json` in `~/.openclaw/`
So Claude Code discovers the MCP server when invoked there.

### 4c. Deploy skill to OpenClaw
Copy the `claude-code` skill into Lesa's extensions:
```bash
cp -r skills/claude-code ~/.openclaw/extensions/lesa-bridge/skills/
```
Or register as part of the lesa-bridge extension.

### 4d. Restart OpenClaw gateway
```bash
openclaw gateway restart
```

---

## Files to Create

| File | Purpose |
|------|---------|
| `~/Documents/Projects/Claude Code/lesa-bridge/` | New project directory |
| `lesa-bridge/PRD.md` | Copy of this plan as project spec |
| `lesa-bridge/README.md` | Project documentation |
| `lesa-bridge/src/index.ts` | MCP server implementation |
| `lesa-bridge/package.json` | Dependencies |
| `lesa-bridge/tsconfig.json` | TypeScript config |
| `lesa-bridge/skills/claude-code/SKILL.md` | OpenClaw skill for Lesa → Claude Code |
| `~/.openclaw/CLAUDE.md` | System context for Claude Code |
| `~/.openclaw/.mcp.json` | MCP server config for Claude Code |

## Files to Modify

| File | Change |
|------|--------|
| `~/.openclaw/openclaw.json` | Add `lesa-bridge` plugin entry (if packaged as extension) |

---

## Verification

1. **Claude Code → Lesa's memory:** Start Claude Code in `~/.openclaw/`, run `lesa_conversation_search("plugin debugging")` — should return conversation chunks
2. **Claude Code → Lesa's workspace:** Run `lesa_read_workspace("MEMORY.md")` — should return file contents
3. **Lesa → Claude Code:** In an iMessage session with Lesa, ask her to use the `claude-code` skill to make a simple file edit — verify it works
4. **Shared context:** Claude Code reads CLAUDE.md automatically when invoked in `~/.openclaw/`
5. **Memory flow:** Claude Code writes a note to `workspace/memory/2026-02-08.md`, Lesa can see it on her next turn

---

## Implementation Order

1. **CLAUDE.md** — immediate value, zero dependencies
2. **lesa-bridge MCP server** — most impactful (gives Claude Code Lesa's memory)
3. **claude-code skill** — lets Lesa delegate coding work
4. **Testing and iteration** — verify both directions work
