# ROS2 Manipulator 실습 기록: Dynamixel 위치값, 토크, 가동 범위 분석

## 1. 실습 개요

ROS2 기반 로봇팔 매니퓰레이션 실습 기록

로봇팔은 Dynamixel XL430 계열 모터 5개를 사용. GUI 티칭과 자동 재생 구조는 `manipulator_architecture.md` 참고.

이 문서는 실습 중 확인한 위치값, torque 상태, 가동 범위, overflow 로그 중심 기록.

## 2. 하드웨어 구성과 모터 ID

강의자료 기준 Manipulator에 사용된 Dynamixel 모터 ID:

```text
ID 11: 바닥 회전 관절
ID 12: 어깨 관절
ID 13: 팔꿈치 관절
ID 14: 손목 관절
ID 15: 그리퍼 관절
```

각 ID의 역할은 조립 방향에 따라 체감 동작 차이 가능

기본 구조: 각 모터 하나가 로봇팔의 관절 하나 담당

로봇팔의 한 자세: 다음 5개 숫자 조합으로 표현

```text
ID11 = 4059
ID12 = 695
ID13 = 2763
ID14 = 2890
ID15 = 3284
```

이 숫자 조합 하나가 Step이며, 여러 Step의 순차 실행으로 하나의 Motion 구성

## 3. Joint State 관점

ID 11~15의 position 조합이 로봇팔의 joint state 역할.

## 4. Dynamixel 위치값의 의미

Dynamixel XL430-W250-T 기준 Position Control Mode의 기본 위치 단위:

```text
0 ~ 4095 ~= 0 ~ 360 degrees
1 count ~= 0.088 degrees
```

예시:

```text
0    ~= 0 degrees
1024 ~= 90 degrees
2048 ~= 180 degrees
3072 ~= 270 degrees
4095 ~= 360 degrees 직전
```

단, 이 값은 "방 기준 북쪽/남쪽" 같은 절대 방향이 아님

모터 내부의 출력축 기준 위치값

조립 방향, 혼(horn) 체결 방향, 브래킷 방향에 따라 같은 숫자라도 실제 로봇팔의 시각적 자세 차이 가능

`0~4095`: 모든 모터가 공통으로 사용하는 숫자 범위

기준 방향: 모터마다 별도

모션 티칭 시 각 ID별 실제 자세와 숫자 함께 기록 권장

```text
ID12 = 700 부근: 어깨가 낮게 내려간 자세
ID13 = 2800 부근: 팔꿈치가 접힌 자세
ID15 = 3280 부근: 그리퍼가 닫힌 자세
```

이런 기록은 나중에 모션 디버깅이나 면접 설명에서 "숫자가 어떤 물리 상태를 의미했는지" 설명할 때 유용

## 5. Torque 관측 기준

Torque ON/OFF와 GUI 티칭 절차는 `manipulator_architecture.md` 참고.

이 실습에서 중요한 관측점:

- Torque OFF는 센서 비활성화가 아니므로 present position 읽기 가능
- 손으로 관절을 움직이면 출력축 회전에 따라 current position 값 갱신
- 안전한 motion 저장은 `0~4095` 범위 확인 뒤 진행

## 6. 실습 중 확인한 모터 상태

DynamixelSDK로 ID 11~15의 상태 직접 확인

확인 스크립트: `check_dxl_limits.py`

확인 항목: 각 모터의 operating mode, torque 상태, min/max position limit, present position, voltage, temperature, hardware error

실제 확인 결과:

```text
device=/dev/ttyACM1, baudrate=1000000
position unit: 0~4095 = 0~360 degrees, about 0.088 degree per count

ID11
  operating mode : 3 (Position Control)
  drive mode     : 4
  torque         : OFF
  min limit      : 0
  max limit      : 4095
  goal position  : 4059
  current pos    : 4059
  velocity       : 0
  temperature    : 39 C
  voltage        : 12.0 V
  hardware error : 0

ID12
  operating mode : 3 (Position Control)
  min limit      : 0
  max limit      : 4095
  current pos    : 695
  hardware error : 0

ID13
  operating mode : 3 (Position Control)
  min limit      : 0
  max limit      : 4095
  current pos    : 2763
  hardware error : 0

ID14
  operating mode : 3 (Position Control)
  min limit      : 0
  max limit      : 4095
  current pos    : 2890
  hardware error : 0

ID15
  operating mode : 3 (Position Control)
  min limit      : 0
  max limit      : 4095
  current pos    : 3284
  hardware error : 0
```

