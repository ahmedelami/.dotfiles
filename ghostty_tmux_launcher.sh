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
HUMOODAGEN_GHOSTTY_LAST_SIZE_FILE="$HUMOODAGEN_STATE_DIR/ghostty-last-size"
HUMOODAGEN_GHOSTTY_PREFILL_FILE="$HUMOODAGEN_STATE_DIR/ghostty-prefill.ansi"

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

PREFILL_DONE=0
prefill_from_file() {
  if [[ ! -t 1 ]]; then
    return
  fi
  if [[ ! -s "$HUMOODAGEN_GHOSTTY_PREFILL_FILE" ]]; then
    return
  fi
  # Draw something immediately so Ghostty doesn't show a blank surface
  # while the tmux client attaches.
  {
    # Avoid doing a full-screen clear or switching screen buffers here: on
    # some setups (tilers + live resize) that can produce a visible diagonal
    # redraw. Just paint the cached frame in-place.
    printf '\033[?2026h\033[H\033[?25l'
    cat "$HUMOODAGEN_GHOSTTY_PREFILL_FILE" 2>/dev/null || true
    printf '\033[?2026l'
  } 2>/dev/null || true
  PREFILL_DONE=1
}

if (( PERSIST )); then
  prefill_from_file
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

STTY_SETTLE_INITIAL=""
STTY_SETTLE_FINAL=""
STTY_SETTLE_MS=""
STTY_SETTLE_TRIES=0
STTY_SETTLE_CHANGED=0
STTY_SETTLE_EXPECTED=""
STTY_SETTLE_REASON=""

wait_for_stty_settle() {
  if [[ ! -t 0 ]]; then
    return
  fi

  local settle_start_ns
  settle_start_ns="$(ts_ns)"

  local expected_rows=""
  local expected_cols=""
  if [[ -r "$HUMOODAGEN_GHOSTTY_LAST_SIZE_FILE" ]]; then
    IFS=" " read -r expected_rows expected_cols <"$HUMOODAGEN_GHOSTTY_LAST_SIZE_FILE" || true
    if [[ "$expected_rows" != <-> || "$expected_cols" != <-> ]]; then
      expected_rows=""
      expected_cols=""
    fi
  fi
  if [[ -n "${expected_rows:-}" && -n "${expected_cols:-}" ]]; then
    STTY_SETTLE_EXPECTED="${expected_cols}x${expected_rows}"
  else
    STTY_SETTLE_EXPECTED=""
  fi

  if [[ -n "${expected_rows:-}" && -n "${expected_cols:-}" ]]; then
    if [[ "$expected_rows" == "$TMUX_START_LINES" && "$expected_cols" == "$TMUX_START_COLS" ]]; then
      STTY_SETTLE_FINAL="${TMUX_START_COLS}x${TMUX_START_LINES}"
      STTY_SETTLE_MS="0"
      STTY_SETTLE_TRIES="0"
      STTY_SETTLE_CHANGED="0"
      STTY_SETTLE_REASON="already_expected"
      return
    fi
  fi

  local last_rows="$TMUX_START_LINES"
  local last_cols="$TMUX_START_COLS"
  local stable=0
  local tries=0
  local stable_target=5
  local stable_target_expected=2
  local alt_stable_target=15
  local sleep_interval=0.01
  local seen_change=0
  local reason="timeout"
  local expect_change=0
  local no_change_timeout_tries=25

  if [[ -n "${expected_rows:-}" && -n "${expected_cols:-}" ]]; then
    if [[ "$expected_rows" != "$TMUX_START_LINES" || "$expected_cols" != "$TMUX_START_COLS" ]]; then
      expect_change=1
    fi
  fi

  while (( tries < 50 )); do
    local rows=""
    local cols=""
    IFS=" " read -r rows cols <<<"$(stty size 2>/dev/null || true)"
    if [[ "$rows" != <-> || "$cols" != <-> ]]; then
      break
    fi
    if [[ "$rows" == "$last_rows" && "$cols" == "$last_cols" ]]; then
      stable=$(( stable + 1 ))
    else
      stable=0
      last_rows="$rows"
      last_cols="$cols"
      seen_change=1
    fi

    if (( expect_change )); then
      if [[ -n "${expected_rows:-}" && -n "${expected_cols:-}" && "$last_rows" == "$expected_rows" && "$last_cols" == "$expected_cols" ]]; then
        if (( stable >= stable_target_expected )); then
          reason="expected"
          break
        fi
      fi
      if (( seen_change )) && (( stable >= alt_stable_target )); then
        reason="stable_after_change"
        break
      fi
      if (( seen_change == 0 )) && (( tries >= no_change_timeout_tries )); then
        reason="no_change_timeout"
        break
      fi
    else
      if (( stable >= stable_target )); then
        reason="stable"
        break
      fi
    fi
    sleep "$sleep_interval"
    tries=$(( tries + 1 ))
  done

  TMUX_START_LINES="$last_rows"
  TMUX_START_COLS="$last_cols"

  local settle_end_ns
  settle_end_ns="$(ts_ns)"
  local settle_ms=""
  if [[ "$settle_start_ns" == <-> && "$settle_end_ns" == <-> ]]; then
    settle_ms=$(( (settle_end_ns - settle_start_ns) / 1000000 ))
  fi
  STTY_SETTLE_FINAL="${TMUX_START_COLS}x${TMUX_START_LINES}"
  STTY_SETTLE_MS="$settle_ms"
  STTY_SETTLE_TRIES="$tries"
  STTY_SETTLE_CHANGED="$seen_change"
  STTY_SETTLE_REASON="$reason"
}

