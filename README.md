# WIP Bridge

Cross-platform agent bridge. Enables Claude Code CLI to talk to OpenClaw CLI without a human in the middle.

## What It Does

WIP Bridge connects two AI agent platforms so they can communicate and share memory:

- **Claude Code** (Anthropic's coding CLI) gains access to the OpenClaw agent's conversation history, workspace files, a live messaging channel, and all OpenClaw skills
- **OpenClaw agents** gain the ability to delegate coding tasks to Claude Code and send it messages

### Example: Parker talking to Lēsa

This is how the bridge was originally built and used. Parker runs Claude Code in one terminal and Lēsa runs in OpenClaw TUI in another. Claude Code sends messages to Lēsa through the gateway, and Lēsa sends messages back through the inbox.

```
# Parker asks Claude Code to check with Lēsa
> "Ask Lēsa if the compaction-indicator fired last night."

# Claude Code sends the message through the bridge
> lesa send "Did the compaction-indicator fire last night?"

# Lēsa's reply comes back through the gateway
"Yes, it fired at 2:14 AM. Context was at 91%. I sent you an iMessage about it."
```

### Standalone Features (WIP Bridge alone)

| Tool | What it does |
|------|-------------|
| `lesa_send_message` | Send a message to the OpenClaw agent via the gateway |
| `lesa_check_inbox` | Check for messages the OpenClaw agent has sent back |
| `lesa_conversation_search` | Semantic search over embedded conversation history |
| `lesa_memory_search` | Keyword search across agent workspace `.md` files |
| `lesa_read_workspace` | Read a specific file from the agent's workspace |
| `oc_skills_list` | Browse and filter all discovered OpenClaw skills |
| `oc_skill_*` | Execute any OpenClaw skill that has scripts (see Skill Bridge below) |

### With Context Embeddings

If you're also running openclaw-context-embeddings, the `lesa_conversation_search` tool gets semantic vector search with **recency-weighted scoring**. Context Embeddings stores conversation turns as OpenAI embeddings in SQLite. WIP Bridge applies a linear decay (`max(0.5, 1.0 - age_days * 0.01)`) so fresh context wins ties while old strong matches still surface. Results include freshness flags (🟢 fresh, 🟡 recent, 🟠 aging, 🔴 stale). Without Context Embeddings, conversation search falls back to text matching.

| Tool | What changes |
|------|-------------|
| `lesa_conversation_search` | Semantic vector search + recency weighting + freshness flags |
| Everything else | No change |

### With Memory Crystal

Memory Crystal is a separate memory system (LanceDB vectors + SQLite metadata, local embeddings via Ollama). It has its own search path with its own recency-weighted scoring. Both systems now apply the same decay formula independently:

- **WIP Bridge** searches the context-embeddings SQLite DB (OpenAI embeddings, conversation turns)
- **Memory Crystal** searches its LanceDB store (conversations, files, explicit memories from both agents)

They're complementary, not redundant. WIP Bridge searches conversation history. Memory Crystal searches everything. Both weight fresh results higher.

## Architecture

```
Any MCP client (Claude Code, etc.)
  └── .mcp.json → lesa-bridge MCP server
        ├── lesa_conversation_search (vector search)
        ├── lesa_memory_search (keyword search)
        ├── lesa_read_workspace (file read)
        ├── lesa_send_message → POST gateway/v1/chat/completions
        ├── lesa_check_inbox ← HTTP inbox on :18790
        ├── oc_skills_list (browse all OpenClaw skills)
        └── oc_skill_* → executes OpenClaw skill scripts
              ├── scans extensions/*/node_modules/openclaw/skills/
              └── scans extensions/*/skills/

OpenClaw agent
  ├── claude-code skill → invokes claude -p
  └── send-to-claude-code skill → POST localhost:18790/message
```

### Message Flow

```
Claude Code  ──lesa_send_message──►  OpenClaw Gateway  ──►  Agent
Claude Code  ◄──lesa_check_inbox───  HTTP Inbox :18790  ◄──  Agent (curl POST)
```

Both directions are live.

## Install

### The easy way (agent-assisted)

Point your OpenClaw TUI or Claude Code at this repo and say:

```bash
claude "Clone https://github.com/wipcomputer/wip-bridge, build it, add it to my .mcp.json, and configure it for my OpenClaw install."
```

The agent reads the README, clones the repo, builds it, and wires up the MCP config. That's it.

### npm

```bash
npm install -g @wipcomputer/wip-bridge
```

### From source

```bash
git clone https://github.com/wipcomputer/wip-bridge.git
cd wip-bridge
npm install && npm run build
```

## CLI Usage

```bash
lesa send "What are you working on?"     # Message the OpenClaw agent
lesa search "API key resolution"          # Semantic search (recency-weighted)
lesa memory "compaction"                  # Keyword search across workspace files
lesa read MEMORY.md                       # Read a workspace file
lesa read memory/2026-02-10.md            # Read a daily log
lesa status                               # Show bridge configuration
lesa diagnose                             # Check gateway, inbox, DB, skills health
```

## MCP Configuration

Add to your `.mcp.json` (or Claude Code MCP settings):

```json
{
  "mcpServers": {
    "lesa-bridge": {
      "command": "npx",
      "args": ["wip-bridge"]
    }
  }
}
```

Or if installed from source:

```json
{
  "mcpServers": {
    "lesa-bridge": {
      "command": "node",
      "args": ["/path/to/wip-bridge/dist/index.js"],
      "env": { "OPENCLAW_DIR": "/path/to/.openclaw" }
    }
  }
}
```

## OpenClaw Skills

WIP Bridge includes two skills that teach the OpenClaw agent how to use Claude Code:

| Skill | What it does |
|-------|-------------|
| `claude-code` | Invoke Claude Code CLI for coding tasks (file editing, git, debugging) |
| `send-to-claude-code` | Push messages into Claude Code's live inbox |

Deploy skills:
```bash
cp -r skills/ ~/.openclaw/extensions/wip-bridge/skills/
```

## Skill Bridge

On startup, WIP Bridge scans OpenClaw's skill directories and automatically exposes them as MCP tools. Claude Code gets the same skills the OpenClaw agent has... no extra config, no duplication.

### How it works

1. Scans `extensions/*/node_modules/openclaw/skills/` (built-in) and `extensions/*/skills/` (custom)
2. Parses each `SKILL.md` frontmatter for name, description, requirements
3. Skills with a `scripts/` folder get registered as executable `oc_skill_{name}` tools
4. All skills (with or without scripts) show up in `oc_skills_list`

### Executable skills

These have scripts and can be called directly:

| Tool | What it does |
|------|-------------|
| `oc_skill_video_frames` | Extract frames from video via ffmpeg |
| `oc_skill_openai_whisper_api` | Transcribe audio via OpenAI Whisper API |
| `oc_skill_openai_image_gen` | Generate images via DALL-E |
| `oc_skill_nano_banana_pro` | Generate/edit images via Gemini 3 Pro |
| `oc_skill_model_usage` | Per-model cost/usage stats |
| `oc_skill_tmux` | Remote-control tmux sessions |
| `oc_skill_skill_creator` | Create and package new OpenClaw skills |

### Instruction-only skills

54+ skills that describe how to use external CLIs. Claude Code can read these via `oc_skills_list` and follow the instructions. As the OpenClaw community adds new skills, they automatically appear here.

### Sample `oc_skills_list` output

```
61 skill(s) (7 executable, 54 instruction-only)

- 🎞️ video-frames [oc_skill_video_frames]: Extract frames or short clips from videos using ffmpeg.
- ☁️ openai-whisper-api [oc_skill_openai_whisper_api]: Transcribe audio via OpenAI Audio Transcriptions API (Whisper).
- 🎨 openai-image-gen [oc_skill_openai_image_gen]: Batch-generate images via OpenAI Images API.
- 📊 model-usage [oc_skill_model_usage]: Summarize per-model usage/cost data from codexbar.
- 🖥️ tmux [oc_skill_tmux]: Remote-control tmux sessions by sending keystrokes and scraping output.
- 🔧 skill-creator [oc_skill_skill_creator]: Create or update AgentSkills.
- 🍌 nano-banana-pro [oc_skill_nano_banana_pro]: Generate or edit images via Gemini 3 Pro.
- 🔑 1password [(instruction-only)]: 1Password CLI integration.
- 📝 apple-notes [(instruction-only)]: Apple Notes integration.
- ...53 more
```

### API keys

Skills that need API keys (whisper needs `OPENAI_API_KEY`, etc.) get them from the environment. The op-secrets plugin sets these from 1Password. The bridge doesn't handle secrets itself.

## Inbox Watcher (Auto-Relay)

The inbox watcher polls the bridge's inbox endpoint and can auto-inject messages into a running Claude Code tmux session. When the OpenClaw agent sends a message, Claude Code picks it up and responds without human intervention.

### Alert mode (notification only)

```bash
bash scripts/watch.sh
```

Plays a terminal bell, prints to stdout, and sends a macOS notification when a message arrives.

### Auto-inject mode (fully automatic)

```bash
bash scripts/watch.sh --auto <tmux-target>
```

Types a prompt into the specified tmux pane so Claude Code reads the inbox and responds automatically. Example:

```bash
# If Claude Code is running in tmux session "claude", window 0, pane 0:
bash scripts/watch.sh --auto claude:0.0
```

### Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `POLL_INTERVAL` | `5` | Seconds between inbox checks |
| `COOLDOWN` | `30` | Minimum seconds between alerts (prevents spam) |
| `INBOX_URL` | `http://127.0.0.1:18790/status` | Inbox status endpoint |

## Requirements

- **OpenClaw** running with gateway enabled
- `gateway.auth.token` set in `openclaw.json`
- `gateway.http.endpoints.chatCompletions.enabled: true` in `openclaw.json`
- **OpenAI API key** for semantic search (falls back to text search without it)

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `OPENCLAW_DIR` | Yes | `~/.openclaw` | Path to OpenClaw installation |
| `OPENAI_API_KEY` | For semantic search | Resolved from 1Password if available | OpenAI API key for embeddings |
| `LESA_BRIDGE_INBOX_PORT` | No | `18790` | Inbox HTTP server port |

## License

MIT

---

Built by Parker Todd Brooks, Lēsa (OpenClaw, Claude Opus 4.6), Claude Code CLI (Claude Opus 4.6).
