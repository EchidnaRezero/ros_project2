# Pose Estimation / LiDAR Issue - 2026-06-16

Jetson에서 미션 실행 중 RViz `2D Pose Estimate`를 찍었을 때 화면이 초기화되는 것처럼 보였고, 이후 LiDAR가 죽어 Nav2/AMCL이 정상 동작하지 않은 문제를 추적한 기록이다.

## 요약

처음에는 `pose estimate`를 찍는 순간 RViz/Nav2가 초기화되는 것처럼 보였다.

조사 결과, 직접 원인은 pose estimate 자체가 아니라 bringup 직후 `sllidar_node`가 죽어 `/scan` 기반 AMCL 위치추정이 성립하지 않은 상태였다. 이 때문에 `map -> odom -> base_link` TF 흐름이 완성되지 않았고, Nav2 global costmap과 RViz가 계속 `map` 프레임을 기다리며 메시지를 버렸다.

최종적으로 LiDAR 포트 `/dev/ttyLidar -> /dev/ttyUSB0`의 CP210x USB-Serial 장치가 커널 레벨에서 `Input/output error` 상태였던 것으로 확인했다.

## 증상

미션 세션을 실행한 뒤 RViz에서 `2D Pose Estimate`를 찍었다.

관찰된 현상:

- RViz 화면이 초기화되거나 다시 그려지는 것처럼 보임
- Nav2에서 초기 pose를 찍었는데도 정상 위치추정이 되는 느낌이 없음
- 이후 주문을 넣으면 로봇이 예정된 방으로 안정적으로 가지 못할 가능성이 높아 보임

이전 폭주 조사에서도 비슷하게 AMCL pose 설정과 TF 관련 경고가 있었기 때문에 처음에는 pose estimate를 늦게 찍었거나 잘못 찍은 것이 원인 후보였다.

## 실행 중 상태 확인

먼저 미션 세션과 주요 프로세스가 살아 있는지 확인했다.

```bash
tmux list-windows -t rtree-mission 2>/dev/null || true

pgrep -af 'navigation2|amcl|controller_server|planner_server|bt_navigator|lifecycle|rviz|delivery_ctrl|bringup|turtlebot3_node' || true
```

확인된 상태:

- `rtree-mission` tmux 세션은 살아 있었음
- `bringup`, `navigation2`, `delivery_ctrl`, `amcl`, `planner_server`, `controller_server`, `rviz2` 프로세스도 살아 있었음
- 즉 전체 세션이 죽거나 재시작된 것은 아니었음

## 확인한 로그

이번 실행의 주요 로그 파일:

```text
/home/jetson/.ros/log/2026-06-16-11-29-24-358701-nano-37645/launch.log
/home/jetson/.ros/log/sllidar_node_38021_1781576973397.log
/home/jetson/.ros/log/rviz2_38384_1781577000723.log
/home/jetson/.ros/log/planner_server_38374_1781576998923.log
/home/jetson/.ros/log/amcl_38368_1781576998750.log
/home/jetson/.ros/log/controller_server_38372_1781576998895.log
```

최근 로그 파일 목록 확인:

```bash
ls -lt /home/jetson/.ros/log | head -40
```

tmux pane 로그 확인:

```bash
tmux capture-pane -t rtree-mission:nav -p -S -220
tmux capture-pane -t rtree-mission:mission -p -S -120
tmux capture-pane -t rtree-mission:debug -p -S -160
tmux capture-pane -t rtree-mission:bringup -p -S -160
tmux capture-pane -t rtree-mission:vision -p -S -120
```

## Nav2 / RViz에서 보인 현상

Nav2 planner 로그에서 `map` 프레임을 찾지 못하는 메시지가 계속 반복됐다.

```text
Timed out waiting for transform from base_link to map to become available,
tf error: Invalid frame ID "map" passed to canTransform argument target_frame - frame does not exist
```

RViz 로그에서는 `/odom` 메시지가 계속 버려졌다.

```text
Message Filter dropping message: frame 'odom' ...
reason 'discarding message because the queue is full'
```

이 상태에서는 RViz에서 pose estimate를 찍어도 AMCL/Nav2가 안정적으로 `map` 기준 위치를 만들 수 없다. 그래서 화면이 초기화되는 것처럼 보일 수 있다.

## ROS graph 조회 시도

다음과 같이 ROS graph와 topic 상태를 보려 했다.

```bash
source /opt/ros/galactic/setup.bash

ros2 node list
ros2 topic list
ros2 topic echo /map nav_msgs/msg/OccupancyGrid --once --field header
ros2 topic echo /amcl_pose geometry_msgs/msg/PoseWithCovarianceStamped --once --field header
ros2 run tf2_ros tf2_echo map odom
ros2 run tf2_ros tf2_echo odom base_link
```

하지만 여러 ROS CLI 명령이 타임아웃됐다. 당시 CPU 부하도 컸다.

확인한 부하 요인:

- `camera_ros publisher`가 높은 CPU 사용률
- `rviz2`도 높은 CPU 사용률
- `debug` 창에서 `ros2 topic echo`가 여러 개 동시에 실행 중

그래서 ROS CLI 조회 자체가 느리거나 멈추는 현상도 있었다. 이때 생긴 타임아웃 명령은 나중에 정리했다.

```bash
pkill -f 'ros2 param get /amcl|ros2 node list|ros2 topic list|tf2_echo map odom|tf2_echo odom base_link' 2>/dev/null || true
```