이 결과로 확인한 내용:

```text
1. ID 11~15 모터 모두 통신 가능
2. 모두 Position Control Mode, 즉 Operating Mode 3
3. Goal Position 제한은 0~4095
4. 전압 12.0V로 정상
5. 온도 36~39도 수준으로 정상
6. hardware error = 0으로 모터 내부 에러 없음
```

## 7. Goal Position Limit과 Present Position의 차이

실습 중 확인한 중요한 차이:

```text
Goal Position:
  모터에게 명령으로 보낼 목표 위치값
  Position Control Mode에서는 Min/Max Position Limit의 영향을 받음
  실습 장비에서는 0~4095

Present Position:
  현재 모터 출력축이 실제로 어디에 있는지 읽은 값
  Torque OFF 상태에서 손으로 돌리면 0~4095를 넘는 값도 관측될 수 있음
```

`max limit = 4095`라고 해서 `Present Position`이 항상 4095 이하로만 읽힌다는 뜻은 아님

Torque OFF 상태에서 손으로 출력축을 돌리면 다음과 같이 증가 가능

```text
4059
5018
5155
5395
5636
```

이 값들은 "Goal Position으로 안전하게 명령할 수 있는 값"이라기보다, 토크가 꺼진 상태에서 손으로 돌려 발생한 현재 위치 readback 값에 가까움

모션 저장 시 적용한 원칙:

```text
current 값이 0~4095 안에 있을 때만 save step
0보다 작거나 4095보다 크면 저장하지 않음
```

## 8. 음수/초과값 관련 로그와 분석

특정 방향으로 관절을 움직이면서 current 값이 0을 향해 감소하다가, 0 아래로 내려가는 구간에서 노드 종료 문제 발생

로그 핵심:

```text
AssertionError: The 'position' field must be an integer in [-2147483648, 2147483647]
```

발생 위치: SDK 노드의 `/get_position` 서비스 응답 처리 부분

```text
read_write_node_omx.py
get_position_callback()
response.position = dxl_present_position
```

원인 해석:

```text
1. Dynamixel Present Position은 4바이트 값으로 읽힘
2. 0 아래로 내려간 값이 unsigned 32-bit처럼 해석될 수 있음
3. 예를 들어 -1이 4294967295처럼 보일 수 있음
4. ROS2 custom service의 position 필드는 int32
5. int32 최대값 2147483647보다 큰 값을 response.position에 넣으면서 AssertionError 발생
```

예상 변환 관계:

```text
-1  -> 4294967295
-2  -> 4294967294
-10 -> 4294967286
```

이 문제는 "모터가 물리적으로 고장났다"기보다, `Present Position` readback 값을 ROS2 int32 응답에 그대로 넣으면서 생긴 signed/unsigned 해석 문제로 판단

## 9. 코드 수정 검토

초기 수정 방안으로 `% 4096` 정규화 고려

```python
dxl_present_position = dxl_present_position % 4096
```

이 방식의 문제:

```text
5636 -> 1540
4097 -> 1
-1   -> 4095
```

이렇게 값이 겉으로는 0~4095 안에 들어오지만, 실제로는 "한 바퀴 이상 돌아갔다" 또는 "음수 방향으로 넘어갔다"는 정보 손실

GUI가 이 값을 그대로 저장하면 이상 상태를 정상 위치처럼 저장할 위험

더 안전한 판단:

```text
1. Present Position readback은 unsigned -> signed 변환만 적용
2. %4096으로 조용히 감싸지 않음
3. 0~4095 밖의 current 값은 사람이 보고 저장하지 않음
4. Goal Position은 0~4095 밖이면 실행하지 않도록 방어하는 것이 안전
```

최소 수정 예시:

