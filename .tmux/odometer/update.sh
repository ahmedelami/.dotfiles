#!/usr/bin/env bash

# Directory setup
DIR="$HOME/.tmux/odometer"
TOTAL_FILE="$DIR/total_seconds"
LAST_RUN_FILE="$DIR/last_run"
STATE_FILE="$DIR/current_state"
LOCK_DIR="$DIR/lock"

# Configuration
TIMEOUT_SECONDS=1

# --- TEXT COLOR STATUS ---
# Active: Dark Green (28)
C_ON="28"
# Idle: Bright Red (196)
C_OFF="196"

# Initialize
if [ ! -f "$TOTAL_FILE" ]; then echo "0" > "$TOTAL_FILE"; fi
if [ ! -f "$LAST_RUN_FILE" ]; then date +%s > "$LAST_RUN_FILE"; fi
if [ ! -f "$STATE_FILE" ]; then echo "" > "$STATE_FILE"; fi

# Self-Heal Lock
if [ -d "$LOCK_DIR" ]; then
    NOW=$(date +%s)
    LAST_MOD=$(stat -f %m "$LOCK_DIR" 2>/dev/null || echo "$NOW")
    AGE=$((NOW - LAST_MOD))
    if [ "$AGE" -gt 3 ]; then rmdir "$LOCK_DIR" 2>/dev/null; fi
fi

# Update Logic
if mkdir "$LOCK_DIR" 2>/dev/null; then
    trap 'rmdir "$LOCK_DIR"' EXIT
    NOW=$(date +%s)
    LAST=$(cat "$LAST_RUN_FILE")
    TOTAL=$(cat "$TOTAL_FILE")
    DELTA=$((NOW - LAST))

    if [ "$DELTA" -gt 0 ] && [ "$DELTA" -lt 10 ]; then
        LAST_ACTIVITY_TS=$(tmux list-clients -F "#{client_activity}" 2>/dev/null | sort -nr | head -n 1)
        if [ -z "$LAST_ACTIVITY_TS" ]; then LAST_ACTIVITY_TS=0; fi
        IDLE_TIME=$((NOW - LAST_ACTIVITY_TS))
        if [ "$IDLE_TIME" -lt 0 ]; then IDLE_TIME=0; fi

        if [ "$IDLE_TIME" -lt "$TIMEOUT_SECONDS" ]; then
            TOTAL=$((TOTAL + DELTA))
            echo "$TOTAL" > "$TOTAL_FILE"
            
            # ACTIVE: Set Color to Green
            STYLE="#[fg=colour${C_ON},bold]"
        else
            # IDLE: Set Color to Red
            STYLE="#[fg=colour${C_OFF},bold]"
        fi
    else
        # LAG: Treat as Idle (Red) to avoid flashing yellow
        STYLE="#[fg=colour${C_OFF},bold]"
    fi

    echo "${STYLE}" > "$STATE_FILE"
    echo "$NOW" > "$LAST_RUN_FILE"
fi

TOTAL=$(cat "$TOTAL_FILE")
STYLE=$(cat "$STATE_FILE")

HOURS=$((TOTAL / 3600))
REMAINDER=$((TOTAL % 3600))
MINUTES=$((REMAINDER / 60))
SECONDS=$((REMAINDER % 60))

# Print the Time directly in the calculated color.
# Note the trailing space.
printf "%s%dh %dm %ds " "$STYLE" "$HOURS" "$MINUTES" "$SECONDS"