## Bringup 로그에서 발견한 핵심 단서

bringup 창에서 `sllidar_node`가 시작 직후 죽은 것이 확인됐다.

```text
[sllidar_node]: SLLidar running on ROS2 package SLLidar.ROS2 SDK Version:1.0.1, SLLIDAR SDK Version:2.1.0
[sllidar_node]: Error, unexpected error, code: 80008004
[ERROR] [sllidar_node-2]: process has died [pid 38021, exit code 255, cmd '/home/jetson/turtlebot3_ws/install/sllidar_ros2/lib/sllidar_ros2/sllidar_node ...']
```

해당 로그 파일:

```text
/home/jetson/.ros/log/sllidar_node_38021_1781576973397.log
```

이번 로그 내용:

```text
[INFO] [1781576973.731650078] [sllidar_node]: SLLidar running on ROS2 package SLLidar.ROS2 SDK Version:1.0.1, SLLIDAR SDK Version:2.1.0
[ERROR] [1781576978.904505780] [sllidar_node]: Error, unexpected error, code: 80008004
```

이전 정상 로그와 비교했다.

```text
[INFO] [1781576114.299612218] [sllidar_node]: SLLidar S/N: 8AE4E0F8C6E59AC0B5E29FF909314E00
[INFO] [1781576114.299767273] [sllidar_node]: Firmware Ver: 1.02
[INFO] [1781576114.303747925] [sllidar_node]: SLLidar health status : 0
[INFO] [1781576114.303857615] [sllidar_node]: SLLidar health status : OK.
[INFO] [1781576114.587305654] [sllidar_node]: current scan mode: Standard, sample rate: 5 Khz, max_distance: 16.0 m, scan frequency:10.0 Hz,
```

즉 설정이 항상 틀린 것은 아니고, 이전에는 같은 장비가 정상으로 열린 적이 있다.

## LiDAR 장치 / 포트 확인

bringup 설정 확인:

```bash
sed -n '1,120p' /home/jetson/turtlebot3_ws/src/turtlebot3/turtlebot3_bringup/launch/robot.launch.py
sed -n '1,120p' /home/jetson/turtlebot3_ws/src/sllidar_ros2/launch/sllidar_c1_launch.py
```

`robot.launch.py`는 LiDAR를 다음과 같이 실행한다.

```python
IncludeLaunchDescription(
    PythonLaunchDescriptionSource([lidar_pkg_dir, '/sllidar_c1_launch.py']),
    launch_arguments={'serial_port': '/dev/ttyLidar', 'frame_id': 'base_scan'}.items(),
)
```

`sllidar_c1_launch.py` 기본값:

```text
serial_baudrate: 460800
scan_mode: Standard
```

장치 링크 확인:

```bash
ls -l /dev/ttyLidar /dev/ttyRtreeCon /dev/ttyManipCon /dev/ttyUSB0 /dev/ttyACM0 /dev/ttyACM1 2>/dev/null || true
```

확인 결과:

```text
/dev/ttyLidar -> ttyUSB0
/dev/ttyRtreeCon -> ttyACM0
/dev/ttyManipCon -> ttyACM1
```

udev 규칙:

```text
/etc/udev/rules.d/99-tty.rules
```

내용:

```text
SUBSYSTEM=="tty", MODE:="0666", ATTRS{idVendor}=="2e8a", ATTRS{idProduct}=="00c0", SYMLINK+="ttyRtreeCon"
SUBSYSTEM=="tty", MODE:="0666", ATTRS{idVendor}=="2f5d", ATTRS{idProduct}=="2202", SYMLINK+="ttyManipCon"
SUBSYSTEM=="tty", MODE:="0666", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", SYMLINK+="ttyLidar"
```

`/dev/ttyLidar`는 Silicon Labs CP2102N USB-to-UART 장치였다.

```text
ID_VENDOR=Silicon_Labs
ID_MODEL=CP2102N_USB_to_UART_Bridge_Controller
ID_VENDOR_ID=10c4
ID_MODEL_ID=ea60
ID_USB_DRIVER=cp210x
```

## 커널 로그에서 확인한 직접 원인

커널 로그 확인:

```bash
dmesg -T | egrep -i 'ttyUSB0|cp210|ttyLidar|usb 1-2\.3\.4|disconnect|reset|unable|error -110|error -71' | tail -80
```

핵심 로그:

```text
[Tue Jun 16 11:29:38 2026] cp210x ttyUSB0: failed set request 0x0 status: -110
[Tue Jun 16 11:29:38 2026] cp210x ttyUSB0: cp210x_open - Unable to enable UART
```

`stty`로도 직접 포트를 열어봤다.

```bash
stty -F /dev/ttyUSB0 -a
```

결과:

```text
stty: /dev/ttyUSB0: Input/output error
```

이 결과는 ROS나 sllidar 노드 이전에, OS 레벨에서 `/dev/ttyUSB0` 포트 자체가 정상적으로 열리지 않는다는 뜻이다.

## 다른 프로세스 간섭 확인

포트를 잡고 있는 프로세스가 있는지 확인했다.

```bash
lsof /dev/ttyLidar /dev/ttyUSB0 2>/dev/null || true
fuser -v /dev/ttyLidar /dev/ttyUSB0 2>/dev/null || true
ps -eo pid,comm,args | egrep 'gpsd|ModemManager|brltty|sllidar|ros2|python3' | grep -v grep || true
```

