# Phone-Jetson WebSocket Test

ROS2 미션과 분리해서 핸드폰 브라우저와 Jetson 사이의 WebSocket 연결만 확인하는 테스트 파일 모음.

## 테스트 방식

| 방식 | 용도 | 포트 |
|---|---|---|
| 로컬/핫스팟 | Jetson이 HTML과 WebSocket echo 서버 제공 | HTTP `8000`, WS `3000` |
| GitHub Pages/Cloudflare | 외부 WebSocket 경로 확인 | HTTP `8001`, WS `3001` |

실제 로봇 명령 bridge와 충돌하지 않도록 Cloudflare echo 테스트는 `3001`, `8001` 사용.

## 로컬/핫스팟 테스트

Jetson Nano에서:

```bash
python3 -m pip install websockets
python3 ws_echo_server_jetson.py
```

정상 실행 시 출력되는 `Use this on the phone browser:` 주소를 핸드폰 브라우저에 입력.

```text
http://{{JETSON_IP}}:8000/phone_ws_client.html
```

연결 경로:

```text
Phone browser
-> http://{{JETSON_IP}}:8000/phone_ws_client.html
-> ws://{{JETSON_IP}}:3000
-> Jetson WebSocket echo server
```

성공 기준:

- 핸드폰 화면에 `connected` 표시
- 핸드폰 화면에 `received: echo: hello from phone` 표시
- Jetson 터미널에 `received: hello from phone` 출력

## GitHub Pages + Cloudflare Echo 테스트

실제 delivery bridge 실행 전 외부 WebSocket 경로만 확인할 때 사용.

Jetson에서:

```bash
cd ~/ros_project/auxiliary_code_backup/network_connectivity
chmod +x start_echo_quicktunnel.sh
./start_echo_quicktunnel.sh
```

출력된 `wss://...trycloudflare.com` 주소를 GitHub Pages의 `debug.html`에 입력.

```text
https://HisameOgasahara.github.io/ros_webclient/debug.html
```

`Connect` 후 `Send` 선택 시 `received: echo: hello from github pages`가 나오면 정상.

포트 변경:

```bash
WS_PORT=3011 HTTP_PORT=8011 ./start_echo_quicktunnel.sh
```

## 테스트 코드

`ws_echo_server_jetson.py`:

- Jetson의 Python 실행 경로와 버전 출력
- Jetson의 네트워크 주소 출력
- `phone_ws_client.html` 자동 생성
- `0.0.0.0:8000`에서 HTML 테스트 페이지 제공
- `0.0.0.0:3000`에서 WebSocket echo 서버 제공

`phone_ws_client.html`:

- 현재 접속한 Jetson host 기준으로 WebSocket 주소 자동 설정
- `Send Test Message` 버튼으로 `hello from phone` 전송
- Jetson에서 받은 echo 응답 표시

## 실패 원인과 대처

### 폰에서 HTML 파일 직접 열기 실패

증상:

```text
page origin: content://...
closed: code=1006
```

대처:

HTML을 폰에서 파일로 직접 열지 않고 Jetson HTTP 서버 주소로 접속.

### `404 File not found`

증상:

```text
GET /phone_ws_client.html HTTP/1.1 404
```

대처:

최신 `ws_echo_server_jetson.py`는 `phone_ws_client.html`이 없으면 자동 생성. 최신 파일을 Jetson에 복사한 뒤 다시 실행.

## IP 변경

다른 핫스팟이나 Wi-Fi 사용 시 Jetson IP가 바뀔 수 있음.

순수 WebSocket 테스트에서는 서버 실행 시 출력된 새 `http://{{JETSON_IP}}:8000/phone_ws_client.html` 주소를 다시 열면 됨.

실제 프로젝트 Web UI와 tunnel 기준은 `docs/NETWORK.md` 참고.
