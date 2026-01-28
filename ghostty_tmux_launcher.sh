#!/bin/zsh -f

# Zero-Touch Ghostty Tmux Launcher
# Always start a brand-new session to avoid restoring prior state.

# Avoid slow shell startup files (zsh -f). Ensure common tool paths exist.
if [[ -d "/opt/homebrew/bin" ]]; then
  case ":$PATH:" in
    *":/opt/homebrew/bin:"*) ;;
    *) export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH" ;;
  esac
fi
if [[ -d "$HOME/.cargo/bin" ]]; then
  case ":$PATH:" in
    *":$HOME/.cargo/bin:"*) ;;
    *) export PATH="$HOME/.cargo/bin:$PATH" ;;
  esac
fi

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
HUMOODAGEN_STATE_DIR="$STATE_HOME/humoodagen"
HUMOODAGEN_GHOSTTY_PERF_FLAG="$HUMOODAGEN_STATE_DIR/ghostty-perf-on"
HUMOODAGEN_GHOSTTY_PERF_UI_FLAG="$HUMOODAGEN_STATE_DIR/ghostty-perf-ui-on"
HUMOODAGEN_GHOSTTY_TMUX_RS_FLAG="$HUMOODAGEN_STATE_DIR/ghostty-use-tmux-rs"

TMUX_BIN_TMUX="/opt/homebrew/bin/tmux"
if [[ ! -x "$TMUX_BIN_TMUX" ]]; then
  TMUX_BIN_TMUX="$(command -v tmux)"
fi

TMUX_BIN_TMUX_RS="$HOME/.cargo/bin/tmux-rs"

TMUX_BIN="$TMUX_BIN_TMUX"
TMUX_IMPL="tmux"
if [[ -f "$HUMOODAGEN_GHOSTTY_TMUX_RS_FLAG" ]]; then
  if [[ -x "$TMUX_BIN_TMUX_RS" ]]; then
    TMUX_BIN="$TMUX_BIN_TMUX_RS"
    TMUX_IMPL="tmux-rs"
  fi
fi

PERSIST_FLAG="$HUMOODAGEN_STATE_DIR/ghostty-persist-session"
PERSIST=0
if [[ -f "$PERSIST_FLAG" ]]; then
  PERSIST=1
fi

TMUX_SERVER_NAME="humoodagen-ghostty"
if (( PERSIST )); then
  TMUX_SERVER_NAME="humoodagen-ghostty-persist"
fi

resolve_start_dir() {
  if [[ -d "$HOME/repos" ]]; then
    printf '%s' "$HOME/repos"
    return
  fi

  local state_file="${HUMOODAGEN_STATE_DIR}/ghostty-cwd"
  if [[ -f "$state_file" ]]; then
    local p
    p="$(head -n 1 "$state_file" | sed 's/[[:space:]]*$//')"
    if [[ -n "$p" ]]; then
      p="${p/#\~/$HOME}"
      if [[ -d "$p" ]]; then
        printf '%s' "$p"
        return
      fi
    fi
  fi

  printf '%s' "$HOME"
}

START_DIR="$(resolve_start_dir)"

SESSION_NAME="ghostty_$(date +%Y%m%d%H%M%S)_$RANDOM"
if (( PERSIST )); then
  SESSION_NAME="ghostty"
fi
export HUMOODAGEN_TMUX_SESSION="$SESSION_NAME"

TMUX_START_COLS=160
TMUX_START_LINES=50
if [[ -t 0 ]]; then
  rows=""
  cols=""
  IFS=" " read -r rows cols <<<"$(stty size 2>/dev/null || true)"
  if [[ "$rows" == <-> && "$cols" == <-> ]]; then
    TMUX_START_LINES="$rows"
    TMUX_START_COLS="$cols"
  fi
fi

