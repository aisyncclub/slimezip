# 공증 준비 — 한 번만 하면 됩니다

공증(notarization)을 받으면 설치가 이렇게 바뀝니다.

| | 지금 | 공증 후 |
|---|---|---|
| 다운로드 | dmg 열고 끌어다 놓기 | 그대로 |
| **처음 열기** | **시스템 설정 → 확인 없이 열기** | **그냥 열림** |
| 손쉬운 사용 켜기 | 필요 | 그대로 |
| Homebrew 등록 | 불가 | 가능 |

**실작업은 30분, 나머지는 애플 승인 대기 1~2일입니다.**

이 문서의 1~4번은 **직접 하셔야 합니다.** 애플 계정 로그인, 결제, 암호가
들어가는 일이라 대신 해 드릴 수 없습니다. 5번부터는 스크립트가 합니다.

> **Xcode는 필요 없습니다.** `notarytool`이 Command Line Tools에 들어 있습니다.
> 이 맥에서 `xcrun notarytool --version`으로 확인했습니다.

---

## 1. Apple Developer Program 가입 — 연 $99

<https://developer.apple.com/programs/enroll/>

**개인(Individual)으로 가입하세요.** 법인으로 하면 D-U-N-S 번호가 필요하고
발급에만 몇 주가 걸립니다. 개인은 그게 없습니다.

가입 후 **승인까지 보통 24~48시간**입니다. 신분증 확인을 요구받으면 며칠 더
걸릴 수 있습니다. 승인 메일이 오면 2번으로 갑니다.

---

## 2. Developer ID Application 인증서 만들기

앱에 서명할 인증서입니다. Xcode 없이 하는 방법으로 적었습니다.

### 2-1. 인증서 요청 파일(CSR) 만들기

**키체인 접근** 앱을 엽니다 (`⌘Space` → "키체인 접근").

메뉴 막대의 **키체인 접근 → 인증서 지원 → 인증 기관에서 인증서 요청**

| 칸 | 입력 |
|---|---|
| 사용자 이메일 주소 | 애플 개발자 계정 이메일 |
| 일반 이름 | 아무거나 (예: `SlimeZIP Developer ID`) |
| CA 이메일 주소 | **비워 둡니다** |
| 요청 항목 | **디스크에 저장됨** 선택 |
| 본인이 키 쌍 정보 지정 | **체크** |

계속 → 키 크기 `2048비트`, 알고리즘 `RSA` → 계속

`CertificateSigningRequest.certSigningRequest` 파일이 저장됩니다.

### 2-2. 애플에 올려서 인증서 받기

<https://developer.apple.com/account/resources/certificates/list>

**+** 버튼 → **Developer ID Application** 선택 → Continue

> **Developer ID Installer가 아닙니다.** 우리는 앱에 서명하지 설치 패키지를
> 만들지 않습니다. 둘 다 만들어도 되지만 지금 필요한 건 Application입니다.

Profile Type은 **G2 Sub-CA**를 고르세요 (기본값). 2-1에서 만든 `.certSigningRequest`
파일을 올리고 Continue → **Download**.

### 2-3. 설치

받은 `developerID_application.cer`을 **두 번 누릅니다.** 키체인에 들어갑니다.

확인:

```bash
security find-identity -v -p codesigning
```

`Developer ID Application: 이름 (TEAMID)` 가 보이면 됩니다.

---

## 3. 앱 암호(App-Specific Password) 만들기

공증 서버에 로그인할 때 쓰는 일회용 암호입니다. 애플 계정 본암호는 쓰지 않습니다.

<https://account.apple.com/account/manage> → **로그인 및 보안** → **앱 암호**

**+** → 이름은 아무거나 (예: `slimezip-notary`) → 생성

**`xxxx-xxxx-xxxx-xxxx` 형태의 암호가 한 번만 보입니다.** 복사해 두세요.
다시 볼 수 없고, 잃어버리면 지우고 새로 만들면 됩니다.

---

## 4. 자격증명을 키체인에 저장

터미널에서:

