# 알려진 경로 문제

## 하드코딩 경로

| 파일 | 현재 코드의 경로 | 현재 백업 구조 기준 |
|---|---|---|
| `turtlebot3_ws/src/camera_ros/camera_ros/publisher.py` | `/home/jetson/turtlebot3_ws/src/camera_ros/camera_ros/` | `~/turtlebot3_ws/src/camera_ros/camera_ros/` |
| `turtlebot3_ws/src/mediapipe_hand_tracker/mediapipe_hand_tracker/hand_tracker_node.py` | `/home/jetson/mp_env/...` | Jetson의 `mp_env` 존재 여부 확인 |

## 고정값

| 파일 | 값 | 확인 내용 |
|---|---|---|
| `turtlebot3_ws/src/manipulator/launch/*.launch.py` | `/dev/ttyManipCon` | udev symlink 존재 확인 |
| `turtlebot3_ws/src/turtlebot3/turtlebot3_bringup/launch/robot.launch.py` | `/dev/ttyRtreeCon`, `/dev/ttyLidar` | udev symlink 존재 확인 |
| `turtlebot3_ws/src/camera_ros/camera_ros/publisher.py` | `CAMERA_INPUT_URI` 기본 `csi://0` | IMX219 CSI와 `nvargus-daemon` 상태 확인 |

## 처리 기준

실행이 막히면 위 경로를 먼저 확인. Jetson-only 모델, 지도, 가상환경은 보존 대상으로 관리.
