import SwiftUI
import TycoonEngine

/// Iteration 11, wave two — W2. Naming an heir. The dynasty reads it when
/// the run ends: the named person is offered first, and the room says why.
struct FamilyWillSheet: View {
    let engine: GameEngine
    @Environment(\.dismiss) private var dismiss

    @State private var pickedChild: UUID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    CardView("Everything goes to", systemImage: "signature") {
                        VStack(spacing: Theme.Spacing.sm) {
                            ForEach(available, id: \.self) { heir in
                                row(heir)
                            }
                        }
                    }
                    if let name = engine.state.familyDrama.heirName {
                        Text("Signed and lodged. \(name) does not know.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("The will")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var available: [FamilyHeir] {
        FamilyHeir.allCases.filter { heir in
            switch heir {
            case .partner: engine.state.life.family.stage != .single
            case .child: !engine.state.life.family.children.isEmpty
            case .employee: engine.state.employees.contains { !$0.isFounder }
            case .sibling, .nobody: true
            }
        }
    }

    @ViewBuilder
    private func row(_ heir: FamilyHeir) -> some View {
        let chosen = engine.state.familyDrama.heirKind == heir
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Button { sign(heir, childID: heir == .child ? pickedChild : nil) } label: {
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    Image(systemName: chosen ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(chosen ? Theme.accent : .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name(for: heir))
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        Text(heir.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.pressableRow)
            .disabled(heir == .child && pickedChild == nil)

            if heir == .child {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(engine.state.life.family.children) { child in
                            Button {
                                pickedChild = child.id
                                Haptics.tap()
                            } label: {
                                VStack(spacing: 4) {
                                    PixelPortrait(seed: child.appearanceSeed, size: 40)
                                    Text(child.name)
                                        .font(.caption2)
                                        .lineLimit(1)
                                }
                                .frame(width: 66)
                                .padding(4)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(pickedChild == child.id
                                            ? Theme.accent.opacity(0.16) : Color.clear)
                                )
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                }
            }
        }
    }

    private func name(for heir: FamilyHeir) -> String {
        switch heir {
        case .partner:
            engine.state.life.family.partnerName ?? heir.displayName
        case .child:
            engine.state.life.family.children.first { $0.id == pickedChild }?.name
                ?? heir.displayName
        case .employee:
            engine.state.employees
                .filter { !$0.isFounder }
                .min { ($0.hiredDay, $0.name) < ($1.hiredDay, $1.name) }?.name
                ?? heir.displayName
        case .sibling:
            engine.state.familyRelativeName(.sibling, content: engine.content)
        case .nobody:
            heir.displayName
        }
    }

    private func sign(_ heir: FamilyHeir, childID: UUID?) {
        engine.send(.signWill(heir: heir, childID: childID))
        Haptics.commit()
    }
}
