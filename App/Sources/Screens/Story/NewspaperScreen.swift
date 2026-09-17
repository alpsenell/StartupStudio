import SwiftUI
import TycoonEngine

/// The week's front page: masthead, lead story, the office as a
/// photograph, the rival and market columns, the small print — set on
/// newsprint in the game's own hand, with the last four issues one swipe
/// apart.
///
/// Pushed from HQ (the journal card, the rail's report line and the
/// `.newspaper` route). The page is `NewspaperPage`, a pure function of
/// one `NewspaperIssue`, so the snapshot suite renders it without the
/// pager or the scroll view.
struct NewspaperScreen: View {
    let engine: GameEngine

    @State private var issues: [NewspaperIssue] = []
    @State private var selectedWeek = 0
    /// An issue the player turned to by hand. The stand follows the newest
    /// issue as weeks land, unless the player is reading an older one.
    @State private var pinnedWeek: Int?
    /// Which way the last page turn went, so the incoming page slides in
    /// from the right side.
    @State private var turnedForward = true
    /// Iteration 7 (R4): the issue being shared, as a card.
    @State private var sharing: NewspaperIssue?

    private var composer: NewspaperComposer {
        NewspaperComposer(state: engine.state, content: engine.content, balance: engine.balance)
    }

    private var current: NewspaperIssue? {
        issues.first { $0.week == selectedWeek } ?? issues.last
    }

    var body: some View {
        ScrollView {
            if let issue = current {
                NewspaperPage(issue: issue)
                    .id(issue.week)
                    .transition(
                        Theme.Motion.transition(
                            .asymmetric(
                                insertion: .move(edge: turnedForward ? .trailing : .leading).combined(with: .opacity),
                                removal: .opacity
                            )
                        )
                    )
            }
        }
        .background(Newsprint.paper)
        .navigationTitle("Front page")
        .navigationBarTitleDisplayMode(.inline)
        // Iteration 7 (R4): share this issue as a 1080×1350 card.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    guard let issue = current else { return }
                    Haptics.tap()
                    Sounds.play(.tap)
                    sharing = issue
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(current == nil)
                .accessibilityLabel("Share this front page")
            }
        }
        .sheet(item: $sharing) { issue in
            ShareCardSheet(card: .frontPage(issue: issue, companyName: engine.state.company.name))
        }
        .safeAreaInset(edge: .top, spacing: 0) { newsstand }
        .gesture(pageTurn)
        .onChange(of: engine.state.day, initial: true) { _, _ in refresh() }
        .onChange(of: engine.state.eventLog.count) { _, _ in refresh() }
    }

    /// The last four issues, as a segmented control: system chrome for a
    /// control, the paper below it for the game.
    private var newsstand: some View {
        Picker("Issue", selection: pickerSelection) {
            ForEach(issues) { issue in
                Text(issue.isInProgress ? "Week \(issue.week) so far" : "Week \(issue.week)")
                    .tag(issue.week)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityLabel("Issue")
    }

    private var pickerSelection: Binding<Int> {
        Binding(
            get: { selectedWeek },
            set: { week in turn(to: week) }
        )
    }

    /// A horizontal swipe turns the page: left for a newer issue, right
    /// for an older one.
    private var pageTurn: some Gesture {
        DragGesture(minimumDistance: 32)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let weeks = issues.map(\.week)
                guard let index = weeks.firstIndex(of: selectedWeek) else { return }
                let next = value.translation.width < 0 ? index + 1 : index - 1
                guard weeks.indices.contains(next) else { return }
                Haptics.tap()
                turn(to: weeks[next])
            }
    }

    private func turn(to week: Int) {
        guard week != selectedWeek else { return }
        turnedForward = week > selectedWeek
        pinnedWeek = week
        withAnimation(Theme.Motion.entrance) {
            selectedWeek = week
        }
    }

    /// Recomposes the newsstand. The newest issue is on top unless the
    /// player turned to an older one that is still on the stand.
    private func refresh() {
        let fresh = composer.issues()
        issues = fresh
        if let pinnedWeek, fresh.contains(where: { $0.week == pinnedWeek }) {
            selectedWeek = pinnedWeek
        } else {
            pinnedWeek = nil
            selectedWeek = fresh.last?.week ?? 0
        }
    }
}

