# Jetson Hardware / Port Settings

작성일: 2026-06-15  
대상: `jetson@100.101.167.4:/home/jetson/turtlebot3_ws`

이 문서는 현재 Jetson 실제 연결과 코드 반영 상태를 기준으로 한다.

장애 증상, 탐지 방법, 실제 대처 기록은 `JETSON_HARDWARE_TROUBLESHOOTING.md`를 본다.

## 현재 결론

| 역할 | 실제 장치 | 안정 이름 | 현재 코드 기준 |
|---|---|---|---|
| TurtleBot3 base / Rtree | `/dev/ttyACM1` | `/dev/ttyRtreeCon` | `/dev/ttyRtreeCon` |
| Manipulator OpenRB | `/dev/ttyACM0` | `/dev/ttyManipCon` | `/dev/ttyManipCon` |
| LiDAR | `/dev/ttyUSB0` | `/dev/ttyLidar` | `/dev/ttyLidar` |
| Camera | `/dev/video0` | 없음 | `csi://0` |

중요: `/dev/ttyACM0`, `/dev/ttyACM1`, `/dev/ttyUSB0`는 연결 순서에 따라 바뀔 수 있으므로 코드에서는 역할 기반 symlink를 사용한다.

## udev rule

Jetson `/etc/udev/rules.d/99-tty.rules`:

```udev
SUBSYSTEM=="tty", MODE:="0666", ATTRS{idVendor}=="2e8a", ATTRS{idProduct}=="00c0", SYMLINK+="ttyRtreeCon"
SUBSYSTEM=="tty", MODE:="0666", ATTRS{idVendor}=="2f5d", ATTRS{idProduct}=="2202", SYMLINK+="ttyManipCon"
SUBSYSTEM=="tty", MODE:="0666", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", SYMLINK+="ttyLidar"
```

현재 확인된 symlink:

```text
/dev/ttyRtreeCon  -> ttyACM1
/dev/ttyManipCon  -> ttyACM0
/dev/ttyLidar     -> ttyUSB0
```

## 적용된 코드

### TurtleBot3 base

파일:

```text
src/turtlebot3/turtlebot3_bringup/launch/robot.launch.py
```

기준:

```text
usb_port 기본값 /dev/ttyRtreeCon
```

### LiDAR

파일:

```text
src/turtlebot3/turtlebot3_bringup/launch/robot.launch.py
```

수정 내용:

```python
launch_arguments={'serial_port': '/dev/ttyLidar', 'frame_id': 'base_scan'}
```

주의: `sllidar_c1_launch.py`의 인자 이름은 `port`가 아니라 `serial_port`다.

정상 로그:

```text
SLLidar S/N: ...
SLLidar health status : OK.
current scan mode: Standard
```

LiDAR를 뺐다 꽂은 뒤에는 기존 `sllidar_node`가 자동 재시작되지 않으므로 미션 세션을 다시 시작한다.

```bash
~/turtlebot3_ws/scripts/stop_mission_tmux.sh
~/turtlebot3_ws/scripts/start_mission_tmux.sh
```

### Manipulator

파일:

```text
src/manipulator/launch/manipulatorCtrl.launch.py
src/manipulator/launch/manipulatorGUI.launch.py
src/dynamixel_sdk_examples/src/read_write_node_omx.py
Jetson: src/DynamixelSDK/ros/dynamixel_sdk_examples/src/read_write_node_omx.py
```

수정 내용:

```text
/dev/ttyACM1 -> /dev/ttyManipCon
```

검증 결과:

```text
/dev/ttyManipCon open OK
Dynamixel ID 11,12,13,14,15 ping 성공
manipulatorCtrl.launch.py 초기화 성공
```

정상 로그:

```text
Succeeded to open the port.
Succeeded to set the baudrate.
Succeeded to set Position Control Mode.
Succeeded to set Drive Mode to Time-based profile.
Succeeded to enable torque.
MotionPlayer node ready
```

## Camera

확인 결과:

```text
v4l2-ctl --list-devices
vi-output, imx219 7-0010:
  /dev/video0
```

`/dev/video0`는 USB 웹캠이 아니라 IMX219 CSI raw Bayer 장치다. `v4l2:///dev/video0`는 현재 `jetson_utils.videoSource` 입력으로 실패했다.

현재 기준:

```text
camera_ros.publisher input_uri 기본값: csi://0
start_mission_tmux.sh vision 창 시작 전: sudo systemctl restart nvargus-daemon
```

정상 확인:

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

## 물리 연결 기준

현재 대화 기준:

```text
Rtree / TurtleBot3 base: Jetson 본체 쪽 USB
OpenRB / manipulator: 확장포트 쪽
LiDAR: /dev/ttyLidar로 잡히는 CP210x USB-UART
Camera: IMX219 CSI
```

USB 저장장치와 모델 파일은 포트 변경 대상이 아니다.

## 확인 명령

장치:

```bash
ls -l /dev/ttyACM* /dev/ttyUSB* /dev/ttyRtreeCon /dev/ttyManipCon /dev/ttyLidar /dev/video0 2>/dev/null
lsusb
v4l2-ctl --list-devices
systemctl is-active nvargus-daemon
```

LiDAR:

```bash
source /opt/ros/galactic/setup.bash
source ~/turtlebot3_ws/install/setup.bash
ros2 topic hz /scan
```

Manipulator ping:

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

## 백업

최근 작업 중 생성한 백업:

```text
/home/jetson/Desktop/backup3/
```
