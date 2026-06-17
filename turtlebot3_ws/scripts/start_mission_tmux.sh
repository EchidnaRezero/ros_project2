#!/usr/bin/env bash
set -eo pipefail

SESSION="${SESSION:-rtree-mission}"
WS_PORT="${WS_PORT:-3000}"
WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/turtlebot3_ws}"
ROS_DISTRO_SETUP="${ROS_DISTRO_SETUP:-/opt/ros/galactic/setup.bash}"
WORKSPACE_SETUP="${WORKSPACE_SETUP:-$WORKSPACE_DIR/install/setup.bash}"
TURTLEBOT3_MODEL="${TURTLEBOT3_MODEL:-waffle}"
MAP_FILE="${MAP_FILE:-$WORKSPACE_DIR/maps/map_6f.yaml}"
URL_SUMMARY_FILE="${URL_SUMMARY_FILE:-$WORKSPACE_DIR/mission_urls.txt}"
GITHUB_PAGES_URL="${GITHUB_PAGES_URL:-https://hisameogasahara.github.io/ros_webclient/}"
GITHUB_PAGES_DEBUG_URL="${GITHUB_PAGES_DEBUG_URL:-https://hisameogasahara.github.io/ros_webclient/debug.html}"
GUI_DISPLAY="${GUI_DISPLAY:-${DISPLAY:-:0}}"
GUI_RUNTIME_DIR="${GUI_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-/run/user/$(id -u)}}"
GUI_DBUS="${GUI_DBUS:-${DBUS_SESSION_BUS_ADDRESS:-unix:path=${GUI_RUNTIME_DIR}/bus}}"
GUI_XAUTHORITY="${GUI_XAUTHORITY:-${XAUTHORITY:-}}"

USE_CLOUDFLARE=1
DEBUG_ECHO=1
KILL_ONLY=0
AUTO_OPEN_TERMINAL="${AUTO_OPEN_TERMINAL:-1}"

if [ -z "$GUI_XAUTHORITY" ]; then
  if [ -f "$HOME/.Xauthority" ]; then
    GUI_XAUTHORITY="$HOME/.Xauthority"
  elif [ -f "${GUI_RUNTIME_DIR}/gdm/Xauthority" ]; then
    GUI_XAUTHORITY="${GUI_RUNTIME_DIR}/gdm/Xauthority"
  fi
fi

usage() {
  cat <<EOF
Usage: $(basename "$0") [--no-cloudflare] [--debug-echo] [--kill]

Starts the rtree mission stack in a tmux session named "$SESSION".
EOF
}

open_visible_terminal() {
  [ "$AUTO_OPEN_TERMINAL" = "1" ] || return 0
  command -v gnome-terminal >/dev/null 2>&1 || return 0

  env \
    DISPLAY="$GUI_DISPLAY" \
    XDG_RUNTIME_DIR="$GUI_RUNTIME_DIR" \
    DBUS_SESSION_BUS_ADDRESS="$GUI_DBUS" \
    XAUTHORITY="$GUI_XAUTHORITY" \
    gnome-terminal --title "rtree-mission" -- bash -lc "tmux attach -t $(printf '%q' "$SESSION")" \
    >/tmp/rtree-mission-terminal.log 2>&1 &
}

open_safety_terminal() {
  [ "$AUTO_OPEN_TERMINAL" = "1" ] || return 0
  command -v gnome-terminal >/dev/null 2>&1 || return 0

  env \
    DISPLAY="$GUI_DISPLAY" \
    XDG_RUNTIME_DIR="$GUI_RUNTIME_DIR" \
    DBUS_SESSION_BUS_ADDRESS="$GUI_DBUS" \
    XAUTHORITY="$GUI_XAUTHORITY" \
    SESSION="$SESSION" \
    WORKSPACE_DIR="$WORKSPACE_DIR" \
    ROS_DISTRO_SETUP="$ROS_DISTRO_SETUP" \
    WORKSPACE_SETUP="$WORKSPACE_SETUP" \
    gnome-terminal --title "rtree-safety" -- bash -lc '"$WORKSPACE_DIR/scripts/safety_control.sh"' \
    >/tmp/rtree-safety-terminal.log 2>&1 &
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --no-cloudflare)
      USE_CLOUDFLARE=0
      ;;
    --debug-echo)
      DEBUG_ECHO=1
      ;;
    --kill)
      KILL_ONLY=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux is not installed. Install it first: sudo apt install -y tmux" >&2
  exit 1
