# 하드웨어 트러블슈팅

## LiDAR

`/scan`이 없거나 RViz/Nav2가 불안정하면 `/dev/ttyLidar`와 `/scan`을 먼저 확인한다.

```bash
ls -l /dev/ttyLidar /dev/ttyUSB* 2>/dev/null
ros2 topic hz /scan
```

`sllidar_c1_launch.py`의 LiDAR 포트 인자명은 `serial_port` 기준이다.

LiDAR를 물리적으로 재연결한 뒤에는 기존 세션이 자동 복구되지 않을 수 있다. 이때는 미션 세션을 다시 시작한다.

```bash
~/turtlebot3_ws/scripts/stop_mission_tmux.sh
~/turtlebot3_ws/scripts/start_mission_tmux.sh
```

## Manipulator / OpenRB

OpenRB는 `/dev/ttyACM*` 번호가 바뀔 수 있으므로 `/dev/ttyManipCon` symlink 기준으로 확인한다.

```bash
ls -l /dev/ttyManipCon /dev/ttyACM* 2>/dev/null
```

Dynamixel ID 11~15 ping 성공 여부가 기본 확인 지점이다.

프로세스 종료 후에도 torque가 남을 수 있다. 필요하면 `/set_torque` 또는 Dynamixel SDK로 torque off를 확인한다.

## Camera / Vision

IMX219 CSI 카메라는 `csi://0` 기준으로 실행한다.

```bash
sudo systemctl restart nvargus-daemon
systemctl is-active nvargus-daemon
```

카메라 단독 확인:

```bash
gst-launch-1.0 nvarguscamerasrc sensor-id=0 num-buffers=30 ! "video/x-raw(memory:NVMM), width=1280, height=720, framerate=30/1, format=NV12" ! fakesink
```

## Hand Gesture / MediaPipe

`lambda_sign` 조건은 pinch/OK에 가깝다.

세부 조건은 `docs/LAMBDA_GESTURE_GUIDE.html`에서 확인한다.

## 로그 확인

ROS 로그:

```text
/home/jetson/.ros/log
```

tmux 창 내용:

```bash
tmux capture-pane -t rtree-mission:<window-name> -p
```

장애 직후에는 `dmesg`, `/scan`, `/dev/tty*` symlink, tmux pane, ROS log 순서로 확인한다.
