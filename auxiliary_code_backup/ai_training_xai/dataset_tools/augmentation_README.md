# Augmentation Source

`object2_colab_augmented` 데이터셋 생성에 사용한 증강 생성 코드

## 포함

```text
build_augmented_voc_dataset.py
```

## 사용 예

```cmd
python build_augmented_voc_dataset.py --source object2 --output object2_colab_augmented
```

입력 `object2`: VOC 형식 필요

```text
Annotations/
JPEGImages/
ImageSets/
labels.txt
```

출력 `object2_colab_augmented`: Colab 학습용 압축 파일 `object2_colab_augmented.zip`으로 사용
