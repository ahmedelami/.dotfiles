# Shell history (sanitized, git-tracked)

The live shared history file is **not** tracked in git:

- macOS: `~/Library/Application Support/nushell/history.txt`

Instead, we export a **sanitized snapshot** into this repo:

- `~/.dotfiles/history/shell_history_sanitized.txt`

## Export / update

Run:

```sh
~/.dotfiles/shell_history_export.py
```

This reads the shared history, drops lines that look like they contain secrets,
de-duplicates, and writes a bounded snapshot for backup/portability.

## Restore / seed on a new machine

Append the sanitized snapshot into the shared history file:

```sh
cat ~/.dotfiles/history/shell_history_sanitized.txt >> "$HOME/Library/Application Support/nushell/history.txt"
```

Then open a new `nu` / `zsh` session so suggestions can pick it up.

## Safety note

The export script uses heuristics to exclude secret-looking commands, but it is
not perfect. Always review `shell_history_sanitized.txt` before committing.

