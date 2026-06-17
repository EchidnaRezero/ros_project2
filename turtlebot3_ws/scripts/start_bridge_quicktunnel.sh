#!/usr/bin/env bash
set -eo pipefail

WS_PORT="${WS_PORT:-3000}"
ROS_DISTRO_SETUP="${ROS_DISTRO_SETUP:-/opt/ros/galactic/setup.bash}"
WORKSPACE_SETUP="${WORKSPACE_SETUP:-$HOME/turtlebot3_ws/install/setup.bash}"
URL_SUMMARY_FILE="${URL_SUMMARY_FILE:-}"
GITHUB_PAGES_URL="${GITHUB_PAGES_URL:-https://echidnarezero.github.io/ros_project2/web_client/}"
GITHUB_PAGES_DEBUG_URL="${GITHUB_PAGES_DEBUG_URL:-https://echidnarezero.github.io/ros_project2/web_client/debug.html}"

if ! command -v cloudflared >/dev/null 2>&1; then
  echo "cloudflared is not installed or not in PATH." >&2
  echo "Install cloudflared first, then run this script again." >&2
  exit 1
fi

if [ -f "$ROS_DISTRO_SETUP" ]; then
  # shellcheck disable=SC1090
  source "$ROS_DISTRO_SETUP"
fi

if [ -f "$WORKSPACE_SETUP" ]; then
  # shellcheck disable=SC1090
  source "$WORKSPACE_SETUP"
else
  echo "Workspace setup file not found: $WORKSPACE_SETUP" >&2
  exit 1
fi

cleanup() {
  if [ -n "${BRIDGE_PID:-}" ] && kill -0 "$BRIDGE_PID" 2>/dev/null; then
    kill "$BRIDGE_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

echo "Starting ROS2 delivery bridge on ws://0.0.0.0:${WS_PORT}"
ros2 run rtreebot delivery_bridge --ros-args -p ws_port:="$WS_PORT" &
BRIDGE_PID=$!

sleep 2
if ! kill -0 "$BRIDGE_PID" 2>/dev/null; then
  echo "delivery_bridge exited early." >&2
  wait "$BRIDGE_PID"
fi

echo "Starting Cloudflare quick tunnel for http://localhost:${WS_PORT}"
echo "Open UI: $GITHUB_PAGES_URL"
echo "When a trycloudflare URL appears, paste it into the UI as wss://..."
echo

cloudflared tunnel --url "http://localhost:${WS_PORT}" 2>&1 | while IFS= read -r line; do
  echo "$line"
  if [[ "$line" =~ https://[a-zA-Z0-9.-]+\.trycloudflare\.com ]]; then
    URL="${BASH_REMATCH[0]}"
    WSS_URL="${URL/https:/wss:}"
    if [ -n "$URL_SUMMARY_FILE" ]; then
      cat > "$URL_SUMMARY_FILE" <<EOF
Open UI:
$GITHUB_PAGES_URL

Debug:
$GITHUB_PAGES_DEBUG_URL

Paste into UI:
$WSS_URL
EOF
    fi
    echo
    echo "============================================================"
    echo "Open UI:"
    echo "$GITHUB_PAGES_URL"
    echo
    echo "Debug:"
    echo "$GITHUB_PAGES_DEBUG_URL"
    echo
    echo "Paste into UI:"
    echo "$WSS_URL"
    echo "============================================================"
    echo
  fi
done
