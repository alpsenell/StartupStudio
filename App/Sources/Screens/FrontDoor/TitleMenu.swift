import SwiftUI

// MARK: Iteration 7

/// The three rows under *New company* on the title screen: *Today's
/// company* (R3), *Custom company* and *From a code* (R4). Each is behind
/// its lane's flag so two lanes flip a constant each and never edit the
/// screen; a row that is off is not rendered, so the front door's
/// snapshots hold until a lane turns its row on.
struct TitleMenu {
    enum Flags {
        /// R3.
        static let daily = false
        /// R4.
        static let custom = true
        /// R4.
        static let fromCode = true
    }

    struct Row: Identifiable {
        enum ID: String {
            case daily, custom, fromCode
        }

        let id: ID
        var title: String
        var systemImage: String
        var isEnabled: Bool
        var action: () -> Void
    }

    var rows: [Row]

    init(rows: [Row] = []) {
        self.rows = rows
    }

    static func make(
        onDaily: @escaping () -> Void,
        onCustom: @escaping () -> Void,
        onFromCode: @escaping () -> Void
    ) -> TitleMenu {
        TitleMenu(rows: [
            Row(id: .daily, title: "Today's company", systemImage: "calendar", isEnabled: Flags.daily, action: onDaily),
            Row(id: .custom, title: "Custom company", systemImage: "slider.horizontal.3", isEnabled: Flags.custom, action: onCustom),
            Row(id: .fromCode, title: "From a code", systemImage: "number", isEnabled: Flags.fromCode, action: onFromCode),
        ])
    }

    var enabledRows: [Row] { rows.filter(\.isEnabled) }
}

/// The enabled rows as a row of bordered buttons; nothing at all when
/// none is.
struct TitleMenuView: View {
    let menu: TitleMenu

    var body: some View {
        if !menu.enabledRows.isEmpty {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(menu.enabledRows) { row in
                    Button {
                        Haptics.tap()
                        Sounds.play(.tap)
                        row.action()
                    } label: {
                        Label(row.title, systemImage: row.systemImage)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.xs)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
                }
            }
        }
    }
}
