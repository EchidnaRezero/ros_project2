# Jetson Hardware Troubleshooting Log

작성일: 2026-06-15

이 문서는 미션 준비 중 실제로 겪은 하드웨어/장치 오류와 탐지, 대처 방법을 기록한다. 포트의 현재 정답은 `JETSON_HARDWARE_SETTINGS.md`를 기준으로 한다.

## 빠른 확인 순서

미션 실행 전 또는 이상 동작 시 Jetson에서 먼저 확인한다.

```bash
ls -l /dev/ttyACM* /dev/ttyUSB* /dev/ttyRtreeCon /dev/ttyManipCon /dev/ttyLidar /dev/video0 2>/dev/null
v4l2-ctl --list-devices
systemctl is-active nvargus-daemon
```

ROS 상태:

```bash
cd ~/turtlebot3_ws
source /opt/ros/galactic/setup.bash
source install/setup.bash

ros2 topic hz /scan
ros2 topic echo /move_request
ros2 topic echo /mediapipe/start
ros2 topic echo /manipulator/motion_id
ros2 topic echo /move_resume
```

미션 tmux에서는 `debug`, `bringup`, `nav`, `vision`, `manipulator` 창을 같이 본다.

## LiDAR

### 증상

- RViz/Nav2에서 scan이 제대로 들어오지 않음
- 초기 위치를 잡아도 LiDAR 상태가 불안정하거나 reset되는 것처럼 보임
- LiDAR를 뺐다 꽂은 뒤에도 기존 세션에서는 정상 복구되지 않음

### 탐지

장치 확인:

```bash
ls -l /dev/ttyUSB* /dev/ttyLidar 2>/dev/null
```

ROS scan 확인:

```bash
ros2 topic hz /scan
```

bringup 로그에서 정상일 때는 아래처럼 나온다.

```text
SLLidar S/N: ...
SLLidar health status : OK.
current scan mode: Standard
```

### 원인

두 가지가 있었다.

1. `robot.launch.py`가 `sllidar_c1_launch.py`에 잘못된 인자 이름을 넘겼다.

수정 전:

```text
port=/dev/ttyUSB0
```

실제 `sllidar_c1_launch.py`가 받는 인자:

```text
serial_port
```

2. LiDAR 재연결 후 기존 `sllidar_node`가 자동으로 정상 복구되지 않았다.

### 대처

`robot.launch.py`에서 LiDAR launch 인자를 아래처럼 고정했다.

```python
launch_arguments={'serial_port': '/dev/ttyLidar', 'frame_id': 'base_scan'}
```

LiDAR를 뺐다 꽂은 뒤에는 미션 세션을 다시 시작한다.

```bash
~/turtlebot3_ws/scripts/stop_mission_tmux.sh
~/turtlebot3_ws/scripts/start_mission_tmux.sh
```

### 재발 시 판단

- `/dev/ttyLidar`가 없으면 udev/symlink 또는 물리 연결 문제
- `/dev/ttyLidar`는 있는데 `/scan`이 없으면 bringup 로그 확인
- 로그에 `serial_port`가 아니라 `/dev/ttyUSB0` 직접값이 보이면 코드/빌드 반영 문제
- LiDAR를 물리적으로 재연결했다면 세션 재시작부터 한다

## Manipulator / OpenRB

### 증상

- 매니퓰레이터가 명령에 반응하지 않음
- `/manipulator/motion_id`가 나가도 실제 동작으로 이어지지 않음
- OpenRB 포트가 `/dev/ttyACM0`, `/dev/ttyACM1` 사이에서 바뀔 가능성이 있음

### 탐지

장치 확인:

```bash
ls -l /dev/ttyACM* /dev/ttyManipCon 2>/dev/null
```

Dynamixel ping:

