import AppKit
import ZipBarKit

// The OS-churn early-warning system.
//
// macOS has broken menu bar manipulation in two consecutive releases. Instead
// of guessing which technique still works after an update, run this: it asks
// every backend and prints what each actually returned on this machine.

let arguments = Array(CommandLine.arguments.dropFirst())
let command = arguments.first ?? "capabilities"

func printHeader() {
    let version = ProcessInfo.processInfo.operatingSystemVersionString
    print("zipbar-probe — macOS \(version)")
    print("접근성 권한: \(AXIsProcessTrusted() ? "허용됨" : "없음")")
    print(String(repeating: "─", count: 64))
}

func report(_ result: ProbeResult) {
    print("\n[\(result.backend)] 아이템 \(result.items.count)개")
    for note in result.notes {
        print("  · \(note)")
    }
}

func listItems(_ result: ProbeResult, limit: Int = 60) {
    for item in result.items.prefix(limit) {
        let index = item.index.map { String(format: "%3d", $0) } ?? "  ?"
        let owner = item.ownerName ?? item.bundleIdentifier ?? "?"
        let frame = item.frame.map {
            String(format: "x=%.0f w=%.0f", $0.minX, $0.width)
        } ?? "위치 없음"
        print("  \(index)  \(owner.padded(to: 24))  \(item.displayName.padded(to: 28))  \(frame)")
    }
    if result.items.count > limit {
        print("  … 외 \(result.items.count - limit)개")
    }
}

extension String {
    func padded(to width: Int) -> String {
        count >= width ? String(prefix(width)) : self + String(repeating: " ", count: width - count)
    }
}

let probes: [ItemProbe] = [AXSweepProbe(), LegacyWindowProbe(), PrivateBridgeProbe()]

switch command {
case "capabilities":
    printHeader()
    let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    print("\n숨기기 백엔드")
    print("  spacer (길이 팽창): \(SpacerStrategy.isSupported() ? "지원" : "미지원 — macOS 27+에서 무력화")")
    print("\n열거 백엔드")
    for probe in probes {
        report(probe.probe())
    }
    print("\n귀속 신뢰도")
    print("  CGWindowList 소유자 정보: \(LegacyWindowProbe.attributionIsReliable ? "신뢰 가능" : "신뢰 불가 (macOS \(major) 오염)")")

case "list":
    printHeader()
    for probe in probes {
        let result = probe.probe()
        report(result)
        listItems(result)
    }

case "ax":
    printHeader()
    let result = AXSweepProbe().probe()
    report(result)
    listItems(result, limit: 200)

case "press":
    // press <pid> <index> — verifies that we can activate an item we found.
    guard arguments.count == 3,
          let pid = pid_t(arguments[1]),
          let index = Int(arguments[2])
    else {
        print("사용법: zipbar-probe press <pid> <index>")
        exit(2)
    }
    let ok = AXSweepProbe().press(pid: pid, index: index)
    print(ok ? "성공" : "실패")
    exit(ok ? 0 : 1)

default:
    print("""
    사용법: zipbar-probe <command>

      capabilities   현재 macOS에서 각 백엔드가 되는지 요약 (기본값)
      list           모든 백엔드의 열거 결과를 나열
      ax             접근성 스윕 결과만 상세 출력
      press <pid> <index>
                     찾은 아이템을 실제로 눌러 봄
    """)
    exit(2)
}
