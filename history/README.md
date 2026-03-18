# Shell history (sanitized, git-tracked)

The live shell history file is **not** tracked in git:

- macOS zsh: `~/.zsh_history`

Instead, we export a **sanitized snapshot** into this repo:

- `~/.dotfiles/history/shell_history_sanitized.txt`

## Export / update

Run:

```sh
~/.dotfiles/shell_history_export.py
```

This reads zsh history, drops lines that look like they contain secrets,
de-duplicates, and writes a bounded snapshot for backup/portability.

## Restore / seed on a new machine

From an interactive `zsh` session, replay the sanitized commands into history:

```sh
while IFS= read -r cmd; do
  print -sr -- "$cmd"
done < ~/.dotfiles/history/shell_history_sanitized.txt
```

## Safety note

The export script uses heuristics to exclude secret-looking commands, but it is
not perfect. Always review `shell_history_sanitized.txt` before committing.
