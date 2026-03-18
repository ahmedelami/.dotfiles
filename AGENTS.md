# Repository Guidelines

## Project Structure & Ownership

- This repository's single VCS root is `.dotfiles/`. Run `git` and `jj` from here.
- Managed XDG config directories live under `.config/`:
  - `.config/nvim`
  - `.config/ghostty`
  - `.config/jj`
  - `.config/git`
  - `.config/starship.toml`
- `~/.config` is a normal directory. Only selected subdirectories are symlinked back into this repo. Do not assume the whole `~/.config` tree is repo-managed.
- Shell and terminal files live at the repo root and under `zsh/`, `.tmux/`, and `bin/`.
- Small utilities and automation scripts live at the repo root, `bin/`, `launchd/`, and `history/`.
- If you are working inside `.config/nvim`, follow the more specific instructions in `.config/nvim/AGENTS.md`.

## Development Workflow

- Use `git status` or `jj status` from `.dotfiles/` to review changes.
- Keep changes scoped by tool or concern. Avoid mixing Neovim, Ghostty, shell, and system-script edits in one commit unless they are part of the same feature.
- Before removing tracked files under `.config/`, confirm they are intentionally no longer repo-managed rather than accidentally deleted from the live machine.
- Do not recreate nested Git or Jujutsu repos under `.config/` or any subdirectory.

## Editing Conventions

- Prefer small, focused edits over broad rewrites.
- Keep filenames lowercase unless an existing file already establishes a different convention.
- Preserve executable bits on scripts in `bin/` and repo-root helper scripts.
- Avoid introducing machine-specific paths unless the file is already explicitly machine-local. Prefer `$HOME`, XDG paths, or existing repo conventions.
- Do not commit app-generated caches, backups, or transient state unless this repo already intentionally tracks them.

## Validation

- Neovim changes: `nvim --headless "+qa"`
- Jujutsu config changes: `jj status`
- Shell or script changes: run the narrowest relevant command or script directly when practical.
- For repo-structure changes, verify both `git rev-parse --show-toplevel` and `jj root` return the `.dotfiles` path from affected subdirectories.

## Commit Guidelines

- Prefer scoped commit subjects such as `feat:`, `fix:`, `docs:`, `chore:`, or `improve:`.
- Keep commits reviewable and logically grouped.
- Surface conflicts explicitly instead of silently picking a side when user intent is unclear.

## Safety Notes

- Check `.gitignore` before adding new generated outputs or local artifacts.
- Treat `.config/ghostty/config`, `.config/jj/config.toml`, and shell startup files as high-impact: bad edits there affect the active terminal environment immediately.
- Never store secrets or auth tokens in tracked files. Prefer local untracked files or existing ignored paths.
