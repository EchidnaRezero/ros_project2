# LiDAR / Pose Estimation Issue 2026-06-16

RViz 초기 위치 지정과 Nav2 위치추정 실패를 `/scan` 부재와 LiDAR USB-Serial 계층 문제로 좁힌 사건 기록.

## 증상

- RViz에서 `2D Pose Estimate` 지정 시 화면이 초기화되는 것처럼 보임
- Nav2/AMCL 위치추정 불안정
- global costmap과 RViz가 `map` frame을 기다리며 메시지 폐기

## 검증 순서

1. `/scan` 수신 여부 확인

```bash
ros2 topic hz /scan
```

2. LiDAR 장치명과 USB-Serial 상태 확인

```bash
ls -l /dev/ttyLidar /dev/ttyUSB* 2>/dev/null
stty -F /dev/ttyLidar -a
dmesg | tail -100
```

3. bringup 로그 확인

```bash
tmux capture-pane -t rtree-mission:bringup -p
```

정상 기준:

```text
SLLidar health status : OK.
current scan mode: Standard
```

단독 LiDAR 실행:

```bash
source /opt/ros/galactic/setup.bash
source ~/turtlebot3_ws/install/setup.bash
ros2 launch sllidar_ros2 sllidar_c1_launch.py serial_port:=/dev/ttyLidar frame_id:=base_scan
```

Galactic 환경에서 `ros2 topic echo --once`가 맞지 않으면 `timeout`으로 짧게 제한.

```bash
timeout 6 ros2 topic echo /scan sensor_msgs/msg/LaserScan
```

## 확인한 사실

- `sllidar_node` 종료로 `/scan`이 사라진 상태 확인
- `/scan` 부재로 AMCL이 `map -> odom -> base_link` TF 흐름 생성 실패
- `/dev/ttyLidar -> /dev/ttyUSB0` CP210x 장치에서 `Input/output error` 확인
- kernel log에 `cp210x_open - Unable to enable UART`, `failed set request ... status: -110` 계열 메시지 기록
- LiDAR 단독 실행에서도 `sllidar_node` 실패
- 실패 지점은 포트 bind 자체보다 장치 정보 요청 단계로 좁혀짐
- `80008004`는 `SL_RESULT_OPERATION_NOT_SUPPORT`로 확인
- `gpsd`와 `ModemManager`를 잠시 중지해도 같은 실패가 재현되어 주요 원인으로 보기는 어려움
- baudrate 후보 `460800`, `115200`, `256000`, `1000000` 변경만으로는 정상 device info 응답을 확인하지 못함

## 진단

직접 원인:

```text
LiDAR scan 미수신 -> AMCL 위치추정 실패 -> Nav2/RViz map frame 대기
```

하드웨어 계층 후보:

```text
USB-Serial 초기화 실패
케이블/허브/전원 불안정
LiDAR 재연결 후 기존 sllidar_node 복구 실패
```

코드/설정 계층 후보:

```text
sllidar launch 인자명 불일치 여부
/dev/ttyUSB0 직접값 사용 여부
udev symlink /dev/ttyLidar 반영 여부
```

## 조치

- `robot.launch.py`에서 LiDAR launch 인자를 `serial_port=/dev/ttyLidar` 기준으로 사용
- LiDAR 물리 재연결 후 미션 세션 재시작

```bash
~/turtlebot3_ws/scripts/stop_mission_tmux.sh
~/turtlebot3_ws/scripts/start_mission_tmux.sh
```

## 확정한 범위

- 재연결 후 Jetson 본체 USB, 확장 허브, 전체 주변기기 조합에서 `/scan` 정상 수신 확인
- `/scan` 정상 수신 후 RViz/Nav2 위치추정 흐름 복구 가능성 확인
- 전체 장치 조합에서 약 10 Hz `/scan` 수신이 유지된 구간 확인

## 확정하지 못한 범위

- CP210x I/O error의 단일 원인 확정 불가
- 케이블, 허브, 전원, LiDAR 초기화 중 어느 하나로 단정하지 않음
- 가장 보수적인 결론은 순간적인 USB-Serial, 케이블, 허브, 전원, 초기화 문제
- 특정 주변기기 하나의 고정 결함이나 ROS 코드 결함으로 단정하지 않음

## 재발 시 판단 기준

- `/dev/ttyLidar` 없음: udev/symlink 또는 물리 연결 문제
- `/dev/ttyLidar` 있음, `/scan` 없음: `sllidar_node`와 bringup 로그 확인
- kernel log에 CP210x error 반복: USB-Serial/전원/케이블 계층 우선 점검
- LiDAR 재연결 직후: 미션 세션 재시작부터 수행

재발 직후 저장할 로그:

```bash
dmesg -T | grep -Ei 'cp210|ttyUSB|error -110|error -71|unable to enumerate|over-current'
lsusb -t
ls -l /dev/ttyLidar /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || true
stty -F /dev/ttyLidar -a
ros2 topic hz /scan
```
