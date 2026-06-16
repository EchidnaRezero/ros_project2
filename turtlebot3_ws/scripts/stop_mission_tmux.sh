#!/usr/bin/env bash
set -euo pipefail

SESSION="${SESSION:-rtree-mission}"
WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/turtlebot3_ws}"

if tmux has-session -t "$SESSION" 2>/dev/null; then
  SAFETY_STOP_ALL_ONCE=1 \
    SESSION="$SESSION" \
    WORKSPACE_DIR="$WORKSPACE_DIR" \
    "$WORKSPACE_DIR/scripts/safety_control.sh"
else
  echo "No tmux session found: $SESSION"
fi
