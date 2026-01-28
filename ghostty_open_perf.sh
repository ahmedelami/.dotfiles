#!/bin/zsh -l

STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
HUMOODAGEN_STATE_DIR="$STATE_HOME/humoodagen"
OPEN_TS_FILE="$HUMOODAGEN_STATE_DIR/ghostty-open-ts-ns"

mkdir -p "$HUMOODAGEN_STATE_DIR" 2>/dev/null || true

ts_ns() {
  zmodload zsh/datetime 2>/dev/null || true
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

printf '%s\n' "$(ts_ns)" >|"$OPEN_TS_FILE" 2>/dev/null || true

open -na /Applications/Ghostty.app --args "$@"
