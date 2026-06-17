# 보조문서

## 보조 자료 범위

`auxiliary_code_backup/`는 모델 학습, XAI, 네트워크 연결, 매니퓰레이터 티칭을 위한 보조 자료.

`docs/LAMBDA_GESTURE_GUIDE.html`은 MediaPipe landmark 기준 손동작 조건을 시각적으로 확인하는 참고 HTML.

## auxiliary_code_backup 구조

| 폴더 | 역할 |
|---|---|
| `ai_training_xai/dataset_tools/` | VOC/XML 변환, train/val 분리, 데이터 증강 |
| `ai_training_xai/object_training/` | Colab 학습, ONNX 변환, 데이터셋 감사, Grad-CAM 실행 스크립트 |
| `ai_training_xai/onnx_gradcam/` | ONNX 추론과 Grad-CAM 확인 노트북 |
| `ai_training_xai/ssd_reference/` | SSD 학습/추론/XAI 외부 참고 코드 |
| `manipulation_teaching/` | 매니퓰레이터 티칭 문서, Dynamixel limit 확인, 조작 메모 |
| `network_connectivity/` | 휴대폰과 Jetson WebSocket 연결 테스트 |

## LAMBDA_GESTURE_GUIDE.html

| 항목 | 내용 |
|---|---|
| 위치 | `docs/LAMBDA_GESTURE_GUIDE.html` |
| 용도 | MediaPipe hand landmark 기준으로 PASS/FAIL 조건 확인 |
| 보존 이유 | 배송 흐름의 손동작 인식 실패를 설명할 때 코드 조건을 눈으로 확인 가능 |

현재 `lambda_sign` 조건은 pinch/OK에 가까움.

## Git에 두는 자료

- Git에는 학습 스크립트, 변환 코드, 검증 노트북, 체크섬 등 경량 자료 보관.
