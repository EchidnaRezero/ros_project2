# Jetson SSH 접속 매뉴얼

Windows PC에서 Tailscale을 통해 Jetson Nano에 SSH로 접속하는 방법이다.

## 1. 접속 정보

| 항목 | 값 |
|---|---|
| Tailscale 계정 | `HisameOgasahara@github` |
| Windows 장치 | `desktop-uun4s0b` |
| Windows Tailscale IP | `100.104.31.37` |
| Jetson 장치 | `nano` |
| Jetson Tailscale IP | `100.101.167.4` |
| Jetson 사용자 | `jetson` |
| Jetson 홈 경로 | `/home/jetson` |
| Jetson ROS 워크스페이스 | `/home/jetson/turtlebot3_ws` |

## 2. Windows에서 SSH 키 만들기

PowerShell을 연다.

```powershell
mkdir $env:USERPROFILE\.ssh -Force
ssh-keygen -t ed25519 -f $env:USERPROFILE\.ssh\id_ed25519_jetson_hisame -C "hisame-jetson-tailscale"
```

암호를 묻는 단계에서는 그냥 Enter를 눌러도 된다.

생성되는 파일은 두 개다.

```text
C:\Users\경북대학교\.ssh\id_ed25519_jetson_hisame
C:\Users\경북대학교\.ssh\id_ed25519_jetson_hisame.pub
```

`id_ed25519_jetson_hisame`는 개인키이므로 다른 곳에 올리거나 공유하지 않는다.

## 3. 공개키 파일 만들기

PowerShell에서 공개키 내용을 확인한다.

```powershell
type $env:USERPROFILE\.ssh\id_ed25519_jetson_hisame.pub
```

출력되는 한 줄을 Jetson의 `authorized_keys`에 넣어야 한다.

예시:

```text
ssh-ed25519 AAAA... hisame-jetson-tailscale
```

반드시 `ssh-ed25519`, 긴 키 문자열, `hisame-jetson-tailscale` 사이에 공백이 있어야 한다.

## 4. Jetson에 공개키 등록하기

Jetson에서 터미널을 연다.

```bash
mkdir -p ~/.ssh
nano ~/.ssh/authorized_keys
```

Windows에서 확인한 공개키 한 줄을 붙여넣고 저장한다.

권한을 설정한다.

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

SSH 서버를 재시작한다.

```bash
sudo systemctl restart ssh
```

## 5. Windows에서 접속하기

PowerShell에서 실행한다.

```powershell
ssh -i $env:USERPROFILE\.ssh\id_ed25519_jetson_hisame jetson@100.101.167.4
```

접속되면 아래처럼 확인한다.

```bash
whoami
hostname
pwd
```

정상 예시:

```text
jetson
nano
/home/jetson
```

## 6. ROS 워크스페이스로 이동하기

Jetson SSH 접속 후:

```bash
cd ~/turtlebot3_ws
ls
```

## 7. 접속 확인만 빠르게 하기

Windows PowerShell에서:

```powershell
ssh -i $env:USERPROFILE\.ssh\id_ed25519_jetson_hisame jetson@100.101.167.4 "whoami; hostname; pwd"
```

정상 예시:

```text
jetson
nano
/home/jetson
```

## 8. 짧은 접속 이름 등록하기

Windows에서 SSH 설정 파일을 연다.

```powershell
notepad $env:USERPROFILE\.ssh\config
```

아래 내용을 추가한다.

```text
Host jetson-nano
    HostName 100.101.167.4
    User jetson
    IdentityFile ~/.ssh/id_ed25519_jetson_hisame
```

이후부터는 짧게 접속할 수 있다.

```powershell
ssh jetson-nano
```

명령만 실행할 때:

```powershell
ssh jetson-nano "cd ~/turtlebot3_ws && ls"
```