확인된 관련 서비스:

```text
gpsd
ModemManager
```

직접 포트를 점유 중인 흔적은 뚜렷하지 않았다. 다만 CP210x 장치를 GPS/모뎀 계열 서비스가 건드릴 가능성은 남아 있다.

## 최종 판단

이번 pose estimate 초기화처럼 보인 문제의 직접 원인은 다음 흐름이다.

1. 미션 bringup 시작
2. `sllidar_node`가 `/dev/ttyLidar`를 열려고 함
3. `/dev/ttyLidar -> /dev/ttyUSB0` CP210x 장치가 `Unable to enable UART`로 실패
4. `sllidar_node`가 exit code 255로 죽음
5. AMCL이 `/scan` 없이 정상 위치추정을 못 함
6. `map` 프레임이 생기지 않음
7. Nav2 global costmap이 `base_link -> map` transform을 계속 기다림
8. RViz가 메시지를 버리고 화면이 초기화/갱신되는 것처럼 보임

따라서 이 문제는 `delivery_ctrl.py`나 pose estimate UI 자체의 문제가 아니라, LiDAR USB-Serial 장치가 죽은 상태에서 Nav2를 실행한 문제에 가깝다.

## 즉시 조치

사용자 요청에 따라 전체 미션을 종료하고 토크를 껐다.

정지:

```bash
cd /home/jetson/turtlebot3_ws
./scripts/stop_mission_tmux.sh || true
```

확인:

```bash
tmux ls 2>/dev/null || true
pgrep -af 'rtree-mission|bringup|navigation2|delivery_ctrl|delivery_bridge|controller_server|planner_server|bt_navigator|amcl|turtlebot3_node|sllidar|camera_ros|item_detector|mediapipe_hand_tracker|manipulator|rviz2|cloudflared' || true
```

매니퓰레이터 토크도 확인 후 `id=11..15` 전부 OFF 처리했다.

```text
id=11 torque=OFF
id=12 torque=OFF
id=13 torque=OFF
id=14 torque=OFF
id=15 torque=OFF
```

## 다음 재시도 전 체크리스트

재실행 전에 다음 순서로 확인한다.

1. LiDAR USB 케이블 또는 USB 허브 전원을 물리적으로 리셋한다.
2. `/dev/ttyLidar`가 `/dev/ttyUSB0`로 정상 연결되는지 확인한다.
3. `stty -F /dev/ttyUSB0 -a`가 `Input/output error` 없이 출력되는지 확인한다.
4. 단독으로 LiDAR만 실행해서 `/scan`이 나오는지 확인한다.
5. LiDAR가 정상일 때만 전체 미션을 실행한다.

단독 LiDAR 확인 예시:

```bash
source /opt/ros/galactic/setup.bash
source /home/jetson/turtlebot3_ws/install/setup.bash

ros2 launch sllidar_ros2 sllidar_c1_launch.py serial_port:=/dev/ttyLidar frame_id:=base_scan
```

다른 터미널에서:

```bash
source /opt/ros/galactic/setup.bash
ros2 topic echo /scan sensor_msgs/msg/LaserScan --once
```

만약 `stty`부터 실패한다면 ROS를 재실행해도 해결되지 않을 가능성이 높다. 그 경우 USB 케이블/허브/전원 또는 CP210x 장치 리셋이 우선이다.

## 참고

이번 조사 중 CPU 부하도 높았다.

- `camera_ros publisher`
- `rviz2`
- 여러 개의 `ros2 topic echo` debug 프로세스

이 부하는 RViz 메시지 드롭과 ROS CLI 타임아웃을 악화시킬 수 있지만, 이번 LiDAR 사망의 직접 원인은 `/dev/ttyUSB0` I/O error였다.

## 추가 조사: LiDAR 재연결 후 원인 좁히기

사용자가 LiDAR 또는 관련 전원을 껐다 켠 뒤, 같은 문제를 더 좁히기 위해 추가 조사를 진행했다. 이 단계의 목적은 다음 가설들을 분리하는 것이었다.

- 가설 A: USB 재연결 후 `/dev/ttyLidar`가 정상으로 돌아왔고, 전체 미션 부하 때문에만 문제가 생겼다.
- 가설 B: `gpsd` 또는 `ModemManager`가 CP210x 장치를 GPS/모뎀으로 오인해 LiDAR 포트를 건드리고 있다.
- 가설 C: LiDAR baudrate 또는 scan mode 설정이 맞지 않는다.
- 가설 D: ROS/Nav2가 아니라 LiDAR 본체, CP210x USB-Serial, 케이블, 허브, 전원 쪽 통신이 불안정하다.

### 1. 재연결 기록 확인

먼저 젯슨이 재부팅됐는지, 기존 kernel log가 남아 있는지 확인했다.

```bash
date
uptime
tmux ls 2>/dev/null || true
pgrep -af 'sllidar|bringup|navigation2|amcl|turtlebot3_node|rtree-mission' || true
```

확인 결과, 젯슨은 재부팅된 것이 아니라 uptime이 계속 이어지고 있었다. 따라서 `dmesg` 기록도 남아 있었다.

장치 링크 확인:

```bash
ls -l /dev/ttyLidar /dev/ttyUSB* /dev/ttyACM* /dev/ttyRtreeCon /dev/ttyManipCon 2>/dev/null || true
```

