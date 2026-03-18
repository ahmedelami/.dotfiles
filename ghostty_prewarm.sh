#!/bin/zsh

app="/Applications/Ghostty.app"

if /usr/bin/pgrep -x ghostty >/dev/null 2>&1; then
  exit 0
fi

if [[ ! -d "$app" ]]; then
  print -u2 "ghostty_prewarm: not found: $app"
  exit 1
fi

exec /usr/bin/open -gj -a "$app" --args --initial-window=false --quit-after-last-window-closed=false
