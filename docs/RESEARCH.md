# 메뉴바 조작 기술 현황

이 문서는 **이 저장소에서 실제로 측정한 결과**와 출처가 있는 외부 보고를 구분해 기록한다.
macOS가 1년에 두 번 이 영역을 깨뜨리므로, 추측이 아니라 재현 가능한 사실만 남긴다.

측정 환경: **macOS 26.5.2 (25F84), Apple Silicon** — `zipbar-probe`로 측정.

---

## 1. CGWindowList (layer 25) — ❌ macOS 26에서 사용 불가

Bartender와 Ice가 기반으로 삼았던 기법.

**측정 결과 (이 머신):**
```
[CGWindowList] 아이템 78개
  · 78개 윈도우가 전부 '제어 센터' 소유로 보고됨
```

상태바 레이어에 윈도우는 여전히 존재하지만 **모두 Control Center 소유로 보고**되어
아이템→앱 귀속이 불가능하다. [FB18327911](https://github.com/feedback-assistant/reports/issues/679)이
이 머신에서 그대로 재현된다.

또한 ZipBar 자신의 PID로 조회하면 윈도우가 **0개**다. 상태 아이템이 더 이상
소유 프로세스의 윈도우가 아니라는 뜻이다.

→ `LegacyWindowProbe`가 이 상태를 감지해 리포트한다. `attributionIsReliable`는
macOS 26 이상에서 `false`.

---

## 2. 상태 아이템은 이제 아웃오브프로세스로 호스팅된다

`PrivateBridgeProbe`가 런타임에 발견한 AppKit 비공개 클래스:

```
NSStatusItemHost                NSStatusItemHostListener
NSStatusItemScene               NSStatusItemSceneExtension
NSSceneStatusItem               NSSceneHostingStatusItem
NSStatusItemReplicantView       NSStatusItemReplicantImageView
NSStatusItemReplicantShadowView NSCGSStatusItem
NSLocalStatusItem               NSMenuBarItemView
```

"Replicant"과 "SceneHosting"이라는 이름이 결정적이다. 앱이 만든 상태 아이템의 내용이
**씬으로 호스팅되어 메뉴바 프로세스에 복제**된다. 그래서 윈도우 소유자가 전부
Control Center로 찍히고, 소유 프로세스에는 윈도우가 남지 않는다.

**Phase 2의 공략 지점이 바로 이 클래스들이다.**

`MenuServiceBridge`에 대한 정정: 커뮤니티에서 이 이름이 Apple 비공개 프레임워크처럼
언급되지만, **macOS 26.5에 그런 프레임워크는 존재하지 않는다.** dyld 공유 캐시 전체를
검색해도 문자열이 없고, `/System/Library/PrivateFrameworks`에도 없다.
Peekaboo 등 서드파티 도구가 쓰는 **자체 래퍼 타입 이름**으로 보인다.
따라서 Phase 2는 이 이름에 바인딩하지 않고, 위 AppKit 클래스들을 대상으로 한다.

---

## 3. AX 스윕 — 검증 대기

각 앱의 AX 트리에서 `AXExtrasMenuBar`를 읽는 방식. 윈도우 소유자가 오염되어도
앱은 여전히 자신의 상태 아이템을 자기 AX 트리로 노출하므로 유력한 후보다.

**아직 측정하지 못했다** — 접근성 권한이 필요하다. 확인 방법:

```bash
zipbar-probe ax
```

권한을 부여한 뒤 위 명령이 아이템을 반환하면 Phase 2의 열거 백엔드로 확정한다.
반환이 0개라면 이 경로도 막힌 것이므로 §2의 비공개 클래스로 간다.

---

## 4. 길이 팽창 (스페이서) — ✅ 현재 동작, macOS 27에서 사망 예정

`NSStatusItem.length`를 화면 폭의 2배로 부풀려 왼쪽 이웃을 화면 밖으로 밀어낸다.
권한이 전혀 필요 없다.

구현 상수 (출처: [Hidden Bar ARCHITECTURE.md](https://github.com/dwarvesf/hidden/blob/develop/docs/ARCHITECTURE.md)):

| 항목 | 값 |
|---|---|
| 숨김 길이 | `max(500, min(가장넓은화면폭 × 2, 10_000))` |
| 시스템 상한 | 10,000pt |
| 펼침 길이 | 20pt |
| 접힘 판정 | `length > 20` — **등호 아님** |

접힘 판정이 비교인 이유: 접힌 상태에서 디스플레이가 추가되면 길이가 재계산되는데,
특정 값과의 등호 비교였다면 그 순간 접힘 상태를 잃는다.

**한계:**
- 노치 뒤의 아이콘은 꺼낼 수 없다
- 아이콘 배치는 사용자가 ⌘드래그로 직접 해야 한다
- 구분자는 중첩된다 — 어떤 그룹을 접으면 그 왼쪽 그룹도 함께 가려진다
  (상태 아이템이 오른쪽→왼쪽으로 배치되기 때문. Bartender/Ice가 딱 2단인 이유)

**macOS 27 Golden Gate에서 무력화된다.** Apple이 개별 아이템 윈도우를 단일 윈도우로
통합했고, 그 결과 Bartender·Ice·Barbee·Thaw·Sane Bar·Glow·BetterTouchTool이 전부
깨졌다 ([BTT 커뮤니티](https://community.folivora.ai/t/macos-27-golden-gate-menu-bar-management-broken-solutions-ice-thaw-bartender-barbee-etc/47232)).
`SpacerStrategy.isSupported()`가 major ≥ 27에서 `false`를 반환해 엔진이 다음
백엔드로 넘어간다.

---

## 5. macOS 26 네이티브 메뉴바 설정으로는 이 문제가 안 풀린다

System Settings → Menu Bar가 추가됐지만 Apple 자체 컨트롤의 표시/숨김이 주 대상이고,
서드파티 아이템은 부분 지원이며, **오버플로우와 노치 문제는 전혀 다루지 않는다.**
ZipBar가 푸는 문제와 겹치지 않는다.

---

## 재측정 방법

OS 베타가 나오면 가장 먼저 이것부터:

```bash
swift build && ./.build/debug/zipbar-probe capabilities
```

각 백엔드가 그 OS에서 실제로 무엇을 반환하는지 5분 안에 알 수 있다.