확인 결과:

```text
/dev/ttyLidar -> ttyUSB0
/dev/ttyUSB0
/dev/ttyRtreeCon -> ttyACM0
/dev/ttyManipCon -> ttyACM1
```

재연결 직후에는 `stty`가 한 번 정상 출력됐다.

```bash
stty -F /dev/ttyLidar -a
stty -F /dev/ttyUSB0 -a
```

출력 예:

```text
speed 115200 baud; rows 0; columns 0; line = 0;
...
```

이 시점에서는 "포트 파일은 다시 열릴 수 있는 상태"로 보였다.

커널 로그에서는 실제 disconnect/reconnect가 확인됐다.

```bash
dmesg -T | egrep -i 'ttyUSB0|cp210|ttyLidar|usb 1-2\.3\.4|disconnect|reset|unable|error -110|error -71|new full-speed USB device|converter' | tail -120
```

핵심 로그:

```text
[Tue Jun 16 11:42:14 2026] usb 1-2.3.4: USB disconnect, device number 9
[Tue Jun 16 11:42:14 2026] cp210x ttyUSB0: cp210x converter now disconnected from ttyUSB0
[Tue Jun 16 11:42:16 2026] usb 1-2.3.4: new full-speed USB device number 16 using tegra-xusb
[Tue Jun 16 11:42:16 2026] cp210x 1-2.3.4:1.0: cp210x converter detected
[Tue Jun 16 11:42:16 2026] usb 1-2.3.4: cp210x converter now attached to ttyUSB0
```

해석:

물리적 재연결은 OS에서 감지됐고, `/dev/ttyLidar` 링크도 다시 생성됐다. 따라서 "장치가 아예 사라진 상태"는 아니었다.

### 2. LiDAR 단독 실행 실험

전체 미션 부하나 Nav2/AMCL 영향을 제거하기 위해 LiDAR만 단독으로 실행했다.

```bash
source /opt/ros/galactic/setup.bash
source /home/jetson/turtlebot3_ws/install/setup.bash

ros2 launch sllidar_ros2 sllidar_c1_launch.py serial_port:=/dev/ttyLidar frame_id:=base_scan
```

실행 로그:

```text
[sllidar_node]: SLLidar running on ROS2 package SLLidar.ROS2 SDK Version:1.0.1, SLLIDAR SDK Version:2.1.0
[sllidar_node]: Error, unexpected error, code: 80008004
[ERROR] [sllidar_node-1]: process has died [pid 44086, exit code 255, cmd '/home/jetson/turtlebot3_ws/install/sllidar_ros2/lib/sllidar_ros2/sllidar_node ...']
```

해당 로그:

```text
/home/jetson/.ros/log/sllidar_node_44086_1781577828851.log
```

이후 다시 비슷한 단독 실행에서도 같은 에러가 났다.

```text
/home/jetson/.ros/log/sllidar_node_44966_1781577927416.log
```

해석:

전체 미션, RViz, Nav2, AMCL을 제외하고 LiDAR만 띄워도 실패했다. 따라서 원인은 미션 코드나 pose estimate UI가 아니라 LiDAR 경로 자체에 있다.

### 3. `/scan` 확인 시도

LiDAR 단독 실행 후 `/scan` topic을 확인하려 했다.

```bash
ros2 topic echo /scan sensor_msgs/msg/LaserScan
```

그러나 `sllidar_node`가 먼저 죽었기 때문에 `/scan`은 정상 수신되지 않았다.

참고: Galactic 환경에서는 일부 ROS CLI 옵션이 기대와 다를 수 있어 `--once` 사용 시 다음과 같은 에러가 났다.

```text
ros2: error: unrecognized arguments: --once
```

따라서 이후에는 `timeout`으로 짧게 topic echo를 제한하는 방식이 더 적합하다.

```bash
timeout 6 ros2 topic echo /scan sensor_msgs/msg/LaserScan
```

### 4. 서비스 간섭 가설 확인

`/dev/ttyUSB0`가 `/dev/gps0`로도 잡혀 있었다.

```bash
ls -l /dev/gps* /run/gpsd.sock 2>/dev/null || true
```

결과:

```text
/dev/gps0 -> ttyUSB0
/run/gpsd.sock
```

서비스 상태:

```bash
systemctl is-active gpsd ModemManager brltty 2>/dev/null || true
ps -eo pid,comm,args | egrep 'gpsd|ModemManager|brltty' | grep -v grep || true
```

결과:

```text
gpsd: active
ModemManager: active
brltty: inactive
```

관련 udev rule도 확인했다.

```bash
grep -RIn 'gpsdctl@%k\|ID_MM_DEVICE_MANUAL_SCAN_ONLY\|ID_MM_DEVICE_IGNORE\|10c4.*ea60' /lib/udev/rules.d /etc/udev/rules.d 2>/dev/null
```

확인된 내용:

```text
/lib/udev/rules.d/60-gpsd.rules:
ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", SYMLINK+="gps%n", TAG+="systemd", ENV{SYSTEMD_WANTS}="gpsdctl@%k.service"

/etc/udev/rules.d/70-snap.snapd.rules:
ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", ENV{ID_MM_DEVICE_MANUAL_SCAN_ONLY}="1"

/etc/udev/rules.d/99-tty.rules:
SUBSYSTEM=="tty", MODE:="0666", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", SYMLINK+="ttyLidar"
```