# AeroSpace (and other tilers) can resize the window shortly after Ghostty
# spawns the command, so wait briefly for the PTY size to settle before using
# it for tmux sizing decisions.
if (( PERSIST )); then
  STTY_SETTLE_INITIAL="${TMUX_START_COLS}x${TMUX_START_LINES}"
  wait_for_stty_settle
fi

# Persist the last known terminal grid size so detached tmux sessions can be
# started (and pre-sized) without defaulting to 80x24.
mkdir -p "$HUMOODAGEN_STATE_DIR" 2>/dev/null || true
printf '%s %s\n' "$TMUX_START_LINES" "$TMUX_START_COLS" >|"$HUMOODAGEN_GHOSTTY_LAST_SIZE_FILE" 2>/dev/null || true

# Start directly in Neovim. When you quit Neovim, drop into a login shell
# instead of closing the Ghostty pane.
if [[ -f "$HUMOODAGEN_GHOSTTY_PERF_FLAG" ]]; then
  mkdir -p "$HUMOODAGEN_STATE_DIR"
  HUMOODAGEN_GHOSTTY_LAUNCH_LOG="$HUMOODAGEN_STATE_DIR/ghostty-launch.log"

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
    {
      printf '%s | launcher:stty_settle | launch_ts_ns=%s | initial=%s | final=%sx%s | ms=%s | tries=%s | changed=%s | expected=%s | reason=%s\n' \
        "$(ts_ns)" \
        "$launch_ts_ns" \
        "${STTY_SETTLE_INITIAL:-}" \
        "$TMUX_START_COLS" \
        "$TMUX_START_LINES" \
        "${STTY_SETTLE_MS:-}" \
        "${STTY_SETTLE_TRIES:-}" \
        "${STTY_SETTLE_CHANGED:-}" \
        "${STTY_SETTLE_EXPECTED:-}" \
        "${STTY_SETTLE_REASON:-}"
    } >>"$HUMOODAGEN_GHOSTTY_LAUNCH_LOG" 2>/dev/null || true

    # If the persistent session is detached, resize it to the current terminal
    # size before attaching. This avoids a visible "one-frame" reflow when the
    # first client attaches with a different size than the last one.
    if TMUX_SKIP_TPM=1 "$TMUX_BIN" -L "$TMUX_SERVER_NAME" has-session -t "$SESSION_NAME" 2>/dev/null; then
      target_window="${SESSION_NAME}:"
      desired_window_size="$(
        TMUX_SKIP_TPM=1 "$TMUX_BIN" -L "$TMUX_SERVER_NAME" show-option -gqv window-size 2>/dev/null | tr -d '[:space:]'
      )"
      if [[ -z "${desired_window_size:-}" || "${desired_window_size:-}" == "manual" ]]; then
        desired_window_size="latest"
      fi
      tmux_window_before="$(
        TMUX_SKIP_TPM=1 "$TMUX_BIN" -L "$TMUX_SERVER_NAME" list-windows -t "$SESSION_NAME" -F "#{window_width}x#{window_height}" 2>/dev/null | head -n 1 | tr -d '[:space:]'
      )"
      clients_count="$(
        TMUX_SKIP_TPM=1 "$TMUX_BIN" -L "$TMUX_SERVER_NAME" list-clients -t "$SESSION_NAME" 2>/dev/null | wc -l | tr -d '[:space:]'
      )"
      {
        printf '%s | launcher:persist:pre_attach | launch_ts_ns=%s | pid=%s | clients=%s | stty=%sx%s | tmux_window_before=%s | desired_window_size=%s | target=%s\n' \
          "$(ts_ns)" "$launch_ts_ns" "$$" "${clients_count:-?}" "$TMUX_START_COLS" "$TMUX_START_LINES" "${tmux_window_before:-}" "$desired_window_size" "$target_window"
      } >>"$HUMOODAGEN_GHOSTTY_LAUNCH_LOG" 2>/dev/null || true
      if [[ "${clients_count:-0}" == "0" ]]; then
        TMUX_SKIP_TPM=1 "$TMUX_BIN" -L "$TMUX_SERVER_NAME" resize-window \
          -t "$target_window" \
          -x "$TMUX_START_COLS" \
          -y "$TMUX_START_LINES" 2>/dev/null || true
        # resize-window forces window-size=manual; restore the configured mode
        # so future resizes work normally.
        restore_status="ok"
        if ! TMUX_SKIP_TPM=1 "$TMUX_BIN" -L "$TMUX_SERVER_NAME" set-option -w -t "$target_window" window-size "$desired_window_size" 2>/dev/null; then
          restore_status="fail"
        fi
        effective_window_size="$(
          TMUX_SKIP_TPM=1 "$TMUX_BIN" -L "$TMUX_SERVER_NAME" show-option -w -t "$target_window" -qv window-size 2>/dev/null | tr -d '[:space:]'
        )"
        tmux_window_after="$(
          TMUX_SKIP_TPM=1 "$TMUX_BIN" -L "$TMUX_SERVER_NAME" list-windows -t "$SESSION_NAME" -F "#{window_width}x#{window_height}" 2>/dev/null | head -n 1 | tr -d '[:space:]'
        )"
        {
          printf '%s | launcher:persist:pre_attach_resized | launch_ts_ns=%s | pid=%s | stty=%sx%s | tmux_window_after=%s | window_size_restored=%s | restore_status=%s | window_size_effective=%s\n' \
            "$(ts_ns)" "$launch_ts_ns" "$$" "$TMUX_START_COLS" "$TMUX_START_LINES" "${tmux_window_after:-}" "$desired_window_size" "$restore_status" "${effective_window_size:-}"
        } >>"$HUMOODAGEN_GHOSTTY_LAUNCH_LOG" 2>/dev/null || true

        # Fallback prefill if we didn't already have a cached snapshot to draw.
        # (Best-effort: still somewhat late, but it will also seed the cache for
        # the next launch.)
        if (( PREFILL_DONE == 0 )) && [[ -t 1 ]]; then
          prefill_start_ns="$(ts_ns)"
          prefill_tmp="${HUMOODAGEN_GHOSTTY_PREFILL_FILE}.$$"
          umask 077
          TMUX_SKIP_TPM=1 "$TMUX_BIN" -L "$TMUX_SERVER_NAME" capture-pane -pe -t "$target_window" >|"$prefill_tmp" 2>/dev/null || true
          if [[ -s "$prefill_tmp" ]]; then
            mv -f "$prefill_tmp" "$HUMOODAGEN_GHOSTTY_PREFILL_FILE" 2>/dev/null || true
            prefill_from_file
          else
            rm -f "$prefill_tmp" 2>/dev/null || true
          fi
          prefill_end_ns="$(ts_ns)"
          prefill_ms=""
          if [[ "$prefill_start_ns" == <-> && "$prefill_end_ns" == <-> ]]; then
            prefill_ms=$(( (prefill_end_ns - prefill_start_ns) / 1000000 ))
          fi
          {
            printf '%s | launcher:persist:prefill | launch_ts_ns=%s | pid=%s | ms=%s\n' \
              "$(ts_ns)" "$launch_ts_ns" "$$" "${prefill_ms:-}"
          } >>"$HUMOODAGEN_GHOSTTY_LAUNCH_LOG" 2>/dev/null || true
        fi
      fi
    fi

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
  # If the persistent session is detached, resize it to the current terminal
  # size before attaching. This avoids a visible "one-frame" reflow when the
  # first client attaches with a different size than the last one.
  if TMUX_SKIP_TPM=1 "$TMUX_BIN" -L "$TMUX_SERVER_NAME" has-session -t "$SESSION_NAME" 2>/dev/null; then
    target_window="${SESSION_NAME}:"
    desired_window_size="$(
      TMUX_SKIP_TPM=1 "$TMUX_BIN" -L "$TMUX_SERVER_NAME" show-option -gqv window-size 2>/dev/null | tr -d '[:space:]'
    )"
    if [[ -z "${desired_window_size:-}" || "${desired_window_size:-}" == "manual" ]]; then
      desired_window_size="latest"
    fi
    clients_count="$(
      TMUX_SKIP_TPM=1 "$TMUX_BIN" -L "$TMUX_SERVER_NAME" list-clients -t "$SESSION_NAME" 2>/dev/null | wc -l | tr -d '[:space:]'
    )"
    if [[ "${clients_count:-0}" == "0" ]]; then
      TMUX_SKIP_TPM=1 "$TMUX_BIN" -L "$TMUX_SERVER_NAME" resize-window \
        -t "$target_window" \
        -x "$TMUX_START_COLS" \
        -y "$TMUX_START_LINES" 2>/dev/null || true
      TMUX_SKIP_TPM=1 "$TMUX_BIN" -L "$TMUX_SERVER_NAME" set-option -w -t "$target_window" window-size "$desired_window_size" 2>/dev/null || true

      if (( PREFILL_DONE == 0 )) && [[ -t 1 ]]; then
        prefill_tmp="${HUMOODAGEN_GHOSTTY_PREFILL_FILE}.$$"
        umask 077
        TMUX_SKIP_TPM=1 "$TMUX_BIN" -L "$TMUX_SERVER_NAME" capture-pane -pe -t "$target_window" >|"$prefill_tmp" 2>/dev/null || true
        if [[ -s "$prefill_tmp" ]]; then
          mv -f "$prefill_tmp" "$HUMOODAGEN_GHOSTTY_PREFILL_FILE" 2>/dev/null || true
          prefill_from_file
        else
          rm -f "$prefill_tmp" 2>/dev/null || true
        fi
      fi
    fi
  fi

  TMUX_SKIP_TPM=1 exec "$TMUX_BIN" -L "$TMUX_SERVER_NAME" start-server \
    \; set-option -g destroy-unattached off \
    \; set-hook -g client-attached 'run-shell -b "$HOME/.dotfiles/ghostty_tmux_hook.sh tmux:client-attached"' \
    \; set-hook -g client-detached 'run-shell -b "$HOME/.dotfiles/ghostty_tmux_hook.sh tmux:client-detached"' \
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
