# 하드웨어 트러블슈팅

Jetson 미션 준비 중 실제로 확인한 장치/포트/카메라 문제와 진단 기준.

## 빠른 확인 순서

장치명과 카메라 정상 기준은 `docs/HARDWARE.md`, 주요 ROS topic 기준은 `docs/CODEBASE.md` 참고.

장애 직후에는 `dmesg`, `/scan`, 역할 기반 장치명, tmux pane, ROS log 순서로 확인.

```bash
ls -l /dev/ttyACM* /dev/ttyUSB* /dev/ttyRtreeCon /dev/ttyManipCon /dev/ttyLidar /dev/video0 2>/dev/null
v4l2-ctl --list-devices
systemctl is-active nvargus-daemon
```

```bash
source /opt/ros/galactic/setup.bash
source ~/turtlebot3_ws/install/setup.bash
ros2 topic hz /scan
ros2 topic echo /move_request
ros2 topic echo /mediapipe/start
ros2 topic echo /manipulator/motion_id
ros2 topic echo /move_resume
```

tmux에서는 `debug`, `bringup`, `nav`, `vision`, `manipulator` 창을 우선 확인. 로그 위치와 tmux 캡처 명령은 `docs/LOGGING.md` 참고.

## LiDAR

### 증상

- RViz/Nav2에서 `/scan` 부재 또는 불안정
- `2D Pose Estimate` 이후 위치추정이 다시 흔들리는 현상
- LiDAR 재연결 후 기존 세션에서 자동 복구 실패 가능

### 검증

`/dev/ttyLidar`, `/scan`, bringup 로그 순서로 확인.

```bash
ls -l /dev/ttyUSB* /dev/ttyLidar 2>/dev/null
stty -F /dev/ttyLidar -a
dmesg -T | grep -Ei 'ttyUSB|cp210|ttyLidar|error -110|error -71|Unable to enable UART|over-current' | tail -80
```

### 진단

- `robot.launch.py`에서 LiDAR launch에 넘기는 인자명 확인
- `sllidar_c1_launch.py`의 포트 인자명은 `serial_port`
- `/dev/ttyLidar`가 있어도 `/scan`이 없으면 bringup 로그와 `sllidar_node` 상태 확인
- 로그에 `/dev/ttyUSB0` 직접값이 보이면 코드/빌드 반영 문제
- `stty`가 `Input/output error`를 내면 ROS보다 USB-Serial, 케이블, 허브, 전원 계층을 먼저 확인
- LiDAR를 물리적으로 재연결했다면 기존 `sllidar_node`가 자동 복구되지 않을 수 있음

### 조치

`robot.launch.py`에서 LiDAR launch 인자를 역할 기반 장치명으로 고정.

```text
serial_port=/dev/ttyLidar
frame_id=base_scan
```

재연결 후 세션 재시작. 자세한 재현 기록은 `docs/issues/LIDAR_POSE_ESTIMATION_2026-06-16.md` 참고.

### 확정/한계

- `/dev/ttyLidar`와 `/scan` 정상 수신까지 확인하면 ROS 계층 복구로 판단
- USB-Serial, 케이블, 허브, 전원, 초기화 문제는 재발 가능성 유지

## Manipulator / OpenRB

### 증상

- `/manipulator/motion_id` 발행 후 실제 로봇팔 무반응
- OpenRB가 `/dev/ttyACM0`, `/dev/ttyACM1` 사이에서 바뀔 가능성
- 미션 종료 후에도 Dynamixel torque가 남아 있는 듯한 상태

### 검증

Dynamixel ID 11~15 ping 기준:

```text
port=/dev/ttyManipCon
baudrate=1000000
protocol=2.0
ids=11,12,13,14,15
expected=all ping success
```

직접 확인 스크립트:

```bash
python3 - <<'PY'
from dynamixel_sdk import PortHandler, PacketHandler, COMM_SUCCESS
port = '/dev/ttyManipCon'
ids = [11, 12, 13, 14, 15]
packet = PacketHandler(2.0)
ph = PortHandler(port)
print('open', ph.openPort())
print('baud', ph.setBaudRate(1000000))
for dxl_id in ids:
    model, result, error = packet.ping(ph, dxl_id)
    print(dxl_id, packet.getTxRxResult(result), error, model if result == COMM_SUCCESS else None)
ph.closePort()
PY
```

정상 로그 기준:

```text
Succeeded to open the port.
Succeeded to set the baudrate.
Succeeded to enable torque.
MotionPlayer node ready
```

### 진단

- 직접 포트 `/dev/ttyACM*` 기준은 연결 순서에 취약
- 역할 기반 symlink `/dev/ttyManipCon` 존재 여부가 1차 기준
- ping 실패는 포트/권한/물리 연결 문제
- ping 성공 후 무동작은 launch 로그와 `/manipulator/motion_id` 수신 여부 확인

