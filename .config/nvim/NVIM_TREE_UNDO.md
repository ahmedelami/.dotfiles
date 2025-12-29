# NVIM_TREE_UNDO.md

## Overview

This config adds a per-project undo stack for NvimTree filesystem actions.
Use `u` inside the NvimTree window to undo the last action.

Actions recorded:
- Create (file or folder)
- Rename
- Delete (moves into a stash so it can be restored)

## Storage & Lifetime

- Stash path: `/Volumes/t7/.nvim-tree-undo/<project-id>/`
- Each project gets its own folder (hash of git root or cwd).
- Deleted files are moved into `items/` under that folder.
- Undo entries expire after 24 hours and are cleaned on every action/undo.

If `/Volumes/t7` is not available, undo is disabled for that session and
deletes fall back to the normal NvimTree trash behavior.

## Usage

- `u` in NvimTree: undo last filesystem action.
- `x` in NvimTree: delete (stashed so it can be undone).

## Troubleshooting

- If undo says "stack empty", there is nothing recorded yet.
- If undo fails after a delete, the stash item is missing or the target path
  already exists.
