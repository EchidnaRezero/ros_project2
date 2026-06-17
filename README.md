# ROS2 AMR Manipulator Delivery Robot

웹 화면에서 물품 배송/회수를 요청하면 Jetson에서 ROS2 로봇이 이동, 인식, 로봇팔 동작, 완료 알림까지 처리하는 프로젝트.

[포트폴리오 PDF](docs/portfolio/ros_project2_portfolio.pdf) / [포트폴리오 PPTX](docs/portfolio/ros_project2_portfolio.pptx)

[Web UI 열기](https://echidnarezero.github.io/ros_project2/web_client/)

## 무엇을 하는 프로젝트인가

미션 흐름과 실행 순서의 우선 문서는 `docs/MISSION.md`. `guide/mission/s0.png`~`s6.png`는 Web UI 사용자 흐름의 원형 이미지.

## 사용 환경

| 항목 | 내용 |
|---|---|
| OS | Ubuntu 20.04 기반 Jetson image |
| Robot middleware | ROS2 Galactic |
| Edge computer | Jetson |
| 이동 | TurtleBot3 base, Nav2, LiDAR |
| 인식 | CSI camera, Jetson Inference, MediaPipe |
| 조작 | Dynamixel manipulator |

## 프로젝트 전용 외부 리소스

| 리소스 | 링크 | 용도 |
|---|---|---|
| `ssd-mobilenet.onnx` | `https://huggingface.co/pomupomu2/ros2` | 회수 물품 인식 모델 본체 |

## 아카이브와 재현 기준

이 저장소는 당시 Jetson 실행 환경을 보존하기 위한 아카이브 성격의 코드베이스. 일부 경로는 범용 배포용으로 추상화하지 않고 Jetson 기준값 유지.

| 경로 | 의미 |
|---|---|
| `/home/jetson/turtlebot3_ws` | Jetson의 ROS2 workspace 기준 경로 |
| `/home/jetson/mp_env` | MediaPipe 실행용 Python 가상환경 기준 경로 |

재현 시 위 경로에 맞춰 workspace와 venv 구성. 리팩토링 시 환경변수/ROS parameter/package share 경로 기준으로 변경 가능.

## 실행 방법

실행 순서와 종료 방법은 `docs/MISSION.md` 참고.

## 문서

| 문서 | 내용 |
|---|---|
| `docs/MISSION.md` | 미션 흐름과 실행 방법 |
| `docs/HARDWARE.md` | Jetson, 장치명, 카메라, 하드웨어 설정 |
| `docs/CODEBASE.md` | ROS2 패키지 구조, 노드, 토픽, entry point |
| `docs/NETWORK.md` | Web UI, WebSocket bridge, tunnel, SSH/Tailscale 기준 |
| `docs/AUXILIARY.md` | 모델 학습, XAI, 네트워크 테스트 등 보조 자료 |
| `docs/issues/` | 경로 문제, 하드웨어 문제, LiDAR/pose 문제 기록 |
| `web_client/` | GitHub Pages용 정적 Web UI |

## 마스킹 기준

IP, SSH key 경로, Tailscale 계정, tunnel 주소는 `<JETSON_HOST>`, `<SSH_KEY_PATH>`, `<TUNNEL_WSS_URL>`처럼 표기. 모델 파일 본체와 TensorRT engine 파일은 Jetson 런타임 리소스로 관리.
