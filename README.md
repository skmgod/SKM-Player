# Player 64X — 가벼운 8K 동영상 플레이어

개발자 **SKM**

KMPlayer 64X 처럼 가볍게 쓰는 Windows 동영상 플레이어입니다.
FFmpeg 엔진(Qt Multimedia)으로 **8K · HEVC · AV1 · H.264** 를 별도 코덱 설치 없이 재생하고,
확대 · 이동 · 옆으로 보기 · 자막 · 재생목록 · 구간 반복을 지원합니다.

## 기능

- **확대 / 축소**: 마우스 휠(커서 위치 기준), `+` `-`
- **영상 이동**: 마우스 왼쪽 버튼 드래그, `Ctrl + 방향키`
- **옆으로 보기**: 90° 회전, 좌우반전, 화면 비율 변경(16:9 · 21:9 · 32:9 · 4:3 · 꽉 채우기)
- **슬로우 모션**: 0.5x → 0.25x → 0.1x, 재생 속도 0.1x ~ 4x
- **구간 반복(A–B)**: 시작/끝 지점을 눌러 반복 재생
- **재생목록**: 여러 파일·폴더를 끌어놓으면 자연 정렬로 목록 생성, 이전/다음, 반복, 셔플, 자동 다음 재생
- **자막**: SRT · SMI · VTT · ASS 자동 로딩, 언어(트랙) 선택, 내장 자막, 글자 크기·싱크 조절
- **실시간 자동 자막**: Windows 11 실시간 캡션 연결
- **캡처**: 지금 장면을 영상 원본 크기 PNG 로 `사진\Player64X` 에 저장 (`C`)
- **단축키 설정**: 모든 단축키를 직접 바꾸고 자동 저장 (`F1` → 단축키 설정)
- **사용 설명서**: 프로그램 안에서 `F1`

## 기본 단축키

| 동작 | 키 | 동작 | 키 |
|---|---|---|---|
| 재생 / 일시정지 | `Space` | 확대 / 축소 | `+` / `-` |
| 5초 뒤로 / 앞으로 | `←` / `→` | 영상 이동 | `Ctrl + 방향키` |
| 30초 뒤로 / 앞으로 | `Shift + ←/→` | 회전 / 좌우반전 / 비율 | `R` / `H` / `A` |
| 볼륨 | `↑` / `↓` | 슬로우 모션 | `Z` |
| 전체화면(화면 크게) | `Enter` (`F` 도 가능) | 구간 반복 | `B` |
| 현재 화면 캡처 | `C` | | |
| 다음 / 이전 영상 | `N` / `P` | 자막 메뉴 | `S` |
| 파일 열기 | `O` | 도움말 | `F1` |

## 실행 (소스에서)

```bash
pip install PySide6
python player8k/player.py [영상 파일 또는 폴더 ...]
```

## exe 로 묶기

```bash
pip install pyinstaller
cd player8k
python make_icon.py
pyinstaller --noconfirm --windowed --name Player64X_8K --icon icon.ico ^
  --add-data "Main.qml;." --add-data "icon.png;." ^
  --hidden-import PySide6.QtMultimedia --hidden-import PySide6.QtQuick ^
  --hidden-import PySide6.QtQml --hidden-import PySide6.QtNetwork --hidden-import PySide6.QtOpenGL ^
  player.py
```

## 기본 플레이어로 지정

1. `install\register_default_player.bat` 을 더블클릭 → Player 64X 가 Windows 기본 앱 목록에 등록됩니다 (현재 사용자만, 관리자 권한 불필요).
2. 열리는 **설정 → 기본 앱** 에서 `Player 64X` 를 고르고 `.mp4`, `.mkv` 등 원하는 확장자에 지정하세요.
3. 되돌리려면 `install\unregister_default_player.ps1` 실행.

> Windows 는 보안상 프로그램이 기본 앱을 강제로 바꾸지 못하게 막아 두어서, 마지막 선택은 설정 창에서 직접 해야 합니다.

## 구성

| 경로 | 설명 |
|---|---|
| `player8k/` | 메인 플레이어 (Python + PySide6, QML UI, FFmpeg 엔진) |
| `*.xaml`, `*.cs`, `Player64X.csproj` | 초기 버전 (WPF / Windows 내장 미디어 엔진). 참고용 |

## 참고

- 단축키 설정은 `%APPDATA%\Player64X\keys.json` 에 저장됩니다.
- 8K 재생 성능은 PC의 GPU 와 영상 코덱에 따라 달라집니다.
- 실시간 자동 자막은 Windows 11 의 실시간 캡션(LiveCaptions)을 사용하므로 지원 언어는 Windows 설정에 따릅니다.
