# Phone-Jetson WebSocket Test

현재 ROS2 프로젝트와 무관하게, 핸드폰 브라우저와 Jetson Nano 사이의 WebSocket 통신만 확인하기 위한 테스트 파일 모음

현재 `work_ref_jetson_ready`에서 사용 가능한 두 가지 방식

- 로컬/핫스팟 확인: Jetson이 `phone_ws_client.html` 직접 제공, 폰이 `ws://JETSON_IP:3000`에 연결
- GitHub Pages/Cloudflare 확인: GitHub Pages의 `debug.html`이 `wss://...trycloudflare.com`으로 echo 서버에 연결

실제 로봇 명령 브릿지와 충돌하지 않도록 Cloudflare echo 테스트는 기본 WebSocket 포트 `3001`, HTTP 포트 `8001` 사용

## 성공한 방식

Jetson이 HTML을 HTTP로 제공, 핸드폰은 해당 URL로 접속

```text
Phone browser
-> http://{{JETSON_IP}}:8000/phone_ws_client.html
-> ws://{{JETSON_IP}}:3000
-> Jetson WebSocket server
```

`{{JETSON_IP}}`에는 Jetson에서 서버 실행 시 출력되는 핫스팟/Wi-Fi IP 입력

성공 당시 예시:

```text
{{JETSON_IP}} = 10.59.121.144
```

## 1. Jetson Nano에서 실행

Jetson Nano 터미널에서:

```bash
python3 -m pip install websockets
python3 ws_echo_server_jetson.py
```

정상 실행 시 아래 두 서버 동시 실행

```text
WebSocket: ws://0.0.0.0:3000
HTML page: http://0.0.0.0:8000/phone_ws_client.html
```

서버 출력 중 아래 부분 확인

```text
hostname -I: {{JETSON_IP}} ...

Use this on the phone browser:
  http://{{JETSON_IP}}:8000/phone_ws_client.html
This page will connect WebSocket to:
  ws://{{JETSON_IP}}:3000
```

폰에서는 `Use this on the phone browser:` 아래에 출력된 주소 그대로 입력

## GitHub Pages + Cloudflare echo 테스트

실제 delivery bridge 실행 전 외부 WebSocket 경로만 확인할 때 사용

Jetson에서:

```bash
cd ~/ros_project/auxiliary_code_backup/network_connectivity
chmod +x start_echo_quicktunnel.sh
./start_echo_quicktunnel.sh
```

스크립트 내부 echo 서버 설정:

```text
WS_PORT=3001
HTTP_PORT=8001
```

이후 `cloudflared tunnel --url http://localhost:3001` 실행

출력 중 아래 형식의 주소 복사

```text
wss://example-random-name.trycloudflare.com
```

GitHub Pages의 `debug.html` 열기 후 WebSocket URL에 위 주소 입력

```text
https://HisameOgasahara.github.io/ros_webclient/debug.html
```

`Connect` 후 `Send` 선택 시 `received: echo: hello from github pages`가 나오면 아래 경로 정상

```text
GitHub Pages debug.html
-> Cloudflare quick tunnel
-> Jetson echo WebSocket server
```

이 테스트는 ROS2 topic 변경 없음. 네트워크/WebSocket 계층만 확인

포트 변경 시 실행할 때 환경변수 지정

```bash
WS_PORT=3011 HTTP_PORT=8011 ./start_echo_quicktunnel.sh
```

## 2. 핸드폰에서 열기

핸드폰 브라우저 주소창에 아래 주소 입력

```text
http://{{JETSON_IP}}:8000/phone_ws_client.html
```

예시:

```text
http://10.59.121.144:8000/phone_ws_client.html
```

화면에서 `Send Test Message` 버튼 선택

## 성공 기준

- 핸드폰 화면에 `connected` 표시
- 핸드폰 화면에 `received: echo: hello from phone` 표시
- Jetson 터미널에 `received: hello from phone` 출력

