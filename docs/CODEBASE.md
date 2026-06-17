# 코드베이스 구조와 동작

## 전체 미션 흐름

```text
Web UI
  -> WebSocket bridge
  -> /move_request
  -> mission controller
  -> Nav2 NavigateToPose
  -> vision / gesture
  -> /manipulator/motion_id
  -> manipulator
  -> /move_resume
  -> /move_finish
  -> Web UI
```

배송은 `/mediapipe/start`, 회수는 `/inference_switch`와 `/item_detector/start`로 인식 흐름을 시작한다.

## ROS2 workspace 구조

| 경로 | 역할 |
|---|---|
| `turtlebot3_ws/src/rtreebot` | WebSocket bridge, 미션 제어, Nav2 goal 관리 |
| `turtlebot3_ws/src/camera_ros` | CSI camera 입력, `/camera`, `/detectnet/result` 발행 |
| `turtlebot3_ws/src/item_detector` | 회수 물품 검출 결과를 motion id로 변환 |
| `turtlebot3_ws/src/mediapipe_hand_tracker` | 배송 흐름의 손동작 인식 |
| `turtlebot3_ws/src/manipulator` | 저장 motion JSON 재생, Dynamixel 위치 명령 발행 |
| `turtlebot3_ws/src/dynamixel_sdk*` | Dynamixel 통신, custom interface, read/write node |
| `turtlebot3_ws/src/sllidar_ros2` | LiDAR `/scan` 발행 |
| `turtlebot3_ws/src/turtlebot3`, `turtlebot3_msgs` | base bringup, robot description, Nav2 설정, 메시지 |

수동조작용 `turtlebot3_teleop`와 지도 생성을 위한 `turtlebot3_cartographer`는 TurtleBot3 소스 안에 보존한다.

## 주요 토픽

| 토픽 | 흐름 | 역할 |
|---|---|---|
| `/move_request` | WebSocket bridge -> mission controller | 웹 요청 전달 |
| `/mediapipe/start` | mission controller -> MediaPipe hand tracker | 배송 손동작 인식 시작 |
| `/inference_switch` | mission controller -> camera node | 회수 객체 인식 활성화 |
| `/item_detector/start` | mission controller -> item detector | 회수 물품 검출 시작 |
| `/detectnet/result` | camera node -> item detector | 객체 인식 결과 |
| `/manipulator/motion_id` | hand tracker 또는 item detector -> manipulator | 물품별 motion 실행 |
| `/set_position` | manipulator -> Dynamixel control node | Dynamixel joint 위치 명령 |
| `/move_resume` | manipulator -> mission controller | 매니퓰레이터 작업 완료 |
| `/move_finish` | mission controller -> WebSocket bridge | Web UI 완료 이벤트 |
| `/scan` | LiDAR -> Nav2/AMCL | 위치추정과 navigation 입력 |

## 노드와 entry point

| 명령 | entry point |
|---|---|
| `ros2 run rtreebot delivery_bridge` | `rtreebot.delivery_bridge_node:main` |
| `ros2 run rtreebot delivery_ctrl` | `rtreebot.delivery_ctrl:main` |
| `ros2 run camera_ros publisher` | `camera_ros.publisher:main` |
| `ros2 run camera_ros video_test` | `camera_ros.video_test:main` |
| `ros2 run item_detector detection` | `item_detector.detection:main` |
| `ros2 run mediapipe_hand_tracker hand_tracker_node` | `mediapipe_hand_tracker.hand_tracker_node:main` |
| `ros2 run manipulator manipulatorCtrl` | `manipulator.manipulatorCtrl:main` |
| `ros2 run manipulator manipulatorGUI` | `manipulator.manipulatorGUI:main` |

## 요청 형식

| 요청 | 예시 |
|---|---|
| 배송 | `A_driver_call`, `B_pen_call` |
| 회수 | `A_driver_recall`, `B_wrench_recall` |

허용 값:

| 종류 | 값 |
|---|---|
| 방 | `A`, `B` |
| 물품 | `driver`, `block`, `pen`, `wrench` |
| 모드 | `call`, `recall` |

## 물품별 motion id

| 물품 | motion id |
|---|---:|
| `block` | 1 |
| `wrench` | 2 |
| `driver` | 3 |
| `pen` | 4 |

## 실행 리소스

| 리소스 | 위치 |
|---|---|
| 지도 | `turtlebot3_ws/maps/map_6f.yaml`, `map_6f.pgm` |
| manipulator motion | `turtlebot3_ws/src/manipulator/manipulator/saved_motions.json` |
| camera labels | `turtlebot3_ws/src/camera_ros/camera_ros/labels.txt` |
| model checksum | `turtlebot3_ws/src/camera_ros/camera_ros/ssd-mobilenet.onnx.sha256sum` |
