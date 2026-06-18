# 네트워크

## 전체 연결 구조

```text
브라우저 UI
  -> GitHub Pages web_client
  -> wss://<TUNNEL_WSS_URL>
  -> Jetson tunnel process
  -> ROS2 WebSocket bridge
  -> ROS2 topics
```

## Web UI

| 항목 | 값 |
|---|---|
| Repository | `https://github.com/EchidnaRezero/ros_project2` |
| Web UI source | `web_client/` |
| Original Web UI | `https://github.com/HisameOgasahara/ros_webclient` |
| Pages URL | `https://echidnarezero.github.io/ros_project2/web_client/` |
| Debug URL | `https://echidnarezero.github.io/ros_project2/web_client/debug.html` |
| 입력할 서버 주소 | `wss://<TUNNEL_WSS_URL>` |

Web UI에서 방, 물품, 배송/회수 요청 입력.

## WebSocket bridge

Jetson 내부 WebSocket bridge는 ROS2 topic과 Web UI 명령 연결.

| 항목 | 기준 |
|---|---|
| 내부 host | `0.0.0.0` |
| 기본 port | `3000` |
| 발행 topic | `/move_request` |
| 구독 topic | `/move_finish` |

Bridge는 허용된 명령만 `/move_request`로 변환.

| 값 종류 | 허용 값 |
|---|---|
| action | `create_order`, `retrieve_item` |
| destination | `A`, `B` |
| item | `driver`, `block`, `pen`, `wrench` |

## Cloudflare quick tunnel

외부 브라우저가 Jetson 내부 bridge에 직접 접근하기 어려운 경우 quick tunnel 사용.

전체 미션 실행:

```bash
~/turtlebot3_ws/scripts/start_mission_tmux.sh
```

Bridge와 tunnel만 따로 실행:

```bash
~/turtlebot3_ws/scripts/start_bridge_quicktunnel.sh
```

운영 순서:

1. Jetson에서 미션 또는 bridge/tunnel 실행.
2. 터미널에 출력된 WSS 주소 확인.
3. GitHub Pages UI 설정창에 WSS 주소 입력.

무료 quick tunnel 주소는 실행할 때마다 변경 가능.

주소 확인:

```bash
cat ~/turtlebot3_ws/mission_urls.txt 2>/dev/null || true
```

Bridge는 Cloudflare 전용 코드 없이 `0.0.0.0:3000` WebSocket 서버를 열고, tunnel이 외부 `wss://` 요청을 Jetson 내부 bridge로 전달.

데모용 bridge는 별도 token이나 Origin 검증 없이 허용된 명령만 ROS topic으로 변환.

## SSH / Tailscale

Jetson 원격 관리는 SSH와 Tailscale 사용.

공개 문서 예시:

```bash
ssh -i <SSH_KEY_PATH> <JETSON_USER>@<JETSON_HOST>
```

## 마스킹 기준

| 실제 의미 | 공개용 표기 |
|---|---|
| Jetson host | `<JETSON_HOST>` |
| Jetson Tailscale IP | `<JETSON_TAILSCALE_IP>` |
| Jetson hotspot IP | `<JETSON_HOTSPOT_IP>` |
| SSH 개인키 경로 | `<SSH_KEY_PATH>` |
| Tailscale 계정 | `<TAILSCALE_ACCOUNT>` |
| Tailscale 장치명 | `<TAILSCALE_DEVICE_NAME>` |
| Cloudflare WSS URL | `wss://<CLOUDFLARE_QUICK_TUNNEL_HOST>` |
| 일반 tunnel WSS URL | `wss://<TUNNEL_WSS_URL>` |
