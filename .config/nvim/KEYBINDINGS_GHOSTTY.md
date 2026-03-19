# KEYBINDINGS_GHOSTTY.md

This file exists to prevent re-doing hours of testing. The Ghostty transport
details below were verified repeatedly with `cat -v` in Ghostty and
`vim.fn.keytrans` in Neovim. The Neovim-side actions listed here describe the
current config. If something breaks, follow the procedure here instead of
re-running exploratory experiments.

## Verified behavior (Ghostty -> Neovim)

### Cmd+J / Cmd+K (forwarded to Neovim)

Ghostty sends these directly as the existing Ctrl bindings used by Neovim:

- Cmd+J => `^J` => Neovim sees `<C-j>`
- Cmd+K => `^K` => Neovim sees `<C-k>`

That lets Ghostty drive the Neovim Ctrl-key mappings from the Command key:

- Cmd+J => `fff.nvim` live grep (cwd)
- Cmd+K => `fff.nvim` find/create files (cwd)
- Press Cmd+K again inside the picker to close it (Ghostty sends another `<C-k>`)
- Press Cmd+J again inside the picker to close it (Ghostty sends another `<C-j>`)

### Cmd+E (file tree)

Ghostty sends:

- Cmd+E => `^[[19;3~`

Neovim often translates that to:

- Cmd+E => `<F56>`

Because Neovim may translate the sequence, the working fix is to map **both**
the raw sequence **and** the translated keycode. `Cmd+E` is the file tree
mapping. See:
`~/.dotfiles/.config/nvim/lua/humoodagen/remap.lua`.

NvimTree undo behavior is documented in `~/.dotfiles/.config/nvim/NVIM_TREE_UNDO.md`.

### Cmd+R (git UI)

Ghostty sends:

- Cmd+R => `^[[28~`

Neovim often translates that to:

- Cmd+R => `<F15>`

Because Neovim may translate the sequence, the working fix is to map **both**
the raw sequence **and** the translated keycode. `Cmd+R` is context-aware:
it toggles the git review sidecar from a real file buffer, opens or retargets a
3-pane review layout from NvimTree for the selected file, opens Diffview's
repo-wide changed-file panel from terminal buffers or non-file tree nodes, and
closes the git review sidecar when pressed inside that diff buffer. The Neovim
mapping works from normal, insert, visual, and terminal mode. In Neovide, the
same action is also mapped directly on `<D-r>`. See:
`~/.dotfiles/.config/nvim/lua/humoodagen/remap.lua`.

### Ghostty split navigation

Ghostty keeps split movement on:

- Cmd+H / Cmd+L => left / right
- Cmd+Alt+H/J/K/L => left / down / up / right

This leaves Cmd+J/K free for Neovim-only actions.

### Cmd+T / Cmd+1..9 (toggleterm tabs)

Ghostty maps `Cmd+T` to `\x02t` and `Cmd+1..9` to `\x02\x31`..`\x02\x39`. Neovim
uses those sequences (`<C-b>t` / `<C-b>1..9`) inside toggleterm buffers to
create and switch terminal tabs independently for bottom and right terminals.
This requires tmux to pass these keys through when the pane runs `nvim`
(see `~/.tmux.conf`).

Outside toggleterm buffers, `<C-b>1..9` (and `<D-1..9>` in Neovide) switches the
**bottom workspace**: it selects the bottom terminal tab and restores the main
file buffer associated with that workspace (or an empty placeholder buffer if
none has been set yet).

Tmux uses a per-pane flag (`@pane_is_nvim`) set by Neovim on `VimEnter` to keep
the passthrough working even when a toggleterm child process (e.g. `zsh`) is the
foreground job in that tmux pane (see `~/.config/nvim/lua/humoodagen/init.lua`).

## Other keybindings (Neovim-only)

### Ctrl+W / Ctrl+S (quarter-page scroll)

- Ctrl+W => scroll up by about a quarter screen, then center
- Ctrl+S => scroll down by about a quarter screen, then center

This intentionally overrides Neovim's default normal-mode `Ctrl+W` window
prefix.

### Cmd+J / Cmd+K (`fff.nvim`, via Ghostty -> Ctrl+J / Ctrl+K)

- Cmd+J => `fff.nvim` live grep (cwd)
- Press Cmd+J again inside the picker to close it (abort)

- Cmd+K => `fff.nvim` find/create files (cwd)
- Press Cmd+K again inside the picker to close it (toggle behavior)
- Inside the picker:
  - Enter and Tab accept the current file (or create the typed path if there are no matches)
  - Right arrow completes the query to the next path segment for the currently highlighted entry

### Cmd+R (git UI)

- Cmd+R on a real file => toggle the synchronized git review sidecar for that file
- Cmd+R in NvimTree => open Diffview's changed-file panel for the repo
- Cmd+R in NvimTree on a directory/non-file node => open Diffview's changed-file panel
- Cmd+R in terminal => open Diffview's changed-file panel
- Open a file from the Diffview changed-file panel => open a separate review tab with current file on the left and unified diff on the right
- Cmd+R in that review tab => return to the Diffview changed-file panel
- Cmd+R on the Diffview changed-file panel => close Diffview and return to the normal NvimTree tab
- Cmd+R in the git review diff sidecar => close the sidecar
- Works from normal, insert, visual, and terminal mode
- In Neovide, `Cmd+R` arrives as `<D-r>` instead of Ghostty's escape sequence

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

## Startup profiling (Ghostty -> Neovim)

Enable lightweight timeline logging for cold starts:

- `HUMOODAGEN_PERF=1 ghostty`

This writes a timestamped log to `vim.fn.stdpath("state")/humoodagen-perf.log`.
Open it from inside Neovim with `:HumoodagenPerfOpen`.

For deeper Neovim-only timings:

- `HUMOODAGEN_FAST_START=1 nvim --startuptime /tmp/nvim-startup.log +qa`
- In Neovim: `:Lazy profile` (plugin load/config breakdown)
