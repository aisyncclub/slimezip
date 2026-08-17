import SwiftUI
import ZipBarKit

struct GroupListView: View {
    @ObservedObject var engine: MenuBarEngine
    @State private var selection: MenuBarGroup.ID?

    /// Chevron glyphs that read sensibly at menu bar size.
    private static let symbolChoices = [
        "chevron.left", "chevron.left.2", "ellipsis.circle",
        "square.stack.3d.up", "tray.full", "archivebox", "bolt.horizontal",
    ]

    var body: some View {
        HSplitView {
            groupList
                .frame(minWidth: 200, idealWidth: 220)
            detail
                .frame(minWidth: 300)
        }
    }

    // MARK: - List

    private var groupList: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(engine.layout.groups) { group in
                    HStack {
                        Image(systemName: group.symbolName)
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(group.name)
                            Text(group.behavior.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if engine.collapseState[group.id] == true {
                            Image(systemName: "eye.slash")
                                .foregroundStyle(.secondary)
                                .help("접힘")
                        }
                    }
                    .tag(group.id)
                }
                .onMove { source, destination in
                    engine.moveGroups(fromOffsets: source, toOffset: destination)
                }
            }

            Divider()

            HStack(spacing: 4) {
                Button {
                    engine.addGroup(named: "그룹 \(engine.layout.groups.count + 1)")
                    selection = engine.layout.groups.last?.id
                } label: {
                    Image(systemName: "plus")
                }
                .help("그룹 추가")

                Button {
                    if let selection {
                        engine.removeGroup(id: selection)
                        self.selection = engine.layout.groups.first?.id
                    }
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selection == nil)
                .help("선택한 그룹 삭제")

                Spacer()
            }
            .buttonStyle(.borderless)
            .padding(6)
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if let selection, let group = engine.layout.group(id: selection) {
            editor(for: group)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("그룹을 선택하거나 추가하세요")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func editor(for group: MenuBarGroup) -> some View {
        // Edits are written straight through the engine so persistence and
        // the live menu bar stay in step with the form — there is no separate
        // draft state to fall out of sync.
        let bound = Binding<MenuBarGroup>(
            get: { engine.layout.group(id: group.id) ?? group },
            set: { engine.update($0) }
        )

        return Form {
            Section {
                TextField("이름", text: bound.name)

                Picker("셰브론", selection: bound.symbolName) {
                    ForEach(Self.symbolChoices, id: \.self) { symbol in
                        Label(symbol, systemImage: symbol).tag(symbol)
                    }
                }

                Picker("동작", selection: bound.behavior) {
                    ForEach(MenuBarGroup.Behavior.allCases, id: \.self) { behavior in
                        Text(behavior.displayName).tag(behavior)
                    }
                }
            }

            Section {
                Toggle("포인터가 메뉴바를 벗어나면 다시 접기", isOn: bound.autoHide)
                if bound.wrappedValue.autoHide {
                    LabeledContent("지연") {
                        HStack {
                            Slider(value: bound.autoHideDelay, in: 1...15, step: 1)
                            Text("\(Int(bound.wrappedValue.autoHideDelay))초")
                                .monospacedDigit()
                                .frame(width: 34, alignment: .trailing)
                        }
                    }
                }
            } header: {
                Text("자동 숨김")
            }

            Section {
                Button(engine.collapseState[group.id] == true ? "펴기" : "접기") {
                    engine.toggle(group.id)
                }
                .disabled(!engine.capabilities.canHide)
            }
        }
        .formStyle(.grouped)
    }
}