### 조치

Manipulator launch와 Dynamixel read/write node 기준을 `/dev/ttyManipCon`으로 정리.

확인 파일:

```text
turtlebot3_ws/src/manipulator/launch/manipulatorCtrl.launch.py
turtlebot3_ws/src/manipulator/launch/manipulatorGUI.launch.py
turtlebot3_ws/src/dynamixel_sdk_examples/src/read_write_node_omx.py
turtlebot3_ws/src/DynamixelSDK/ros/dynamixel_sdk_examples/src/read_write_node_omx.py
```

### Torque off 확인

프로세스 종료가 torque off를 보장하지 않으므로, 안전 대기 상태가 필요하면 별도 확인.

노드/프로세스 확인:

```bash
tmux ls 2>/dev/null || true
source /opt/ros/galactic/setup.bash
source ~/turtlebot3_ws/install/setup.bash
ros2 node list
ps -eo pid,ppid,stat,cmd | grep -Ei "manipulator|read_write_node_omx|dynamixel|motion" | grep -v grep || true
```

ROS topic으로 torque off:

```bash
for id in 11 12 13 14 15; do
  ros2 topic pub --once /set_torque dynamixel_sdk_custom_interfaces/msg/SetTorque "{id: $id, torque: false}"
done
```

노드가 없는데 torque가 남아 있으면 Dynamixel SDK로 직접 disable.

```bash
python3 - <<'PY'
from dynamixel_sdk import PortHandler, PacketHandler
ADDR_TORQUE_ENABLE = 64
PROTOCOL_VERSION = 2.0
BAUDRATE = 1000000
DEVICE_NAME = '/dev/ttyManipCon'
DXL_IDS = [11, 12, 13, 14, 15]
ph = PortHandler(DEVICE_NAME)
packet = PacketHandler(PROTOCOL_VERSION)
print('open', ph.openPort())
print('baud', ph.setBaudRate(BAUDRATE))
for dxl_id in DXL_IDS:
    result, error = packet.write1ByteTxRx(ph, dxl_id, ADDR_TORQUE_ENABLE, 0)
    print(dxl_id, packet.getTxRxResult(result), error)
ph.closePort()
PY
```

팔을 지지하지 않은 상태에서 torque off를 실행하면 관절이 힘을 잃을 수 있음.

정상 결과는 ID 11~15가 모두 torque OFF 상태.

## Camera / Vision

### 증상

- `/dev/video0`는 보이지만 vision node가 프레임 수신 실패
- `v4l2:///dev/video0` 입력에서 `jetson_utils.videoSource` 실패
- 이전 비정상 종료 뒤 camera session 생성 실패

### 검증

카메라 장치와 `nvargus-daemon` 정상 기준은 `docs/HARDWARE.md` 참고.

### 진단

- `/dev/video0`는 USB webcam이 아니라 IMX219 CSI raw Bayer 장치
- 현재 vision 입력 기준은 `csi://0`
- `nvargus-daemon` 상태가 꼬이면 ROS 밖 카메라 테스트도 실패 가능

### 조치

- `camera_ros.publisher`의 기본 입력을 `csi://0` 기준으로 유지
- `start_mission_tmux.sh` vision 창 시작 전 `nvargus-daemon` 재시작

```text
CAMERA_INPUT_URI 기본값: csi://0
```

스크립트 흐름 기준:

```bash
sudo systemctl restart nvargus-daemon 2>/dev/null || true
sleep 2
export CAMERA_INPUT_URI="${CAMERA_INPUT_URI:-csi://0}"
```

### 확정/한계

- `gst-launch-1.0 nvarguscamerasrc ... ! fakesink` 성공 시 ROS 밖 카메라 계층 정상으로 판단
- 이후 vision node 실패는 모델 경로, 입력 URI, Jetson inference 계층 확인

## TurtleBot3 Base / Rtree

### 증상

- Nav2 goal은 들어가지만 base 모터 무반응
- 주행 명령과 실제 base 연결 사이 불일치 의심

### 검증

역할 기반 장치명 기준은 `docs/HARDWARE.md` 참고.

### 진단/조치

- TurtleBot3 base / Rtree 기준 장치명은 `/dev/ttyRtreeCon`
- `robot.launch.py`의 `usb_port` 기본값이 `/dev/ttyRtreeCon`인지 확인
- `/dev/ttyRtreeCon` 부재 시 udev rule, 물리 연결, 보드 전원 확인

## 로그 확인

자세한 로그 위치와 검색 명령은 `docs/LOGGING.md` 참고.
