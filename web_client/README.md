# Robot Delivery UI

## 실행

1. Jetson에서 아래 명령어 하나만 실행

```bash
~/turtlebot3_ws/scripts/start_mission_tmux.sh
```

2. 브라우저에서 웹 UI 열기

[Robot Delivery UI 열기](https://echidnarezero.github.io/ros_project2/web_client/)

3. Jetson tmux의 `urls` 창에 나온 `wss://...trycloudflare.com` 주소를 웹 UI 상단 입력칸에 붙여넣고 `연결` 선택

`urls` 창 출력 예시:

```text
Open UI:
https://echidnarezero.github.io/ros_project2/web_client/

Paste into UI:
wss://...trycloudflare.com
```

상태가 `연결됨`이면 주문 전송

## 주문/회수

1. 방 `A` 또는 `B` 선택
2. 물품 `driver`, `block`, `pen`, `wrench` 중 하나 선택
3. `주문하기` 선택
4. 배송 완료 후 필요한 경우 `사용 완료` 선택 및 회수 요청 전송

## 비상 조작

Jetson tmux에서 `safety` 창 열기

```text
1) Stop bringup/nav motion
2) Stop all mission tmux
q) Quit this safety menu only
```

로봇 이동만 멈추려면 `1` 선택

미션 전체 종료는 `2` 선택

## 연결 확인

웹 UI 연결 실패 시 [debug 페이지](https://echidnarezero.github.io/ros_project2/web_client/debug.html) 열기

미션 실행 때 나온 같은 `wss://...trycloudflare.com` 주소 입력 후 `Connect` 선택

연결 성공 시 GitHub Pages -> Cloudflare -> Jetson WebSocket 경로 정상

## 종료

Jetson에서:

```bash
~/turtlebot3_ws/scripts/stop_mission_tmux.sh
```
