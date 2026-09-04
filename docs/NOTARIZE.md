# 공증 준비 — 한 번만 하면 됩니다

공증(notarization)을 받으면 설치가 이렇게 바뀝니다.

| | 지금 | 공증 후 |
|---|---|---|
| 다운로드 | dmg 열고 끌어다 놓기 | 그대로 |
| **처음 열기** | **시스템 설정 → 확인 없이 열기** | **그냥 열림** |
| 손쉬운 사용 켜기 | 필요 | 그대로 |
| Homebrew 등록 | 불가 | 가능 |

**실작업은 30분, 나머지는 애플 승인 대기 1~2일입니다.**

이 문서의 1~4번은 **직접 하셔야 합니다.** 애플 계정 로그인, 결제, 비밀이
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

**여기서 만들어진 개인 키를 잃어버리면 인증서도 같이 죽습니다.** 키체인 접근의
"키" 항목에 남아 있고, 다른 맥에서 서명하려면 이 키를 옮겨야 합니다.
그 경로에서 걸리는 함정 두 개는 아래 "안 될 때"에 적어 뒀습니다.

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
**안 보이면 아래 "안 될 때"의 중간 인증서 항목을 보세요.** 인증서 자체는
멀쩡한데 목록에 안 나오는 경우가 있습니다.

---

## 3. 공증 서버 자격증명 — API 키를 쓰세요

`notarytool`이 애플에 로그인하는 방법은 두 가지입니다. **API 키를 권합니다.**

| | API 키 (권장) | 앱 암호 |
|---|---|---|
| 형태 | `.p8` 파일 + ID 두 개 | `xxxx-xxxx-xxxx-xxxx` |
| 만드는 곳 | **개발자 계정 안** | 애플 계정 전체 |
| 계정 착오 | **구조적으로 불가능** | 흔한 실패 원인 |
| 애플 계정 암호 변경 시 | 영향 없음 | 다시 만들어야 함 |
| CI에 넣기 | 파일 하나 | 비밀번호 관리 필요 |

앱 암호가 위험한 게 아니라, **어느 Apple ID로 만들었는지가 계속 문제를
일으킵니다.** 개발자 멤버십이 붙은 계정과 앱 암호를 만든 계정이 다르면
`store-credentials`가 401을 뱉는데, 오류 메시지는 "암호가 틀렸다"고만
말하지 계정이 다르다고는 안 알려 줍니다. API 키는 개발자 포털 안에서
만들기 때문에 애초에 그럴 수가 없습니다.

### 3-A. API 키 만들기 (권장)

<https://appstoreconnect.apple.com/access/integrations/api>

**Team Keys** 탭 → **+**

| 칸 | 입력 |
|---|---|
| Name | 아무거나 (예: `slimezip-notary`) |
| Access | **Admin** |

Generate → **Download**.

**`.p8` 파일은 한 번만 받을 수 있습니다.** 잃어버리면 키를 폐기하고 새로
만들어야 합니다. 같은 화면에 **Issuer ID**(긴 UUID)와 **Key ID**(10자리)가
있습니다. 셋 다 필요합니다.

repo 밖에 두세요. 커밋되면 남이 우리 이름으로 공증을 제출할 수 있습니다:

```bash
mkdir -p ~/AppleDeveloper && chmod 700 ~/AppleDeveloper
mv ~/Downloads/AuthKey_*.p8 ~/AppleDeveloper/
chmod 600 ~/AppleDeveloper/AuthKey_*.p8
```

### 3-B. 앱 암호 (대안)

API 키를 못 쓰는 상황이면 이 방법도 됩니다.

<https://account.apple.com/account/manage> → **로그인 및 보안** → **앱 암호**

**+** → 이름은 아무거나 → 생성. `xxxx-xxxx-xxxx-xxxx`가 **한 번만** 보입니다.

> **반드시 개발자 멤버십이 붙은 Apple ID로 로그인한 상태에서 만드세요.**
> <https://developer.apple.com/account> 오른쪽 위에 보이는 그 계정입니다.
> 다른 계정으로 만들면 401이 납니다.

---

## 4. 자격증명을 키체인에 저장

### API 키를 쓰는 경우