```python
raw_position = dxl_present_position

if raw_position > 0x7FFFFFFF:
    dxl_present_position = raw_position - 0x100000000
else:
    dxl_present_position = raw_position

response.position = int(dxl_present_position)
```

이렇게 하면 `4294967295`가 `-1`로 바뀌어 ROS2 int32 범위 안에 진입하고, 노드 종료 방지

동시에 `5000` 같은 초과값은 그대로 보여 사람이 이상 상태 판단 가능

Goal Position 전송부에서 고려할 검증:

```python
goal_position = int(msg.position)

if goal_position < 0 or goal_position > 4095:
    self.get_logger().error(
        f'[ID: {msg.id}] Goal Position {goal_position} outside 0..4095. Ignore command.'
    )
    return
```

이 방식은 `%4096`으로 값을 몰래 바꾸는 것보다 안전

예를 들어 `5636`을 자동으로 `1540`으로 바꿔 실행하면, 사용자가 잘못 저장된 모션을 알아차리기 어려움

## 10. 실제 가동 범위 기록의 필요성

제조사/모터 기준 범위와 실제 로봇팔의 안전 범위는 다름

```text
모터 내부 limit:
  0~4095

실제 로봇팔 안전 범위:
  브래킷 간섭, 케이블 장력, 링크 충돌, 그리퍼 간섭을 고려해야 함
```

모션 티칭 전 각 관절별 실제 안전 범위 기록 권장

기록표 예시:

```text
ID11 바닥 회전
  왼쪽 안전 한계:
  오른쪽 안전 한계:
  실사용 범위:

ID12 어깨
  위쪽 안전 한계:
  아래쪽 안전 한계:
  실사용 범위:

ID13 팔꿈치
  접힘 한계:
  펴짐 한계:
  실사용 범위:

ID14 손목
  위쪽 한계:
  아래쪽 한계:
  실사용 범위:

ID15 그리퍼
  열림 값:
  닫힘 값:
  물건을 안정적으로 잡는 값:
```

측정 방법:

```text
1. Torque OFF
2. 관절을 손으로 천천히 움직임
3. 물리적으로 걸리기 직전에서 멈춤
4. Torque ON
5. read positions from dxl
6. current 값 기록
7. 반대 방향도 동일하게 기록
8. 실제 사용값은 한계값보다 여유를 둠
```

예: 물리적 한계가 700이라면 실제 모션에는 800 이상을 사용하는 방식으로 안전 여유 확보

### 실습 중 기록한 관절별 실사용 끝단값

아래 값들: 실제 물리 한계에 딱 닿는 극한값이 아니라, 충돌/간섭 원인 확인 뒤 약간의 여유를 두고 정한 실사용 끝단값

괄호 안의 내용: 해당 방향의 가동 범위를 제한하는 주요 원인

```text
ID11 바닥 회전
  특징:
    거의 360도 가까이 회전 가능
    다른 관절보다 0 아래 또는 4095 초과 readback 문제가 발생하기 쉬움
    모션 저장 시 current 값이 0~4095 안에 있는지 특히 확인 필요

ID12 어깨
  실사용 범위:
    800 (로봇 바닥판 간섭) ~ 3000 (LiDAR 간섭)

ID13 팔꿈치
  실사용 범위:
    800 (모터 간섭) ~ 2700 (로봇팔 링크 간섭)

ID14 손목
  실사용 범위:
    880 (전선 간섭) ~ 2800 (전선 간섭)

ID15 그리퍼
  실사용 범위:
    3300 ~ 3800
  제한 원인:
    양쪽 모두 집게 구조/그리퍼 기구 한계
```

이 기록으로 확인한 점:

```text
1. 코드상 Dynamixel Goal Position Limit은 모든 모터가 0~4095로 동일
2. 실제 조립된 로봇팔에서는 관절마다 물리적 간섭 때문에 실사용 범위 축소
3. ID12~ID15는 로봇 바닥판, LiDAR, 모터, 팔 링크, 전선, 그리퍼 구조 때문에 대략 180도 전후 범위에서 사용
4. ID11은 바닥 회전 관절이라 상대적으로 넓은 회전 범위, Present Position이 0 아래 또는 4095 이상으로 넘어가는 readback 문제 주 발생
```

