# 알려진 경로 문제

Jetson 실사용 환경에 묶인 경로와 장치명을 정리한 재현 기준.

## 문제 성격

일부 코드는 범용 package share 경로가 아니라 당시 Jetson의 실제 workspace, Python venv, udev symlink를 기준으로 동작.

이 값들은 코드에서 사라진 문제가 아니라 재현 시 먼저 맞춰야 하는 환경 조건.

## 하드코딩 경로

| 파일 | 현재 코드의 경로 | 확인 기준 |
|---|---|---|
| `turtlebot3_ws/src/camera_ros/camera_ros/publisher.py` | `/home/jetson/turtlebot3_ws/src/camera_ros/camera_ros/` | 모델/라벨 파일을 해당 기준으로 탐색 |
| `turtlebot3_ws/src/mediapipe_hand_tracker/mediapipe_hand_tracker/hand_tracker_node.py` | `/home/jetson/mp_env/...` | MediaPipe 전용 venv 존재 여부 확인 |

검증 포인트:

```bash
ls -l /home/jetson/turtlebot3_ws/src/camera_ros/camera_ros/
ls -ld /home/jetson/mp_env
```

## 역할 기반 장치명

장치명 기준은 `docs/HARDWARE.md` 참고.

이 문서에서는 코드가 해당 역할 기반 장치명에 의존한다는 점만 다룸.

| 파일 | 코드 의존값 |
|---|---|
| `turtlebot3_ws/src/manipulator/launch/*.launch.py` | `/dev/ttyManipCon` |
| `turtlebot3_ws/src/turtlebot3/turtlebot3_bringup/launch/robot.launch.py` | `/dev/ttyRtreeCon`, `/dev/ttyLidar` |
| `turtlebot3_ws/src/camera_ros/camera_ros/publisher.py` | `CAMERA_INPUT_URI` 기본 `csi://0` |

## 진단 기준

- 파일이 없으면 코드 문제가 아니라 Jetson-only 리소스 누락 가능성 우선 확인
- `/dev/ttyACM*`, `/dev/ttyUSB*` 직접값은 연결 순서에 따라 변경 가능
- 코드에서는 역할 기반 symlink 유지
- 모델 본체, 지도, 가상환경은 Git 전체 동기화 대상이 아니라 Jetson 런타임 리소스로 관리

## 리팩토링 후보

- camera model path를 package share 또는 ROS parameter 기준으로 변경
- MediaPipe venv shebang/sys.path 제거 후 launch 환경에서 Python interpreter 지정
- udev symlink는 유지하되 진단 명령을 README/HARDWARE와 동기화