// MARK: - The page

/// One front page, laid out for a phone width. Pure: an issue in, a page
/// out.
struct NewspaperPage: View {
    let issue: NewspaperIssue
    /// Iteration 7 (R4): the share card sets the page above the fold —
    /// masthead, lead, photo and the two columns, without the small print
    /// and the footer — so the fitted page keeps its type legible.
    var aboveTheFold = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            masthead
            DoubleRule()
            lead
            Rule()
            photo
            Rule()
            columns
            // MARK: Iteration 11 — N4 (fame and the feed)
            beef
            // MARK: end of Iteration 11 — N4
            if !aboveTheFold {
                Rule()
                smallPrint
                footer
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Newsprint.paper)
    }

    // MARK: Masthead

    private var masthead: some View {
        VStack(spacing: Theme.Spacing.xs) {
            HStack {
                Text(issue.edition)
                Spacer(minLength: 0)
                Text(issue.isInProgress ? "Early edition" : "Free")
            }
            .font(.caption2.smallCaps())
            .foregroundStyle(Newsprint.ink.opacity(0.7))
            .monospacedDigit()

            // MARK: Iteration 18 — the studio mark
            // The paper belongs to the industry, not to the studio, so the
            // mark sits *beside* the masthead as the subject's badge —
            // the way a trade paper runs the logo of whoever it is about.
            // Nothing is drawn, and the masthead is centred exactly as it
            // always was, for a company that never picked one.
            HStack(spacing: Theme.Spacing.sm) {
                if let markSeed = issue.markSeed {
                    StudioMarkView(seed: markSeed, size: 18)
                }
                PixelText(text: issue.masthead, scale: 3, color: Newsprint.ink)
            }
            .frame(maxWidth: .infinity)
            .accessibilityAddTraits(.isHeader)
            // MARK: end of Iteration 18

            Text(issue.dateline)
                .font(.caption)
                .foregroundStyle(Newsprint.ink.opacity(0.8))
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: Lead

    private var lead: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                PixelText(text: issue.lead.kicker, scale: 2, color: Newsprint.accent)
                Spacer(minLength: 0)
                Text("Day \(issue.lead.day)")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(Newsprint.ink.opacity(0.6))
            }
            PixelHeadline(text: issue.lead.headline, scale: 3, color: Newsprint.ink)
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                Image(systemName: issue.lead.icon)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Newsprint.accent)
                    .frame(width: 18)
                    .accessibilityHidden(true)
                Text(issue.lead.body)
                    .font(.subheadline)
                    .foregroundStyle(Newsprint.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(issue.lead.kicker). \(issue.lead.headline). \(issue.lead.body)")
    }

    // MARK: Photo

    private var photo: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs + 2) {
            OfficePhotoView(scene: issue.photo.scene, moment: issue.photo.moment)
                .frame(maxWidth: .infinity)
                .background(Newsprint.ink.opacity(0.06))
                .overlay {
                    PixelPanelBorder(thickness: 3, corner: 3)
                        .fill(Newsprint.ink)
                }
            Text(issue.photo.caption)
                .font(.caption.italic())
                .foregroundStyle(Newsprint.ink.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Columns

    /// Rivals beside the market; stacked at the accessibility sizes, where
    /// two columns of large type would be two words wide.
    @ViewBuilder
    private var columns: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                NewsColumn(column: issue.rivalColumn)
                Rule()
                NewsColumn(column: issue.marketColumn)
            }
        } else {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                NewsColumn(column: issue.rivalColumn)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Rectangle()
                    .fill(Newsprint.ink.opacity(0.5))
                    .frame(width: 1)
                NewsColumn(column: issue.marketColumn)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Iteration 11 — N4 (fame and the feed)

    /// The beef column, full width under the two columns, because it is
    /// quotation rather than a list and quotation wants the measure. Drawn
    /// only in a week the founder actually posted — `beefColumn` is `nil`
    /// otherwise, and the page below is the page that shipped.
    @ViewBuilder
    private var beef: some View {
        if let column = issue.beefColumn {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Rule()
                NewsColumn(column: column)
            }
        }
    }

    // MARK: end of Iteration 11 — N4

    // MARK: Small print

    private var smallPrint: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs + 2) {
            PixelText(text: "In brief", scale: 2, color: Newsprint.ink)
                .accessibilityAddTraits(.isHeader)
            Text(issue.smallPrint.isEmpty ? "Nothing else to report." : issue.smallPrint.joined(separator: "  ·  "))
                .font(.caption)
                .foregroundStyle(Newsprint.ink.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        Text("Covers days \(issue.dayRange.lowerBound)–\(issue.dayRange.upperBound) · Printed weekly, read on Mondays")
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(Newsprint.ink.opacity(0.5))
            .frame(maxWidth: .infinity)
            .padding(.top, Theme.Spacing.xs)
    }
}

