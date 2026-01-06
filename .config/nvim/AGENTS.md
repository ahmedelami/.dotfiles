# Repository Guidelines

This directory contains the Neovim configuration used in the dotfiles repo. Keep startup reliable and plugin versions reproducible via `lazy-lock.json`.

## Project Structure & Module Organization

- `init.lua` bootstraps the config and loads `lua/humoodagen/`.
- `lua/humoodagen/` holds core modules (settings, keymaps, commands, autocommands).
- `lua/humoodagen/lazy/` contains `lazy.nvim` plugin specs/config (generally one file per feature/plugin).
- `lazy-lock.json` pins plugin revisions (generated/updated by `lazy.nvim`).
- `*.md` files are user notes and workflow docs (e.g., `KEYBINDINGS_GHOSTTY.md`, `NVIM_TREE_UNDO.md`).

## Build, Test, and Development Commands

- `nvim` starts Neovim with this config (first run bootstraps `lazy.nvim`).
- `nvim --headless "+Lazy! sync" +qa` installs/updates plugins non-interactively.
- `nvim --headless "+checkhealth" +qa` runs quick health checks for providers/LSP/etc.
- `NVIM_APPNAME=nvim-dev nvim` runs an isolated profile (copy/symlink this folder to `~/.config/nvim-dev` first).

## Coding Style & Naming Conventions

- Lua: match surrounding file style; prefer 2-space indentation in `lua/humoodagen/lazy/*.lua`; avoid tabs.
- Add new config modules under `lua/humoodagen/` and wire them from `lua/humoodagen/init.lua`.
- Keep diffs focused; avoid drive-by reformatting and don’t commit OS/editor artifacts (e.g., `.DS_Store`) or secrets.

## Testing Guidelines

There’s no automated test suite in this directory. Validate changes by running `:Lazy sync`, restarting Neovim, checking `:messages`, and using `:checkhealth` after larger edits (LSP, treesitter, terminal integration).

## Commit & Pull Request Guidelines

- Follow the style used in history: `feat(nvim): ...`, `fix: ...`, `docs: ...`, `chore: ...` (imperative; add a scope when helpful).
- PRs should explain intent, list impacted modules/plugins, and call out `lazy-lock.json` changes; include a screenshot/GIF for UI- or keymap-heavy changes.
