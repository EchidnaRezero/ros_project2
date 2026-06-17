# 미션

## 미션 목적

웹 UI에서 방, 물품, 배송/회수 요청을 선택하면 Jetson의 ROS2 로봇이 요청을 처리한다.

로봇은 Nav2로 목적지까지 이동하고, 카메라 인식 또는 손동작 인식 후 Dynamixel 매니퓰레이터로 물품을 전달하거나 회수한다. 작업이 끝나면 ROS2 완료 신호가 WebSocket bridge를 통해 Web UI에 표시된다.

## 전체 흐름

```text
Web UI
  -> wss://<TUNNEL_WSS_URL>
  -> Jetson WebSocket bridge
  -> ROS2 /move_request
  -> Nav2 목적지 이동
  -> 배송: MediaPipe 손동작 확인
  -> 회수: camera / DetectNet 객체 인식
  -> Dynamixel manipulator motion 실행
  -> ROS2 /move_finish
  -> Web UI 완료 상태 갱신
```

## 실행 전 확인

```bash
tmux ls
ls -l /dev/ttyRtreeCon /dev/ttyManipCon /dev/ttyLidar /dev/video0 2>/dev/null
systemctl is-active nvargus-daemon
```

기본 기준:

| 항목 | 기준 |
|---|---|
| Workspace | `~/turtlebot3_ws` |
| ROS2 | Galactic |
| Web UI | `https://hisameogasahara.github.io/ros_webclient/` |
| 지도 | `~/turtlebot3_ws/maps/map_6f.yaml` |

## 실행 순서

Jetson 터미널에서:

```bash
cd ~/turtlebot3_ws
source /opt/ros/galactic/setup.bash
source install/setup.bash
MAP_FILE=~/turtlebot3_ws/maps/map_6f.yaml ~/turtlebot3_ws/scripts/start_mission_tmux.sh
```

그다음:

1. RViz에서 `2D Pose Estimate`로 로봇의 시작 위치와 방향을 찍는다.
2. Web UI를 연다: `https://hisameogasahara.github.io/ros_webclient/`
3. `urls` tmux 창에 표시된 `wss://<TUNNEL_WSS_URL>` 주소를 Web UI에 입력한다.
4. 방 A 또는 B를 선택한다.
5. `driver`, `block`, `pen`, `wrench` 중 물품을 선택한다.
6. 배송 또는 회수 요청을 보낸다.
7. tmux의 `debug`, `mission`, `nav`, `vision`, `manipulator` 창에서 상태를 확인한다.

종료:

```bash
~/turtlebot3_ws/scripts/stop_mission_tmux.sh
```

## tmux 창

| 창 | 역할 |
|---|---|
| `urls` | Web UI와 tunnel 주소 확인 |
| `safety` | 안전 정지 메뉴 |
| `bridge` | WebSocket bridge와 tunnel |
| `bringup` | TurtleBot3 base bringup |
| `nav` | Nav2 실행 |
| `mission` | 배송/회수 mission controller |
| `vision` | camera, object detection, hand tracking |
| `manipulator` | Dynamixel manipulator control |
| `debug` | 상태 확인 |

tmux 창 이동은 `Ctrl-b`를 누른 뒤 창 번호를 누른다.

## 배송 흐름

1. Web UI에서 배송 요청을 보낸다.
2. WebSocket bridge가 요청을 ROS2 `/move_request`로 바꾼다.
3. 요청 예시는 `A_driver_call`, `B_pen_call`이다.
4. `delivery_ctrl.py`가 Nav2 goal을 보내 목적지로 이동한다.
5. 목적지 이동 성공 후 `/mediapipe/start`에 물품 이름을 발행한다.
6. MediaPipe 손동작 인식이 성공하면 `/manipulator/motion_id`를 발행한다.
7. 매니퓰레이터가 저장된 motion sequence를 실행한다.
8. 매니퓰레이터 동작 후 `/move_resume`이 발행된다.
9. `delivery_ctrl.py`가 HOME 복귀 goal을 보내고 `/move_finish`를 발행한다.
10. Web UI가 완료 상태로 갱신된다.

## 회수 흐름

1. Web UI에서 회수 요청을 보낸다.
2. WebSocket bridge가 요청을 ROS2 `/move_request`로 바꾼다.
3. 요청 예시는 `A_driver_recall`, `B_wrench_recall`이다.
4. `delivery_ctrl.py`가 Nav2 goal을 보내 목적지로 이동한다.
5. 목적지 이동 성공 후 `/inference_switch=True`와 `/item_detector/start=True`를 발행한다.
6. camera node와 item detector가 회수 대상 물품을 찾는다.
7. 물품이 확인되면 `/manipulator/motion_id`를 발행한다.
8. 매니퓰레이터가 회수 motion sequence를 실행한다.
9. 매니퓰레이터 동작 후 `/move_resume`이 발행된다.
10. `delivery_ctrl.py`가 HOME 복귀 goal을 보내고 `/move_finish`를 발행한다.
11. Web UI가 완료 상태로 갱신된다.

## 물품별 motion id

| 물품 | motion id |
|---|---:|
| `block` | 1 |
| `wrench` | 2 |
| `driver` | 3 |
| `pen` | 4 |

## 실제 코드 기준 주의점

- `/move_resume=True`를 받으면 HOME 복귀 goal과 `/move_finish`가 함께 발행된다.
- 배송 요청은 목적지 이동 성공 후 `/mediapipe/start=<item>`을 발행한다.
- 회수 요청은 목적지 이동 성공 후 `/inference_switch=True`와 `/item_detector/start=True`를 발행한다.
- quick tunnel 주소는 실행할 때마다 바뀔 수 있다.
- `stop_mission_tmux.sh`는 미션 프로세스와 tmux를 끄는 기능이다. Dynamixel torque off는 별도 확인이 필요하다.

## 확인용 ROS2 토픽

```bash
ros2 topic list
ros2 topic echo /move_request
ros2 topic echo /mediapipe/start
ros2 topic echo /manipulator/motion_id
ros2 topic echo /move_resume
ros2 topic echo /move_finish
ros2 topic hz /scan
```