가설:

CP210x 장치가 LiDAR인데도 `gpsd`에 의해 `/dev/gps0`로도 잡히고, `gpsd` 또는 `ModemManager`가 장치를 건드려 LiDAR 통신을 방해할 수 있다.

실험:

`gpsd`, `gpsd.socket`, `ModemManager`를 잠깐 stop한 뒤 LiDAR만 단독 실행했다. 실험 후에는 원래 active였던 서비스를 다시 start했다.

```bash
GPSD_WAS=$(systemctl is-active gpsd 2>/dev/null || true)
GPSD_SOCKET_WAS=$(systemctl is-active gpsd.socket 2>/dev/null || true)
MM_WAS=$(systemctl is-active ModemManager 2>/dev/null || true)

sudo systemctl stop gpsd.socket gpsd ModemManager 2>/dev/null || true

source /opt/ros/galactic/setup.bash
source /home/jetson/turtlebot3_ws/install/setup.bash
ros2 launch sllidar_ros2 sllidar_c1_launch.py serial_port:=/dev/ttyLidar frame_id:=base_scan

[ "$GPSD_SOCKET_WAS" = active ] && sudo systemctl start gpsd.socket 2>/dev/null || true
[ "$GPSD_WAS" = active ] && sudo systemctl start gpsd 2>/dev/null || true
[ "$MM_WAS" = active ] && sudo systemctl start ModemManager 2>/dev/null || true
```

결과:

```text
BEFORE gpsd=active gpsd.socket=active ModemManager=active
AFTER_STOP gpsd=inactive gpsd.socket=inactive ModemManager=inactive

[sllidar_node]: SLLidar running ...
[sllidar_node]: Error, unexpected error, code: 80008004

RESTORED gpsd=active gpsd.socket=active ModemManager=active
```

해석:

서비스 간섭은 가능성 있는 환경 요인이지만, 이번 실패의 직접 원인으로 확정되지는 않았다. 해당 서비스를 꺼도 같은 에러가 재현됐기 때문이다.

다만 `/dev/gps0 -> ttyUSB0`는 혼란을 만들 수 있으므로, 장기적으로는 LiDAR CP210x 장치를 `gpsd` 대상에서 제외하는 udev rule을 검토할 수 있다.

### 5. 에러 코드와 실패 지점 확인

`80008004`의 의미를 소스에서 확인했다.

```bash
grep -RIn '80008004\|RESULT_OPERATION\|unexpected error' \
  /home/jetson/turtlebot3_ws/src/sllidar_ros2 \
  /home/jetson/turtlebot3_ws/install/sllidar_ros2 2>/dev/null | head -120
```

관련 정의:

```text
/home/jetson/turtlebot3_ws/src/sllidar_ros2/sdk/include/sl_types.h

#define SL_RESULT_FAIL_BIT               (sl_result)0x80000000
#define SL_RESULT_OPERATION_NOT_SUPPORT  (sl_result)(0x8004 | SL_RESULT_FAIL_BIT)
```

즉 `80008004`는 `SL_RESULT_OPERATION_NOT_SUPPORT`다.

에러 로그가 찍히는 위치:

```text
/home/jetson/turtlebot3_ws/src/sllidar_ros2/src/sllidar_node.cpp
```

관련 코드 흐름:

```cpp
op_result = drv->getDeviceInfo(devinfo);
if (SL_IS_FAIL(op_result)) {
    if (op_result == SL_RESULT_OPERATION_TIMEOUT) {
        RCLCPP_ERROR(this->get_logger(),"Error, operation time out. SL_RESULT_OPERATION_TIMEOUT! ");
    } else {
        RCLCPP_ERROR(this->get_logger(),"Error, unexpected error, code: %x",op_result);
    }
    return false;
}
```

그리고 이 함수는 driver connect 직후 호출된다.

```cpp
if (SL_IS_FAIL((drv)->connect(_channel))) {
    RCLCPP_ERROR(this->get_logger(),"Error, cannot bind to the specified serial port %s.",serial_port.c_str());
    return -1;
}

if (!getSLLIDARDeviceInfo(drv)) {
    return -1;
}
```

해석:

`connect()` 단계에서 "cannot bind to serial port"로 실패한 것이 아니라, 포트 연결 후 `getDeviceInfo()`에서 실패했다. 즉 OS가 포트 파일을 여는 단계는 일부 통과하지만, LiDAR 장치와의 기본 핸드셰이크/장치정보 응답이 실패한다.

### 6. Baudrate 가설 확인

LiDAR 모델/설정 불일치 가능성을 보기 위해 baudrate 후보를 바꿔 단독 실행했다.

테스트한 값:

```text
460800
115200
256000
1000000
```

실험 명령 예:

```bash
source /opt/ros/galactic/setup.bash
source /home/jetson/turtlebot3_ws/install/setup.bash

timeout 7 ros2 launch sllidar_ros2 sllidar_c1_launch.py \
  serial_port:=/dev/ttyLidar \
  serial_baudrate:=460800 \
  frame_id:=base_scan
```

결과:

어떤 baud에서도 정상 로그가 나오지 않았다.

정상이라면 다음 로그가 나와야 한다.

```text
SLLidar S/N: ...
Firmware Ver: ...
Hardware Rev: ...
SLLidar health status : OK.
current scan mode: Standard ...
```

