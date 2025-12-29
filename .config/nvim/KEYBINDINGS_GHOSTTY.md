# KEYBINDINGS_GHOSTTY.md

This file exists to prevent re-doing hours of testing. The mappings and behaviors
below were verified repeatedly with `cat -v` in Ghostty and `vim.fn.keytrans` in
Neovim. They are not guesses. If something breaks, follow the procedure here
instead of re-running exploratory experiments.

## Verified behavior (Ghostty -> Neovim)

Ghostty sends raw escape sequences, but Neovim often translates them into
function keys (`<F55>`, etc). That translation is why mappings can "look right"
but still not work if you only bind the raw escape sequence.

### Cmd+H/J/K/L (jump panes)

Neovim mappings:
- Cmd+H => focus filetree (NvimTree)
- Cmd+J => focus bottom terminal
- Cmd+K => focus main file pane
- Cmd+L => focus right terminal

If you're already focused on that pane, pressing the same key again hides it:
- Cmd+H (in tree) => hide tree
- Cmd+J (in bottom terminal) => hide bottom terminal
- Cmd+K (in main file pane) => toggle file-only mode (hide/restore tree + terminals)
- Cmd+L (in right terminal) => hide right terminal

Ghostty (shell, `cat -v`):
- Cmd+H => `^[[18;3~`
- Cmd+J => `^[[19;3~`
- Cmd+K => `^[[20;3~`
- Cmd+L => `^[[21;3~`

Neovim (`:lua print(vim.fn.keytrans(vim.fn.getcharstr()))`):
- Cmd+H => `<F55>`
- Cmd+J => `<F56>`
- Cmd+K => `<F57>`
- Cmd+L => `<F58>`

Because Neovim translates the sequence, the working fix was to map **both**
the raw sequence **and** the translated keycodes. See:
`~/.dotfiles/.config/nvim/lua/humoodagen/remap.lua`.

NvimTree undo behavior is documented in `~/.dotfiles/.config/nvim/NVIM_TREE_UNDO.md`.

### Cmd+Shift+H/J/K/L (toggle panes)

Neovim mappings:
- Cmd+Shift+H => toggle filetree (no focus)
- Cmd+Shift+J => toggle bottom terminal
- Cmd+Shift+K => toggle file-only mode (hide/restore tree + terminals)
- Cmd+Shift+L => toggle right terminal

Ghostty (shell, `cat -v`):
- Cmd+Shift+H => `^[[18;2~`
- Cmd+Shift+J => `^[[19;2~`
- Cmd+Shift+K => `^[[20;2~`
- Cmd+Shift+L => `^[[21;2~`

Neovim:
- Cmd+Shift+H => `<F19>`
- Cmd+Shift+J => `<F20>`
- Cmd+Shift+K => `<F21>`
- Cmd+Shift+L => `<F22>`

### Cmd+Ctrl+H/J/K/L (resize splits)

These resize the active split, directionally, from any pane (tree, file, bottom
terminal, right terminal).

Ghostty (shell, `cat -v`):
- Cmd+Ctrl+H => `^[[18;5~`
- Cmd+Ctrl+J => `^[[19;5~`
- Cmd+Ctrl+K => `^[[20;5~`
- Cmd+Ctrl+L => `^[[21;5~`

Neovim:
- Cmd+Ctrl+H => `<F31>`
- Cmd+Ctrl+J => `<F32>`
- Cmd+Ctrl+K => `<F33>`
- Cmd+Ctrl+L => `<F34>`

All of the above are mapped (raw + translated) in:
`~/.config/nvim/lua/humoodagen/remap.lua`.

### Cmd+T / Cmd+1..9 (toggleterm tabs)

Ghostty maps `Cmd+T` to `\x02t` and `Cmd+1..9` to `\x021`..`\x029`. Neovim uses
those sequences (`<C-b>t` / `<C-b>1..9`) inside toggleterm buffers to create and
switch terminal tabs independently for bottom and right terminals.
This requires tmux to pass these keys through when the pane runs `nvim`
(see `~/.tmux.conf`).

## Other keybindings (Neovim-only)

### Ctrl+K (fzf file search)

- Ctrl+K => `fzf-lua` find/create files (cwd)
- Press Ctrl+K again inside the picker to close it (toggle behavior)
- Inside the picker:
  - Tab behaves like Enter (accept/open; creates the typed path if there are no matches)
  - Right arrow completes the query to the next path segment for the currently highlighted entry

### Tab (completion)

- Insert completion (`nvim-cmp`): Tab confirms the current completion (use arrows or Ctrl+N/P to navigate)

## How to add or fix Cmd / Cmd+Shift keys

1) **Confirm what Ghostty sends**
   - In Ghostty: `cat -v`, press the key combo, note the escape sequence.

2) **Confirm what Neovim receives**
   - In Neovim: `:lua print(vim.fn.keytrans(vim.fn.getcharstr()))`
   - Press the key combo and record the printed key (often `<F..>`).

3) **Map both forms in Neovim**
   - Add keymaps for the raw escape sequence **and** the translated key.
   - Use `all_modes` if it should work from terminal mode too.
   - File to edit: `~/.config/nvim/lua/humoodagen/remap.lua`

4) **Verify the mapping**
   - `:verbose map <key>` to confirm the correct binding is active.

## Notes / gotchas

- Neovim will not load mappings if there is a Lua parse error. If mappings
  suddenly disappear, check `:messages` and ensure the config loads cleanly.
- Lua string escapes: `<C-\\>` must be written as `<C-\\\\>` in Lua strings.
  A single backslash can create a parse error.