```bash
xcrun notarytool store-credentials slimezip \
  --apple-id "애플_계정_이메일" \
  --team-id "TEAMID" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

- `TEAMID`는 2-3의 `security find-identity` 출력 괄호 안에 있습니다.
  <https://developer.apple.com/account> 오른쪽 위에서도 볼 수 있습니다.
- `slimezip`은 프로필 이름입니다. 릴리스 스크립트가 이 이름을 찾습니다.

확인:

```bash
xcrun notarytool history --keychain-profile slimezip
```

목록이 비어 있어도(아직 제출한 적이 없으니) 오류만 안 나면 성공입니다.

---

## 5. 여기서부터는 스크립트가 합니다

```bash
./scripts/release.sh v0.3.0
```

`release.sh`가 알아서:

1. Developer ID 인증서를 찾아 **타임스탬프와 함께** 서명합니다
   (타임스탬프가 없으면 인증서 만료와 함께 서명도 죽습니다)
2. zip을 애플에 제출하고 **결과를 기다립니다** (보통 5분 이내)
3. 티켓을 앱에 **첨부(staple)** 합니다 — 이래야 오프라인에서도 통과합니다
4. 첨부한 뒤에 zip과 dmg를 **다시** 만듭니다
   (첨부는 번들을 바꾸므로, 그 전에 포장한 건 티켓이 없습니다)
5. `spctl`로 검증하고 결과를 출력합니다
6. 릴리스 노트를 공증된 문구로 바꿔서 올립니다

인증서나 자격증명이 없으면 **공증을 건너뛰고 그렇게 말합니다.** 조용히
공증 없이 나가는 릴리스는 공증된 것과 겉보기가 똑같아서, 남이 열어 보기
전까지 아무도 모릅니다.

### 성공하면 이렇게 나옵니다

```
==> 공증 제출 (보통 5분 이내)
    status: Accepted
==> 티켓 첨부
    The staple and validate action worked!
==> 서명 검증
    ✅ 공증됨 — 받아서 두 번 누르면 바로 열립니다
```

---

## 안 될 때

<details>
<summary><b>status: Invalid 로 거절당했습니다</b></summary>

<br>

이유를 받아 봅니다. 제출 ID는 출력에 있습니다.

```bash
xcrun notarytool log <제출ID> --keychain-profile slimezip
```

흔한 원인 셋:

- **하드닝 런타임이 없음** — `build-app.sh`가 `--options runtime`을 붙이므로
  이 프로젝트에서는 해당 없습니다
- **타임스탬프가 없음** — Developer ID로 서명될 때만 `--timestamp`가 붙습니다.
  `ZipBar Dev`로 서명됐다면 인증서를 못 찾은 것입니다
- **번들 안에 서명 안 된 실행 파일** — 우리는 `zipbar-probe`를 같이 넣는데,
  `codesign`이 번들 전체를 훑으므로 함께 서명됩니다

</details>

<details>
<summary><b>인증서가 find-identity에 안 보입니다</b></summary>

<br>

`.cer` 파일을 두 번 눌렀는데도 안 보이면, CSR을 만들 때 생긴 **개인 키가
같은 키체인에 있어야** 합니다. 키체인 접근 → 로그인 → 키 항목에서 2-1에서
지정한 이름의 키를 찾아보세요. 다른 맥에서 CSR을 만들었다면 그 맥에 키가
있습니다.

</details>

<details>
<summary><b>Team ID를 모르겠습니다</b></summary>

<br>

```bash
security find-identity -v -p codesigning
```

`Developer ID Application: 홍길동 (AB12CD34EF)` 에서 괄호 안이 Team ID입니다.

</details>

<details>
<summary><b>공증했는데도 경고가 뜹니다</b></summary>

<br>

티켓이 첨부되지 않았을 때 그렇습니다. 확인:

```bash
xcrun stapler validate /Applications/SlimeZIP.app
spctl -a -vvv /Applications/SlimeZIP.app
```

두 번째가 `source=Notarized Developer ID`라고 나와야 합니다.
`source=Developer ID`까지만 나오면 서명은 됐지만 공증 티켓이 없는 상태입니다.

</details>

---

## 갱신

Developer ID 인증서는 **5년**짜리입니다. 멤버십은 **연 $99**로 매년 갱신해야
하고, 끊기면 새 서명은 못 하지만 **이미 공증된 빌드는 계속 열립니다.**
타임스탬프를 붙이는 이유가 이것입니다.
