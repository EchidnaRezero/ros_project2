# Jetson 반영 전 작업 노트

이 폴더는 Jetson 실사용 코드를 보존하고 재현하기 위해 정리한 work_ref 트리다.

원칙:

- Jetson 실사용 환경과 비교한 뒤, 필요한 코드 파일만 방향을 정해 동기화한다.
- Jetson의 전체 워크스페이스를 무겁게 가져오지 않는다.
- 하드웨어 포트, Dynamixel 포트, 모델 engine처럼 Jetson 실제 환경에 묶인 항목은 신중하게 따로 다룬다.

## 우선 적용 방향

| 영역 | 기준 |
|---|---|
| `mediapipe_hand_tracker/hand_tracker_node.py` | ref 기준. 람다 수신호 지원 유지 |
| `rtreebot/delivery_ctrl.py` | ref 기준으로 정리하되 회수 흐름은 별도 검토 |
| Web UI | 별도 `github_pages_robot_ui` 프로젝트에서 관리 |
| 지도 경로 | Jetson 실제 지도 `/home/jetson/map_6f.yaml`, `/home/jetson/map_6f.pgm` 보존 |
| 모델 파일 | Jetson 실제 위치 `src/camera_ros/camera_ros/` 유지 |
| Dynamixel / 하드웨어 포트 | 역할 기반 symlink 사용: `/dev/ttyRtreeCon`, `/dev/ttyManipCon`, `/dev/ttyLidar` |
| Cloudflare bridge | `turtlebot3_ws/scripts/start_mission_tmux.sh`가 bridge/quick tunnel까지 자동 실행 |

## Jetson으로 옮길 후보 파일

| 후보 | Jetson 대상 경로 |
|---|---|
| `turtlebot3_ws/src/mediapipe_hand_tracker/mediapipe_hand_tracker/hand_tracker_node.py` | `/home/jetson/turtlebot3_ws/src/mediapipe_hand_tracker/mediapipe_hand_tracker/hand_tracker_node.py` |
| `turtlebot3_ws/src/rtreebot/rtreebot/delivery_ctrl.py` | `/home/jetson/turtlebot3_ws/src/rtreebot/rtreebot/delivery_ctrl.py` |
| `turtlebot3_ws/src/item_detector/` | `/home/jetson/turtlebot3_ws/src/item_detector/` |
| `turtlebot3_ws/scripts/*.sh` | `/home/jetson/turtlebot3_ws/scripts/` |
| `turtlebot3_ws/src/turtlebot3/turtlebot3_bringup/launch/robot.launch.py` | `/home/jetson/turtlebot3_ws/src/turtlebot3/turtlebot3_bringup/launch/robot.launch.py` |
| `turtlebot3_ws/src/manipulator/launch/*.launch.py` | `/home/jetson/turtlebot3_ws/src/manipulator/launch/` |
| `turtlebot3_ws/src/camera_ros/camera_ros/publisher.py` | `/home/jetson/turtlebot3_ws/src/camera_ros/camera_ros/publisher.py` |

## 주의

Jetson 현재 기준은 다음과 같다.

```text
TurtleBot3 base / Rtree -> /dev/ttyRtreeCon
Manipulator OpenRB      -> /dev/ttyManipCon
LiDAR                   -> /dev/ttyLidar
Camera                  -> csi://0
```

`/dev/ttyACM0`, `/dev/ttyACM1`, `/dev/ttyUSB0` 직접값은 연결 순서에 따라 바뀔 수 있으므로 새 코드에서는 역할 기반 symlink를 기준으로 한다.

## 관련 문서

| 문서 | 내용 |
|---|---|
| `JETSON_ONLY_RESOURCES.md` | 작업 트리에 넣지 않는 Jetson-only/무거운 리소스 |
| `CLOUDFLARE_QUICKTUNNEL.md` | 무료 Cloudflare quick tunnel 방식 |
| `turtlebot3_ws/scripts/start_bridge_quicktunnel.sh` | 브릿지와 quick tunnel 동시 실행 helper |

## 데모용 브릿지 입력 정책

브릿지는 외부 quick tunnel로 열리지만, 데모 편의성을 위해 token/Origin 체크는 넣지 않는다. 대신 다음 조합만 ROS `/move_request`로 발행한다.

- action: `create_order`, `retrieve_item`
- destination: `A`, `B`
- item: `driver`, `block`, `pen`, `wrench`

나머지는 WebSocket 에러 응답만 보내고 ROS 토픽으로 발행하지 않는다.
