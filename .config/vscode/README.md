# VS Code Config

This folder is the repo-owned source of truth for VS Code user config:

- `settings.jsonc`
- `keybindings.jsonc`

The files here are a pragmatic VSCodeVim translation of the Neovim config under
`.config/nvim`, not a literal reuse of the Lua config.

## Apply to a live profile

Use:

```sh
bin/vscode-user-sync
```

By default that targets stable VS Code on macOS:

- `~/Library/Application Support/Code/User/settings.json`
- `~/Library/Application Support/Code/User/keybindings.json`

Other supported profiles:

```sh
bin/vscode-user-sync insiders
bin/vscode-user-sync codium
bin/vscode-user-sync windsurf
```

## What translates well

- leader key, search behavior, yank highlight, surround, and easymotion toggles
- centered scrolling and search result recentering
- `fzf-lua` style file and grep shortcuts mapped to Quick Open and Find in Files
- LSP navigation and actions mapped to native VS Code commands
- explorer, SCM, notifications, and problems-panel shortcuts mapped to native UI

## What is only approximate

- wrapped-line `j` and `k` use `keybindings.json` and lose exact `10j` / `10k`
  behavior from the Neovim expr mapping
- `<C-c>` closes the current VS Code window instead of running Neovim `:qa`
- `<C-t>`, `Cmd+;`, and `Cmd+E` reveal the active file in Explorer instead of
  creating a new tab and opening `nvim-tree` in-place
- `Trouble`, `Oil`, `Noice`, and Git review map to native VS Code surfaces, not
  the same plugin interfaces

## Not covered yet

- Harpoon slots and menu behavior
- `nvim-tree`-specific file operations and inline create flows
- toggleterm, tmux, and Ghostty passthrough behavior
- exact `flash.nvim` motion behavior on `s`
- `<leader>x` for `chmod +x %`
- `<C-f>` tmux-sessionizer
- Ctrl+1..9 tab navigation

If you want your actual Neovim plugins and Lua mappings to run inside VS Code,
use `vscode-neovim` instead of VSCodeVim.
