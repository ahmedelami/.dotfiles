#!/bin/zsh -f
set -euo pipefail

# Prewarm Ghostty without creating an initial window so subsequent opens are
# "warm" (the process is already running).

if pgrep -x ghostty >/dev/null 2>&1; then
  exit 0
fi

APP="/Applications/Ghostty.app"
if [[ ! -d "$APP" ]]; then
  print -r -- "ghostty_prewarm: not found: $APP" >&2
  exit 1
fi

exec /usr/bin/open -gj -a "$APP" --args \
  --initial-window=false \
  --quit-after-last-window-closed=false
