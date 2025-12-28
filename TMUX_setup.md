# Tmux "Stealth Group" Architecture

## The Goal
To achieve **"Multiplayer Mode without Handcuffs"**:
1.  **Shared Content:** All terminal windows share the same list of windows/panes. Typing in one mirrors to others *if and only if* they are on the same window.
2.  **Independent Navigation:** Switching a window in one terminal does *not* force other terminals to switch. You can work on Window 1 in Terminal A while Terminal B stays on Window 2.
3.  **Unified UI:** The system looks and feels like a single session (e.g., `[project-alpha]`), hiding the underlying complexity of multiple "shadow" sessions.

## The Architecture

### 1. The Backend: Grouped Sessions
Standard `tmux attach` links a client to a **Session**. If multiple clients attach to the *same* Session, they are forced to look at the same "Current Window".

To decouple them, we use **Grouped Sessions**:
```bash
tmux new-session -t target_session
```
This creates a new "Shadow Session" (e.g., `project-alpha-1`) that shares the *Windows* of the target (`project-alpha`), but has its own independent view.

### 2. The Frontend: "Stealth Mode" UI
Since Grouped Sessions technically create multiple sessions (e.g., `project-alpha`, `project-alpha-1`, `project-alpha-2`), the UI becomes cluttered. We fix this by configuring tmux to "mask" this complexity.

#### A. Status Bar Masking (.tmux.conf)
We configure the status bar to display the **Group Name** (the shared parent name) instead of the unique Session Name.
```tmux
# If part of a group, show Group Name. Otherwise, show Session Name.
set -g status-left "[#{?session_group,#{session_group},#S}] "
```
*Result:* `project-alpha` and `project-alpha-1` both display as `[project-alpha]`.

#### B. Session List Filtering (.tmux.conf)
We override the standard `Ctrl+s` (choose-tree) command to hide the "Shadow Clones".
```tmux
# Filter: Show session IF (Name == Group) OR (Group is empty/ungrouped)
bind-key s choose-tree -s -f "#{||:#{==:#{session_name},#{session_group}},#{==:#{session_group},}}" -F "#{session_name}: #{session_windows} windows" -O name
```
*Result:* The list only shows the "Leader" session (`project-alpha`). All `project-alpha-X` clones are hidden. Standalone sessions are still visible.

### 3. Context Awareness (.zshrc)
When opening a new terminal (`Cmd+N`), the shell script determines which session to join using a **Most Recently Used (MRU)** strategy.

**Logic:**
1.  List *all* sessions sorted by `#{session_activity}` (timestamp).
2.  Pick the most recent one (whatever it is called).
3.  Create a new Grouped Session linked to it.

*Result:* If you are working in `project-alpha`, `Cmd+N` opens `project-alpha`. If you switch to `backend-server` and type, `Cmd+N` opens `backend-server`. It adapts to your workflow instantly.

## Keybindings (Shortcuts)

| Shortcut | Action | Description |
| :--- | :--- | :--- |
| `Ctrl+b` `<` | **Move Left** | Swaps current window with the one to the left. |
| `Ctrl+b` `>` | **Move Right** | Swaps current window with the one to the right. |
| `Ctrl+b` `.` | **Swap #** | Prompts for a number. Swaps current window with that index. |

## Relevant Files
- **`zsh/.zshrc`**: Contains the startup script for auto-grouping and MRU logic.
- **`.tmux.conf`**: Contains the `status-left` masking, `bind s` list filtering, and window shortcuts.
