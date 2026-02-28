---
name: send-to-claude-code
description: Send a message to Claude Code's live terminal session via the lesa-bridge inbox. Use when user says "tell Claude Code", "message CC", "ask Claude Code to", "send this to Claude Code", or when you need to coordinate with Claude Code without Parker relaying.
metadata:
  {
    "openclaw":
      {
        "emoji": "\U0001F4EC",
        "requires": {},
      },
  }
---

# Send Message to Claude Code

Send a message directly into Claude Code's running session. The message lands in an inbox that Claude Code checks with `lesa_check_inbox`. This enables real-time agent-to-agent communication without Parker relaying.

## When to Use

- **Share findings** — tell Claude Code what you discovered or completed
- **Ask questions** — ask Claude Code to look something up or investigate
- **Coordinate work** — align on who's doing what
- **Respond to Claude Code** — when Claude Code sends you a message via `lesa_send_message`, reply back through this

## How to Send

```bash
bash command:"curl -sS -X POST http://127.0.0.1:18790/message -H 'Content-Type: application/json' -d '{\"from\": \"Lesa\", \"message\": \"YOUR MESSAGE HERE\"}'"
```

Replace `YOUR MESSAGE HERE` with your actual message. Keep the JSON structure intact.

## Examples

### Simple message
```bash
bash command:"curl -sS -X POST http://127.0.0.1:18790/message -H 'Content-Type: application/json' -d '{\"from\": \"Lesa\", \"message\": \"Finished updating the PRD. Ready for your review.\"}'"
```

### Report a finding
```bash
bash command:"curl -sS -X POST http://127.0.0.1:18790/message -H 'Content-Type: application/json' -d '{\"from\": \"Lesa\", \"message\": \"Found a bug in the compaction-indicator plugin: it fires at 74% instead of 75%. The threshold comparison uses < instead of <=\"}'"
```

### Ask for help
```bash
bash command:"curl -sS -X POST http://127.0.0.1:18790/message -H 'Content-Type: application/json' -d '{\"from\": \"Lesa\", \"message\": \"Can you check if the op-secrets plugin resolves the Tavily API key? I am getting auth failures on web search.\"}'"
```

## Check if Inbox is Running

```bash
bash command:"curl -sS http://127.0.0.1:18790/status"
```

Returns `{"ok":true,"pending":N}` where N is the number of queued messages.

## How It Works

1. You POST a message to `localhost:18790/message`
2. The lesa-bridge MCP server (running inside Claude Code) queues it
3. Claude Code calls `lesa_check_inbox` to read pending messages
4. Claude Code sees your message and can respond via `lesa_send_message`

## Important Notes

- Messages are queued in memory — if Claude Code restarts, unread messages are lost
- The inbox only accepts connections from localhost (127.0.0.1)
- Claude Code must be running for the inbox to be available
- If the inbox is not reachable, Claude Code is not running or the MCP server failed to start
