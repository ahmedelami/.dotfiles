#!/bin/zsh -f
set -euo pipefail

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
HUMOODAGEN_STATE_DIR="$STATE_HOME/humoodagen"
PERSIST_FLAG="$HUMOODAGEN_STATE_DIR/ghostty-persist-session"
TMUX_RS_FLAG="$HUMOODAGEN_STATE_DIR/ghostty-use-tmux-rs"
LAST_SIZE_FILE="$HUMOODAGEN_STATE_DIR/ghostty-last-size"

mkdir -p "$HUMOODAGEN_STATE_DIR" 2>/dev/null || true
print -r -- "" >|"$PERSIST_FLAG" 2>/dev/null || true

TMUX_START_COLS=160
TMUX_START_LINES=50
if [[ -r "$LAST_SIZE_FILE" ]]; then
  rows=""
  cols=""
  IFS=" " read -r rows cols <"$LAST_SIZE_FILE" || true
  if [[ "$rows" == <-> && "$cols" == <-> ]]; then
    TMUX_START_LINES="$rows"
    TMUX_START_COLS="$cols"
  fi
fi

TMUX_BIN="/opt/homebrew/bin/tmux"
if [[ ! -x "$TMUX_BIN" ]]; then
  TMUX_BIN="$(command -v tmux || true)"
fi

TMUX_IMPL="tmux"
TMUX_RS_BIN="$HOME/.cargo/bin/tmux-rs"
if [[ -f "$TMUX_RS_FLAG" && -x "$TMUX_RS_BIN" ]]; then
  TMUX_BIN="$TMUX_RS_BIN"
  TMUX_IMPL="tmux-rs"
fi

if [[ -z "${TMUX_BIN:-}" || ! -x "$TMUX_BIN" ]]; then
  print -r -- "ghostty_persist_enable: tmux not found"
  exit 1
fi

TMUX_SERVER_NAME="humoodagen-ghostty-persist"
SESSION_NAME="ghostty"

start_dir="$HOME"
if [[ -d "$HOME/repos" ]]; then
  start_dir="$HOME/repos"
fi

if TMUX_SKIP_TPM=1 "$TMUX_BIN" -L "$TMUX_SERVER_NAME" has-session -t "$SESSION_NAME" 2>/dev/null; then
  print -r -- "ghostty persistent session already running: $SESSION_NAME (server=$TMUX_SERVER_NAME, tmux=$TMUX_IMPL)"
  exit 0
fi

TMUX_SKIP_TPM=1 "$TMUX_BIN" -L "$TMUX_SERVER_NAME" start-server \
  \; set-option -g destroy-unattached off \
  \; new-session -d \
  -x "$TMUX_START_COLS" \
  -y "$TMUX_START_LINES" \
  -c "$start_dir" \
  -s "$SESSION_NAME" \
  -n nvim \
  -e "HUMOODAGEN_GHOSTTY=1" \
  -e "HUMOODAGEN_TMUX_BIN=$TMUX_BIN" \
  -e "HUMOODAGEN_TMUX_IMPL=$TMUX_IMPL" \
  -e "HUMOODAGEN_TMUX_SESSION=$SESSION_NAME" \
  -- "$HOME/.dotfiles/ghostty_tmux_pane.sh"

print -r -- "ghostty persistent mode enabled and session started: $SESSION_NAME (server=$TMUX_SERVER_NAME, tmux=$TMUX_IMPL, size=${TMUX_START_COLS}x${TMUX_START_LINES})"
