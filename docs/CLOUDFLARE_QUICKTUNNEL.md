# Cloudflare Quick Tunnel 실행

GitHub Pages UI를 무료 quick tunnel 주소로 Jetson 브릿지에 연결하는 방식이다.

## 실행

Jetson에서 작업 트리를 배포한 뒤:

```bash
cd ~/turtlebot3_ws
source /opt/ros/galactic/setup.bash
source install/setup.bash
```

브릿지와 Cloudflare tunnel을 한 번에 실행:

```bash
~/turtlebot3_ws/scripts/start_bridge_quicktunnel.sh
```

또는 이 repo의 `turtlebot3_ws/scripts/start_bridge_quicktunnel.sh`를 Jetson의 적절한 위치에 복사해서 실행한다.

출력 예:

```text
https://example-random-name.trycloudflare.com

GitHub Pages WebSocket URL:
wss://example-random-name.trycloudflare.com
```

GitHub Pages UI의 서버 주소 설정에 `wss://...trycloudflare.com`을 입력한다.

## 주소가 매번 바뀌는 문제

무료 quick tunnel은 실행할 때마다 주소가 바뀔 수 있다. 따라서 시연/테스트 시작 시:

1. Jetson에서 quick tunnel 실행
2. 터미널에 출력된 `wss://...trycloudflare.com` 복사
3. GitHub Pages UI 설정창에 붙여넣기

이렇게 운영한다.

## 브릿지 코드 수정 여부

`delivery_bridge_node.py`는 이미 `0.0.0.0:3000`으로 WebSocket 서버를 열 수 있으므로 Cloudflare 전용 코드 변경이 필요 없다. Cloudflare가 외부 `wss://` 요청을 Jetson 내부 `http://localhost:3000`으로 전달한다.

브릿지는 데모 편의성을 위해 별도 token이나 Origin 체크를 하지 않는다. 대신 `create_order`/`retrieve_item`, `A`/`B`, `driver`/`block`/`pen`/`wrench`만 `/move_request`로 변환한다. 그 외 메시지는 ROS로 보내지 않는다.
