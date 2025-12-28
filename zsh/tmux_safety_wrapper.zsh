# Tmux Safe Attach Wrapper
# Prevents accidental double-attachment to the same session, which links views.
# Automatically creates a grouped clone instead.

tmux() {
  local cmd="$1"
  local target=""
  
  # If running specific attach commands...
  if [[ "$cmd" == "attach" || "$cmd" == "attach-session" || "$cmd" == "a" || "$cmd" == "at" ]]; then
    
    # Parse arguments to find the target (-t)
    local args=("$@")
    for ((i=1; i<${#args[@]}; i++)); do
      if [[ "${args[$i]}" == "-t" ]]; then
        target="${args[$i+1]}"
        break
      fi
    done
    
    # If no target specified, use the most recent session
    if [[ -z "$target" ]]; then
       target=$(command tmux list-sessions -F "#{session_last_attached} #{session_name}" 2>/dev/null | sort -nr | head -n 1 | awk '{print $2}')
    fi

    # Check if the target is ALREADY attached
    if [[ -n "$target" ]]; then
        local is_attached=$(command tmux list-sessions -F "#{session_name} #{session_attached}" 2>/dev/null | awk -v t="$target" '$1 == t {print $2}')
        
        if [[ "$is_attached" == "1" ]]; then
            echo "⚠️  Session '$target' is already attached."
            echo "Creating an independent clone to prevent view syncing..."
            command tmux new-session -t "$target" \; set-option destroy-unattached on
            return
        fi
    fi
  fi

  # Pass through to the real tmux for everything else
  command tmux "$@"
}