하지만 테스트에서는 공통적으로 아래 정도까지만 진행됐다.

```text
SLLidar running on ROS2 package SLLidar.ROS2 SDK Version:1.0.1, SLLIDAR SDK Version:2.1.0
```

이후 성공 로그가 없었다. 일부 테스트는 `timeout 7`로 끊겨 에러 출력 전 종료됐을 수 있지만, 적어도 정상 장치정보 응답은 확인되지 않았다.

해석:

단순 baudrate mismatch 하나로 보기 어렵다. 이전 정상 로그에서 같은 시스템이 `current scan mode: Standard`까지 올라간 기록이 있으므로, 설정 파일이 항상 틀린 것도 아니다.

### 7. 재실패 후 포트 상태 변화

LiDAR 단독 실행과 baud 테스트 이후 다시 포트를 확인했다.

```bash
stty -F /dev/ttyLidar -a
ls -l /dev/ttyLidar /dev/gps0 /dev/ttyUSB0 2>/dev/null || true
```

결과:

```text
stty: /dev/ttyLidar: Input/output error
/dev/gps0 -> ttyUSB0
/dev/ttyLidar -> ttyUSB0
/dev/ttyUSB0
```

커널 로그에도 다시 CP210x open 실패가 반복됐다.

```text
[Tue Jun 16 11:43:53 2026] cp210x ttyUSB0: failed set request 0x0 status: -110
[Tue Jun 16 11:43:53 2026] cp210x ttyUSB0: cp210x_open - Unable to enable UART
[Tue Jun 16 11:45:31 2026] cp210x ttyUSB0: failed set request 0x0 status: -110
[Tue Jun 16 11:45:31 2026] cp210x ttyUSB0: cp210x_open - Unable to enable UART
[Tue Jun 16 11:47:04 2026] cp210x ttyUSB0: failed set request 0x0 status: -110
[Tue Jun 16 11:47:04 2026] cp210x ttyUSB0: cp210x_open - Unable to enable UART
```

해석:

재연결 직후에는 포트가 잠깐 열렸지만, LiDAR 통신 시도 후 다시 OS 레벨 `Input/output error` 상태로 악화됐다. 이는 ROS 코드보다 USB-Serial/케이블/허브/전원/장치 쪽 불안정성을 강하게 가리킨다.

## 추가 조사 후 보강 결론

추가 실험으로 좁혀진 결론은 다음과 같다.

1. 전체 미션 부하 없이 LiDAR만 단독 실행해도 실패한다.
2. 실패 지점은 sllidar node의 `connect()`가 아니라 `getDeviceInfo()`다.
3. 에러 코드 `80008004`는 `SL_RESULT_OPERATION_NOT_SUPPORT`다.
4. `gpsd`/`ModemManager`를 잠깐 꺼도 같은 실패가 재현됐다.
5. baudrate 후보를 바꿔도 정상 장치정보 응답은 확인되지 않았다.
6. 실패 후 `/dev/ttyLidar`는 다시 `Input/output error` 상태가 됐다.

따라서 현재 가장 유력한 원인은 다음 중 하나다.

- LiDAR 본체가 정상적으로 응답하지 않음
- CP2102N USB-Serial 어댑터 또는 LiDAR 케이블 불량
- USB 허브/포트 전원 불안정
- LiDAR 전원이 완전히 리셋되지 않아 내부 상태가 꼬임

남은 낮은 가능성:

- `gpsd` udev rule 때문에 CP210x 장치가 `/dev/gps0`로도 잡히는 환경 혼선
- ModemManager의 초기 probe 영향
- sllidar SDK/드라이버가 특정 장치 상태에서 복구하지 못하는 문제

## 포트폴리오용 문제 해결 흐름 요약

이번 디버깅은 아래처럼 진행했다.

1. 사용자 증상에서 출발: "pose estimate를 찍으면 초기화되는 것 같다."
2. Nav2/RViz 로그 확인: `map` frame 없음, odom message drop 확인.
3. AMCL/TF 문제로 좁힘: `/scan` 없이는 AMCL이 map transform을 만들 수 없음.
4. bringup 로그 확인: `sllidar_node`가 시작 직후 죽는 것을 발견.
5. OS 장치 확인: `/dev/ttyLidar -> /dev/ttyUSB0`, CP210x 장치 확인.
6. kernel log 확인: `cp210x_open - Unable to enable UART`, `Input/output error` 확인.
7. 전체 미션 영향 제거: LiDAR 단독 실행에서도 같은 실패 재현.
8. 서비스 간섭 가설 검증: `gpsd`/`ModemManager` stop 후에도 실패.
9. 드라이버 소스 확인: `getDeviceInfo()` 단계 실패와 `80008004` 의미 확인.
10. baudrate 가설 검증: 여러 baud 후보에서도 정상 device info 응답 없음.
11. 최종 결론: ROS 미션 코드보다 LiDAR 하드웨어/USB-Serial 경로 문제 가능성이 가장 높음.

## 추가 재현성 실험: 확장 허브 부하 조합 검증

위 실험 이후 LiDAR를 뽑았다가 다시 연결하고, 확장 허브에 연결되는 장치를 단계적으로 늘리며 재현성 실험을 진행했다.

목표는 다음 가설을 분리하는 것이었다.

