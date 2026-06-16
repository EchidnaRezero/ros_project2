# Jetson Log Paths

Jetson에서 미션 이상 동작을 조사할 때 참고할 로그 위치다.

## ROS 런타임 로그

```bash
/home/jetson/.ros/log
```

ROS 2 노드와 launch가 남기는 기본 로그다.

이번 폭주 의심 상황에서는 아래 파일들을 확인했다.

```text
/home/jetson/.ros/log/amcl_18337_1781573153224.log
/home/jetson/.ros/log/planner_server_18343_1781573153227.log
/home/jetson/.ros/log/controller_server_18341_1781573153224.log
/home/jetson/.ros/log/recoveries_server_18345_1781573153830.log
```

확인한 핵심 로그:

```text
AMCL cannot publish a pose or update the transform. Please set the initial pose...
Planning algorithm GridBased failed to generate a valid path to (11.93, -1.44)
Failed to make progress
Controller patience exceeded
Collision Ahead - Exiting Spin
backup failed
```

최근 로그 목록:

```bash
find ~/.ros/log -maxdepth 2 -type f \
  -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' 2>/dev/null | sort | tail -80
```

Nav2 관련 메시지 검색:

```bash
grep -RInE 'goal|cmd_vel|Failed|WARN|ERROR|transform|costmap|progress|patience|Aborting' \
  ~/.ros/log/controller_server_*.log \
  ~/.ros/log/planner_server_*.log \
  ~/.ros/log/amcl_*.log \
  ~/.ros/log/recoveries_server_*.log 2>/dev/null | tail -200
```

## Launch 로그

ROS launch 단위 로그는 날짜/시간별 하위 폴더에 있다.

예시:

```text
/home/jetson/.ros/log/2026-06-16-10-25-27-504020-nano-17058/launch.log
/home/jetson/.ros/log/2026-06-16-10-25-37-933424-nano-17260/launch.log
/home/jetson/.ros/log/2026-06-16-10-25-40-581359-nano-17405/launch.log
```

이번 확인에서는 bringup/nav/manipulator launch가 언제 시작됐는지 봤다.

```bash
cat ~/.ros/log/2026-*/launch.log 2>/dev/null | tail -200
```

## Python 노드 로그

`ros2 run`으로 실행된 Python 노드는 `python3_*.log`로 남는 경우가 있다.

```bash
ls -lt ~/.ros/log/python3_*.log 2>/dev/null | head
```

delivery bridge/controller 관련 흔적 검색:

```bash
grep -RInE 'delivery|move_request|Valid request|Sending navigation|Navigation|A_|B_|driver|block|pen|wrench|call|recall' \
  ~/.ros/log/python3_* ~/.ros/log/*delivery* 2>/dev/null | tail -200
```

주의: tmux pane에만 찍히고 파일 로그로 안 남는 출력도 있다.

## tmux 세션 로그

현재 스크립트는 tmux pane 내용을 별도 파일로 저장하지 않는다.

세션이 살아 있을 때만 캡처할 수 있다.

```bash
tmux capture-pane -p -t rtree-mission:mission -S -200
tmux capture-pane -p -t rtree-mission:nav -S -200
tmux capture-pane -p -t rtree-mission:bringup -S -200
tmux capture-pane -p -t rtree-mission:debug -S -200
```

세션을 `tmux kill-session`으로 닫으면 pane 내용은 사라진다.

## 미션 스크립트 임시 로그

GNOME terminal 실행 요청 로그:

```text
/tmp/rtree-mission-terminal.log
/tmp/rtree-safety-terminal.log
```

수동으로 `/cmd_vel` 정지 명령을 보냈을 때 생긴 임시 로그 예시:

```text
/tmp/cmdvel_stop_1.log
/tmp/cmdvel_stop_2.log
/tmp/cmdvel_stop_3.log
/tmp/cmdvel_stop_4.log
/tmp/cmdvel_stop_5.log
```

관련 파일 확인:

```bash
find /tmp -maxdepth 1 -type f \
  \( -name '*rtree*' -o -name '*cmdvel*' -o -name '*mission*' -o -name '*cloudflare*' \) \
  -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' 2>/dev/null | sort | tail -80
```

## Workspace 로그

```bash
/home/jetson/turtlebot3_ws/log
```

주로 `colcon build` 로그가 있다. 런타임 폭주 분석보다는 빌드/설치 확인용이다.

최근 workspace 로그:

```bash
find ~/turtlebot3_ws/log -maxdepth 3 -type f \
  -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' 2>/dev/null | sort | tail -80
```

## 미션 URL 파일

```text
/home/jetson/turtlebot3_ws/mission_urls.txt
```

미션 실행 시 Cloudflare quick tunnel 주소가 남는다.

```bash
cat ~/turtlebot3_ws/mission_urls.txt 2>/dev/null || true
```

## 현재 상태 확인

미션 세션/프로세스:

```bash
tmux ls 2>/dev/null || true
ps -eo pid,ppid,stat,lstart,cmd | \
  grep -Ei 'ros|nav2|turtlebot|bringup|delivery|cloudflare|camera|manipulator|hand_tracker' | \
  grep -v grep || true
```

ROS graph:

```bash
source /opt/ros/galactic/setup.bash
source ~/turtlebot3_ws/install/setup.bash
ros2 node list
ros2 topic list
ros2 topic info /cmd_vel -v
```

