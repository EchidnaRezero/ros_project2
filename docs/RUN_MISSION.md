# Run Mission

기준일: 2026-06-15

이 문서는 Jetson에서 현재 미션을 실행할 때 보는 운영 문서다.

## 같이 볼 문서

```text
SSH_TAILSCALE_JETSON.md
JETSON_HARDWARE_SETTINGS.md
JETSON_HARDWARE_TROUBLESHOOTING.md
JETSON_WORK_REF.md
```

미션 이미지:

```text
work_ref_jetson_ready/guide/mission/s0.png ... s6.png
```

수신호 그림:

```text
LAMBDA_GESTURE_GUIDE.html
```

주의: 현재 코드의 `lambda_sign`은 이름과 달리 L/V 모양이 아니라 MediaPipe landmark 기준 `thumb_tip`과 `index_tip`이 가까운 pinch/OK 모양에 가깝다.

## Jetson 접속

```powershell
ssh -i $env:USERPROFILE\.ssh\id_ed25519_jetson_hisame jetson@100.101.167.4
```

Jetson workspace:

```text
/home/jetson/turtlebot3_ws
```

## 다음 세션 시작 체크

다음 AI가 처음 들어오면 아래 순서로 현재 상태를 확인한다.

```bash
tmux ls
ps -eo pid,ppid,stat,cmd | grep -Ei "mission|rtree|nav2|bringup|manipulator|dynamixel|camera|cloudflared" | grep -v grep
ls -l /dev/ttyRtreeCon /dev/ttyManipCon /dev/ttyLidar /dev/video0 2>/dev/null
cat ~/turtlebot3_ws/mission_urls.txt 2>/dev/null || true
```

판단 기준:

```text
rtree-mission tmux가 있으면 실행 중인 세션을 먼저 확인
tmux가 없으면 미션은 꺼진 상태로 보고 start_mission_tmux.sh 실행 가능
로봇팔이 뻣뻣해도 manipulator 노드가 없을 수 있음. 토크 잔류 여부는 JETSON_HARDWARE_TROUBLESHOOTING.md 참고
코드 동기화 판단은 JETSON_WORK_REF.md 참고
```

## 실행

Jetson에서:

```bash
~/turtlebot3_ws/scripts/start_mission_tmux.sh
```

이 스크립트는 `rtree-mission` tmux 세션을 만들고 Jetson 모니터에 GNOME terminal을 열어 붙인다. 기본 선택 창은 `debug`다.
비상 정지는 별도 `rtree-safety` GNOME terminal로도 열린다.
미션 세션이나 safety 메뉴가 종료되면 이 별도 GNOME terminal 창도 같이 닫히도록 되어 있다.

생성 window:

```text
urls
safety
bridge
bringup
nav
mission
vision
manipulator
debug
```

웹 UI:

```text
https://hisameogasahara.github.io/ros_webclient/
```

WSS 주소는 실행 후 아래 파일 또는 `urls` 창에 표시된다.

```text
~/turtlebot3_ws/mission_urls.txt
```

## 사용 순서

1. `start_mission_tmux.sh` 실행
2. RViz에서 `2D Pose Estimate`로 초기 위치/방향 지정
3. 웹 UI에 `wss://...trycloudflare.com` 입력 후 연결
4. 주문/회수 테스트
5. 상태 확인은 tmux `debug`, `mission`, `nav`, `vision`, `manipulator` 창 확인

tmux 창 이동:

```text
Ctrl-b 누른 뒤 창 번호
```

## Safety

Jetson 화면의 `rtree-safety` 터미널:

```text
1) Stop bringup/nav motion
2) Stop all mission tmux
q) Quit this safety menu only
```

같은 메뉴는 tmux 안의 `safety` 창에도 있다. tmux에서 보려면 `Ctrl-b` 누른 뒤 `1`을 누른다.

1번은 `/cmd_vel` 0을 여러 번 보낸 뒤 `nav`, `bringup`에 Ctrl-C를 보낸다.
2번은 `/cmd_vel` 0을 보낸 뒤 `rtree-mission` 전체를 종료한다.

전체 종료:

```bash
~/turtlebot3_ws/scripts/stop_mission_tmux.sh
```

중요: 현재 전체 종료는 미션 프로세스/tmux를 끄는 기능이다. 로봇팔 Dynamixel torque off는 자동 보장되지 않는다. 완전 대기 상태로 만들려면 `JETSON_HARDWARE_TROUBLESHOOTING.md`의 torque off 절차로 ID 11-15가 모두 OFF인지 확인한다.

## 미션 흐름

웹 주문:

```text
GitHub Pages UI -> Cloudflare quick tunnel -> delivery_bridge -> /move_request
```

`delivery_ctrl.py`:

```text
call   -> A/B 이동 성공 후 /mediapipe/start=item publish
recall -> A/B 이동 성공 후 /inference_switch=True, /item_detector/start=True publish
완료   -> /move_resume=True 수신 후 HOME 복귀 및 /move_finish=True publish
```

item-motion 기준:

```text
block  -> 1
wrench -> 2
driver -> 3
pen    -> 4
```

수신호 기준:

```text
현재 lambda_sign 코드: thumb_tip과 index_tip이 가까운 pinch/OK 형태
네가 생각한 L/V/Λ 모양: 현재 코드에서는 실패할 수 있음
자세한 MediaPipe 뼈대 그림: LAMBDA_GESTURE_GUIDE.html
```

## 확인 명령

```bash
cd ~/turtlebot3_ws
source /opt/ros/galactic/setup.bash
source install/setup.bash

ros2 topic list
ros2 topic echo /move_request
ros2 topic echo /mediapipe/start
ros2 topic echo /manipulator/motion_id
ros2 topic echo /move_resume
ros2 topic echo /move_finish
ros2 topic hz /scan
```

장치 확인:

```bash
ls -l /dev/ttyRtreeCon /dev/ttyManipCon /dev/ttyLidar /dev/video0
v4l2-ctl --list-devices
systemctl is-active nvargus-daemon
```

## Jetson-only 보존 자산

삭제식 전체 덮어쓰기 금지. 아래는 Jetson 기존 위치를 보존한다.

```text
/home/jetson/map_6f.yaml
/home/jetson/map_6f.pgm
/home/jetson/mp_env
/home/jetson/turtlebot3_ws/src/camera_ros/camera_ros/ssd-mobilenet.onnx
/home/jetson/turtlebot3_ws/src/camera_ros/camera_ros/ssd-mobilenet.onnx.1.1.8001.GPU.FP16.engine
```
