# ROS2 Practice Robot Backup

이 저장소는 ROS2 AMR+Manipulator 수업에서 실제 Jetson 환경에 사용한 코드와 보조 실험 코드를 백업한다. 이 프로젝트에서 임시작업하고 검증된 경우 사용자 승낙하에 젯슨쪽도 동기화한다.

## 구조

```text
turtlebot3_ws/
  실제 미션 재현용 ROS2 워크스페이스

auxiliary_code_backup/
  테스트, 보조, 디버깅, 훈련, 추론, XAI 코드 백업

guide/mission/
  미션 화면 자료

docs/
  프로젝트 루트 기준 설명 문서(* turtlebot3_ws\docs 의 docs는 레거시 문서라 그대로 따르면X. 이쪽은 참조하게 되면 사용자에게 물어볼 것. 루트 아래의 docs와는 혼동주의)
```

## 문서

| 문서 | 내용 |
|---|---|
| `turtlebot3_ws/docs/mission_codebase_overview.md` | 미션, 코드 구조, 포함 리소스, 실행 순서 |
| `turtlebot3_ws/docs/external_dependencies.md` | 외부에서 받아야 할 코드, 모델, 시스템 의존성 |
| `turtlebot3_ws/docs/known_path_issues.md` | 현재 백업 구조와 코드 하드코딩 경로 차이 |
| `docs/auxiliary_code_backup.md` | 보조 코드 백업 폴더 설명 |
| `docs/RUN_MISSION.md` | Jetson 실사용 실행/종료 절차 |
| `docs/JETSON_WORK_REF.md` | Jetson 실제 환경과 work_ref 백업 기준 |
| `docs/JETSON_HARDWARE_SETTINGS.md` | Jetson 포트/하드웨어 기준 |
| `docs/JETSON_HARDWARE_TROUBLESHOOTING.md` | 라이다, 매니퓰레이터, 토크 문제 기록 |

## 모델 파일

모델과 훈련 데이터는 Git에 포함하지 않는다. 모델 관련 파일은 Hugging Face `pomupomu2/ros2`에서 받아 Jetson 실행 위치에 배치한다.

## Jetson 반영 전 작업

이 복사본은 Jetson으로 바로 전체 덮어쓰기 위한 것이 아니라, 여기서 ref 기준으로 정리한 뒤 필요한 파일만 Jetson으로 옮기는 작업 트리다.

추가 문서:

| 문서 | 내용 |
|---|---|
| `docs/WORKING_NOTES.md` | Jetson 반영 전 작업 기준 |
| `docs/JETSON_ONLY_RESOURCES.md` | Jetson에만 두는 모델, engine, mp_env 등 |
| `docs/CLOUDFLARE_QUICKTUNNEL.md` | GitHub Pages UI와 Cloudflare quick tunnel 연결 |
| `docs/SSH_TAILSCALE_JETSON.md` | Jetson Tailscale SSH 접속 기준 |
| `docs/LAMBDA_GESTURE_GUIDE.html` | MediaPipe lambda gesture 시각화 |

GitHub Pages용 UI는 이 폴더가 아니라 프로젝트 루트의 `github_pages_robot_ui/`에서 관리한다.
