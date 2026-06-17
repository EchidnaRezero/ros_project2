# ROS2 AMR Manipulator Delivery Robot

웹 화면에서 물품 배송/회수를 요청하면 Jetson에서 ROS2 로봇이 이동, 인식, 로봇팔 동작, 완료 알림까지 처리하는 프로젝트다.

## 무엇을 하는 프로젝트인가

```text
Web UI
  -> WebSocket tunnel
  -> Jetson ROS2 bridge
  -> Nav2 이동
  -> 카메라/손동작 인식
  -> Dynamixel manipulator 동작
  -> Web UI 완료 표시
```

사용자는 웹에서 방과 물품을 고른다. 로봇은 목적지로 이동한 뒤 배송이면 손동작을 확인하고, 회수면 카메라로 물품을 인식한다. 이후 로봇팔이 저장된 동작을 실행한다.

## 사용 환경

| 항목 | 내용 |
|---|---|
| Robot middleware | ROS2 Galactic |
| Edge computer | Jetson |
| 이동 | TurtleBot3 base, Nav2, LiDAR |
| 인식 | CSI camera, Jetson Inference, MediaPipe |
| 조작 | Dynamixel manipulator |
| Web UI | `https://github.com/HisameOgasahara/ros_webclient` |
| Web UI 주소 | `https://hisameogasahara.github.io/ros_webclient/` |

## 프로젝트 전용 외부 리소스

| 리소스 | 링크 | 용도 |
|---|---|---|
| `ssd-mobilenet.onnx` | `https://huggingface.co/pomupomu2/ros2` | 회수 물품 인식 모델 본체 |

## 실행 방법

Jetson에서:

```bash
cd ~/turtlebot3_ws
source /opt/ros/galactic/setup.bash
source install/setup.bash
MAP_FILE=~/turtlebot3_ws/maps/map_6f.yaml ~/turtlebot3_ws/scripts/start_mission_tmux.sh
```

그다음:

1. RViz에서 `2D Pose Estimate`로 로봇 시작 위치를 찍는다.
2. Web UI를 연다: `https://hisameogasahara.github.io/ros_webclient/`
3. `urls` tmux 창에 나온 `wss://...` 주소를 Web UI에 입력한다.
4. 방 A/B와 물품을 고른 뒤 배송 또는 회수를 누른다.
5. 상태는 tmux의 `debug`, `mission`, `nav`, `vision`, `manipulator` 창에서 확인한다.

종료:

```bash
~/turtlebot3_ws/scripts/stop_mission_tmux.sh
```

## 문서

| 문서 | 내용 |
|---|---|
| `docs/MISSION.md` | 미션 흐름과 실행 방법 |
| `docs/HARDWARE.md` | Jetson, 장치명, 카메라, 하드웨어 설정 |
| `docs/CODEBASE.md` | ROS2 패키지 구조, 노드, 토픽, entry point |
| `docs/NETWORK.md` | Web UI, WebSocket bridge, tunnel, SSH/Tailscale 기준 |
| `docs/AUXILIARY.md` | 모델 학습, XAI, 네트워크 테스트 등 보조 자료 |
| `docs/issues/` | 경로 문제, 하드웨어 문제, LiDAR/pose 문제 기록 |

## 마스킹 기준

IP, SSH key 경로, Tailscale 계정, tunnel 주소는 `<JETSON_HOST>`, `<SSH_KEY_PATH>`, `<TUNNEL_WSS_URL>`처럼 표기한다. 모델 파일 본체와 TensorRT engine 파일은 Jetson 런타임 리소스로 관리한다.
