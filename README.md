# ZipBar

macOS 메뉴바가 넘칠 때 아이콘을 **그룹으로 묶고, 접고, 순서를 잡고, 전부 다시 보이게** 하는 앱.

노치 있는 MacBook에서 아이콘이 노치 뒤로 사라져 클릭조차 못 하는 상황을 해결하는 것이 목표다.

## 지금 상태 — Phase 1

| 기능 | 상태 |
|---|---|
| 이름 있는 그룹 N개, 각각 셰브론으로 접기/펴기 | ✅ 동작 |
| 자동 숨김 (포인터가 메뉴바를 벗어나면 다시 접기) | ✅ 동작 |
| 설정 UI, 레이아웃 영속화 | ✅ 동작 |
| 백엔드 진단 CLI | ✅ 동작 |
| 아이콘 열거·순서 이동·원격 클릭 | ⬜ Phase 2 |
| 오버플로우 패널 (노치 뒤 아이콘 표시) | ⬜ Phase 3 |

경쟁자들이 "숨김 / 항상 숨김" 2단으로 고정된 반면 ZipBar는 그룹을 원하는 만큼 만든다.

## 왜 새로 만드는가

macOS가 이 영역을 두 번 연속 깨뜨렸다. macOS 26 Tahoe가 윈도우 소유자 정보를 오염시켰고,
macOS 27 Golden Gate가 메뉴바 구조를 통째로 바꿔 Bartender·Ice·Barbee·Thaw·BetterTouchTool이
전부 동작 불능이 됐다. 측정 근거는 [docs/RESEARCH.md](docs/RESEARCH.md)에 있다.

그래서 ZipBar의 설계 원칙은 **런타임 능력 탐지**다. 기능을 하드코딩하지 않고 OS에 물어본 뒤
되는 것만 UI에 노출한다. 안 되면 조용히 실패하는 대신 배너로 말한다.

```
UI  ────────────────────────  Capabilities에 따라 기능을 켜고 끔
MenuBarEngine  ─────────────  그룹·순서·상태의 단일 진실
HidingStrategy (프로토콜) ──  ★ OS가 바뀌어도 여기까지만 다시 씀
  └ SpacerStrategy           길이 팽창 · 권한 0개 · macOS 14–26
  └ (Phase 2) BridgeStrategy 열거 · 이동 · 원격 클릭
```

## 빌드

Xcode는 필요 없다. Command Line Tools만으로 빌드된다.

```bash
swift build && swift test
```

앱 번들 만들기:

```bash
./scripts/build-app.sh
```

`dist/ZipBar.app`이 생성된다. `open dist/ZipBar.app`으로 실행.

## 진단

OS 업데이트 후 무엇이 깨졌는지 확인하는 도구. **베타가 나오면 가장 먼저 이걸 돌린다.**

```bash
./.build/debug/zipbar-probe capabilities   # 각 백엔드가 되는지 요약
./.build/debug/zipbar-probe list           # 모든 백엔드의 열거 결과
./.build/debug/zipbar-probe ax             # 접근성 스윕 상세 (권한 필요)
```

앱 자체의 기동 상태를 확인하려면:

```bash
ZIPBAR_DIAGNOSTIC=1 ./dist/ZipBar.app/Contents/MacOS/ZipBar
```

## 사용법 (Phase 1)

1. 설정에서 그룹을 추가한다 → 메뉴바에 구분자(⋮)와 셰브론이 생긴다
2. **⌘를 누른 채** 숨기고 싶은 아이콘을 구분자 **왼쪽**으로 드래그한다
3. 셰브론을 클릭해 접고 편다

2번이 수동인 이유: 스페이서 백엔드는 다른 앱의 아이콘을 옮길 수 없다. Phase 2에서 자동화된다.

## 배포 제약

접근성 권한과 비공개 API를 쓰므로 **샌드박스가 불가능하고 Mac App Store에 올릴 수 없다.**
Developer ID 서명 + 공증 후 직접 배포(+ Homebrew cask)가 유일한 경로다. Phase 5에서 구성한다.

## 라이선스 주의

`Ice`는 GPL-3.0이다. 향후 라이선스 유연성을 위해 **Ice 소스는 읽지도 참조하지도 않는다.**
동작만 관찰한다.