```bash
source /opt/ros/galactic/setup.bash
source ~/turtlebot3_ws/install/setup.bash
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

정상 확인된 결과:

```text
/dev/ttyManipCon open OK
Dynamixel ID 11,12,13,14,15 ping 성공
```

manipulator launch 정상 로그:

```text
Succeeded to open the port.
Succeeded to set the baudrate.
Succeeded to set Position Control Mode.
Succeeded to set Drive Mode to Time-based profile.
Succeeded to enable torque.
MotionPlayer node ready
```

### 원인

기존 코드가 직접 포트 `/dev/ttyACM1`을 전제로 했다. 하지만 실제 Jetson에서는 OpenRB가 `/dev/ttyACM0`로 잡혔고, 연결 순서에 따라 `ttyACM*` 번호는 바뀔 수 있다.

### 대처

역할 기반 symlink를 기준으로 바꿨다.

```text
/dev/ttyACM1 -> /dev/ttyManipCon
```

반영한 파일:

```text
src/manipulator/launch/manipulatorCtrl.launch.py
src/manipulator/launch/manipulatorGUI.launch.py
src/dynamixel_sdk_examples/src/read_write_node_omx.py
Jetson: src/DynamixelSDK/ros/dynamixel_sdk_examples/src/read_write_node_omx.py
```

### 재발 시 판단

- `/dev/ttyManipCon`이 없으면 udev rule 또는 OpenRB 물리 연결 문제
- ping에서 open 실패면 포트/권한 문제
- ping은 되는데 동작하지 않으면 manipulator launch 로그와 `/manipulator/motion_id`를 확인
- Jetson 실제 사용 경로 `src/DynamixelSDK/ros/.../read_write_node_omx.py`도 같이 확인한다

### 토크가 남아 있는 것처럼 보일 때

`tmux ls`, `ros2 node list`, `ps`에서 manipulator 관련 노드가 없어도 Dynamixel 토크가 남아 있을 수 있다. `read_write_node_omx.py`는 시작 시 각 ID의 torque를 enable하고, 프로세스가 종료될 때 자동으로 torque off를 보장하지 않는다.

현재 `stop_mission_tmux.sh`와 safety 2번은 미션 tmux/proc 종료용이다. 토크 OFF까지 자동 보장하지 않으므로, 미션을 완전히 끝낸 뒤 안전 대기 상태로 만들 때는 아래 torque off 확인을 별도로 수행한다.

먼저 노드/프로세스 상태를 확인한다.

```bash
tmux ls 2>/dev/null || true
source /opt/ros/galactic/setup.bash
source ~/turtlebot3_ws/install/setup.bash
ros2 node list
ps -eo pid,ppid,stat,cmd | grep -Ei "manipulator|read_write_node_omx|dynamixel|motion" | grep -v grep || true
```

manipulator 노드가 살아 있으면 ROS topic으로 torque off를 보낸다.

```bash
for id in 11 12 13 14 15; do
  ros2 topic pub --once /set_torque dynamixel_sdk_custom_interfaces/msg/SetTorque "{id: $id, torque: false}"
done
```

manipulator 노드가 없는데도 토크가 남아 있으면, 직접 Dynamixel SDK로 torque disable을 보낸다.

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

위 명령은 팔을 지지하지 않은 상태에서 실행하면 관절이 힘을 잃을 수 있으므로, 사람이 팔/물체를 받치고 있는지 먼저 확인한다.

정상 확인 결과는 아래처럼 전부 OFF여야 한다.

```text
id=11 torque=OFF raw=0
id=12 torque=OFF raw=0
id=13 torque=OFF raw=0
id=14 torque=OFF raw=0
id=15 torque=OFF raw=0
```

## Hand Gesture / MediaPipe

### 혼동 지점

현재 `mediapipe_hand_tracker`의 코드 이름은 `lambda_sign`이지만, 실제 조건은 L/V/Λ 손모양이 아니라 pinch/OK 모양에 가깝다.

핵심 조건:

```text
thumb_tip과 index_tip의 거리 <= 0.08
thumb_tip.y는 thumb_mcp.y보다 위
index_tip.y는 index_mcp.y보다 위
middle/ring/pinky는 접힘
```

따라서 엄지와 검지를 크게 벌린 L/V 모양은 사람이 보기엔 람다처럼 보여도 현재 코드에서는 실패할 수 있다.

### 시각화

프로젝트 루트의 아래 파일을 브라우저로 연다.

```text
LAMBDA_GESTURE_GUIDE.html
```

이 파일은 손 그림이 아니라 MediaPipe landmark 뼈대 기준으로 PASS/FAIL 조건을 보여준다.

## Camera / Vision

### 증상

- `/dev/video0`는 보이는데 vision 노드가 프레임을 못 받음
- `v4l2:///dev/video0`로 실행하면 `jetson_utils.videoSource`에서 실패
- 이전 비정상 종료 뒤 camera session 생성 실패가 발생

