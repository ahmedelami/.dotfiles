# Tmux "Stealth Group" Architecture

## The Goal
To achieve **"Multiplayer Mode without Handcuffs"**:
1.  **Shared Content:** All terminal windows share the same list of windows/panes (typing in one mirrors to others if on the same window).
2.  **Independent Navigation:** Switching a window in one terminal does *not* force other terminals to switch.
3.  **Unified UI:** The system should look and feel like a single session (e.g., `[wiredl]`), hiding the underlying complexity of multiple "shadow" sessions.

## The Architecture

### 1. The Backend: Grouped Sessions
Standard `tmux attach` links a client to a **Session**. A Session has one "Current Window". If multiple clients attach to one Session, they share that "Current Window".

To decouple them, we use **Grouped Sessions**:
```bash
tmux new-session -t target_session
```
This creates a new "Shadow Session" that shares the *Windows* of the target, but has its own independent "Current Window" pointer.

### 2. The Frontend: "Stealth Mode" UI
Since Grouped Sessions technically create multiple sessions (e.g., `wiredl`, `wiredl-1`, `wiredl-2`), the UI becomes cluttered. We fix this by configuring tmux to "lie" to the user.

#### A. Status Bar Masking (.tmux.conf)
We configure the status bar to display the **Group Name** instead of the unique Session Name.
```tmux
# If part of a group, show Group Name. Otherwise, show Session Name.
set -g status-left "[#{?session_group,#{session_group},#S}] "
```
*Result:* `wiredl` and `wiredl-1` both display as `[wiredl]`.

#### B. Session List Filtering (.tmux.conf)
We override the standard `Ctrl+s` (choose-tree) command to hide the "Shadow Clones".
```tmux
# Filter: Show session IF (Name == Group) OR (Group is empty)
bind-key s choose-tree -s -f "#{||:#{==:#{session_name},#{session_group}},#{==:#{session_group},}}" -F "#{session_name}: #{session_windows} windows" -O name
```
*Result:* The list only shows the "Leader" session (`wiredl`). All `wiredl-X` clones are hidden.

### 3. Context Awareness (.zshrc)
When opening a new terminal (`Cmd+N`), the shell script determines which session to join using a **Most Recently Used (MRU)** strategy.

**Logic:**
1.  List all sessions sorted by `#{session_activity}` (timestamp).
2.  Pick the most recent one.
3.  Create a new Grouped Session linked to it.

*Result:* If you are working in `wiredl`, `Cmd+N` opens `wiredl`. If you switch to `komputer` and type, `Cmd+N` opens `komputer`.

## Relevant Files
- **`zsh/.zshrc`**: Contains the startup script for auto-grouping and MRU logic.
- **`.tmux.conf`**: Contains the `status-left` masking and `bind s` list filtering.