/// One titled column of the page.
private struct NewsColumn: View {
    let column: NewspaperIssue.Column

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            PixelText(text: column.title, scale: 2, color: Newsprint.ink)
                .accessibilityAddTraits(.isHeader)
            Rectangle()
                .fill(Newsprint.ink.opacity(0.5))
                .frame(height: 1)
            ForEach(Array(column.lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.footnote)
                    .foregroundStyle(Newsprint.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Rules

/// A hairline in ink.
private struct Rule: View {
    var body: some View {
        Rectangle()
            .fill(Newsprint.ink)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

/// The masthead's double rule: a thick line over a thin one.
private struct DoubleRule: View {
    var body: some View {
        VStack(spacing: 2) {
            Rectangle().fill(Newsprint.ink).frame(height: 3)
            Rectangle().fill(Newsprint.ink).frame(height: 1)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Newsprint

/// The page's own tokens. In light mode they are exactly
/// `Theme.pixelPaper` and `Theme.pixelInk`; in dark mode the paper stays
/// paper — dimmed, as a sheet of newsprint is under a lamp — rather than
/// flipping to the dark panel tone, and the ink stays ink so the page
/// reads as the same object in both appearances.
enum Newsprint {
    static let paper = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 196 / 255, green: 190 / 255, blue: 176 / 255, alpha: 1)
            : UIColor(red: 244 / 255, green: 238 / 255, blue: 226 / 255, alpha: 1)
    })

    /// The sprite outline: PixelKit's (32, 30, 42), in both appearances.
    static let ink = Color(red: 32 / 255, green: 30 / 255, blue: 42 / 255)

    /// The founder's indigo, in the light-mode depth that carries on cream.
    static let accent = Color(red: 78 / 255, green: 74 / 255, blue: 168 / 255)
}

// MARK: - Headline

/// A headline in the bitmap face, wrapped on word boundaries to the width
/// it is given. `PixelText` sets one line; this sets a paragraph of them.
struct PixelHeadline: View {
    let text: String
    var scale: CGFloat = 3
    var color: Color = Theme.pixelInk

    private var words: [String] {
        text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
    }

    var body: some View {
        PixelFlow(wordSpacing: 6 * scale, lineSpacing: 3 * scale) {
            ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                PixelText(text: word, scale: scale, color: color)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Left-to-right flow that wraps when a subview would cross the proposed
/// width. Every subview is one word.
struct PixelFlow: Layout {
    var wordSpacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = rows(fitting: width, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * lineSpacing
        let widest = rows.map(\.width).max() ?? 0
        return CGSize(width: width == .infinity ? widest : min(width, max(widest, 0)), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(fitting: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + wordSpacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(fitting width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let needed = row.indices.isEmpty ? size.width : row.width + wordSpacing + size.width
            if needed > width, !row.indices.isEmpty {
                rows.append(row)
                row = Row()
            }
            row.width = row.indices.isEmpty ? size.width : row.width + wordSpacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}