- LiDAR 본체 또는 케이블이 항상 고장인지
- 확장 허브 자체가 항상 문제인지
- 특정 주변기기 조합에서만 전원/USB 통신이 불안정해지는지
- 이전 실패가 일시적 접촉/전원/초기화 타이밍 문제였는지

공통 확인 명령은 다음과 같았다.

```bash
source /opt/ros/galactic/setup.bash
source /home/jetson/turtlebot3_ws/install/setup.bash

lsusb -t
lsusb
ls -l /dev/ttyLidar /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || true
stty -F /dev/ttyLidar -a

dmesg -T | grep -Ei \
  'ttyUSB0|cp210|failed set request|Unable to enable UART|error -110|error -71|unable to enumerate|over-current|usb 1-2\.3\.'

ros2 launch sllidar_ros2 sllidar_c1_launch.py \
  serial_port:=/dev/ttyLidar \
  frame_id:=base_scan

timeout 6 ros2 topic echo /scan sensor_msgs/msg/LaserScan
```

테스트 후에는 매번 테스트용 프로세스를 종료했다.

```bash
pkill -INT -f 'ros2 launch sllidar_ros2'
pkill -INT -f 'sllidar_node'
```

### 1. Jetson 본체 USB 직접 연결

LiDAR를 확장 허브가 아니라 Jetson 본체 USB에 직접 연결했다.

결과:

```text
SLLidar S/N: 8AE4E0F8C6E59AC0B5E29FF909314E00
Firmware Ver: 1.02
Hardware Rev: 18
SLLidar health status : OK.
current scan mode: Standard, sample rate: 5 Khz, max_distance: 16.0 m, scan frequency:10.0 Hz
```

`/scan`도 정상 수신됐다.

해석:

LiDAR 본체, CP210x USB-Serial, ROS launch 설정이 항상 고장인 것은 아니다. 같은 LiDAR가 직접 USB에서는 정상 동작했다.

### 2. 확장 허브에 LiDAR만 연결

확장 허브 전원은 켜둔 상태에서 주변 장치를 빼고 LiDAR만 확장 허브에 연결했다.

결과:

- `/dev/ttyLidar -> ttyUSB0` 정상
- `stty -F /dev/ttyLidar -a` 정상
- `sllidar_node` 정상 시작
- `/scan` 정상 수신

해석:

확장 허브 자체가 항상 고장인 것도 아니다. 최소 부하 상태에서는 확장 허브 경유 LiDAR도 동작했다.

### 3. LiDAR + 모니터/터치 장치

확장 허브에 LiDAR와 모니터/터치 장치를 함께 연결했다.

확인된 장치:

```text
10c4:ea60 Silicon Labs CP210x UART Bridge
27c0:0859 TouchScreen
```

결과:

- `stty` 정상
- `sllidar_node` 정상 시작
- health `OK`
- `/scan` 정상 수신

해석:

모니터/터치 장치 단독 추가만으로는 문제가 재현되지 않았다.

### 4. LiDAR + OpenRB

확장 허브에 LiDAR와 OpenRB를 함께 연결했다.

확인된 장치:

```text
10c4:ea60 Silicon Labs CP210x UART Bridge
2f5d:2202 OpenRB-150
```

결과:

- `/dev/ttyACM1`로 OpenRB 인식
- `/dev/ttyLidar -> ttyUSB0` 유지
- `sllidar_node` 정상 시작
- `/scan` 정상 수신

해석:

OpenRB 단독 추가만으로도 문제가 재현되지 않았다.

### 5. LiDAR + 모니터/터치 + OpenRB

확장 허브에 LiDAR, 모니터/터치 장치, OpenRB를 함께 연결했다.

확인된 장치:

```text
10c4:ea60 Silicon Labs CP210x UART Bridge
27c0:0859 TouchScreen
2f5d:2202 OpenRB-150
```

결과:

- 세 장치 모두 같은 확장 허브 아래에서 인식
- `stty` 정상
- `sllidar_node` 정상 시작
- `/scan` 정상 수신

해석:

LiDAR + 모니터 + OpenRB 조합에서도 문제가 재현되지 않았다.

### 6. 전체 조합: LiDAR + 모니터/터치 + OpenRB + 키보드/마우스 동글

원래 실패 당시와 가장 가까운 조합으로 전부 연결했다.

확인된 장치:

```text
10c4:ea60 Silicon Labs CP210x UART Bridge
27c0:0859 TouchScreen
2f5d:2202 OpenRB-150
3554:fc03 2.4G Receiver
2e8a:00c0 TurtleBot3/Pico 계열 보드
```

결과:

- `/dev/ttyLidar -> ttyUSB0` 정상
- `/dev/ttyACM0`, `/dev/ttyACM1` 정상
- `sllidar_node` 정상 시작
- health `OK`
- `/scan` 정상 수신
- 새 `cp210x_open - Unable to enable UART` 에러 없음

해석:

전체 연결 조합에서도 짧은 테스트에서는 문제가 재현되지 않았다.

### 7. 전체 조합 3분 안정성 테스트

전체 장치를 연결한 상태에서 LiDAR를 약 3분 동안 계속 실행하고 `/scan` 주파수를 측정했다.

실험 명령의 핵심:

```bash
ros2 launch sllidar_ros2 sllidar_c1_launch.py \
  serial_port:=/dev/ttyLidar \
  frame_id:=base_scan

timeout 180 ros2 topic hz /scan
```

