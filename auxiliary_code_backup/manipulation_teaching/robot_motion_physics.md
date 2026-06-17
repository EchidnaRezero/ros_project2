# 매니퓰레이터 코드와 물리량 대응

현재 코드에서 실제로 읽고 쓰는 값만 기준으로 정리.

## 전체 대응

```mermaid
flowchart LR
    user["사용자 수동 티칭"]
    encoder["Dynamixel present position"]
    gui["manipulatorGUI<br/>current/saved"]
    json["saved_motions.json<br/>motions/times/next_motions"]
    ctrl["manipulatorCtrl<br/>motion_id 재생"]
    topic["/set_position<br/>id, position, runtime"]
    dxl["read_write_node_omx.py<br/>Dynamixel register write"]
    done["/move_resume"]

    user --> encoder --> gui --> json --> ctrl --> topic --> dxl --> done
```

| 코드 값 | 실제 의미 | 물리적으로 볼 수 있는 값 |
|---|---|---|
| `DXL_IDS = [11, 12, 13, 14, 15]` | 제어 대상 Dynamixel ID | 관절별 모터 ID |
| `position` | Dynamixel goal/present position 값 | 엔코더 tick |
| `motions[m][s][i]` | `m`번 Motion, `s`번 Step, `i`번 모터 목표 position | 저장된 관절 자세 |
| `times[m][s][0]` | 해당 Step의 `run_time` | 하위 노드에 전달되는 profile 시간값 |
| `times[m][s][1]` | 해당 Step 후 `end_delay` | 다음 Step 전 대기 시간 |
| `next_motions[m]` | 현재 Motion 뒤 자동 실행할 Motion 번호 | Motion 간 전이 |

## ID와 배열 인덱스

`manipulatorGUI.py`와 `manipulatorCtrl.py` 모두 Dynamixel ID 11~15를 5개 position 배열에 대응.

| Dynamixel ID | 배열 인덱스 | 코드 기준 |
|---|---:|---|
| `11` | `0` | `dxl_id - 11` |
| `12` | `1` | `dxl_id - 11` |
| `13` | `2` | `dxl_id - 11` |
| `14` | `3` | `dxl_id - 11` |
| `15` | `4` | `dxl_id - 11` |

관련 코드:

```python
self.motions[self.motion][self.step][motor.dxl_id - 11] = int(text)
```

```python
msg.id = DXL_IDS[j]
msg.position = int(pos)
```

## 티칭 시 position 저장

GUI에서 `readButton`을 누르면 `/get_position` service로 현재 Dynamixel present position 요청.

```python
motor.request_position(self.position_response_callback)
```

응답 값은 `current` 칸과 `motor.curPosition`에 반영.

```python
motor.curPosition = response.position
self.currentLineEdits[dxl_id].setText(str(motor.curPosition))
```

`save step` 동작은 현재 position을 `saved` 칸과 `motions` 배열에 복사.

```python
self.savedLineEdits[motor.dxl_id].setText(text)
self.motions[self.motion][self.step][motor.dxl_id - 11] = int(text)
```

이 코드에서 확인되는 물리량:

| GUI 값 | 의미 |
|---|---|
| `current` | 방금 읽은 present position |
| `saved` | Step에 저장할 목표 position |
| `motions[m][s]` | 5개 Dynamixel position으로 구성된 한 자세 |

## Step 실행

GUI의 `run step`과 `manipulatorCtrl.py`의 자동 실행은 모두 `/set_position`으로 목표값 발행.

```python
msg.id = motor_id
msg.position = target_position
msg.runtime = run_time
```

`SetPosition.msg` 실제 구조:

```text
uint8 id
int32 position
float32 runtime
```

하위 Dynamixel 노드는 이 값을 받아 다음 register에 기록.

| 메시지 필드 | 하위 노드 처리 |
|---|---|
| `id` | 대상 Dynamixel ID |
| `position` | `ADDR_GOAL_POSITION`에 기록 |
| `runtime` | `ADDR_PROFILE_VELOCITY`, `ADDR_PROFILE_ACCELERATION` 계산에 사용 |