# Start directly in Neovim. When you quit Neovim, drop into a login shell
# instead of closing the Ghostty pane.
if [[ -f "$HUMOODAGEN_GHOSTTY_PERF_FLAG" ]]; then
  mkdir -p "$HUMOODAGEN_STATE_DIR"
  HUMOODAGEN_GHOSTTY_LAUNCH_LOG="$HUMOODAGEN_STATE_DIR/ghostty-launch.log"

  zmodload zsh/datetime 2>/dev/null || true

  ts_ns() {
    if [[ -n "${EPOCHREALTIME:-}" ]]; then
      local sec="${EPOCHREALTIME%.*}"
      local frac="${EPOCHREALTIME#*.}"
      frac="${frac}000000000"
      frac="${frac[1,9]}"
      printf '%s%s' "$sec" "$frac"
      return
    fi
    python3 -c 'import time; print(time.time_ns())'
  }

  launch_ts_ns="$(ts_ns)"
  export HUMOODAGEN_LAUNCH_TS_NS="$launch_ts_ns"
  export HUMOODAGEN_GHOSTTY_LAUNCH_LOG
  export HUMOODAGEN_PERF=1
  PERF_UI=0
  if [[ -f "$HUMOODAGEN_GHOSTTY_PERF_UI_FLAG" ]]; then
    PERF_UI=1
  fi
  export HUMOODAGEN_PERF_UI="$PERF_UI"

  open_ts_file="${HUMOODAGEN_STATE_DIR}/ghostty-open-ts-ns"
  open_ts=""
  if [[ -r "$open_ts_file" ]]; then
    open_ts="$(head -n 1 "$open_ts_file" | tr -d '[:space:]')"
  fi
  open_delta_ns=""
  if [[ "$open_ts" == <-> ]]; then
    open_delta_ns=$(( launch_ts_ns - open_ts ))
    # Ignore stale timestamps (e.g. when Ghostty is launched by clicking the app).
    if (( open_delta_ns < 0 || open_delta_ns > 10000000000 )); then
      open_ts=""
      open_delta_ns=""
    fi
  else
    open_ts=""
  fi

  {
    printf '%s | launcher:start | launch_ts_ns=%s | pid=%s\n' "$(ts_ns)" "$launch_ts_ns" "$$"
    if [[ -n "$open_ts" && -n "$open_delta_ns" ]]; then
      printf '%s | launcher:open_to_launcher | launch_ts_ns=%s | open_ts_ns=%s | delta_ns=%s\n' "$launch_ts_ns" "$launch_ts_ns" "$open_ts" "$open_delta_ns"
    fi
    printf '%s | launcher:perf=1 | launch_ts_ns=%s | session=%s\n' "$(ts_ns)" "$launch_ts_ns" "$SESSION_NAME"
    printf '%s | launcher:perf_ui=%s | launch_ts_ns=%s\n' "$(ts_ns)" "$PERF_UI" "$launch_ts_ns"
    printf '%s | launcher:tmux_impl=%s | launch_ts_ns=%s | tmux_bin=%s\n' "$(ts_ns)" "$TMUX_IMPL" "$launch_ts_ns" "$TMUX_BIN"
    printf '%s | launcher:persist=%s | launch_ts_ns=%s\n' "$(ts_ns)" "$PERSIST" "$launch_ts_ns"
    printf '%s | launcher:exec-tmux | launch_ts_ns=%s | session=%s\n' "$(ts_ns)" "$launch_ts_ns" "$SESSION_NAME"
  } >>"$HUMOODAGEN_GHOSTTY_LAUNCH_LOG"

  if (( PERSIST )); then
    TMUX_SKIP_TPM=1 exec "$TMUX_BIN" -L "$TMUX_SERVER_NAME" start-server \
      \; set-environment -g HUMOODAGEN_LAUNCH_TS_NS "$launch_ts_ns" \
      \; set-environment -g HUMOODAGEN_GHOSTTY_LAUNCH_LOG "$HUMOODAGEN_GHOSTTY_LAUNCH_LOG" \
      \; set-environment -g HUMOODAGEN_PERF 1 \
      \; set-environment -g HUMOODAGEN_PERF_UI "$PERF_UI" \
      \; set-hook -g client-attached 'run-shell -b "$HOME/.dotfiles/ghostty_tmux_hook.sh tmux:client-attached"' \
      \; set-hook -g client-detached 'run-shell -b "$HOME/.dotfiles/ghostty_tmux_hook.sh tmux:client-detached"' \
      \; set-option -g destroy-unattached off \
      \; new-session -A \
      -x "$TMUX_START_COLS" \
      -y "$TMUX_START_LINES" \
      -e "HUMOODAGEN_LAUNCH_TS_NS=$launch_ts_ns" \
      -e "HUMOODAGEN_GHOSTTY_LAUNCH_LOG=$HUMOODAGEN_GHOSTTY_LAUNCH_LOG" \
      -e "HUMOODAGEN_GHOSTTY=1" \
      -e "HUMOODAGEN_TMUX_BIN=$TMUX_BIN" \
      -e "HUMOODAGEN_TMUX_IMPL=$TMUX_IMPL" \
      -e "HUMOODAGEN_TMUX_SESSION=$SESSION_NAME" \
      -e "HUMOODAGEN_PERF=1" \
      -e "HUMOODAGEN_PERF_UI=$PERF_UI" \
      -c "$START_DIR" \
      -s "$SESSION_NAME" \
      -n nvim -- "$HOME/.dotfiles/ghostty_tmux_pane.sh"
  fi

  TMUX_SKIP_TPM=1 exec "$TMUX_BIN" -L "$TMUX_SERVER_NAME" start-server \
    \; set-environment -g HUMOODAGEN_LAUNCH_TS_NS "$launch_ts_ns" \
    \; set-environment -g HUMOODAGEN_GHOSTTY_LAUNCH_LOG "$HUMOODAGEN_GHOSTTY_LAUNCH_LOG" \
    \; set-environment -g HUMOODAGEN_PERF 1 \
    \; set-environment -g HUMOODAGEN_PERF_UI "$PERF_UI" \
    \; set-hook -g client-attached 'run-shell -b "$HOME/.dotfiles/ghostty_tmux_hook.sh tmux:client-attached"' \
    \; set-hook -g client-detached 'run-shell -b "$HOME/.dotfiles/ghostty_tmux_hook.sh tmux:client-detached"' \
    \; set-option -g destroy-unattached on \
    \; new-session -d \
    -x "$TMUX_START_COLS" \
    -y "$TMUX_START_LINES" \
    -e "HUMOODAGEN_LAUNCH_TS_NS=$launch_ts_ns" \
    -e "HUMOODAGEN_GHOSTTY_LAUNCH_LOG=$HUMOODAGEN_GHOSTTY_LAUNCH_LOG" \
    -e "HUMOODAGEN_GHOSTTY=1" \
    -e "HUMOODAGEN_TMUX_BIN=$TMUX_BIN" \
    -e "HUMOODAGEN_TMUX_IMPL=$TMUX_IMPL" \
    -e "HUMOODAGEN_TMUX_SESSION=$SESSION_NAME" \
    -e "HUMOODAGEN_PERF=1" \
    -e "HUMOODAGEN_PERF_UI=$PERF_UI" \
    -c "$START_DIR" \
    -s "$SESSION_NAME" \
    -n nvim -- "$HOME/.dotfiles/ghostty_tmux_pane.sh" \
    \; attach-session -t "$SESSION_NAME"
