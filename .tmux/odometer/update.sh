#!/usr/bin/env bash

# Directory setup
DIR="$HOME/.tmux/odometer"
TOTAL_FILE="$DIR/total_seconds"
LAST_RUN_FILE="$DIR/last_run"
STATE_FILE="$DIR/current_state"
LOCK_DIR="$DIR/lock"

# Configuration
TIMEOUT_SECONDS=1

# --- SIMPLE DOT STATUS ---
# Active: Green Circle (Darker)
# Using standard bullet point.
ON="●"
OFF="●"

# Colors
C_ON="28"  # Dark Green
C_OFF="196" # Bright Red

if [ ! -f "$TOTAL_FILE" ]; then echo "0" > "$TOTAL_FILE"; fi
if [ ! -f "$LAST_RUN_FILE" ]; then date +%s > "$LAST_RUN_FILE"; fi
if [ ! -f "$STATE_FILE" ]; then echo "" > "$STATE_FILE"; fi

if [ -d "$LOCK_DIR" ]; then
    NOW=$(date +%s)
    LAST_MOD=$(stat -f %m "$LOCK_DIR" 2>/dev/null || echo "$NOW")
    AGE=$((NOW - LAST_MOD))
    if [ "$AGE" -gt 3 ]; then rmdir "$LOCK_DIR" 2>/dev/null; fi
fi

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
            ICON="#[fg=colour${C_ON},bg=default]${ON}"
        else
            ICON="#[fg=colour${C_OFF},bg=default]${OFF}"
        fi
    else
        ICON="#[fg=yellow]?"
    fi

    echo "${ICON}" > "$STATE_FILE"
    echo "$NOW" > "$LAST_RUN_FILE"
fi

TOTAL=$(cat "$TOTAL_FILE")
DISPLAY_ICON=$(cat "$STATE_FILE")

HOURS=$((TOTAL / 3600))
REMAINDER=$((TOTAL % 3600))
MINUTES=$((REMAINDER / 60))
SECONDS=$((REMAINDER % 60))

# Remove padding so time doesn't shift.
# Just append the icon with one space.
printf "#[fg=black,bold]%dh %dm %ds %s " "$HOURS" "$MINUTES" "$SECONDS" "$DISPLAY_ICON"