```bash
xcrun notarytool store-credentials slimezip \
  --key ~/AppleDeveloper/AuthKey_KEYID.p8 \
  --key-id KEYID \
  --issuer ISSUERID
```

### 앱 암호를 쓰는 경우

```bash
xcrun notarytool store-credentials slimezip \
  --apple-id "애플_개발자_계정_이메일" \
  --team-id "TEAMID" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

- `TEAMID`는 2-3의 `security find-identity` 출력 괄호 안에 있습니다.
- `slimezip`은 프로필 이름입니다. 릴리스 스크립트가 이 이름을 찾습니다.
  어느 방식으로 저장했든 스크립트 쪽은 똑같습니다.

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
<summary><b>store-credentials가 401 Invalid credentials로 거절합니다</b></summary>

<br>

**앱 암호를 만든 Apple ID와 개발자 멤버십이 붙은 Apple ID가 다른 경우가
대부분입니다.** 오류 메시지는 "암호가 틀렸다"고만 하지 계정 얘기를 안 해서
암호를 몇 번씩 다시 만들게 만듭니다.

확인 순서:

1. <https://developer.apple.com/account> 오른쪽 위의 계정 이메일을 봅니다.
   **이게 진짜 계정입니다.**
2. <https://account.apple.com>에 **그 계정으로** 로그인해 앱 암호를 새로 만듭니다.
3. `--apple-id`에 그 주소를 넣고 다시 실행합니다.

**아니면 3-A의 API 키로 갈아타세요.** 키를 개발자 포털 안에서 만들기 때문에
이 문제가 생길 수 없습니다. 이 프로젝트가 그렇게 했습니다.

나머지 가능성:

- 암호를 복사할 때 앞뒤 공백이나 줄바꿈이 붙었습니다
- 만든 뒤 폐기했습니다 (앱 암호는 목록에서 삭제하면 즉시 죽습니다)
- 계정에 2단계 인증이 꺼져 있습니다 (개발자 계정은 필수라 드뭅니다)

</details>

<details>
<summary><b>인증서가 find-identity에 안 보입니다</b></summary>

<br>

**대부분 애플의 중간 인증서(intermediate)가 키체인에 없어서입니다.**
`.cer`은 멀쩡히 들어갔는데 체인이 애플 루트까지 안 이어지면 `find-identity -v`가
**아예 목록에서 빼 버립니다.** 인증서가 없는 것처럼 보이지만 있습니다.

<https://www.apple.com/certificateauthority/> 에서
**Developer ID - G2** 중간 인증서(`DeveloperIDG2CA.cer`, 약 1KB)를 받아
두 번 누르면 됩니다. 그 즉시 목록에 나타납니다.

```bash
security find-identity -v -p codesigning
```

체인 확인:

```bash
security find-certificate -c "Developer ID Application" -p | openssl x509 -noout -subject -issuer
```

그래도 안 보이면 **개인 키가 없는 것**입니다. CSR을 만들 때 생긴 키가 같은
키체인에 있어야 합니다. 키체인 접근 → 로그인 → **키** 항목을 보세요.
다른 맥에서 CSR을 만들었다면 그 맥에 키가 있습니다.

</details>

<details>
<summary><b>다른 맥으로 인증서를 옮기는데 "MAC verification failed"가 납니다</b></summary>

<br>

`openssl pkcs12 -export`로 만든 `.p12`를 `security import`가 못 읽는 경우입니다.
**OpenSSL 3의 기본 암호화(AES-256-CBC + PBKDF2)를 macOS의 `security`가
지원하지 않습니다.** `-legacy`를 붙여 다시 만드세요.

```bash
openssl pkcs12 -export -legacy \
  -inkey DeveloperID.key -in developerID_application.cer \
  -out DeveloperID.p12
```

받는 쪽에서:

```bash
security import DeveloperID.p12 -k ~/Library/Keychains/login.keychain-db \
  -T /usr/bin/codesign -T /usr/bin/security
```

들어간 뒤에도 목록에 안 보이면 위의 중간 인증서 항목을 보세요. 두 함정이
연달아 걸립니다.

</details>

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

App Store Connect API 키는 만료가 없습니다. 유출되면 같은 화면에서
폐기(Revoke)하고 새로 만드세요.