결과:

```text
average rate: 10.008 ~ 10.010 Hz
min: 약 0.084s
max: 약 0.111s
```

`ros2 topic hz`는 `timeout`으로 종료했기 때문에 마지막 상태는 다음처럼 기록됐다.

```text
HZ_DONE=124
```

이는 timeout 종료 코드이며, `/scan` 실패를 의미하지 않는다. 실제로 평균 주파수 로그가 계속 누적됐으므로 `/scan`은 안정적으로 수신됐다.

테스트 중 새로 확인되지 않은 에러:

```text
cp210x_open - Unable to enable UART
failed set request
error -110
error -71
unable to enumerate USB device
over-current
```

해석:

전체 장치를 연결한 상태에서도 3분 동안 LiDAR scan은 약 10 Hz로 안정적으로 유지됐다.

## 현재 확정할 수 있는 부분

이번 조사로 확정할 수 있는 사실은 다음과 같다.

1. 실패 당시 LiDAR 경로에는 실제 OS 레벨 USB-Serial 문제가 있었다.
   - `stty: /dev/ttyLidar: Input/output error`
   - `cp210x_open - Unable to enable UART`
   - `failed set request ... status: -110`
2. 실패 당시 Nav2/RViz 문제의 직접 원인은 LiDAR scan 부재로 볼 수 있다.
   - `/scan`이 없으면 AMCL이 정상적으로 pose를 갱신하기 어렵다.
   - 그 결과 `map` frame/transform 문제가 발생하고, pose estimation 후 화면이 초기화되는 것처럼 보일 수 있다.
3. LiDAR 본체와 ROS launch 설정은 항상 고장난 상태가 아니다.
   - Jetson 본체 USB 직접 연결에서 정상 동작했다.
   - 확장 허브 단독 연결에서도 정상 동작했다.
4. 확장 허브도 항상 고장인 것은 아니다.
   - LiDAR만 연결했을 때 정상
   - LiDAR + 여러 주변기기 조합에서도 정상
5. `gpsd`/`ModemManager`는 주요 원인으로 보기 어렵다.
   - 두 서비스를 잠시 멈춰도 당시 실패는 계속 재현됐다.
6. sllidar 쪽 실패 지점은 단순 실행 실패가 아니라 장치 정보 요청 단계였다.
   - `getDeviceInfo()` 단계에서 `80008004`가 발생한 것으로 좁혀졌다.

## 아직 확정하지 못한 부분

아래 항목은 의심되지만 이번 재실험에서는 확정하지 못했다.

1. 확장 허브 전원 부족 또는 과전류
   - 가능성은 있지만, 이번 테스트 중 `over-current` 로그는 없었다.
   - 전체 조합 3분 테스트도 정상 통과했다.
2. 특정 장치 조합이 항상 LiDAR를 죽이는지 여부
   - LiDAR + 모니터, LiDAR + OpenRB, LiDAR + 모니터 + OpenRB, 전체 조합 모두 재현 실패.
3. 키보드/마우스 동글이 직접 원인인지 여부
   - 전체 조합에서 동글까지 포함했지만 정상 동작했다.
4. 모니터/터치 장치가 직접 원인인지 여부
   - 이전 dmesg에는 TouchScreen 쪽 `error -71`, `error -110` 기록이 있었지만, 이번 재연결 테스트에서는 정상 인식됐다.
5. 케이블/포트 접촉 불량
   - 재연결 후 문제가 사라졌기 때문에 가능성은 남아 있다.
   - 다만 소프트웨어 로그만으로 접촉 불량을 확정할 수는 없다.
6. 부팅 직후 또는 장치 연결 순서에 따른 초기화 문제
   - 이번에는 장치를 단계적으로 다시 꽂으면서 정상화됐다.
   - 동일 순서/동일 전원 상태에서 반복 실험하지 않았으므로 확정 불가.

## 보강 결론

현재 가장 보수적인 결론은 다음과 같다.

이전 LiDAR 장애는 ROS 미션 코드보다는 USB-Serial 계층에서 발생한 실제 통신 장애였다. 다만 이후 재연결 및 조합별 테스트에서는 문제가 재현되지 않았으므로, 특정 코드 결함이나 특정 주변기기 하나의 고정 결함으로 단정하기는 어렵다.

가장 가능성이 남는 원인은 다음과 같다.

- 확장 허브 또는 케이블의 순간적인 접촉 불량
- 허브 전원 상태 변화 또는 순간 전압 강하
- 장치 연결/부팅 순서에 따른 USB 초기화 실패
- TouchScreen 장치가 한때 USB enumeration error를 일으키며 허브 상태에 영향을 준 경우
- CP210x 장치가 실패 후 리셋 전까지 `Input/output error` 상태에 머문 경우

다음에 같은 증상이 발생하면 즉시 아래 로그를 저장하는 것이 좋다.

```bash
dmesg -T | grep -Ei 'cp210|ttyUSB|error -110|error -71|unable to enumerate|over-current'
lsusb -t
ls -l /dev/ttyLidar /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || true
stty -F /dev/ttyLidar -a
ros2 topic hz /scan
```

특히 같은 증상이 다시 생긴 직후의 `dmesg`가 가장 중요하다. 시간이 지나 재연결하면 문제가 사라질 수 있어, 실패 순간의 로그가 원인 확정에 필요하다.
