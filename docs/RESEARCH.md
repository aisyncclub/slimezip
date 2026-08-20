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

## macOS 26.5.2 — AX 열거는 동작한다 (2026-08-20 측정)

앞서 기록한 창 소유권 오염(layer 25 창이 전부 제어 센터 소유로 보고됨)은
사실이지만, **열거 자체가 막힌 것은 아니었다.** 접근성 권한을 부여한 뒤
`AXSweepProbe`를 실제로 돌린 결과:

```
앱 85개 조회, 16개가 AXExtrasMenuBar를 노출, 아이템 35개
```

창 목록이 주지 못하는 것을 AX는 전부 준다.

| | CGWindowList | AX 스윕 |
|---|---|---|
| 개수 | 52 | 35 |
| 소유 앱 | 전부 "제어 센터" (무의미) | 정확 — Tailscale, 카카오톡, Outlook … |
| 번들 ID | 없음 | 있음 |
| 제목 | 없음 | 있음 — "Wi‑Fi, 연결됨, 3개의 막대", "두벌식" |
| 좌표 | 있음 | 있음 |

측정된 실제 항목(발췌):

```
Claude [com.anthropic.claudefordesktop]   frame=1020,42
SSMenuAgent [com.apple.SSMenuAgent]       title=화면 공유       frame=1144,24
ChatGPT [com.openai.codex]                title=ChatGPT        frame=1243,28
카카오톡 [com.kakao.KakaoTalkMac]           frame=1285,24
Tailscale [io.tailscale.ipn.macsys]       frame=1365,24
Magnet [com.crowdcafe.windowmagnet]       frame=1529,24
Microsoft Outlook [com.microsoft.Outlook] title=지금: 강의 자료…  frame=1567,24
```

### 이것이 바꾸는 것

`Capabilities.canEnumerate`는 백엔드 고정값이 아니라 **접근성 권한 여부에
따라 달라지는 런타임 값**이어야 한다. 권한이 있으면 목록 표기·항목 식별이
가능하고, 없으면 ⌘드래그만 남는다.

### 아직 확인되지 않은 것

- **이동.** AX로 위치를 읽을 수는 있으나 쓰기가 되는지는 미검증.
  `AXPress`는 클릭이고, 순서 변경은 macOS가 ⌘드래그로만 노출할 수 있다.
- **숨김 항목의 좌표.** frame이 `0,0`이거나 x가 음수인 항목이 여럿 있다
  (제어 센터 다수, 그리고 접힘 여부와 무관하게 Ollama·OneDrive). 화면 밖
  항목인지, 다중 디스플레이 때문인지 구분이 필요하다.
### 권한 지속성 — 재부여는 필요 없다 (실측)

애드혹 서명이라 리빌드마다 권한이 풀릴 것으로 예상했으나 **사실이 아니다.**
Swift 소스를 바꿔 리빌드해 CDHash가 `6a6b8eb…` → `6ec77e9…`로 바뀐 뒤에도
`axTrusted=true`가 유지됐다. TCC가 애드혹 번들을 cdhash가 아니라 번들 ID와
경로로 식별하는 것으로 보인다.

따라서 자체 서명 인증서는 개발 편의를 위해 도입할 이유가 없다. 배포 단계에서
공증(notarization)이 필요해지면 그때 다시 판단한다.

## 이동은 불가, 클릭은 가능 (2026-08-20 실측)

`AXUIElementIsAttributeSettable`로 부작용 없이 확인한 결과:

```
아이템 34개 중 위치 쓰기 가능 0개
노출된 동작: AXPress (제어 센터는 AXPress, AXCancel)
```

예외가 하나도 없다. 제어 센터 소유 항목도, 평범한 서드파티 앱(Tailscale,
Magnet, 카카오톡, Outlook)도 전부 `AXPosition`을 읽기 전용으로 보고한다.

### 능력 정리

| 능력 | 가능? | 근거 |
|---|---|---|
| 열거 (어떤 아이콘이 있나) | **가능** | AXExtrasMenuBar 스윕, 35개 |
| 식별 (어느 앱 것인가) | **가능** | 번들 ID·앱 이름·제목 |
| 위치 파악 (숨겨졌나) | **가능** | frame |
| 원격 클릭 | **가능** | AXPress |
| 숨기기 | **가능** | 구분자 길이 팽창 |
| **순서 변경 / 이동** | **불가** | AXPosition 쓰기 거부 |

### 설계에 미치는 영향

"아이콘을 그룹에 넣기"를 앱이 대신 수행할 수 없다. 사용자가 ⌘드래그로
직접 옮겨야 하며, 앱이 할 수 있는 최선은 **어느 아이콘을 어디로 옮겨야
하는지 정확히 지목하는 것**이다. 열거가 되므로 이 안내는 구체적일 수 있다
— "Tailscale을 구분자 왼쪽으로" 수준까지.

### 미검증 — CGEvent 드래그 합성

AX 쓰기가 막혔다고 이동이 전부 막힌 것은 아니다. 접근성 권한이 있으면
`CGEvent`로 ⌘드래그를 합성할 수 있고, AX가 정확한 frame을 주므로 좌표는
안다. 다만 이는 사용자의 실제 메뉴바를 건드리는 실험이므로 우리 소유
아이템(ZipBar 구분자)을 대상으로 먼저 확인해야 한다.

## 합성 ⌘드래그도 불가 (2026-08-20 실측)

AX 쓰기가 막혔어도 사용자와 같은 제스처를 흉내내면 되지 않을까 — 확인했고,
안 된다.

우리 소유인 ZipBar 구분자를 대상으로 두 가지 방식을 시험했다.

| 방식 | 결과 |
|---|---|
| 마우스 이벤트에 `.maskCommand` 플래그만 | 이동 0pt |
| Command 키를 실제 키 이벤트로 누른 채 드래그 | 이동 0pt |

두 경우 모두 `cghidEventTap`으로 전송에 성공(`posted=true`)했고 좌표도
정확했다(구분자 x=1109, (1120,15) → (1000,15)). 그런데도 위치가 변하지 않았다.

macOS가 메뉴바 재배치를 합성 입력으로부터 보호하는 것으로 보인다. 실제
사용자 입력만 이 제스처를 시작할 수 있다.

### 확정된 결론

**아이콘 이동은 어떤 경로로도 불가능하다.** AX 쓰기 거부, 합성 드래그 무시.
앱이 할 수 있는 것은 숨기기(구분자 팽창), 열거, 식별, 원격 클릭까지다.
넣고 빼기는 사용자의 ⌘드래그로만 이루어지며, 앱의 역할은 무엇을 어디로
옮겨야 하는지 정확히 지목하는 것이다.
