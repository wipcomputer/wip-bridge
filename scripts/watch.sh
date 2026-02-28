#!/usr/bin/env bash
# cc-inbox-watcher: polls lesa-bridge inbox and auto-injects into Claude Code
#
# Mode 1 (alert only):  bash watch.sh
# Mode 2 (auto-inject): bash watch.sh --auto <tmux-target>
#   e.g. bash watch.sh --auto claude:0.0
#
# In auto mode, when Lesa sends a message, the watcher types
# "Lesa sent me a message, check the inbox" into the Claude Code
# tmux pane so Claude Code responds automatically.

INBOX_URL="http://127.0.0.1:18790/status"
POLL_INTERVAL=5
COOLDOWN=30

AUTO_MODE=false
TMUX_TARGET=""

if [ "$1" = "--auto" ] && [ -n "$2" ]; then
  AUTO_MODE=true
  TMUX_TARGET="$2"
  echo "[watcher] Auto mode: injecting into tmux pane $TMUX_TARGET"
fi

last_alert=0

while true; do
  now=$(date +%s)
  response=$(curl -s --max-time 3 "$INBOX_URL" 2>/dev/null)

  if [ -n "$response" ]; then
    pending=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('pending',0))" 2>/dev/null)

    if [ "$pending" != "" ] && [ "$pending" -gt 0 ] 2>/dev/null; then
      elapsed=$((now - last_alert))
      if [ "$elapsed" -ge "$COOLDOWN" ]; then
        last_alert=$now
        timestamp=$(date +%H:%M)

        if [ "$AUTO_MODE" = true ]; then
          echo "[$timestamp] Injecting check into Claude Code ($pending pending)"
          # Type the message, then send Return (C-m) to submit
          tmux send-keys -t "$TMUX_TARGET" "Lesa sent me a message. Check the inbox and respond to her."
          sleep 0.5
          tmux send-keys -t "$TMUX_TARGET" Enter
        else
          printf "\a"
          echo "[$timestamp] Lesa has a message for you ($pending pending)"
          osascript -e "display notification \"$pending pending message(s)\" with title \"Lesa\" sound name \"Tink\"" 2>/dev/null
        fi
      fi
    fi
  fi

  sleep "$POLL_INTERVAL"
done