### 탐지

장치 확인:

```bash
v4l2-ctl --list-devices
```

확인된 장치:

```text
vi-output, imx219 7-0010:
  /dev/video0
```

CSI 카메라 단독 테스트:

```bash
sudo systemctl restart nvargus-daemon
gst-launch-1.0 nvarguscamerasrc sensor-id=0 num-buffers=30 ! "video/x-raw(memory:NVMM), width=1280, height=720, framerate=30/1, format=NV12" ! fakesink
```

정상 로그:

```text
GST_ARGUS: Setup Complete
CONSUMER: Producer has connected
Done Success
```

### 원인

`/dev/video0`는 USB 웹캠이 아니라 IMX219 CSI raw Bayer 장치였다. 그래서 `v4l2:///dev/video0` 입력은 현재 `jetson_utils.videoSource` 기준에 맞지 않았다.

또한 이전 비정상 종료 후 `nvargus-daemon` 상태가 꼬이면 CaptureSession 생성이 실패할 수 있었다.

### 대처

`camera_ros.publisher` 기본 입력을 CSI 기준으로 유지했다.

```text
CAMERA_INPUT_URI 기본값: csi://0
```

`start_mission_tmux.sh`의 vision 창 시작 전에 `nvargus-daemon`을 재시작하도록 했다.

```bash
sudo systemctl restart nvargus-daemon 2>/dev/null || true
sleep 2
export CAMERA_INPUT_URI="${CAMERA_INPUT_URI:-csi://0}"
```

### 재발 시 판단

- `/dev/video0`가 있어도 USB 카메라라고 가정하지 않는다
- `v4l2-ctl --list-devices`에서 IMX219인지 먼저 확인
- vision 실패 후에는 `nvargus-daemon` 재시작
- 그래도 안 되면 `gst-launch-1.0 nvarguscamerasrc ... ! fakesink`로 ROS 밖에서 먼저 확인

## TurtleBot3 Base / Rtree

### 증상

- 주행 명령이 들어가도 base가 움직이지 않음
- Nav2는 goal을 받은 것처럼 보이지만 실제 모터 반응이 없음

### 탐지

장치 확인:

```bash
ls -l /dev/ttyACM* /dev/ttyRtreeCon 2>/dev/null
```

현재 기준:

```text
Rtree / TurtleBot3 base: /dev/ttyRtreeCon
```

### 대처

`robot.launch.py`의 TurtleBot3 bringup 포트는 `/dev/ttyRtreeCon` 기준으로 둔다.

```text
usb_port 기본값 /dev/ttyRtreeCon
```

### 재발 시 판단

- `/dev/ttyRtreeCon`이 없으면 udev/symlink 또는 Rtree board 연결 문제
- base는 Jetson 본체 쪽 USB에 연결된 것으로 기록됨
- OpenRB/manipulator와 포트를 혼동하지 않는다

## 물리 연결 메모

현재 대화 기준:

```text
Rtree / TurtleBot3 base: Jetson 본체 쪽 USB
OpenRB / manipulator: 확장포트 쪽
LiDAR: /dev/ttyLidar로 잡히는 CP210x USB-UART
Camera: IMX219 CSI
```

USB 저장장치와 모델 파일은 포트 변경 대상이 아니다.

## 백업 기록

작업 중 생성한 백업 위치:

```text
/home/jetson/Desktop/backup3/
```

Manipulator 포트 변경 전 백업:

```text
/home/jetson/Desktop/backup3/manip_port_backup_20260615_165239
```

Camera 입력 변경 전 백업:

```text
/home/jetson/Desktop/backup3/camera_input_backup_20260615_165509
```
