# 하드웨어 및 설정

## 기준 환경

| 항목 | 기준 |
|---|---|
| ROS2 | Galactic |
| Jetson workspace | `<JETSON_WORKSPACE>` |
| 실행 관리 | `tmux` |
| 빌드 도구 | `colcon` |

새 Jetson에서 Galactic 설치 시 Ubuntu/JetPack 조합 확인 필요. Galactic은 오래된 배포판이므로, 기존 Jetson 이미지 또는 동일한 Ubuntu 20.04 기반 환경 기준 재현 권장.

## 하드웨어 구성

| 구성 요소 | 역할 |
|---|---|
| Jetson | ROS2 노드, vision inference, bridge, 미션 제어 실행 |
| TurtleBot3 base / Rtree | AMR base 제어 |
| OpenRB / Manipulator | Dynamixel 기반 로봇팔 제어 |
| LiDAR | navigation scan 입력 |
| IMX219 CSI camera | camera/vision 입력 |

USB 장치는 연결 순서에 따라 `/dev/ttyACM*`, `/dev/ttyUSB*` 번호가 바뀔 수 있으므로 역할 기반 udev 장치명 사용.

## udev 장치명

| 역할 | 기준 장치명 |
|---|---|
| TurtleBot3 base / Rtree | `/dev/ttyRtreeCon` |
| Manipulator OpenRB | `/dev/ttyManipCon` |
| LiDAR | `/dev/ttyLidar` |
| CSI camera | `csi://0` |

확인:

```bash
ls -l /dev/ttyACM* /dev/ttyUSB* /dev/ttyRtreeCon /dev/ttyManipCon /dev/ttyLidar /dev/video0 2>/dev/null
lsusb
v4l2-ctl --list-devices
```

udev rule을 다시 적용해야 할 때:

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

Jetson udev rule 기준:

```udev
SUBSYSTEM=="tty", MODE:="0666", ATTRS{idVendor}=="2e8a", ATTRS{idProduct}=="00c0", SYMLINK+="ttyRtreeCon"
SUBSYSTEM=="tty", MODE:="0666", ATTRS{idVendor}=="2f5d", ATTRS{idProduct}=="2202", SYMLINK+="ttyManipCon"
SUBSYSTEM=="tty", MODE:="0666", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", SYMLINK+="ttyLidar"
```

## 적용된 코드 기준

TurtleBot3 base와 LiDAR:

```text
turtlebot3_ws/src/turtlebot3/turtlebot3_bringup/launch/robot.launch.py
usb_port=/dev/ttyRtreeCon
serial_port=/dev/ttyLidar
frame_id=base_scan
```

`sllidar_c1_launch.py`의 포트 인자명은 `port`가 아니라 `serial_port`.

Manipulator:

```text
turtlebot3_ws/src/manipulator/launch/manipulatorCtrl.launch.py
turtlebot3_ws/src/manipulator/launch/manipulatorGUI.launch.py
turtlebot3_ws/src/dynamixel_sdk_examples/src/read_write_node_omx.py
```

위 파일들은 직접 포트 번호 대신 `/dev/ttyManipCon` 기준.

## 카메라

카메라는 IMX219 CSI camera, 입력 기준은 `csi://0`.

`/dev/video0`가 보이더라도 USB webcam으로 가정하지 않는다. IMX219 CSI raw Bayer 장치일 수 있으므로 `v4l2-ctl --list-devices`로 장치 종류를 먼저 확인.

Vision 시작 전:

```bash
sudo systemctl restart nvargus-daemon
systemctl is-active nvargus-daemon
```

정상 확인:

```bash
gst-launch-1.0 nvarguscamerasrc sensor-id=0 num-buffers=30 ! "video/x-raw(memory:NVMM), width=1280, height=720, framerate=30/1, format=NV12" ! fakesink
```

정상 로그 기준:

```text
GST_ARGUS: Setup Complete
CONSUMER: Producer has connected
Done Success
```

## 빌드 의존성

기본 빌드:

```bash
cd ~/turtlebot3_ws
source /opt/ros/galactic/setup.bash
rosdep install --from-paths src --ignore-src -r -y
colcon build --symlink-install
source install/setup.bash
```

전체 빌드가 막히면 먼저 `docs/issues/KNOWN_PATH_ISSUES.md`의 Jetson 전용 경로와 장치명 확인.
