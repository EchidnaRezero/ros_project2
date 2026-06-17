# LiDAR / Pose Estimation Issue 2026-06-16

## 증상

- RViz에서 `2D Pose Estimate` 지정 시 화면이 초기화되는 것처럼 보임.
- Nav2/AMCL 위치추정 불안정.

## 직접 원인

`sllidar_node` 종료로 `/scan`이 사라진 상태가 직접 원인.

`/scan` 부재로 AMCL이 `map -> odom -> base_link` TF 흐름 생성 실패. Nav2 global costmap과 RViz가 `map` frame을 기다리며 메시지 폐기.

## 확인된 하드웨어 계층 문제

- `/dev/ttyLidar -> /dev/ttyUSB0` CP210x 장치에서 `Input/output error` 확인.
- kernel log에 `cp210x_open - Unable to enable UART`, `failed set request ... status: -110` 계열 메시지 기록.
- LiDAR 단독 실행에서도 `sllidar_node` 실패.

## 결론

재연결 후 Jetson 본체 USB, 확장 허브, 전체 주변기기 조합에서 `/scan` 정상 수신 확인.

가장 보수적인 결론은 순간적인 USB-Serial, 케이블, 허브, 전원, 초기화 문제.

## 다시 확인할 것

```bash
ls -l /dev/ttyLidar /dev/ttyUSB* 2>/dev/null
stty -F /dev/ttyLidar -a
ros2 topic hz /scan
dmesg | tail -100
```
