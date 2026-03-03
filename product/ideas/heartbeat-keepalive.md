# Heartbeat Keepalive

## Problem

Claude Code (CC) has no persistent process. When Parker closes the terminal, CC is gone. Lēsa runs 24/7 but CC can only work when invoked. This means overnight tasks, async collaboration, and continuous work all depend on someone (Parker or Lēsa) manually starting a CC session.

## Idea

A heartbeat system where Lēsa triggers CC sessions on a schedule. Lēsa is the sender. CC is the receiver. The bridge is the channel.

### How it works

1. Lēsa runs a cron-like loop (skill or plugin hook)
2. On each heartbeat, she invokes CC via her `claude-code` skill (`claude -p`)
3. The prompt carries context: pending tasks, work items, status checks
4. CC executes, writes results to a shared location (daily log, exec brief)
5. CC session ends. Lēsa picks up the results on her next turn.

### Tiers

| Tier | What it does | When |
|------|-------------|------|
| Bare ping | "Are you there?" health check | Every 30 min |
| Status check | Run pending tasks, report back | Every 2 hours |
| Work carry | Full task execution with context | On demand / overnight |

### Integration points

- **Exec Brief** (`wip-exec-brief`): overnight work results queue up for Parker's morning review
- **Daily log** (`workspace/memory/YYYY-MM-DD.md`): both agents write here
- **Task list**: Lēsa can check CC's pending tasks and trigger execution

## Open questions

- Rate limiting: how many CC sessions per hour before it's wasteful?
- Context passing: what's the minimum context CC needs to be useful on a cold start?
- Cost: each CC invocation uses API tokens. Budget per overnight cycle?
- Escalation: when should Lēsa wake Parker instead of pinging CC?

## Status

Concept. Not yet built.
