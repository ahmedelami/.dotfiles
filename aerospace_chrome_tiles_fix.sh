#!/bin/zsh
set -euo pipefail

AEROSPACE_BIN="/opt/homebrew/bin/aerospace"

if [[ ! -x "$AEROSPACE_BIN" ]]; then
  exit 0
fi

# Debounce: on-focus-changed can fire a lot; ensure only one instance runs.
lock_dir="${TMPDIR:-/tmp}/aerospace-chrome-tiles-fix.lock"
if ! mkdir "$lock_dir" 2>/dev/null; then
  exit 0
fi
trap 'rmdir "$lock_dir" 2>/dev/null || true' EXIT

focused_bundle_id="$("$AEROSPACE_BIN" list-windows --focused --format '%{app-bundle-id}' 2>/dev/null || true)"
case "$focused_bundle_id" in
  com.google.Chrome*) ;;
  *) exit 0 ;;
esac

workspace="$("$AEROSPACE_BIN" list-windows --focused --format '%{workspace}' 2>/dev/null || true)"
if [[ -z "$workspace" ]]; then
  exit 0
fi

root_layout="$("$AEROSPACE_BIN" list-windows --focused --format '%{workspace-root-container-layout}' 2>/dev/null || true)"
case "$root_layout" in
  h_accordion) "$AEROSPACE_BIN" layout h_tiles >/dev/null 2>&1 || true ;;
  v_accordion) "$AEROSPACE_BIN" layout v_tiles >/dev/null 2>&1 || true ;;
esac
