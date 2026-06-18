# 미션

## 미션 목적

웹 UI에서 방, 물품, 배송/회수 요청을 선택하면 Jetson의 ROS2 로봇이 요청 처리.

로봇은 Nav2로 목적지까지 이동하고, 카메라 인식 또는 손동작 인식 후 Dynamixel 매니퓰레이터로 물품 전달 또는 회수. 작업 완료 후 ROS2 완료 신호가 WebSocket bridge를 통해 Web UI에 표시.

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
ps -eo pid,ppid,stat,cmd | grep -Ei "mission|rtree|nav2|bringup|manipulator|dynamixel|camera|cloudflared" | grep -v grep
ls -l /dev/ttyRtreeCon /dev/ttyManipCon /dev/ttyLidar /dev/video0 2>/dev/null
systemctl is-active nvargus-daemon
cat ~/turtlebot3_ws/mission_urls.txt 2>/dev/null || true
```

`rtree-mission` tmux 세션이 이미 있으면 실행 중인 세션 상태를 먼저 확인.

기본 기준:

| 항목 | 기준 |
|---|---|
| Workspace | `~/turtlebot3_ws` |
| ROS2 | Galactic |
| Web UI | `https://echidnarezero.github.io/ros_project2/web_client/` |
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

1. RViz에서 `2D Pose Estimate`로 로봇의 시작 위치와 방향 지정.
2. Web UI 열기: `https://echidnarezero.github.io/ros_project2/web_client/`
3. `urls` tmux 창에 표시된 `wss://<TUNNEL_WSS_URL>` 주소를 Web UI에 입력.
4. 방 A 또는 B 선택.
5. `driver`, `block`, `pen`, `wrench` 중 물품 선택.
6. 배송 또는 회수 요청 전송.
7. tmux의 `debug`, `mission`, `nav`, `vision`, `manipulator` 창에서 상태 확인.

종료:

```bash
~/turtlebot3_ws/scripts/stop_mission_tmux.sh
```

완전 대기 상태가 필요하면 Dynamixel torque off를 별도로 확인. 절차는 `docs/issues/HARDWARE_TROUBLESHOOTING.md` 참고.

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

tmux 창 이동은 `Ctrl-b`를 누른 뒤 창 번호 입력.

## 배송 흐름

1. Web UI에서 배송 요청 전송.
2. WebSocket bridge가 요청을 ROS2 `/move_request`로 변환.
3. 요청 예시: `A_driver_call`, `B_pen_call`
4. `delivery_ctrl.py`가 Nav2 goal을 보내 목적지로 이동.
5. 목적지 이동 성공 후 `/mediapipe/start`에 물품 이름 발행.
6. MediaPipe 손동작 인식 성공 시 `/manipulator/motion_id` 발행.
7. 매니퓰레이터가 저장된 motion sequence 실행.
8. 매니퓰레이터 동작 후 `/move_resume` 발행.
9. `delivery_ctrl.py`가 HOME 복귀 goal을 보내고 `/move_finish` 발행.
10. Web UI 완료 상태 갱신.

## 회수 흐름

1. Web UI에서 회수 요청 전송.
2. WebSocket bridge가 요청을 ROS2 `/move_request`로 변환.
3. 요청 예시: `A_driver_recall`, `B_wrench_recall`
4. `delivery_ctrl.py`가 Nav2 goal을 보내 목적지로 이동.
5. 목적지 이동 성공 후 `/inference_switch=True`와 `/item_detector/start=True` 발행.
6. camera node와 item detector가 `pen`, `driver`, `block`, `wrench` 중 감지된 물품 검색.
7. 물품 확인 시 `/manipulator/motion_id` 발행.
8. 매니퓰레이터가 회수 motion sequence 실행.
9. 매니퓰레이터 동작 후 `/move_resume` 발행.
10. `delivery_ctrl.py`가 HOME 복귀 goal을 보내고 `/move_finish` 발행.
11. Web UI 완료 상태 갱신.

## 물품별 motion id

물품별 motion id 기준은 `docs/CODEBASE.md` 참고.

## 실제 코드 기준 주의점

- `/move_resume=True` 수신 시 HOME 복귀 goal과 `/move_finish` 함께 발행.
- 배송 요청은 목적지 이동 성공 후 `/mediapipe/start=<item>` 발행.
- 회수 요청은 목적지 이동 성공 후 `/inference_switch=True`와 `/item_detector/start=True` 발행.
- 회수 요청의 `item` 값은 item detector에 미전달. detector는 감지된 지원 물품의 motion id 발행.
- 현재 `lambda_sign` 이름은 실제 손모양 조건과 다를 수 있음. 코드 기준은 MediaPipe landmark에서 엄지와 검지가 가까운 pinch/OK 형태.
- quick tunnel 주소는 실행할 때마다 변경 가능.

## 확인용 ROS2 토픽

주요 토픽 목록은 `docs/CODEBASE.md` 참고.

실행 중 상태 확인:

```bash
ros2 topic echo /move_request
ros2 topic echo /move_finish
ros2 topic hz /scan
```