모션 티칭 시 판단 기준:

```text
ID11:
  0~4095 범위 이탈 여부를 우선 확인
  overflow/underflow성 readback에 주의

ID12~ID14:
  기록한 실사용 범위 안에서만 자세 저장
  괄호 안의 간섭 원인을 기억하고 극한값 근처 사용 자제

ID15:
  단순 각도 관절이라기보다 그리퍼 열림/닫힘 값으로 관리
  물건별 안정적으로 잡히는 값을 추가로 기록하면 좋음
```

## 11. 포트폴리오/면접에서 설명하기 좋은 포인트

이 실습: 단순 GUI 조작이 아니라 실제 하드웨어 로그 기반 위치값과 제어 흐름 분석 경험으로 정리 가능

면접에서 설명할 수 있는 구체적 상황:

```text
Dynamixel XL430 기반 ROS2 manipulator로 motion teaching 수행
각 Dynamixel position value는 월드 좌표계 기준 각도가 아니라 각 모터 출력축 기준의 local joint value이며, ID11~ID15 조합이 로봇팔의 joint state/DOF 상태를 구성한다는 점 확인
GUI에서 Torque OFF 후 손으로 자세를 잡고, /get_position 서비스로 각 모터의 Present Position을 읽어 Step으로 저장
제조사 기준 Goal Position Limit은 0~4095지만, 실제 조립된 로봇팔에서는 로봇 바닥판, LiDAR, 모터, 팔 링크, 전선, 그리퍼 구조 등으로 인해 ID12~ID15의 실사용 범위가 훨씬 좁다는 점 확인 및 관절별 안전 끝단값 기록
실습 중 특정 관절을 0 근처로 이동할 때 read_write_node_omx.py가 AssertionError로 종료되는 문제 발생
로그 분석 결과, Present Position의 unsigned 32-bit readback 값이 ROS2 int32 service field 범위를 초과한 것이 원인
Goal Position Limit 0~4095와 Torque OFF 상태의 Present Position readback 범위가 다를 수 있음을 구분
%4096 정규화는 값 손실과 잘못된 모션 저장을 유발할 수 있어, unsigned->signed 변환 및 0~4095 범위 검증이 더 안전하다는 판단
```

기술 키워드:

```text
ROS2
rclpy
DynamixelSDK
XL430-W250-T
Position Control Mode
Torque Enable
Present Position
Goal Position
Joint Limit
Joint State
Local Joint Angle
Forward Kinematics
TF
Motion Teaching
Hardware Bringup
Log Analysis
Signed/Unsigned Integer
ROS2 Topic/Service
```

면접용 요약 문장:

```text
ROS2 기반 Dynamixel manipulator 실습에서 각 Dynamixel position value가 개별 모터의 local joint angle이며 ID11~ID15의 조합이 로봇팔의 joint state를 구성한다는 관점으로 모션 티칭 진행
GUI 티칭 과정에서 발생한 Present Position overflow 문제를 로그로 분석
모터의 Goal Position Limit은 0~4095지만, Torque OFF 상태에서 손으로 관절을 돌릴 때 Present Position은 multi-turn 또는 signed 32-bit 범위로 읽힐 수 있음
이 값이 ROS2 int32 service response에 그대로 들어가면서 AssertionError 발생, 단순히 %4096으로 보정하면 잘못된 자세를 정상값처럼 저장할 위험 확인
readback은 signed 변환으로 노드 크래시를 막고, 모션 저장/실행 시에는 0~4095 범위를 검증하는 방향이 안전하다는 판단
```

## 12. 참고

- ROBOTIS XL430-W250-T e-Manual  
  https://emanual.robotis.com/docs/en/dxl/x/xl430-w250/

- 주요 레지스터

```text
Operating Mode        : address 11
Torque Enable         : address 64
Hardware Error Status : address 70
Goal Position         : address 116
Present Velocity      : address 128
Present Position      : address 132
Present Input Voltage : address 144
Present Temperature   : address 146
```
