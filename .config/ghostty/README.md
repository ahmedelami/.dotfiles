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
- `CMD + T`: New Tab (Tmux window); when inside Neovim, tmux passes it through to toggleterm tabs.
- `CTRL + W`: Close current Tab (Tmux window).
- `CMD + 1..9`: Switch to Tab index 1..9; when inside Neovim, tmux passes it through to toggleterm tabs.
- `CMD + R`: Toggle Neovim right terminal (pass-through).
- `CMD + B`: Toggle Neovim bottom terminal (pass-through).
- `CMD + D`: Toggle Neovim bottom terminal (pass-through).

### Panes (Ghostty Splits)
- `CMD + ;`: Split Pane **Right** (new isolated Tmux session).
- `CMD + '`: Split Pane **Down** (new isolated Tmux session).
- `CMD + H/J/K/L`: Focus Neovim panels/splits (pass-through).
- `CMD + SHIFT + H/J/K/L`: Resize Neovim splits (pass-through).
- `CMD + SHIFT + Up/Down`: Resize Neovim splits (pass-through).
- `CTRL + Z`: Toggle Pane Zoom.
- `CTRL + D`: Pass through to the terminal (e.g., exit shell/Neovim terminal). Ghostty will close the pane if the shell exits.
- `CTRL + SHIFT + W`: Kill **Entire Pane**.

### General
- `CMD + N`: New Ghostty Window (starts a fresh session).
- `CTRL + /`: Clear Screen (clears buffer and redraws prompt).
- `CMD + Z`: Undo close (reopen last closed tab/split/window).
- `CMD + SHIFT + Z`: Redo close.

## Neovim Cmd Key Passthrough

Some macOS Cmd shortcuts never reach terminal apps. This setup forces `CMD + R` / `CMD + B` / `CMD + D` into the terminal so Neovim can toggle its terminals.

- Ghostty sends F15/F16 (`\x1b[28~` / `\x1b[29~`) via `super+r` and `super+b`.
- Ghostty sends `CMD+H/J/K/L` as `\x1b[18;3~`..`\x1b[21;3~` for Neovim focus.
- Ghostty sends xterm-style Shift+Function sequences (`\x1b[18;2~`..`\x1b[24;2~`) via `super+shift+h/j/k/l` and `super+shift+up/down`.
- Ghostty sends `CMD+T` as `\x02t` so Neovim can create toggleterm tabs.
- Tmux conditionally passes `CMD+T` and `CMD+1..9` to Neovim when the pane runs `nvim`.
- On macOS, Ghostty may still emit Shift+F5/Shift+F7 (`^[[15;2~` / `^[[17;2~`). Neovim has fallbacks for these in `~/.config/nvim/lua/humoodagen/lazy/toggleterm.lua`.
- Verify what Ghostty sends with `cat -v`, then press the keys.
- If the sequences change, update the Neovim mappings to match.

## Design Philosophy

- **Quietness:** No confirmation prompts for closing tabs or panes.
- **Focus:** Unfocused panes are dimmed (`opacity = 0.6`).
- **Isolation:** Ghostty handles the splits; Tmux handles the tabs *within* those splits.

## AI Guidelines (AGENTS)

- **Keybinding Bridge:** Ghostty uses `text` actions to send `Ctrl-b` sequences to Tmux. Always use the `\x02` prefix for these (e.g., `\x02t` for new tab).
- **Session Management:** The Ghostty `command` uses a timestamped session name to ensure every split is truly independent.
- **Theme:** Foreground #000000, Background #ffffff. Active highlight #005eff.