관련 코드:

```python
ADDR_PROFILE_VELOCITY = 112
ADDR_PROFILE_ACCELERATION = 108
ADDR_GOAL_POSITION = 116
```

```python
write4ByteTxRx(port, msg.id, ADDR_PROFILE_VELOCITY, int(msg.runtime * 1000))
write4ByteTxRx(port, msg.id, ADDR_PROFILE_ACCELERATION, int(msg.runtime * 250))
write4ByteTxRx(port, msg.id, ADDR_GOAL_POSITION, goal_position)
```

따라서 `runtime`은 코드에서 직접 궤적을 계산하는 값이 아니라, Dynamixel profile register에 넘기는 입력값.

## Motion 실행

`manipulatorCtrl.py`는 `/manipulator/motion_id`를 받으면 `saved_motions.json`에서 해당 Motion을 선택.

```python
idx = motion_id - 1
steps = self.motions[idx]
times = self.times[idx]
```

각 Step에서 5개 position을 순서대로 `/set_position` 발행.

```python
for step_idx, joint_positions in enumerate(steps):
    move_time, stop_time = times[step_idx]

    for j, pos in enumerate(joint_positions):
        msg.id = DXL_IDS[j]
        msg.position = int(pos)
        msg.runtime = float(move_time)
        self.pos_pub.publish(msg)
```

대기 동작:

```python
time.sleep(move_time)
if stop_time > 0.0:
    time.sleep(stop_time)
```

코드 기준 Motion의 의미:

| 단계 | 코드 동작 | 물리적 의미 |
|---|---|---|
| Step 선택 | `joint_positions` 읽기 | 5개 모터 목표 position 선택 |
| 발행 | `/set_position` 5회 발행 | 각 모터에 목표 position 전달 |
| 이동 대기 | `time.sleep(move_time)` | profile 실행 시간만큼 대기 |
| 정지 대기 | `time.sleep(stop_time)` | 다음 Step 전 유지 시간 |

## 다음 Motion과 완료 신호

`manipulatorCtrl.py`는 자동 실행에서 `next_motions`만 사용. `spin_numbers`는 GUI 저장/수동 실행 쪽 값이며 Ctrl 자동 실행에는 사용되지 않음.

```python
next_motion = self.next_motions[idx]

if next_motion != 0:
    self.execute_motion(next_motion)
else:
    self.move_resume_pub.publish(Bool(data=True))
```

| 값 | Ctrl 자동 실행 기준 |
|---|---|
| `next_motions[idx] != 0` | 다음 Motion 재귀 실행 |
| `next_motions[idx] == 0` | `/move_resume=True` 발행 |
| `spin_numbers` | `manipulatorCtrl.py`에서 미사용 |

## Torque ON/OFF

GUI는 선택된 모터에 `/set_torque` 발행.

```python
msg.id = self.dxl_id
msg.torque = enable
self.torquePublisher.publish(msg)
```

하위 노드는 `ADDR_TORQUE_ENABLE`에 `1` 또는 `0` 기록.

```python
ADDR_TORQUE_ENABLE = 64
TORQUE_ENABLE = 1
TORQUE_DISABLE = 0
```

| GUI 동작 | 하위 노드 값 | 의미 |
|---|---:|---|
| Torque ON | `1` | 위치 제어 활성 |
| Torque OFF | `0` | 모터 출력 해제, 수동 티칭 가능 |

## 이 문서에서 제외한 내용

현재 코드에서 직접 계산하지 않는 항목:

- 정기구학 `x = f(q)`
- DH parameter 기반 말단 pose 계산
- Jacobian 기반 말단 속도 계산
- 동역학 방정식 기반 torque 계산
- Python 노드 내부 trajectory interpolation

위 항목은 로봇공학적으로 설명할 수 있는 배경 지식이지만, 현재 코드의 실행 경로와 직접 대응되는 계산은 아님.
