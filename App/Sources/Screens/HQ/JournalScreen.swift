import SwiftUI
import TycoonEngine

/// The full journal: every event of the run, newest first, grouped by
/// week, filterable by strand and searchable.
struct JournalScreen: View {
    let engine: GameEngine

    @State private var filter: JournalCategory?
    @State private var query = ""

    private var copy: EventCopy {
        EventCopy(state: engine.state, content: engine.content, balance: engine.balance)
    }

    private var rows: [JournalRow] {
        var entries = JournalBuilder.entries(state: engine.state, copy: copy)
        if let filter {
            entries = entries.filter { $0.category == filter }
        }
        if !query.isEmpty {
            entries = entries.filter {
                $0.line.message.localizedCaseInsensitiveContains(query)
            }
        }
        return JournalBuilder.collapsingRoutine(entries)
    }

    private var groups: [(week: Int, rows: [JournalRow])] {
        var result: [(week: Int, rows: [JournalRow])] = []
        for row in rows {
            if result.last?.week == row.week {
                result[result.count - 1].rows.append(row)
            } else {
                result.append((week: row.week, rows: [row]))
            }
        }
        return result
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg, pinnedViews: [.sectionHeaders]) {
                if groups.isEmpty {
                    ContentUnavailableView(
                        query.isEmpty ? "Nothing here yet" : "No matches",
                        systemImage: "book.closed",
                        description: Text(
                            query.isEmpty
                                ? "The journal fills in as the weeks go by."
                                : "Nothing in this filter matches “\(query)”."
                        )
                    )
                    .padding(.top, Theme.Spacing.xl)
                } else {
                    ForEach(groups, id: \.week) { group in
                        Section {
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                ForEach(group.rows) { row in
                                    JournalRowView(row: row)
                                }
                            }
                            .cardStyle()
                        } header: {
                            HStack {
                                PixelText(text: "Week \(group.week)", scale: 2, color: Theme.pixelAccent)
                                Spacer(minLength: 0)
                                Text(GameCalendar(day: (group.week - 1) * 7).longLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, Theme.Spacing.xs)
                            .padding(.vertical, Theme.Spacing.xs)
                            .background(Theme.screenBackground)
                            .accessibilityAddTraits(.isHeader)
                        }
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.screenBackground)
        .navigationTitle("Journal")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Search the journal")
        .safeAreaInset(edge: .top, spacing: 0) { filterBar }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                FilterChip(title: "All", systemImage: "square.grid.2x2", isOn: filter == nil) {
                    filter = nil
                }
                ForEach(JournalCategory.allCases) { category in
                    FilterChip(
                        title: category.displayName,
                        systemImage: category.systemImage,
                        isOn: filter == category
                    ) {
                        filter = filter == category ? nil : category
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }
}

private struct FilterChip: View {
    let title: String
    let systemImage: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            withAnimation(.spring(duration: 0.25)) { action() }
        } label: {
            Label(title, systemImage: systemImage)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm - 2)
                .background(isOn ? Theme.accent : Theme.chipBackground, in: Capsule())
                .foregroundStyle(isOn ? Color.white : Color.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}