## 실패 원인과 대처

### 1. 폰에서 HTML 파일 직접 열기 실패 가능

증상:

```text
page origin: content://...
closed: code=1006
```

원인:

폰 파일 앱/브라우저가 HTML을 `content://...` 출처로 열면 외부 `ws://{{JETSON_IP}}:3000` WebSocket 연결 실패 가능. 일반적인 fetch/ajax CORS라기보다는 모바일 브라우저의 로컬 파일/content origin 보안 정책 문제에 가까움

대처:

HTML을 폰에서 파일로 직접 열지 않고, Jetson에서 HTTP로 제공

```bash
python3 ws_echo_server_jetson.py
```

폰에서는 아래처럼 HTTP URL로 접속

```text
http://{{JETSON_IP}}:8000/phone_ws_client.html
```

### 2. `404 File not found`

증상:

```text
GET /phone_ws_client.html HTTP/1.1 404
```

원인:

HTTP 서버가 보고 있는 폴더에 `phone_ws_client.html` 없음

대처:

최신 `ws_echo_server_jetson.py`는 `phone_ws_client.html`이 없으면 자동 생성. 최신 파일을 Jetson에 복사한 뒤 다시 실행

## 테스트 코드 설명

`ws_echo_server_jetson.py`는 Jetson에서 실행하는 단일 테스트 서버

실행 시 다음 작업 수행

- Jetson의 Python 실행 경로와 버전 출력
- Jetson의 현재 네트워크 주소 출력
- `phone_ws_client.html`이 없으면 자동 생성
- `0.0.0.0:8000`에서 HTML 테스트 페이지 제공
- `0.0.0.0:3000`에서 WebSocket echo 서버 제공

폰에서는 파일을 직접 열 필요 없이 아래 주소만 열기

```text
http://{{JETSON_IP}}:8000/phone_ws_client.html
```

`phone_ws_client.html`은 핸드폰 브라우저에서 열리는 테스트 페이지

이 페이지의 수행 작업

- 현재 접속한 Jetson host를 기준으로 WebSocket 주소 자동 설정
- `ws://<현재 Jetson IP>:3000`에 연결
- 연결 성공/실패 로그 표시
- `Send Test Message` 버튼으로 `hello from phone` 전송
- Jetson에서 받은 echo 응답 표시

## IP가 바뀌었을 때

다른 핸드폰 핫스팟이나 다른 Wi-Fi 사용 시 Jetson IP 변경 가능

먼저 Jetson에서 서버를 실행했을 때 출력되는 `Use this on the phone browser:` 주소 확인

예를 들어 새 IP가 `10.59.121.200`이면 `{{JETSON_IP}}` 자리에 해당 값 입력

```text
http://{{JETSON_IP}}:8000/phone_ws_client.html
```

테스트용 `phone_ws_client.html`은 HTTP로 열면 현재 접속한 host를 기준으로 WebSocket 주소 자동 생성

```text
http://{{JETSON_IP}}:8000/phone_ws_client.html
-> ws://{{JETSON_IP}}:3000
```

따라서 순수 WebSocket 테스트에서는 보통 폰 주소창의 IP만 새 Jetson IP로 변경

실제 프로젝트의 `customized_files/user.html`은 기본 WebSocket 주소가 파일 안에 포함. Jetson IP 변경 시 아래 값을 새 IP로 변경

```javascript
const DEFAULT_WS_URL = 'ws://{{JETSON_IP}}:3000';
```

예:

```javascript
const DEFAULT_WS_URL = 'ws://10.59.121.200:3000';
```

예전 주소 자동 교체가 필요하면 `LEGACY_WS_URLS`에도 이전 주소 추가 가능

```javascript
const LEGACY_WS_URLS = ['ws://localhost:3000', 'ws://192.168.0.90:3000'];
```

단, `user.html`에는 IP 설정 버튼이 있으므로 폰 화면에서 직접 새 IP와 포트 `3000` 저장 가능
