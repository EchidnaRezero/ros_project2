# 하드웨어 및 설정

## 기준 환경

| 항목 | 기준 |
|---|---|
| ROS2 | Galactic |
| Jetson workspace | `<JETSON_WORKSPACE>` |
| 실행 관리 | `tmux` |
| 빌드 도구 | `colcon` |

새 Jetson에서 Galactic을 설치하려면 Ubuntu/JetPack 조합이 맞아야 한다. Galactic은 오래된 배포판이므로, 기존 Jetson 이미지 또는 동일한 Ubuntu 20.04 기반 환경을 기준으로 재현하는 것이 안전하다.

## 하드웨어 구성

| 구성 요소 | 역할 |
|---|---|
| Jetson | ROS2 노드, vision inference, bridge, 미션 제어 실행 |
| TurtleBot3 base / Rtree | AMR base 제어 |
| OpenRB / Manipulator | Dynamixel 기반 로봇팔 제어 |
| LiDAR | navigation scan 입력 |
| IMX219 CSI camera | camera/vision 입력 |

USB 장치는 연결 순서에 따라 `/dev/ttyACM*`, `/dev/ttyUSB*` 번호가 바뀔 수 있으므로 역할 기반 udev 장치명을 사용한다.

## udev 장치명

| 역할 | 기준 장치명 |
|---|---|
| TurtleBot3 base / Rtree | `/dev/ttyRtreeCon` |
| Manipulator OpenRB | `/dev/ttyManipCon` |
| LiDAR | `/dev/ttyLidar` |
| CSI camera | `csi://0` |

확인:

```bash
ls -l /dev/ttyRtreeCon /dev/ttyManipCon /dev/ttyLidar /dev/video0 2>/dev/null
```

udev rule을 다시 적용해야 할 때:

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

## 카메라

카메라는 IMX219 CSI camera이며, 입력 기준은 `csi://0`이다.

Vision 시작 전:

```bash
sudo systemctl restart nvargus-daemon
systemctl is-active nvargus-daemon
```

정상 확인:

```bash
gst-launch-1.0 nvarguscamerasrc sensor-id=0 num-buffers=30 ! "video/x-raw(memory:NVMM), width=1280, height=720, framerate=30/1, format=NV12" ! fakesink
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

전체 빌드가 막히면 먼저 `docs/issues/KNOWN_PATH_ISSUES.md`의 Jetson 전용 경로와 장치명을 확인한다.
