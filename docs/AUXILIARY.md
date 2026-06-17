# 보조문서

## 보조 자료 범위

`auxiliary_code_backup/`는 모델 학습, XAI, 네트워크 연결, 매니퓰레이터 티칭을 위한 보조 자료.

## auxiliary_code_backup 구조

| 폴더 | 역할 |
|---|---|
| `ai_training_xai/dataset_tools/` | VOC/XML 변환, train/val 분리, 데이터 증강 |
| `ai_training_xai/object_training/` | Colab 학습, ONNX 변환, 데이터셋 감사, Grad-CAM 실행 스크립트 |
| `ai_training_xai/onnx_gradcam/` | ONNX 추론과 Grad-CAM 확인 노트북 |
| `ai_training_xai/ssd_reference/` | SSD 학습/추론/XAI 외부 참고 코드 |
| `manipulation_teaching/` | 매니퓰레이터 티칭 문서, Dynamixel limit 확인, 조작 메모 |
| `network_connectivity/` | 휴대폰과 Jetson WebSocket 연결 테스트 |

## Git에 두는 자료

- Git에는 학습 스크립트, 변환 코드, 검증 노트북, 체크섬 등 경량 자료 보관.
