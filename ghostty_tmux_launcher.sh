#!/bin/zsh -l

# Zero-Touch Ghostty Tmux Launcher
# Always start a brand-new session to avoid restoring prior state.

TMUX_BIN="/opt/homebrew/bin/tmux"

SESSION_NAME="ghostty_$(date +%Y%m%d%H%M%S)_$RANDOM"
exec $TMUX_BIN new-session -s "$SESSION_NAME"