fi

if [ "$KILL_ONLY" -eq 1 ]; then
  tmux kill-session -t "$SESSION" 2>/dev/null || true
  exit 0
fi

if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "tmux session already exists: $SESSION"
  open_visible_terminal || true
  open_safety_terminal || true
  if [ -t 0 ] && [ -t 1 ]; then
    echo "Attaching to existing session."
    exec tmux attach-session -t "$SESSION"
  fi
  echo "Visible terminal requested on Jetson display."
  echo "Safety terminal requested on Jetson display."
  echo "Attach manually: tmux attach -t $SESSION"
  exit 0
fi

mkdir -p "$(dirname "$URL_SUMMARY_FILE")"
cat > "$URL_SUMMARY_FILE" <<EOF
Open UI:
$GITHUB_PAGES_URL

Debug:
$GITHUB_PAGES_DEBUG_URL

Paste into UI:
waiting for Cloudflare quick tunnel...
EOF

ros_prefix() {
  cat <<EOF
set -e
cd "$WORKSPACE_DIR"
export TURTLEBOT3_MODEL="$TURTLEBOT3_MODEL"
export DISPLAY="$GUI_DISPLAY"
export XDG_RUNTIME_DIR="$GUI_RUNTIME_DIR"
export DBUS_SESSION_BUS_ADDRESS="$GUI_DBUS"
export XAUTHORITY="$GUI_XAUTHORITY"
source "$ROS_DISTRO_SETUP"
source "$WORKSPACE_SETUP"
EOF
}

window() {
  local name="$1"
  local command="$2"
  tmux new-window -t "$SESSION:" -n "$name" "bash -lc $(printf '%q' "$command")"
}

hold() {
  cat <<'EOF'
status=$?
echo
echo "Command exited with status $status. Press Ctrl-D or close this pane when done."
exec bash
EOF
}

urls_cmd=$(cat <<EOF
while true; do
  clear
  cat "$URL_SUMMARY_FILE" 2>/dev/null || true
  echo
  echo "tmux session: $SESSION"
  echo "Attach: tmux attach -t $SESSION"
  echo "Logs: select tmux window 'debug' or press Ctrl-b then 8"
  echo "RViz: use '2D Pose Estimate' to set the robot initial pose"
  echo "Safety: select tmux window 'safety', then press 1 or 2"
  echo "Stop:   $WORKSPACE_DIR/scripts/stop_mission_tmux.sh"
  sleep 2
done
EOF
)

tmux new-session -d -s "$SESSION" -n urls "bash -lc $(printf '%q' "$urls_cmd")"

safety_cmd=$(cat <<EOF
export SESSION="$SESSION"
export WORKSPACE_DIR="$WORKSPACE_DIR"
export ROS_DISTRO_SETUP="$ROS_DISTRO_SETUP"
export WORKSPACE_SETUP="$WORKSPACE_SETUP"
exec "$WORKSPACE_DIR/scripts/safety_control.sh"
EOF
)
window safety "$safety_cmd"

