# KEYBINDINGS_GHOSTTY.md

This file exists to prevent re-doing hours of testing. The mappings and behaviors
below were verified repeatedly with `cat -v` in Ghostty and `vim.fn.keytrans` in
Neovim. They are not guesses. If something breaks, follow the procedure here
instead of re-running exploratory experiments.

## Verified behavior (Ghostty -> Neovim)

Ghostty sends raw escape sequences, but Neovim often translates them into
function keys (`<F55>`, etc). That translation is why mappings can "look right"
but still not work if you only bind the raw escape sequence.

### Cmd+H/J/K/L (pane focus)

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

### Cmd+D / Cmd+R (toggle terminals)

These have appeared as Shift+Function key sequences in Ghostty:
- Cmd+R => `^[[15;2~` (Shift+F5)
- Cmd+D => `^[[17;2~` (Shift+F6)

We keep multiple fallbacks in Neovim because Ghostty can change the translation
layer, and Neovim may show the same input as `<F15>/<F16>` or `<S-F5>/<S-F6>`
depending on terminal config. If they stop working, follow the steps below and
map the **actual** keycode Neovim receives.

## How to add or fix Cmd / Cmd+Shift keys

1) **Confirm what Ghostty sends**
   - In Ghostty: `cat -v`, press the key combo, note the escape sequence.

2) **Confirm what Neovim receives**
   - In Neovim: `:lua print(vim.fn.keytrans(vim.fn.getcharstr()))`
   - Press the key combo and record the printed key (often `<F..>`).

3) **Map both forms in Neovim**
   - Add keymaps for the raw escape sequence **and** the translated key.
   - Use `all_modes` if it should work from terminal mode too.
   - File to edit: `~/.dotfiles/.config/nvim/lua/humoodagen/lazy/toggleterm.lua`

4) **Verify the mapping**
   - `:verbose map <key>` to confirm the correct binding is active.

## Notes / gotchas

- Neovim will not load mappings if there is a Lua parse error. If mappings
  suddenly disappear, check `:messages` and ensure the config loads cleanly.
- Lua string escapes: `<C-\\>` must be written as `<C-\\\\>` in Lua strings.
  A single backslash can create a parse error.
