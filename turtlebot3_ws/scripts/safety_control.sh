#!/usr/bin/env bash
set -euo pipefail

SESSION="${SESSION:-rtree-mission}"
WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/turtlebot3_ws}"
ROS_DISTRO_SETUP="${ROS_DISTRO_SETUP:-/opt/ros/galactic/setup.bash}"
WORKSPACE_SETUP="${WORKSPACE_SETUP:-$WORKSPACE_DIR/install/setup.bash}"
ZERO_COUNT="${ZERO_COUNT:-20}"
ZERO_INTERVAL="${ZERO_INTERVAL:-0.05}"
STOP_SETTLE_SECONDS="${STOP_SETTLE_SECONDS:-0.5}"

source_ros() {
  cd "$WORKSPACE_DIR"
  set +u
  # shellcheck disable=SC1090
  source "$ROS_DISTRO_SETUP"
  # shellcheck disable=SC1090
  source "$WORKSPACE_SETUP"
  set -u
}

publish_zero_cmd_vel() {
  source_ros
  echo "Publishing zero /cmd_vel ${ZERO_COUNT} times..."
  python3 - "$ZERO_COUNT" "$ZERO_INTERVAL" <<'PY' || true
import sys
import time

import rclpy
from geometry_msgs.msg import Twist

count = int(sys.argv[1])
interval = float(sys.argv[2])

rclpy.init(args=None)
node = rclpy.create_node('rtree_safety_zero_cmd_vel')
publisher = node.create_publisher(Twist, '/cmd_vel', 10)
message = Twist()

end_time = time.time() + 0.2
while time.time() < end_time:
    rclpy.spin_once(node, timeout_sec=0.01)

for _ in range(count):
    publisher.publish(message)
    rclpy.spin_once(node, timeout_sec=0.0)
    time.sleep(interval)

node.destroy_node()
rclpy.shutdown()
PY
  echo "Zero /cmd_vel sent."
}

send_ctrl_c() {
  local window_name="$1"
  if tmux list-windows -t "$SESSION" -F '#W' 2>/dev/null | grep -qx "$window_name"; then
    tmux send-keys -t "$SESSION:$window_name" C-c
    echo "Sent Ctrl-C to tmux window: $window_name"
  else
    echo "Window not found, skipped: $window_name"
  fi
}

stop_motion_stack() {
  send_ctrl_c nav
  sleep "$STOP_SETTLE_SECONDS"
  publish_zero_cmd_vel
  sleep "$STOP_SETTLE_SECONDS"
  publish_zero_cmd_vel
  send_ctrl_c bringup
  echo
  echo "Motion stack stop requested. bridge/mission/vision/manipulator windows are still alive."
}

stop_all() {
  echo "Stopping motion sources before closing mission tmux..."
  send_ctrl_c nav
  sleep "$STOP_SETTLE_SECONDS"
  publish_zero_cmd_vel
  sleep "$STOP_SETTLE_SECONDS"
  publish_zero_cmd_vel
  send_ctrl_c bringup
  sleep "$STOP_SETTLE_SECONDS"
  echo "Stopping all mission tmux windows..."
  tmux kill-session -t "$SESSION" 2>/dev/null || true
}

if [ "${SAFETY_STOP_ALL_ONCE:-0}" = "1" ]; then
  stop_all
  exit 0
fi

while true; do
  clear
  cat <<EOF
=== SAFETY CONTROL ===

1) Stop bringup/nav motion
2) Stop all mission tmux
q) Quit this safety menu only

Session: $SESSION
EOF
  printf '\nSelect: '
  read -r choice

  case "$choice" in
    1)
      stop_motion_stack
      printf '\nPress Enter to return to menu...'
      read -r _
      ;;
    2)
      stop_all
      exit 0
      ;;
    q|Q)
      exit 0
      ;;
    *)
      echo "Unknown choice: $choice"
      sleep 1
      ;;
  esac
done
