#!/bin/zsh
set -euo pipefail

AEROSPACE_BIN="/opt/homebrew/bin/aerospace"

if [[ ! -x "$AEROSPACE_BIN" ]]; then
  exit 0
fi

# Debounce: on-focus-changed can fire a lot; ensure only one instance runs.
lock_dir="${TMPDIR:-/tmp}/aerospace-native-tabs-fix.lock"
if ! mkdir "$lock_dir" 2>/dev/null; then
  exit 0
fi
trap 'rmdir "$lock_dir" 2>/dev/null || true' EXIT

focused_bundle_id="$("$AEROSPACE_BIN" list-windows --focused --format '%{app-bundle-id}' 2>/dev/null || true)"
case "$focused_bundle_id" in
  com.mitchellh.ghostty|com.apple.Terminal) ;;
  *) exit 0 ;;
esac

tabbed_app_bundle_id="$focused_bundle_id"

workspace="$("$AEROSPACE_BIN" list-windows --focused --format '%{workspace}' 2>/dev/null || true)"
if [[ -z "$workspace" ]]; then
  exit 0
fi

root_layout="$("$AEROSPACE_BIN" list-windows --focused --format '%{workspace-root-container-layout}' 2>/dev/null || true)"
case "$root_layout" in
  h_tiles|v_tiles|h_accordion|v_accordion) ;;
  *) exit 0 ;;
esac

tabbed_app_count="$("$AEROSPACE_BIN" list-windows --workspace "$workspace" --app-bundle-id "$tabbed_app_bundle_id" --count 2>/dev/null || echo 0)"
total_count="$("$AEROSPACE_BIN" list-windows --workspace "$workspace" --count 2>/dev/null || echo 0)"

# Only auto-switch when the workspace contains only this app. This avoids turning
# a mixed-app workspace into a global accordion layout unexpectedly.
if [[ "$tabbed_app_count" != "$total_count" ]]; then
  exit 0
fi

# macOS native "tabs" can surface as multiple windows. In a tiling layout, that
# creates a blank half because only the focused tab-window draws. Switching to
# accordion stacks them like tabs.
# Keep the workspace in accordion even when only one window exists.
# This pre-switch prevents the brief "half width / blank half" flash that can
# happen the first time a second tab-window appears (before this hook runs).
if (( tabbed_app_count >= 1 )); then
  case "$root_layout" in
    h_tiles) "$AEROSPACE_BIN" layout h_accordion >/dev/null 2>&1 || true ;;
    v_tiles) "$AEROSPACE_BIN" layout v_accordion >/dev/null 2>&1 || true ;;
  esac
fi
