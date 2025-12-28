# Repository Guidelines

## Project Structure & Module Organization

- `init.lua` is the Neovim entrypoint. It silences specific deprecation warnings and loads the main `humoodagen` module.
- `lua/humoodagen/` contains the configuration modules:
  - `init.lua`: Loads `set`, `remap`, and `lazy_init`. It also defines global autocmds (highlight yank, strip whitespace) and **fallback LSP keybindings** (via `LspAttach`).
  - `set.lua`: Core editor options (tabs/spaces, UI defaults, undodir, etc.).
  - `remap.lua`: Keymaps and leader mappings.
  - `lazy_init.lua`: Bootstraps `lazy.nvim` and loads plugin specs from `humoodagen.lazy`.
- `lua/humoodagen/lazy/` holds plugin specifications. Use a **strict one plugin/group per file** convention (e.g., `harpoon2.lua`, `lsp.lua`).
- `lazy-lock.json` pins plugin versions for reproducible installs.

## Build, Test, and Development Commands

This repo is a Neovim config (no separate build step).

- Launch Neovim using this config: `nvim`
- Sync/update plugins (from inside Neovim): `:Lazy sync` or `:Lazy update`
- Non-interactive plugin sync (useful for CI/local sanity): `nvim --headless "+Lazy! sync" +qa`
- Quick health check: `nvim --headless "+checkhealth" +qa`

## Coding Style & Naming Conventions

- Language: Lua (Neovim runtime).
- Indentation: **4 spaces**; prefer `vim.opt.*` for options and `vim.keymap.set` for mappings.
- Suppress Flashes: Keep `vim.g.deprecation_warnings = false` and `change_detection = { notify = false }` to prevent UI noise.
- Module naming: keep files lowercase and require paths stable (e.g., `require("humoodagen.set")`).
- Prefer small, focused modules under `lua/humoodagen/` rather than one large `init.lua`.
- File paths: Prefer `os.getenv("HOME") .. "/.vim/undodir"` for undo history and `vim.fn.stdpath` for other data.
- **Autocmds:** Define global behavior (like LSP fallback keys or whitespace stripping) in `lua/humoodagen/init.lua`.

## Testing Guidelines

No automated test suite is currently set up. Validate changes by:

- Starting Neovim and checking `:messages` for errors.
- Running `nvim --headless "+qa"` to ensure the config loads cleanly.

## Commit & Pull Request Guidelines

- Commit subjects commonly use a scoped prefix: `feat:`, `fix:`, `docs:`, `upgrade:`, `improve:`.
- Keep commits small and focused (one feature/fix per commit when practical).
- PRs should include: a short summary, what changed (paths/modules), and screenshots/gifs for UI/UX changes (themes, statusline, keymaps).

## Theme & UI

- **Colorscheme:** Using `vscode.nvim` (light mode) to match the VS Code light syntax highlighting.
- **Background:** Transparent background is enabled.
- **NvimTree:** Uses bold blue highlights for folders to ensure high visibility.

## Security & Configuration Tips

- Plugin sources are pulled via `lazy.nvim`; keep `lazy-lock.json` updated when changing plugins.
- Avoid committing machine-specific paths; prefer `vim.fn.stdpath(...)`, `$HOME`, or environment variables.
