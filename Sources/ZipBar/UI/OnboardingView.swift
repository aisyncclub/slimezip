import SwiftUI

/// The spacer backend cannot move other apps' icons, so the user has to place
/// them once by hand. Hiding that fact produces an app that looks broken on
/// first launch; stating it produces one that looks honest.
struct OnboardingView: View {
    private struct Step: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let detail: String
    }

    private let steps: [Step] = [
        Step(
            symbol: "1.circle.fill",
            title: "그룹을 만드세요",
            detail: "'그룹' 탭에서 그룹을 추가하면 메뉴바에 구분자(⋮)와 셰브론이 하나씩 생깁니다."
        ),
        Step(
            symbol: "2.circle.fill",
            title: "⌘를 누른 채 아이콘을 드래그하세요",
            detail: "숨기고 싶은 아이콘을 구분자의 왼쪽으로 옮깁니다. macOS가 위치를 기억하므로 한 번만 하면 됩니다."
        ),
        Step(
            symbol: "3.circle.fill",
            title: "셰브론으로 접고 펴세요",
            detail: "셰브론을 클릭하면 해당 그룹이 접히고 펴집니다. 자동 숨김을 켜두면 포인터가 메뉴바를 벗어날 때 다시 접힙니다."
        ),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(steps) { step in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: step.symbol)
                            .font(.title2)
                            .foregroundStyle(.tint)
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

                VStack(alignment: .leading, spacing: 8) {
                    Label("지금 단계의 한계", systemImage: "exclamationmark.triangle")
                        .font(.headline)
                    Text("• 노치 뒤에 가려진 아이콘은 이 방식으로 꺼낼 수 없습니다. 오버플로우 패널이 추가되면 해결됩니다.")
                    Text("• 화면 기록 아이콘처럼 시스템이 우선하는 항목은 숨길 수 없습니다.")
                    Text("• 그룹은 왼쪽으로 갈수록 안쪽입니다. 바깥 그룹을 접으면 그 왼쪽 그룹도 함께 가려집니다.")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        }
    }
}
