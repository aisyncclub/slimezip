import SwiftUI
import ZipBarKit

/// How the app is actually used, told through the slime.
///
/// The previous version described a menu bar that no longer exists: a
/// separator glyph and a chevron the user was told to click, and a ⌘-drag as
/// the only way to move anything. All three are gone — one slime replaced the
/// separator and chevron, and moves became buttons once ZipBar learned to
/// rewrite where macOS remembers each icon. Instructions that describe a
/// previous version are worse than none, because the user trusts them and
/// then cannot find what they name.
struct OnboardingContent: View {
    private struct Step: Identifiable {
        let id = UUID()
        /// Slime fullness to illustrate the step with, when it has one.
        let slimeStage: Int?
        let symbol: String?
        let title: String
        let detail: String
    }

    private let steps: [Step] = [
        Step(
            slimeStage: 1, symbol: nil,
            title: "메뉴바의 슬라임이 SlimeZIP입니다",
            detail: "숨긴 아이콘이 없으면 한 마리가 둥글게 쉬고 있습니다. "
                  + "가끔 숨을 쉬고 눈을 깜빡입니다."
        ),
        Step(
            slimeStage: nil, symbol: "cursorarrow.click",
            title: "슬라임을 클릭하면 접히고 펴집니다",
            detail: "왼쪽 클릭으로 숨긴 아이콘을 잠깐 꺼내 보고 다시 넣습니다. "
                  + "오른쪽 클릭하면 메뉴가 열립니다."
        ),
        Step(
            slimeStage: nil, symbol: "list.bullet.rectangle",
            title: "설정의 '아이콘'에서도 넣고 뺍니다",
            detail: "슬라임을 눌러서 해도 되고, 한 번에 여러 개를 정리할 때는 설정 창이 "
                  + "편합니다. 직접 끌어다 옮길 필요는 없습니다."
        ),
        Step(
            slimeStage: nil, symbol: "arrow.clockwise",
            title: "재시작은 한 번뿐입니다",
            detail: "아이콘의 자리는 그 앱이 시작할 때 읽히므로, 처음 넣거나 뺄 때만 "
                  + "그 앱을 한 번 재시작합니다. 자리가 정해진 뒤로는 감추고 꺼내는 "
                  + "것이 슬라임 클릭만으로 즉시 됩니다."
        ),
        Step(
            slimeStage: 5, symbol: nil,
            title: "많이 물수록 납작해집니다",
            detail: "숨긴 아이콘이 늘어나면 슬라임들이 같은 자리에서 서로를 눌러 "
                  + "찌부됩니다. 아이콘이 넓어지지는 않습니다."
        ),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
                ForEach(steps) { step in
                    HStack(alignment: .top, spacing: 12) {
                        Group {
                            if let stage = step.slimeStage {
                                SlimeDecor.Portrait(stage: stage, height: 26)
                            } else if let symbol = step.symbol {
                                Image(systemName: symbol)
                                    .font(.title3)
                                    .foregroundStyle(.tint)
                                    .frame(width: 26, height: 26)
                            }
                        }
                        .frame(width: 34, alignment: .center)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(step.title).font(.headline)
                            Text(step.detail)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Label("아직 안 되는 것", systemImage: "exclamationmark.triangle")
                        .font(.headline)
                    Text("• 노치 뒤에 가려진 아이콘은 이 방식으로 꺼낼 수 없습니다.")
                    Text("• 화면 기록 아이콘처럼 시스템이 우선하는 항목은 숨길 수 없습니다.")
                    Text("• 숨겨진 앱의 알림은 감지할 수 없습니다. macOS가 다른 앱의 "
                         + "미읽음 상태를 공개하지 않기 때문에, 대신 아이콘이 바뀌면 "
                         + "슬라임에 주황 점이 찍힙니다.")
                    Text("• 그룹은 왼쪽으로 갈수록 안쪽입니다. 바깥 그룹을 접으면 그 "
                         + "왼쪽 그룹도 함께 가려집니다.")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
