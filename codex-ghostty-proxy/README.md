`codex-ghostty-proxy` is a small local PTY wrapper for interactive Codex sessions in Ghostty.

It enables three things:

1. Codex session-event logging (`task_started`, `task_complete`, `turn_aborted`)
2. Ghostty focus reporting (`CSI I` / `CSI O`)
3. Dynamic background tinting via `OSC 11` / `OSC 111`

The state machine is deterministic:

- `task_started` -> red tint
- `task_complete` while unfocused -> green tint
- `task_complete` while focused -> normal
- `FocusIn` while green -> normal
- `turn_aborted` -> normal

On macOS, Ghostty tabs only mirror this tint cleanly when `macos-titlebar-style = tabs`.

The repo also ships a self-healing launcher patcher:

- `bin/codex-ghostty-patch` reapplies the Ghostty proxy patch to installed `codex.js` entrypoints
- `bin/codex-ghostty-patch-install` installs and bootstraps a `launchd` watcher
- `launchd/LaunchAgents/com.humoodagen.codex-ghostty-patch.plist` reruns the patcher at login and whenever Codex gets replaced under Homebrew or `fnm`
