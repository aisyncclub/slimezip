// Korean → English, for every string the user can see.
//
// Keyed by the Korean, so a string missing from this table simply stays
// Korean instead of showing a symbolic key. Format strings keep their `%@`
// placeholders in both languages; where the order differs, the English value
// uses positional `%1$@` markers.
enum L10nTable {
    static let english: [String: String] = [

        // MARK: - Panel
        "밖에 나와 있는 것": "Out in the open",
        "숨긴 아이콘 없음": "Nothing hidden",
        "숨긴 것 꺼내 보기": "Show what's hidden",
        "다시 감추기": "Hide again",
        "· 재시작 없이": "· no restart",
        "항상 숨김만 있습니다": "Only always-hidden groups",
        "지금 감춰져 있습니다": "Currently hidden",
        "지금 펼쳐져 있습니다": "Currently shown",
        "숨겨진 사이에 이 아이콘이 바뀌었습니다": "This icon changed while hidden",
        "다음 로그인": "Next login",
        "재시작 대기": "Awaiting restart",
        "취소": "Cancel",
        "왼쪽으로": "Move left",
        "오른쪽으로": "Move right",
        "넣기": "Put in",
        "꺼내기": "Take out",
        "적용": "Apply",
        "아이콘마다 한 번뿐입니다.": "Once per icon, and only once.",
        "제어 센터는 껐다 켜지 않습니다. 자리는 이미 기록해 뒀습니다.":
            "Control Center is not restarted. The position is already recorded.",
        "위치": "Position",
        "슬라임을 왼쪽으로": "Move the slime left",
        "슬라임을 오른쪽으로": "Move the slime right",
        "항상 숨김까지": "Include always-hidden",
        "설정…": "Settings…",
        "제작자 Ai싱크클럽": "Made by Ai싱크클럽",
        "- 싱크 제작": "— Sync",
        "유튜브": "YouTube",
        "쓰레드": "Threads",
        ")이 있습니다": ") is available",
        "업데이트": "Update",
        "업데이트 확인": "Check for updates",
        "확인 중…": "Checking…",
        "%@개 꺼내 둠": "%@ out",
        "%@개 물고 있음": "%@ held",
        "숨긴 %@개 꺼내 보기": "Show %@ hidden",
        "%@개 앱을 재시작하면 적용됩니다": "Restart %@ app(s) to apply",
        "%@개는 다음 로그인에 적용됩니다": "%@ will apply at next login",
        "새 버전 %@이 있습니다": "Version %@ is available",
        "지금 %1$@ → %2$@": "Now %1$@ → %2$@",
        "최신입니다 · 버전 %@": "Up to date · version %@",
        "버전 %@": "Version %@",

        // MARK: - Icon list
        "재시작": "Restart",
        "아이콘 위치는 앱이 시작할 때 읽히므로, 옮긴 위치는 재시작해야 적용됩니다. 저장하지 않은 작업이 있는 앱은 스스로 거부할 수 있습니다.":
            "An icon's position is read when its app starts, so a move takes effect only after a restart. An app with unsaved work may refuse to quit.",
        "문제가 있었습니다": "Something went wrong",
        "확인": "OK",
        "어떤 아이콘이 메뉴바에 있는지 보려면 접근성 권한이 필요합니다":
            "Accessibility permission is needed to see what is in your menu bar",
        "macOS 26은 상태 아이템을 제어 센터가 대신 표시해서, 권한 없이는 어느 아이콘이 어느 앱 것인지 알 수 없습니다.":
            "On macOS 26 the status items are drawn by Control Center, so without the permission there is no way to tell which icon belongs to which app.",
        "접근성 권한 요청": "Request Accessibility",
        "손쉬운 사용 설정 열기": "Open Accessibility settings",
        "이미 허용했는데 이 화면이 남아 있다면, 실행 중이던 앱에는 권한이 늦게 전달됩니다. 재시작하면 바로 적용됩니다.":
            "If you already granted it and this screen is still here, a running app receives the grant late. Restarting applies it at once.",
        "SlimeZIP 재시작": "Restart SlimeZIP",
        "슬라임이 계속 물고 있습니다": "The slime holds these permanently",
        "슬라임을 누르면 여기가 열리고 닫힙니다": "Clicking the slime opens and closes this",
        "여기는 아직 비어 있습니다. 아래에서 넣어보세요.": "Empty for now. Add something from below.",
        "언제나 메뉴바에 보입니다": "Always visible in the menu bar",
        "메뉴바에 보이는 아이콘이 없습니다.": "No icons are visible in the menu bar.",
        "모두 적용": "Apply all",
        "밖으로 꺼내기": "Take out",
        "숨김 예약": "Hide pending",
        "표시 예약": "Show pending",
        "열기": "Open",
        "옮기기": "Move",
        "이 아이콘은 앱을 특정할 수 없어 옮길 수 없습니다":
            "This icon cannot be moved — its app could not be identified",
        "숨기기·꺼내기는 아이콘의 자리를 옮기는 일이라 그 앱을 한 번 재시작해야 합니다. 자리가 정해진 뒤로는 슬라임 클릭만으로 즉시 감추고 꺼낼 수 있습니다. ⌘드래그로 직접 옮기면 재시작 없이 반영되며, 그 배치가 항상 우선합니다.":
            "Hiding and revealing moves an icon's position, so its app restarts once. After that, a click on the slime hides and shows it instantly. Moving it yourself with ⌘-drag applies with no restart, and that placement always wins.",
        "다시 검사": "Scan again",
        "경계 위치를 아직 알 수 없습니다. 설정을 한 번 닫았다 열어보세요.":
            "The boundary position is not known yet. Close settings and open it again.",
        "재시작: %@": "Restart: %@",
        "%@개 이동이 재시작을 기다립니다": "%@ move(s) waiting on a restart",
        "%@ 아이콘을 클릭합니다 — 숨겨져 있어도 됩니다": "Clicks %@'s icon — even while hidden",
        "%@의 아이콘 위치를 고쳐 쓸 수 없었습니다.": "Could not rewrite %@'s icon position.",
        "%@이(가) 종료를 거부했습니다. 저장하지 않은 작업을 정리한 뒤 그 앱을 직접 재시작하면 적용됩니다.":
            "%@ refused to quit. Save your work, restart that app yourself, and the move applies.",
        "%@을(를) 다시 실행하지 못했습니다. 직접 실행하면 옮긴 위치가 적용됩니다.":
            "Could not relaunch %@. Start it yourself and the move applies.",

        // MARK: - Settings shell
        "시작하기": "Get started",
        "무엇인지, 어떻게 쓰는지": "What it is, how to use it",
        "아이콘": "Icons",
        "넣고 빼기": "Put in and take out",
        "그룹": "Groups",
        "묶어서 관리": "Manage as a set",
        "제작자": "Creator",
        "Ai싱크클럽 · 싱크 제작": "Ai싱크클럽 · made by Sync",
        "진단": "Diagnostics",
        "이 맥에서 되는 것": "What works on this Mac",
        "스페이서 백엔드로 동작 중 — 권한 없이 그룹 접기/펴기가 가능합니다.":
            "Running on the spacer backend — groups collapse and expand with no permissions.",
        "브릿지 백엔드로 동작 중 — 열거·이동·원격 클릭까지 가능합니다.":
            "Running on the bridge backend — enumeration, moving and remote clicks all available.",
        "현재 macOS 버전에서 동작하는 백엔드를 찾지 못했습니다.":
            "No backend works on this version of macOS.",
        "숨기기": "Hide",
        "아이템 열거": "Enumerate items",
        "순서 이동": "Reorder",
        "원격 클릭": "Remote click",
        "아이콘 캡처": "Capture icons",
        "인터넷 사용": "Network use",
        "여섯 시간에 한 번, 패널을 열 때만 두 곳을 읽습니다 — 새 버전이 나왔는지(GitHub 릴리스), 그리고 아래 띠에 띄울 문구입니다. 보내는 것은 없고, 아이콘 목록이나 사용 기록은 어디에도 올라가지 않습니다.":
            "Two reads, at most once every six hours, and only while the panel is open — whether a newer release exists (GitHub Releases), and the copy for the strip at the bottom. Nothing is sent. Your icon list and your usage go nowhere.",
        "끄려면: defaults write com.zipbar.ZipBar com.zipbar.checkForUpdates -bool NO":
            "To switch off: defaults write com.zipbar.ZipBar com.zipbar.checkForUpdates -bool NO",
        "터미널에서 `zipbar-probe capabilities`를 실행하면 각 백엔드가 이 macOS에서 실제로 무엇을 반환하는지 확인할 수 있습니다.":
            "Run `zipbar-probe capabilities` in a terminal to see what each backend actually returns on this macOS.",
        "현재 백엔드: %@": "Current backend: %@",
        "언어": "Language",
        "시스템 설정 따름": "Follow system",

        // MARK: - Tutorial
        "메뉴바의 슬라임이 SlimeZIP입니다": "The slime in your menu bar is SlimeZIP",
        "숨긴 아이콘이 없으면 한 마리가 둥글게 쉬고 있습니다. 가끔 숨을 쉬고 눈을 깜빡입니다.":
            "With nothing hidden it sits there round and idle. It breathes now and then, and blinks.",
        "슬라임을 클릭하면 접히고 펴집니다": "Click the slime to collapse and expand",
        "왼쪽 클릭으로 숨긴 아이콘을 잠깐 꺼내 보고 다시 넣습니다. 오른쪽 클릭하면 메뉴가 열립니다.":
            "Left click brings the hidden icons out for a moment and puts them back. Right click opens the menu.",
        "설정의 '아이콘'에서도 넣고 뺍니다": "You can also do it from Icons in settings",
        "슬라임을 눌러서 해도 되고, 한 번에 여러 개를 정리할 때는 설정 창이 편합니다. 직접 끌어다 옮길 필요는 없습니다.":
            "The slime works fine, but the settings window is easier when sorting several at once. No dragging required.",
        "재시작은 한 번뿐입니다": "One restart, and only one",
        "아이콘의 자리는 그 앱이 시작할 때 읽히므로, 처음 넣거나 뺄 때만 그 앱을 한 번 재시작합니다. 자리가 정해진 뒤로는 감추고 꺼내는 것이 슬라임 클릭만으로 즉시 됩니다.":
            "An icon's position is read when its app starts, so the app restarts once — the first time you put it in or take it out. After that, hiding and showing is a click on the slime, instantly.",
        "많이 물수록 납작해집니다": "The more it holds, the flatter it gets",
        "숨긴 아이콘이 늘어나면 슬라임들이 같은 자리에서 서로를 눌러 찌부됩니다. 아이콘이 넓어지지는 않습니다.":
            "As the hidden count rises the slimes squeeze each other flat in the same slot. The icon never gets wider.",
        "아직 안 되는 것": "Not possible yet",
        "• 노치 뒤에 가려진 아이콘은 이 방식으로 꺼낼 수 없습니다.":
            "• Icons already behind the notch cannot be retrieved this way.",
        "• 화면 기록 아이콘처럼 시스템이 우선하는 항목은 숨길 수 없습니다.":
            "• System-priority items, such as the screen-recording indicator, cannot be hidden.",
        "• 숨겨진 앱의 알림은 감지할 수 없습니다. macOS가 다른 앱의 미읽음 상태를 공개하지 않기 때문에, 대신 아이콘이 바뀌면 슬라임에 주황 점이 찍힙니다.":
            "• Notifications from hidden apps cannot be detected — macOS does not publish another app's unread state. Instead, an orange dot appears on the slime when an icon changes.",
        "• 그룹은 왼쪽으로 갈수록 안쪽입니다. 바깥 그룹을 접으면 그 왼쪽 그룹도 함께 가려집니다.":
            "• Groups nest to the left. Collapsing an outer group hides the groups left of it too.",

        // MARK: - Creator
        "GitHub — 별 눌러 주기": "GitHub — leave a star",
        "소스 공개 · 별 하나가 큰 힘이 됩니다": "Source is open · one star goes a long way",
        "싱크마켓": "SyncMarket",
        "AI 스킬·템플릿·자료 — 오픈베타 무료 배포 중":
            "AI skills, templates and resources — free during open beta",
        "링크 모음": "All links",
        "커뮤니티, 강의, 자료실까지 한 곳에": "Community, courses and archives in one place",
        "Ai싱크클럽": "Ai싱크클럽 (AI Sync Club)",
        "싱크 제작": "Made by Sync",
        "AI를 실제 업무에 붙이는 사람들의 커뮤니티입니다. SlimeZIP은 거기서 나온 도구 중 하나고, 무료이며 소스가 공개돼 있습니다.":
            "A community of people putting AI to work on real jobs. SlimeZIP is one of the tools that came out of it — free, with the source open.",
        "이 앱": "This app",
        "릴리스 기록 보기": "See release history",
        "무료 · 오픈소스 · macOS 14 이상": "Free · open source · macOS 14+",
        "최신 버전입니다": "Up to date",
        "소스 공개 · 지금 별 %@개": "Source is open · %@ stars so far",
        "새 버전 %@이 나와 있습니다": "Version %@ is out",

        // MARK: - Welcome
        "메뉴바에 아이콘이 넘칠 때, 슬라임 한 마리가 나머지를 물고 있습니다.":
            "When the menu bar overflows, one slime holds the rest.",
        "슬라임을 누릅니다": "Click the slime",
        "메뉴바 오른쪽의 슬라임을 클릭하면 지금 떠 있는 아이콘이 전부 나옵니다.":
            "Click the slime at the right of the menu bar and every icon currently up appears.",
        "넣기 · 꺼내기": "Put in · take out",
        "감추고 싶은 것 옆의 버튼을 누릅니다. 여러 개를 한 번에 골라도 됩니다.":
            "Press the button beside anything you want gone. Several at once is fine.",
        "적용은 한 번뿐": "Apply, once",
        "그 앱을 한 번만 재시작하면 자리가 정해집니다. 이후로는 클릭 즉시 됩니다.":
            "Restart that app once and the position is fixed. After that it is instant.",
        "3단계면 끝입니다": "Three steps and you're done",
        "아이콘 목록 열기": "Open the icon list",
        "손쉬운 사용 권한을 켜야 목록에 이름이 나옵니다":
            "Turn on Accessibility to see names in the list",
        "만든 곳": "Made by",
        "버전 %@ · macOS 14 이상 · 무료 · 오픈소스": "Version %@ · macOS 14+ · free · open source",

        // MARK: - Groups
        "접힘": "Collapsed",
        "그룹 추가": "Add group",
        "선택한 그룹 삭제": "Delete selected group",
        "그룹을 선택하거나 추가하세요": "Select a group, or add one",
        "이름": "Name",
        "동작": "Behaviour",
        "포인터가 메뉴바를 벗어나면 다시 접기": "Collapse again when the pointer leaves the menu bar",
        "지연": "Delay",
        "자동 숨김": "Auto-hide",
        "펴기": "Expand",
        "접기": "Collapse",
        "그룹 %@": "Group %@",
        "%@초": "%@s",
        "접기/펴기": "Collapsible",
        "항상 숨김": "Always hidden",
        "숨김": "Hidden",

        // MARK: - Star prompt and banner
        "쓸 만하셨다면 GitHub에 별 하나 부탁드립니다":
            "If it was useful, a star on GitHub would mean a lot",
        "다시 묻지 않습니다": "Won't ask again",
        "무료로 쓰는 오픈소스입니다 · 한 번만 눌러 주시면 됩니다":
            "Free and open source · one click is all it takes",
        "무료로 쓰는 오픈소스입니다 · 지금 별 %@개":
            "Free and open source · %@ stars so far",
        "오픈베타 · 무료 스킬 배포 중": "Open beta · free skills",

        // MARK: - Updater
        "받을 수 있는 릴리스를 찾지 못했습니다.": "No downloadable release was found.",
        "내려받는 중 문제가 생겼습니다. 잠시 뒤 다시 시도해 주세요.":
            "The download ran into trouble. Please try again shortly.",
        "받은 파일을 열지 못했습니다.": "The downloaded file could not be opened.",
        "받은 파일이 SlimeZIP이 아닙니다. 설치를 중단했습니다.":
            "The downloaded file is not SlimeZIP. Installation was stopped.",
        "최신 릴리스 확인 중…": "Checking the latest release…",
        "내려받는 중…": "Downloading…",
        "설치 중…": "Installing…",
        "설치하지 못했습니다 — %@": "Could not install — %@",
        "%@에 쓸 권한이 없습니다": "no permission to write to %@",

        // MARK: - Engine
        "아이콘을 옮기려면 그 앱을 한 번 재시작해야 합니다. 처음 한 번뿐이고, 그 뒤로는 즉시 감춰지고 꺼내집니다.":
            "Moving an icon requires restarting its app once. Only the first time — after that, hiding and showing is immediate.",
        "손쉬운 사용 권한이 꺼져 있습니다. 숨기기는 되지만 어느 아이콘이 어느 앱 것인지 읽을 수 없어 목록이 비어 보입니다.":
            "Accessibility is off. Hiding still works, but the app cannot read which icon belongs to which app, so the list looks empty.",
        "노치 뒤의 아이콘은 이 방식으로 꺼낼 수 없습니다.":
            "Icons behind the notch cannot be retrieved this way.",
        "슬라임 왼쪽으로 ⌘드래그": "⌘-drag to the left of the slime",
        "슬라임 오른쪽으로 ⌘드래그": "⌘-drag to the right of the slime",
        "알 수 없는 앱": "Unknown app",
        "현재 macOS %@에서 동작하는 백엔드를 찾지 못했습니다.":
            "No backend works on macOS %@.",
        "%@ 경계": "%@ boundary",
        "%@ 경계 — 숨길 아이콘을 이 왼쪽으로 ⌘드래그하세요":
            "%@ boundary — ⌘-drag icons to the left of this to hide them",
        "%@ 경계 — 숨길 아이콘을 슬라임 왼쪽으로 ⌘드래그하세요":
            "%@ boundary — ⌘-drag icons to the left of the slime to hide them",

        "%@ 백엔드는 현재 macOS 버전에서 동작하지 않습니다.":
            "The %@ backend does not work on this version of macOS.",
        // MARK: - Menu bar glyph and menus
        "SlimeZIP — 숨겨진 아이콘 없음": "SlimeZIP — nothing hidden",
        "SlimeZIP — %@개 꺼내 둠": "SlimeZIP — %@ out",
        "SlimeZIP — %@개 숨김": "SlimeZIP — %@ hidden",
        " · 변화 있음": " · something changed",
        "SlimeZIP, %1$@개 숨김, %2$@": "SlimeZIP, %1$@ hidden, %2$@",
        "펼침": "expanded",
        "SlimeZIP 종료": "Quit SlimeZIP",
        "SlimeZIP 설정": "SlimeZIP Settings",
        "SlimeZIP 위치": "SlimeZIP position",
        "SlimeZIP %@로 업데이트할까요?": "Update SlimeZIP to %@?",
        "릴리스 페이지 열기": "Open the releases page",
        "업데이트하지 못했습니다": "Could not update",
    ]
}
