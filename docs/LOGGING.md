# 로그 확인

Jetson에서 미션 이상 동작을 조사할 때 확인할 로그 위치와 상태 확인 명령.

## 전체 확인 순서

```text
tmux pane
  -> ROS runtime log
  -> Python node log
  -> temporary script log
  -> workspace build log
  -> ROS graph 상태
```

## ROS 런타임 로그

ROS2 노드와 launch 기본 로그:

```bash
ls -lt ~/.ros/log | head -40
find ~/.ros/log -maxdepth 2 -type f -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' 2>/dev/null | sort | tail -80
```

Nav2, AMCL, LiDAR 관련 메시지 검색:

```bash
grep -RInE 'goal|cmd_vel|Failed|WARN|ERROR|transform|costmap|progress|patience|Aborting|scan|sllidar' \
  ~/.ros/log/controller_server_*.log \
  ~/.ros/log/planner_server_*.log \
  ~/.ros/log/amcl_*.log \
  ~/.ros/log/recoveries_server_*.log \
  ~/.ros/log/sllidar_node_*.log 2>/dev/null | tail -200
```

Launch 단위 로그:

```bash
cat ~/.ros/log/*/launch.log 2>/dev/null | tail -200
```

## Python 노드 로그

`ros2 run`으로 실행된 Python 노드는 `python3_*.log`로 남는 경우가 있다.

```bash
ls -lt ~/.ros/log/python3_*.log 2>/dev/null | head
grep -RInE 'delivery|move_request|Valid request|Sending navigation|Navigation|A_|B_|driver|block|pen|wrench|call|recall' \
  ~/.ros/log/python3_* ~/.ros/log/*delivery* 2>/dev/null | tail -200
```

터미널에만 출력되고 파일 로그로 남지 않는 출력은 tmux pane에서 확인한다.

## tmux pane

미션 세션이 살아 있을 때 최근 출력 캡처:

```bash
tmux capture-pane -p -t rtree-mission:mission -S -200
tmux capture-pane -p -t rtree-mission:nav -S -200
tmux capture-pane -p -t rtree-mission:bringup -S -200
tmux capture-pane -p -t rtree-mission:vision -S -200
tmux capture-pane -p -t rtree-mission:manipulator -S -200
tmux capture-pane -p -t rtree-mission:debug -S -200
```

세션을 종료하면 pane 출력은 사라질 수 있다.

## 임시 로그

미션 스크립트와 정지 명령이 `/tmp`에 임시 로그를 남길 수 있다.

```bash
find /tmp -maxdepth 1 -type f \
  \( -name '*rtree*' -o -name '*cmdvel*' -o -name '*mission*' -o -name '*cloudflare*' \) \
  -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' 2>/dev/null | sort | tail -80
```

## Workspace 로그

`colcon build`와 설치 확인용 로그:

```bash
find ~/turtlebot3_ws/log -maxdepth 3 -type f -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' 2>/dev/null | sort | tail -80
```

## URL 기록

미션 실행 시 tunnel 주소가 저장될 수 있다.

```bash
cat ~/turtlebot3_ws/mission_urls.txt 2>/dev/null || true
```

## 현재 상태

프로세스와 ROS graph:

```bash
tmux ls 2>/dev/null || true
ps -eo pid,ppid,stat,lstart,cmd | \
  grep -Ei 'ros|nav2|turtlebot|bringup|delivery|cloudflare|camera|manipulator|hand_tracker|sllidar' | \
  grep -v grep || true
```

```bash
source /opt/ros/galactic/setup.bash
source ~/turtlebot3_ws/install/setup.bash
ros2 node list
ros2 topic list
ros2 topic info /cmd_vel -v
ros2 topic hz /scan
```
