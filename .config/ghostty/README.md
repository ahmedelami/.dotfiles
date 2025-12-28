# Ghostty Configuration (Isolated Tmux-Pane Setup)

This setup is optimized for extreme performance and true isolation. Every Ghostty pane is its own independent workspace with its own set of tabs (managed by Tmux).

## Project Structure

- `config`: Ghostty configuration.
- `~/.tmux.conf`: Tmux configuration (High Contrast B&W).
- `README.md`: This file (Human + AI guide).

## The Workflow

1.  **Isolated Panes:** When you split the screen in Ghostty (`CTRL + ;` or `CTRL + '`), a completely new and independent Tmux session is started in that pane.
2.  **Tabs in a Pane:** Use `CTRL + T` to open a new tab *inside* the focused pane. These tabs are managed by Tmux and are unique to that pane.
3.  **Automatic Cleanup:** Closing a Ghostty pane automatically kills the associated Tmux session to prevent background resource leaks.
4.  **B&W Theme:** High-contrast black text on a pure white background. Active tabs/panes are highlighted in blue.

## Key Bindings

### Tabs (Local to the focused Pane)
- `CTRL + T`: New Tab (Tmux window).
- `CTRL + W`: Close current Tab (Tmux window).
- `CMD + 1..9`: Switch to Tab index 1..9.

### Panes (Ghostty Splits)
- `CTRL + ;`: Split Pane **Right** (new isolated Tmux session).
- `CTRL + '`: Split Pane **Down** (new isolated Tmux session).
- `CMD + H/J/K/L`: Switch focus between Ghostty Panes (macOS hide shortcut must be remapped).
- `CMD + SHIFT + H/J/K/L`: Resize current Pane.
- `CTRL + Z`: Toggle Pane Zoom.
- `CTRL + D`: Close **Ghostty Pane** (undoable with `CMD + Z`).
- `CTRL + SHIFT + W`: Kill **Entire Pane**.

### General
- `CMD + N`: New Ghostty Window (starts a fresh session).
- `CTRL + /`: Clear Screen (clears buffer and redraws prompt).
- `CMD + Z`: Undo close (reopen last closed tab/split/window).
- `CMD + SHIFT + Z`: Redo close.

## Design Philosophy

- **Quietness:** No confirmation prompts for closing tabs or panes.
- **Focus:** Unfocused panes are dimmed (`opacity = 0.6`).
- **Isolation:** Ghostty handles the splits; Tmux handles the tabs *within* those splits.

## AI Guidelines (AGENTS)

- **Keybinding Bridge:** Ghostty uses `text` actions to send `Ctrl-b` sequences to Tmux. Always use the `\x02` prefix for these (e.g., `\x02t` for new tab).
- **Session Management:** The Ghostty `command` uses a timestamped session name to ensure every split is truly independent.
- **Theme:** Foreground #000000, Background #ffffff. Active highlight #005eff.
