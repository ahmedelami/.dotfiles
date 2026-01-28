# KEYBINDINGS_TERMINAL_APP.md

macOS `Terminal.app` does not forward `Cmd+…` keystrokes into the terminal PTY by
default (many are consumed by menu shortcuts like Hide/Clear). Neovim therefore
won't see `<D-h>`, `<D-j>`, etc.

This Neovim config already maps terminal-friendly escape sequences to the same
pane jump behavior used by Neovide:
`~/.dotfiles/.config/nvim/lua/humoodagen/remap.lua`.

## Recommended: Karabiner-Elements (works even for Cmd+H/Cmd+K)

This avoids fighting Terminal.app / macOS menu shortcuts. It maps (Terminal.app
only):

- Cmd+H → Ctrl+B then `h`
- Cmd+J → Ctrl+B then `j`
- Cmd+K → Ctrl+B then `k`
- Cmd+L → Ctrl+B then `l`

Those sequences are already mapped in Neovim here:
`~/.dotfiles/.config/nvim/lua/humoodagen/remap.lua`.

Karabiner rule file:
`~/.config/karabiner/assets/complex_modifications/terminal_cmd_hjkl_nvim_panes.json`

Enable it in Karabiner-Elements:
Complex Modifications → Add rule → “Terminal.app: Cmd+H/J/K/L → Ctrl+B then h/j/k/l (Neovim panes)”.

## Make Cmd+H/J/K/L work in Terminal.app

Run:

`~/.dotfiles/.config/nvim/bin/terminalapp-cmd-hjkl`

It updates your default Terminal profile (`Basic` by default) so these keys send:

- Cmd+H → `\033[18;3~`
- Cmd+J → `\033[19;3~`
- Cmd+K → `\033[20;3~`
- Cmd+L → `\033[21;3~`

Then quit and relaunch Terminal.app.

If Cmd+H still hides Terminal (or Cmd+K still clears), change those app menu
shortcuts first in:

System Settings → Keyboard → Keyboard Shortcuts → App Shortcuts → Terminal

## Undo

Run:

`~/.dotfiles/.config/nvim/bin/terminalapp-cmd-hjkl --remove`
