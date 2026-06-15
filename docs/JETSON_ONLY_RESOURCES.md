# Jetson Only / Heavy Runtime Resources

이 문서는 `work_ref_jetson_ready`에 직접 넣지 않거나, Jetson 실제 환경에 남겨두는 리소스를 기록한다.

## Jetson에만 두는 리소스

| 항목 | Jetson 위치 | 이유 |
|---|---|---|
| ONNX 모델 | `/home/jetson/turtlebot3_ws/src/camera_ros/camera_ros/ssd-mobilenet.onnx` | Git/작업 트리에 넣기엔 큰 모델 파일. `publisher.py`가 Jetson 위치에서 사용 |
| TensorRT engine | `/home/jetson/turtlebot3_ws/src/camera_ros/camera_ros/ssd-mobilenet.onnx.1.1.8001.GPU.FP16.engine` | Jetson GPU/TensorRT 런타임 캐시. Jetson에서 생성/사용 |
| MediaPipe venv | `/home/jetson/mp_env` | `hand_tracker_node.py` shebang이 사용하는 Jetson Python 환경 |
| jetson-inference | `/home/jetson/jetson-inference` | `camera_ros` 실행에 필요한 Jetson 환경 |
| ROS build outputs | `/home/jetson/turtlebot3_ws/build`, `install`, `log` | Jetson에서 빌드하면 생성되는 산출물 |
| 현재 하드웨어 포트 상태 | `/dev/ttyRtreeCon`, `/dev/ttyManipCon`, `/dev/ttyLidar` | Jetson udev rule로 고정한 런타임 장치명 |

## 현재 작업 트리에 포함된 대체/참조 파일

| 항목 | 작업 트리 위치 |
|---|---|
| 모델 checksum | `turtlebot3_ws/src/camera_ros/camera_ros/ssd-mobilenet.onnx.sha256sum` |
| labels | `turtlebot3_ws/src/camera_ros/camera_ros/labels.txt` |
| 지도 | `turtlebot3_ws/maps/map_6f.yaml`, `map_6f.pgm` |

## Jetson으로 배포할 때 확인할 것

- 모델 파일은 작업 트리에서 복사하지 말고 Jetson 기존 위치를 유지한다.
- `mp_env`는 재생성하지 말고 Jetson 기존 환경을 사용한다.
- `colcon build --symlink-install` 후 `/home/jetson/turtlebot3_ws/install/setup.bash`를 source한다.
- 하드웨어 포트는 직접 `/dev/ttyACM*`, `/dev/ttyUSB*`가 아니라 `/dev/ttyRtreeCon`, `/dev/ttyManipCon`, `/dev/ttyLidar` 기준으로 확인한다.
- CSI 카메라는 `/dev/video0` 직접 입력이 아니라 `csi://0` 기준이며, vision 시작 전 `nvargus-daemon`을 재시작한다.