fi

if (( PERSIST )); then
  TMUX_SKIP_TPM=1 exec "$TMUX_BIN" -L "$TMUX_SERVER_NAME" start-server \
    \; set-option -g destroy-unattached off \
    \; new-session -A \
    -x "$TMUX_START_COLS" \
    -y "$TMUX_START_LINES" \
    -e "HUMOODAGEN_GHOSTTY=1" \
    -e "HUMOODAGEN_TMUX_BIN=$TMUX_BIN" \
    -e "HUMOODAGEN_TMUX_IMPL=$TMUX_IMPL" \
    -e "HUMOODAGEN_TMUX_SESSION=$SESSION_NAME" \
    -c "$START_DIR" \
    -s "$SESSION_NAME" \
    -n nvim -- "$HOME/.dotfiles/ghostty_tmux_pane.sh"
fi

TMUX_SKIP_TPM=1 exec "$TMUX_BIN" -L "$TMUX_SERVER_NAME" start-server \
  \; set-option -g destroy-unattached on \
  \; new-session -d \
  -x "$TMUX_START_COLS" \
  -y "$TMUX_START_LINES" \
  -e "HUMOODAGEN_GHOSTTY=1" \
  -e "HUMOODAGEN_TMUX_BIN=$TMUX_BIN" \
  -e "HUMOODAGEN_TMUX_IMPL=$TMUX_IMPL" \
  -e "HUMOODAGEN_TMUX_SESSION=$SESSION_NAME" \
  -c "$START_DIR" \
  -s "$SESSION_NAME" \
  -n nvim -- "$HOME/.dotfiles/ghostty_tmux_pane.sh" \
  \; attach-session -t "$SESSION_NAME"
