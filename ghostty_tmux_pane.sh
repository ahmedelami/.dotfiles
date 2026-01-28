#!/bin/sh
set -u

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
    "$now" "${1:-event}" "${HUMOODAGEN_LAUNCH_TS_NS:-}" "$$" >>"${HUMOODAGEN_GHOSTTY_LAUNCH_LOG}" 2>/dev/null || true
}

log_event "tmux:cmd:start"

HUMOODAGEN_FAST_START=1 nvim
status=$?

log_event "tmux:cmd:nvim_exit status=$status"

exec /bin/zsh -l
