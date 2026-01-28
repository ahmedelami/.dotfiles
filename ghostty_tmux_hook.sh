#!/bin/sh
set -u

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
HUMOODAGEN_STATE_DIR="$STATE_HOME/humoodagen"
PREFILL_FILE="$HUMOODAGEN_STATE_DIR/ghostty-prefill.ansi"

update_prefill_snapshot() {
  # Only capture a snapshot for the persistent session when it becomes
  # unattached. This lets the next Ghostty launch immediately draw the last
  # known screen instead of a blank surface.
  if ! tmux has-session -t ghostty 2>/dev/null; then
    return 0
  fi

  clients="$(tmux list-clients -t ghostty 2>/dev/null | wc -l | tr -d '[:space:]')"
  if [ "${clients:-0}" != "0" ]; then
    return 0
  fi

  mkdir -p "$HUMOODAGEN_STATE_DIR" 2>/dev/null || true
  umask 077
  tmp="${PREFILL_FILE}.$$"
  tmux capture-pane -pe -t ghostty: >"$tmp" 2>/dev/null || true
  if [ -s "$tmp" ]; then
    mv -f "$tmp" "$PREFILL_FILE" 2>/dev/null || true
  else
    rm -f "$tmp" 2>/dev/null || true
  fi
}

ts_ns() {
  python3 -c 'import time; print(time.time_ns())' 2>/dev/null || echo ""
}

log_event() {
  # Only log when perf mode is enabled (so normal startups stay untouched).
  if [ "${HUMOODAGEN_PERF:-}" != "1" ]; then
    return 0
  fi
  if [ -z "${HUMOODAGEN_GHOSTTY_LAUNCH_LOG:-}" ]; then
    return 0
  fi
  now="$(ts_ns)"
  if [ -z "$now" ]; then
    return 0
  fi
  printf '%s | %s | launch_ts_ns=%s | pid=%s\n' \
    "$now" "${1:-tmux:hook}" "${HUMOODAGEN_LAUNCH_TS_NS:-}" "$$" >>"${HUMOODAGEN_GHOSTTY_LAUNCH_LOG}" 2>/dev/null || true
}

EVENT="${1:-tmux:hook}"
case "$EVENT" in
  tmux:client-detached)
    update_prefill_snapshot
    ;;
esac

log_event "$EVENT"
