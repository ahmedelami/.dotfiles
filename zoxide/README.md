# zoxide (backup + restore)

zoxide stores its database in a platform-specific data directory (on macOS,
typically `~/Library/Application Support/zoxide/db.zo`).

Tracking the binary DB in git is possible, but it churns a lot and is hard to
merge. Instead, this folder lets you track a text export of your directory
scores, and re-seed a fresh machine.

## Export (update tracked snapshot)

```sh
~/.dotfiles/zoxide/export.sh
```

This writes `~/.dotfiles/zoxide/entries.tsv` (score + path).

## Import (seed zoxide DB)

```sh
~/.dotfiles/zoxide/import.sh
```

Options:

- `--existing-only` only imports directories that exist on disk
- `--force` also imports entries already present (will increase their score)

