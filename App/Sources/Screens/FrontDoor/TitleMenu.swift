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
        static let daily = true
        /// R4.
        static let custom = true
        /// R4.
        static let fromCode = true
        /// Iteration 8.
        static let scenarios = true
        static let hall = true
        static let dynasty = true
        static let season = true
        // MARK: Iteration 10 — M5 (morning desk)
        static let desk = true
        // MARK: end of Iteration 10 — M5
        // MARK: Iteration 10 — M4 (leagues)
        static let league = true
        // MARK: end of Iteration 10
    }

    struct Row: Identifiable {
        enum ID: String {
            case daily, custom, fromCode, scenarios, hall, dynasty, season
            // MARK: Iteration 10 — M5 (morning desk)
            case desk
            // MARK: end of Iteration 10 — M5
            // MARK: Iteration 10 — M4 (leagues)
            case league
            // MARK: end of Iteration 10
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
        onFromCode: @escaping () -> Void,
        onScenarios: @escaping () -> Void = {},
        onHall: @escaping () -> Void = {},
        onDynasty: @escaping () -> Void = {},
        onSeason: @escaping () -> Void = {},
        // MARK: Iteration 10 — M5 (morning desk)
        onDesk: @escaping () -> Void = {},
        // MARK: end of Iteration 10 — M5
        // MARK: Iteration 10 — M4 (leagues)
        onLeague: @escaping () -> Void = {}
        // MARK: end of Iteration 10
    ) -> TitleMenu {
        TitleMenu(rows: [
            Row(id: .daily, title: "Today's company", systemImage: "calendar", isEnabled: Flags.daily, action: onDaily),
            Row(id: .season, title: "This season", systemImage: "leaf", isEnabled: Flags.season, action: onSeason),
            Row(id: .scenarios, title: "Scenarios", systemImage: "star.circle", isEnabled: Flags.scenarios, action: onScenarios),
            Row(id: .custom, title: "Custom company", systemImage: "slider.horizontal.3", isEnabled: Flags.custom, action: onCustom),
            Row(id: .fromCode, title: "From a code", systemImage: "number", isEnabled: Flags.fromCode, action: onFromCode),
            Row(id: .hall, title: "Hall of Fame", systemImage: "trophy", isEnabled: Flags.hall, action: onHall),
            Row(id: .dynasty, title: "Dynasty", systemImage: "person.2.crop.square.stack", isEnabled: Flags.dynasty, action: onDynasty),
            // MARK: Iteration 10 — one row per lane (add the id, the flag and the action in your own marked regions)
            // MARK: M4 (leagues)
            Row(id: .league, title: "League", systemImage: "chart.bar.doc.horizontal", isEnabled: Flags.league, action: onLeague),
            // MARK: M5 (morning desk)
            Row(id: .desk, title: "The desk", systemImage: "tray.full", isEnabled: Flags.desk, action: onDesk),
            // MARK: end of Iteration 10
        ])
    }

    var enabledRows: [Row] { rows.filter(\.isEnabled) }
}

// MARK: U1 (ux: the first-hour fixes)

/// The enabled rows in three groups — *Today*, *Set up*, *Remember* — as
/// the body of the front door's *More ways to play* sheet (iteration 13,
/// C9). Nothing at all when every row is off.
///
/// `TitleMenu`'s nine rows and their order are unchanged (two tests pin
/// them); this view only chooses where each is drawn. *The desk* row is
/// the front door's own desk card said twice, so it is not drawn here:
/// the Continue card carries the desk as one line.
struct TitleMenuView: View {
    let menu: TitleMenu
    /// What a tap does with the row. By default it runs the row's action;
    /// the sheet closes itself first and runs it after.
    var onPick: (TitleMenu.Row) -> Void = { $0.action() }

    /// The three groups, by row id, in the order they are drawn.
    static let groups: [(title: String, ids: [TitleMenu.Row.ID])] = [
        (String(localized: "Today", comment: "Bitmap heading in the More ways to play sheet: the daily, the season and the league. Uppercased by the pixel face"), [.daily, .season, .league]),
        (String(localized: "Set up", comment: "Bitmap heading in the More ways to play sheet: scenarios, a custom company and a company from a code. Uppercased by the pixel face"), [.scenarios, .custom, .fromCode]),
        (String(localized: "Remember", comment: "Bitmap heading in the More ways to play sheet: the Hall of Fame and the dynasty. Uppercased by the pixel face"), [.hall, .dynasty]),
    ]

    /// Every enabled row a group draws.
    static func drawnRows(of menu: TitleMenu) -> [TitleMenu.Row] {
        let drawn = Set(groups.flatMap(\.ids))
        return menu.enabledRows.filter { drawn.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            ForEach(Self.groups, id: \.title) { group in
                let rows = group.ids.compactMap { id in menu.enabledRows.first { $0.id == id } }
                if !rows.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        PixelSectionTitle(title: group.title)
                        ForEach(rows) { row in
                            Button {
                                Haptics.tap()
                                Sounds.play(.tap)
                                onPick(row)
                            } label: {
                                Label(row.title, systemImage: row.systemImage)
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, Theme.Spacing.xs)
                            }
                            .buttonStyle(.bordered)
                            .tint(Theme.accent)
                        }
                    }
                }
            }
        }
    }
}

// MARK: end U1
