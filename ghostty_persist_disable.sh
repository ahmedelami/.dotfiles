#!/bin/zsh -f
set -euo pipefail

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
HUMOODAGEN_STATE_DIR="$STATE_HOME/humoodagen"
PERSIST_FLAG="$HUMOODAGEN_STATE_DIR/ghostty-persist-session"

rm -f "$PERSIST_FLAG" 2>/dev/null || true

TMUX_SERVER_NAME="humoodagen-ghostty-persist"

try_kill() {
  local bin="$1"
  if [[ -z "${bin:-}" ]]; then
    return 0
  fi
  if [[ ! -x "$bin" ]]; then
    return 0
  fi
  TMUX_SKIP_TPM=1 "$bin" -L "$TMUX_SERVER_NAME" kill-server 2>/dev/null || true
}

try_kill "$HOME/.cargo/bin/tmux-rs"
try_kill "/opt/homebrew/bin/tmux"
try_kill "$(command -v tmux || true)"

print -r -- "ghostty persistent mode disabled (flag removed) and tmux server stopped: $TMUX_SERVER_NAME"
