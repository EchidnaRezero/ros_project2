# Jetson / Work Ref Status

기준일: 2026-06-15

이 문서는 Jetson 실제 workspace `/home/jetson/turtlebot3_ws`와 백업/정리본 `work_ref_jetson_ready/turtlebot3_ws` 사이에 남아 있는 차이만 기록한다.

## 기준

Jetson이 실사용 환경이다. `work_ref_jetson_ready`는 Jetson 실사용 코드를 보존하고 재현하기 위한 work_ref 백업본이다.

따라서 동기화 방향은 무조건 `work_ref_jetson_ready -> Jetson`이 아니다.

```text
Jetson에서 실제 검증된 파일이면 Jetson -> work_ref_jetson_ready
work_ref_jetson_ready의 정리본이 명백히 최신이고 Jetson 빌드에도 필요한 파일이면 work_ref_jetson_ready -> Jetson
판단이 애매하면 먼저 백업하고 차이만 문서화
```

## 현재 핵심 실행 코드 상태

아래 핵심 파일/패키지는 checksum 기준으로 Jetson과 `work_ref_jetson_ready`가 일치한다.

```text
scripts/*.sh
src/rtreebot/rtreebot/delivery_ctrl.py
src/rtreebot/rtreebot/delivery_bridge_node.py
src/item_detector/
src/mediapipe_hand_tracker/
src/manipulator/ 주요 코드, launch, saved motion json, ui
src/camera_ros/camera_ros/publisher.py
src/turtlebot3/turtlebot3_bringup/launch/robot.launch.py
```

최근 반영:

```text
scripts/start_mission_tmux.sh
  - rtree-mission tmux 터미널과 별도로 rtree-safety GNOME terminal 요청
  - safety 메뉴는 tmux safety window에도 유지
  - GNOME terminal 실행 명령의 trailing shell 제거. 세션 종료 시 빈 쉘 창이 남지 않도록 함
```

Jetson 실제 사용 경로의 Dynamixel 예제도 `work_ref_jetson_ready`의 같은 내용과 일치한다.

```text
Jetson:
/home/jetson/turtlebot3_ws/src/DynamixelSDK/ros/dynamixel_sdk_examples/src/read_write_node_omx.py

work_ref_jetson_ready:
work_ref_jetson_ready/turtlebot3_ws/src/dynamixel_sdk_examples/src/read_write_node_omx.py
```

## 남은 의미 있는 차이

현재 남은 차이는 주로 `src/rtreebot`의 패키징/부가 파일이다.

| 파일 | 상태 | 판단 |
|---|---|---|
| `src/rtreebot/package.xml` | Jetson과 work_ref_jetson_ready 내용 다름 | clean build 관점에서 확인 필요 |
| `src/rtreebot/setup.py` | Jetson과 work_ref_jetson_ready 내용 다름 | clean build 관점에서 확인 필요 |
| `src/rtreebot/resource/rtreebot` | Jetson은 빈 파일, work_ref_jetson_ready는 문자열 있음 | 런타임 영향 낮음 |
| `src/rtreebot/basic.html` | Jetson에만 있음 | 과거/보조 웹 파일로 보임 |
| `src/rtreebot/real.html` | Jetson에만 있음 | 과거/보조 웹 파일로 보임 |
| `src/rtreebot/launch/delivery*.launch.py` | Jetson에만 있음 | 과거 launch일 수 있으나 보존 필요 |
| `src/rtreebot/test/*` | Jetson에만 있음 | 패키지 기본 테스트 파일 |
| `src/rtreebot/web/user.html` | work_ref_jetson_ready에만 있음 | 현재 GitHub Pages 방식에서는 핵심 아님 |
| `src/rtreebot/docs/*` | work_ref_jetson_ready에만 있음 | 문서 백업 |

## 주의할 점

Jetson의 `rtreebot/setup.py`에는 아래 entry point가 남아 있다.

```text
delivery_ctrl_basic
delivery_bridge_basic
```

하지만 현재 Jetson 소스에는 대응하는 `.py` 파일이 보이지 않고 `__pycache__` 흔적만 확인된다. clean build 시 문제가 될 수 있으므로, 동기화 전에 실제로 필요한 과거 entry point인지 확인한다.

Jetson의 `rtreebot/package.xml`에는 `delivery_ctrl.py`가 import하는 `nav2_msgs`가 빠져 있고, `work_ref_jetson_ready`에는 `nav2_msgs`가 들어 있다. clean build 기준으로는 `work_ref_jetson_ready` 쪽이 더 정리된 상태로 보인다.

## 백업

동기화 판단 전 Jetson 차이 파일을 백업했다.

```text
/home/jetson/Desktop/backup3/jetson_rtreebot_diff_before_sync_20260615_171353.tar.gz
```

로컬 프로젝트 루트에도 동기화 후보 파일만 양쪽 기준으로 따로 모아둔 백업을 만들었다.

```text
sync_candidate_backup_20260615_183320/
  work_ref_before_sync/
  jetson_before_sync/
  README.md
  candidate_files.txt
```

주의: `sync_candidate_backup_20260615_183227/`는 Windows 줄바꿈 때문에 Jetson tar가 제대로 들어가지 않은 첫 시도다. 실제 동기화 전 백업 기준은 `sync_candidate_backup_20260615_183320/`를 사용한다.

백업 대상:

```text
src/rtreebot/package.xml
src/rtreebot/setup.py
src/rtreebot/resource/rtreebot
src/rtreebot/basic.html
src/rtreebot/real.html
src/rtreebot/launch/delivery.launch.py
src/rtreebot/launch/delivery_basic.launch.py
src/rtreebot/test/test_copyright.py
src/rtreebot/test/test_flake8.py
src/rtreebot/test/test_pep257.py
```

## 권장 다음 작업

1. 지금 바로 전체 덮어쓰기 하지 않는다.
2. `rtreebot/package.xml`, `setup.py`를 clean build 기준으로 어떤 쪽이 맞는지 결정한다.
3. Jetson-only로 남길 과거 파일과 `work_ref_jetson_ready`에 보존할 파일을 나눈다.
4. 방향이 정해지면 백업 후 한쪽으로 동기화한다.
