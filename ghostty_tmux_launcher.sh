#!/bin/zsh -l

# Zero-Touch Ghostty Tmux Launcher
# This script finds the first available "ghostty_X" session and grabs it.

TMUX_BIN="/opt/homebrew/bin/tmux"
GREP_BIN="/usr/bin/grep"
AWK_BIN="/usr/bin/awk"

# 1. Find the first session that isn't currently attached
for i in {1..20}; do
  SESSION_NAME="ghostty_$i"
  
  # Check if session exists
  if $TMUX_BIN has-session -t "$SESSION_NAME" 2>/dev/null; then
    # Check if it's already attached
    ATTACHED_COUNT=$($TMUX_BIN list-sessions -F "#{session_name} #{session_attached}" | $GREP_BIN "^$SESSION_NAME " | $AWK_BIN '{print $2}')
    if [ "$ATTACHED_COUNT" -eq 0 ]; then
      # Found an existing unattached session! Grab it.
      exec $TMUX_BIN attach-session -t "$SESSION_NAME"
    fi
  else
    # Session doesn't exist yet! Create it and start fresh.
    exec $TMUX_BIN new-session -s "$SESSION_NAME"
  fi
done

# Fallback just in case
exec $TMUX_BIN new-session