if [ "$USE_CLOUDFLARE" -eq 1 ]; then
  bridge_cmd=$(cat <<EOF
$(ros_prefix)
export URL_SUMMARY_FILE="$URL_SUMMARY_FILE"
export GITHUB_PAGES_URL="$GITHUB_PAGES_URL"
export GITHUB_PAGES_DEBUG_URL="$GITHUB_PAGES_DEBUG_URL"
export WS_PORT="$WS_PORT"
set +e
"$WORKSPACE_DIR/scripts/start_bridge_quicktunnel.sh"
$(hold)
EOF
)
else
  bridge_cmd=$(cat <<EOF
$(ros_prefix)
export WS_PORT="$WS_PORT"
set +e
"$WORKSPACE_DIR/scripts/start_bridge_only.sh"
$(hold)
EOF
)
fi
window bridge "$bridge_cmd"

window bringup "$(cat <<EOF
$(ros_prefix)
set +e
ros2 launch turtlebot3_bringup robot.launch.py
$(hold)
EOF
)"

window nav "$(cat <<EOF
$(ros_prefix)
sleep "\${NAV_START_DELAY:-8}"
set +e
ros2 launch turtlebot3_navigation2 navigation2.launch.py map:="$MAP_FILE"
$(hold)
EOF
)"

window mission "$(cat <<EOF
$(ros_prefix)
sleep "\${MISSION_START_DELAY:-3}"
set +e
ros2 run rtreebot delivery_ctrl
$(hold)
EOF
)"

window vision "$(cat <<EOF
$(ros_prefix)
sleep "\${VISION_START_DELAY:-5}"
set +e
sudo systemctl restart nvargus-daemon 2>/dev/null || true
sleep 2
export CAMERA_INPUT_URI="\${CAMERA_INPUT_URI:-csi://0}"
ros2 run camera_ros publisher &
CAMERA_PID=\$!
ros2 run item_detector detection &
ITEM_DETECTOR_PID=\$!
sleep 3
ros2 run mediapipe_hand_tracker hand_tracker_node
kill "\$CAMERA_PID" 2>/dev/null || true
kill "\$ITEM_DETECTOR_PID" 2>/dev/null || true
$(hold)
EOF
)"

window manipulator "$(cat <<EOF
$(ros_prefix)
sleep "\${MANIPULATOR_START_DELAY:-5}"
set +e
ros2 launch manipulator manipulatorCtrl.launch.py
$(hold)
EOF
)"

if [ "$DEBUG_ECHO" -eq 1 ]; then
  debug_cmd=$(cat <<EOF
$(ros_prefix)
set +e
ros2 topic echo /move_request std_msgs/msg/String &
ros2 topic echo /move_finish std_msgs/msg/Bool &
ros2 topic echo /move_resume std_msgs/msg/Bool &
ros2 topic echo /mission/status std_msgs/msg/String &
ros2 topic echo /mediapipe/start std_msgs/msg/String &
ros2 topic echo /manipulator/motion_id std_msgs/msg/Int32 &
ros2 topic echo /item_detector/start std_msgs/msg/Bool &
ros2 topic echo /detectnet/result std_msgs/msg/String &
wait
$(hold)
EOF
)
else
  debug_cmd=$(cat <<EOF
$(ros_prefix)
echo "Useful checks:"
echo "  ros2 topic echo /move_request"
echo "  ros2 topic echo /move_finish"
echo "  ros2 topic echo /move_resume"
echo "  ros2 topic echo /mission/status"
echo "  ros2 topic echo /mediapipe/start"
echo "  ros2 topic echo /manipulator/motion_id"
echo "  ros2 topic echo /item_detector/start"
echo "  ros2 topic echo /detectnet/result"
echo "  ros2 topic list"
echo
exec bash
EOF
)
fi
window debug "$debug_cmd"

tmux select-window -t "$SESSION:debug"
open_visible_terminal || true
open_safety_terminal || true

if [ -t 0 ] && [ -t 1 ]; then
  tmux attach-session -t "$SESSION"
else
  echo "tmux session started: $SESSION"
  echo "Visible terminal requested on Jetson display."
  echo "Safety terminal requested on Jetson display."
  echo "Attach manually: tmux attach -t $SESSION"
fi
