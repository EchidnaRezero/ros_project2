# Robot Delivery UI

## 실행

1. Jetson에서 아래 명령어 하나만 실행한다.

```bash
~/turtlebot3_ws/scripts/start_mission_tmux.sh
```

2. 브라우저에서 웹 UI를 연다.

[Robot Delivery UI 열기](https://echidnarezero.github.io/ros_project2/web_client/)

3. Jetson tmux의 `urls` 창에 나온 `wss://...trycloudflare.com` 주소를 웹 UI 상단 입력칸에 붙여넣고 `연결`을 누른다.

`urls` 창에는 이런 식으로 나온다.

```text
Open UI:
https://echidnarezero.github.io/ros_project2/web_client/

Paste into UI:
wss://...trycloudflare.com
```

상태가 `연결됨`이 되면 주문을 보낸다.

## 주문/회수

1. 방 `A` 또는 `B`를 선택한다.
2. 물품 `driver`, `block`, `pen`, `wrench` 중 하나를 선택한다.
3. `주문하기`를 누른다.
4. 배송 완료 후 필요한 경우 `사용 완료`를 누르고 회수 요청을 보낸다.

## 비상 조작

Jetson tmux에서 `safety` 창을 연다.

```text
1) Stop bringup/nav motion
2) Stop all mission tmux
q) Quit this safety menu only
```

로봇 이동만 멈추려면 `1`을 누른다.

미션 전체를 종료하려면 `2`를 누른다.

## 연결 확인

웹 UI 연결이 안 되면 [debug 페이지](https://echidnarezero.github.io/ros_project2/web_client/debug.html)를 연다.

미션 실행 때 나온 같은 `wss://...trycloudflare.com` 주소를 넣고 `Connect`를 누른다.

연결이 되면 GitHub Pages -> Cloudflare -> Jetson WebSocket 경로는 살아 있다.

## 종료

Jetson에서:

```bash
~/turtlebot3_ws/scripts/stop_mission_tmux.sh
```
