# Object2 Colab Notebook Runtime Files

현재 `colab_object2_train.ipynb`와 Colab 학습에 사용한 보조 파일을 보관한 묶음이다. 이 폴더의 파일은 백업용으로 평평하게 놓여 있다.

## 포함

```text
colab_object2_train.ipynb
audit_voc_dataset.py
colab_drive_train_object2.sh
run_colab_gradcam_test_images.py
run_ssd_gradcam_auto_resized_v3.py
onnx_export_local.py
ONNX_CONVERSION_NOTES.md
```

## 전제

기존 MobileNetV1-SSD 학습 코드와 `object2_colab_augmented.zip`은 별도로 둔다.

Colab 실행 시에는 노트북과 스크립트가 아래 배치를 전제로 한다.

```text
training_code/tools/audit_voc_dataset.py
training_code/tools/colab_drive_train_object2.sh
training_code/mbnet/ros/train_ssd.py
training_code/mbnet/ros/run_colab_gradcam_test_images.py
training_code/mbnet/ros/run_ssd_gradcam_auto_resized_v3.py
```
