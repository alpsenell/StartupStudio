import PixelKit
import SwiftUI
import TycoonEngine
import TycoonSave

/// The front door: the office at night, the game's name, Continue for the
/// slot the player was in, New company, and the three slots.
///
/// Shown at every launch, before onboarding and after an ending. Every
/// way into the game leaves through here: Continue closes the door on
/// the current slot, a slot row opens that slot, an empty row or New
/// company opens the new-game flow into a slot. Deleting a slot asks
/// first.
struct TitleScreen: View {
    let session: GameSession

    /// The slot a delete is being confirmed for.
    @State private var slotToDelete: Int?
    /// New company with every slot taken: which one goes.
    @State private var choosingSlotToReplace = false
    /// The content settles in on arrival; Reduce Motion drops the drift.
    @State private var arrived = false

    var body: some View {
        ScrollView {
            TitleScreenContent(
                scene: scene,
                current: session.currentSummary,
                currentSlot: session.currentSlot,
                slots: session.slots,
                onContinue: {
                    Haptics.tap()
                    Sounds.play(.tap)
                    session.continueGame()
                },
                onNewCompany: newCompany,
                onOpenSlot: { slot in
                    Haptics.tap()
                    Sounds.play(.tap)
                    session.openSlot(slot)
                },
                onDeleteSlot: { slot in slotToDelete = slot },
                // Iteration 7: each row is behind its lane's flag in
                // `TitleMenu.Flags`; the closures are the lanes' to fill.
                menu: .make(
                    onDaily: { /* R3 */ },
                    onCustom: { /* R4 */ },
                    onFromCode: { /* R4 */ }
                )
            )
            .padding(Theme.Spacing.lg)
            .opacity(arrived ? 1 : 0)
            .offset(y: arrived || Theme.Motion.isReduced ? 0 : 12)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.screenBackground.ignoresSafeArea())
        .onAppear {
            session.refreshSlots()
            withAnimation(Theme.Motion.entrance) { arrived = true }
        }
        .confirmationDialog(
            "Delete this save?",
            isPresented: deleting,
            titleVisibility: .visible,
            presenting: slotToDelete
        ) { slot in
            Button("Delete \(name(of: slot))", role: .destructive) {
                Haptics.warning()
                session.deleteSlot(slot)
            }
            Button("Keep it", role: .cancel) {}
        } message: { slot in
            Text(deleteMessage(for: slot))
        }
        .confirmationDialog(
            "Every slot is taken",
            isPresented: $choosingSlotToReplace,
            titleVisibility: .visible
        ) {
            ForEach(session.slots) { row in
                Button("Replace \(name(of: row.slot)) in slot \(row.slot + 1)", role: .destructive) {
                    session.beginNewGame(inSlot: row.slot)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Pick the slot the new company takes. Its save goes when the new one starts, not before.")
        }
    }

    /// The current slot's office after hours, or the garage nobody has
    /// moved into yet.
    private var scene: OfficeSceneInput {
        session.hasCurrentGame ? TitleScene.input(for: session.engine.state) : TitleScene.emptyGarage
    }

    /// New company goes into the first empty slot; with none, the player
    /// picks which save it replaces.
    private func newCompany() {
        Haptics.tap()
        Sounds.play(.tap)
        if let empty = session.slots.first(where: \.isEmpty) {
            session.beginNewGame(inSlot: empty.slot)
        } else {
            choosingSlotToReplace = true
        }
    }

    private var deleting: Binding<Bool> {
        Binding(
            get: { slotToDelete != nil },
            set: { presented in if !presented { slotToDelete = nil } }
        )
    }

    private func name(of slot: Int) -> String {
        guard let row = session.slots.first(where: { $0.slot == slot }) else { return "slot \(slot + 1)" }
        switch row.contents {
        case .saved(let summary, _): return summary.companyName
        case .corrupt: return "the damaged save"
        case .futureFormat: return "the newer save"
        case .empty: return "slot \(slot + 1)"
        }
    }

    private func deleteMessage(for slot: Int) -> String {
        guard let summary = session.slots.first(where: { $0.slot == slot })?.summary else {
            return "Slot \(slot + 1) is cleared. This can't be undone."
        }
        return "Slot \(slot + 1): \(summary.companyName), \(summary.founderName), day \(summary.day). This can't be undone."
    }
}

// MARK: - Content

/// The title screen as one column, without the scroll view, so the
/// snapshot suite can draw it (`ImageRenderer` draws nothing inside a
/// `ScrollView`) and so it is a function of plain values, not a session.
struct TitleScreenContent: View {
    let scene: OfficeSceneInput
    /// The current slot's game, for the Continue card; `nil` when the
    /// slot is empty.
    let current: SaveSummary?
    let currentSlot: Int
    let slots: [SlotSummary]
    var onContinue: () -> Void = {}
    var onNewCompany: () -> Void = {}
    var onOpenSlot: (Int) -> Void = { _ in }
    var onDeleteSlot: (Int) -> Void = { _ in }
    /// Iteration 7: the rows under New company. Nothing is drawn while
    /// every row is off.
    var menu: TitleMenu = TitleMenu()

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            hero
            masthead
            if let current {
                ContinueCard(summary: current, action: onContinue)
            }
            newCompanyButton
            TitleMenuView(menu: menu)
            SlotList(
                slots: slots,
                currentSlot: current == nil ? nil : currentSlot,
                onOpen: onOpenSlot,
                onDelete: onDeleteSlot
            )
        }
    }

    /// The office after hours, in the pixel frame every scene card has.
    private var hero: some View {
        PixelPanel(contentPadding: Theme.Spacing.sm) {
            OfficeSceneView(input: scene)
                .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            scene.occupants.isEmpty
                ? "An empty garage at night"
                : "The \(scene.tier.rawValue) at night, \(scene.occupants.count) at their desks"
        )
    }

    /// The name in the game's own hand, at the largest scale the width
    /// takes, and the line under it.
    private var masthead: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ViewThatFits(in: .horizontal) {
                PixelText(text: "Startup Studio", scale: 4, color: Theme.pixelAccent)
                PixelText(text: "Startup Studio", scale: 3, color: Theme.pixelAccent)
            }
            Text(current == nil
                 ? "Two people in a garage, one laptop, and a name to defend."
                 : "The lights are still on.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .padding(.vertical, Theme.Spacing.xs)
    }

    /// Prominent on a fresh install, where it is the only way in; beside
    /// Continue it steps back.
    @ViewBuilder
    private var newCompanyButton: some View {
        let label = Label("New company", systemImage: "plus")
            .font(.system(.headline, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.xs)
        let hint = slots.contains(where: \.isEmpty)
            ? "Starts the new-game flow in an empty slot"
            : "Every slot is taken; you choose which one to replace"
        if current == nil {
            Button(action: onNewCompany) { label }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .accessibilityHint(hint)
        } else {
            Button(action: onNewCompany) { label }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .accessibilityHint(hint)
        }
    }
}

// MARK: - Continue

/// The game the player was in: the founder's face, the company in pixel
/// caps, the founder, the day and chapter — or the ending — and the one
/// button that goes back in.
private struct ContinueCard: View {
    let summary: SaveSummary
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        portrait
                        facts
                    }
                } else {
                    HStack(alignment: .top, spacing: Theme.Spacing.md) {
                        portrait
                        facts
                    }
                }
                Button(action: action) {
                    Label(
                        summary.endingKind == nil ? "Continue" : "Read the ending",
                        systemImage: summary.endingKind == nil ? "play.fill" : "book.fill"
                    )
                    .font(.system(.headline, design: .rounded))
                }
                .buttonStyle(PixelButtonStyle())
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var portrait: some View {
        PixelPortrait(seed: summary.founderAppearanceSeed ?? 0, isFounder: true, size: 56)
    }

    private var facts: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            PixelCompanyName(name: summary.companyName)
            Text(summary.founderName)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.pixelInk)
            Text(whereItStands)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(Theme.pixelInk.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "Day 214 · Chapter 3 · The loft", or the ending when the run is over.
    private var whereItStands: String {
        var parts = ["Day \(summary.day)"]
        if let ending = summary.endingKind {
            parts.append(ending.headline)
        } else if let chapter = summary.chapter {
            var line = "Chapter \(chapter)"
            if let title = summary.chapterTitle, !title.isEmpty { line += " · \(title)" }
            parts.append(line)
        }
        return parts.joined(separator: " · ")
    }

    private var accessibilityLabel: String {
        "\(summary.endingKind == nil ? "Continue" : "Read the ending of") \(summary.companyName), "
            + "\(summary.founderName), \(whereItStands)"
    }
}

/// A company name in pixel caps when it fits on one line, in the rounded
/// face when it does not: the bitmap font is a display face for short
/// labels and cannot wrap.
private struct PixelCompanyName: View {
    let name: String
    var scale: CGFloat = 2

    var body: some View {
        ViewThatFits(in: .horizontal) {
            PixelText(text: name, scale: scale, color: Theme.pixelInk)
            Text(name)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.pixelInk)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }
}

// MARK: - Slots

/// The three slots: company, founder, day and ending or "Running" on a
/// saved one; "Empty" on the rest. The current slot is marked. Tapping
/// a row opens it; the trash asks before it deletes.
private struct SlotList: View {
    let slots: [SlotSummary]
    /// The slot the engine is in, when it holds a game.
    let currentSlot: Int?
    let onOpen: (Int) -> Void
    let onDelete: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            PixelSectionTitle(title: "Saves")
            ForEach(slots) { row in
                SlotRow(
                    row: row,
                    isCurrent: row.slot == currentSlot,
                    onOpen: { onOpen(row.slot) },
                    onDelete: { onDelete(row.slot) }
                )
            }
        }
    }
}

private struct SlotRow: View {
    let row: SlotSummary
    let isCurrent: Bool
    let onOpen: () -> Void
    let onDelete: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button(action: onOpen) {
                // The number, the face and the company sit on one line
                // until the company's name needs the whole width. At the
                // accessibility sizes the row was three ellipses.
                let layout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.sm))
                    : AnyLayout(HStackLayout(spacing: Theme.Spacing.md))
                layout {
                    HStack(spacing: Theme.Spacing.md) {
                        slotNumber
                        if let summary = row.summary {
                            PixelPortrait(seed: summary.founderAppearanceSeed ?? 0, isFounder: true, size: 34)
                        }
                        if typeSize.isAccessibilitySize {
                            Spacer(minLength: 0)
                            trailingIcon
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(row.isEmpty ? .secondary : .primary)
                            .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                            .minimumScaleFactor(0.85)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(detail)
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                            .fixedSize(horizontal: false, vertical: true)
                        if let footnote {
                            Text(footnote)
                                .font(.caption2.weight(isCurrent ? .semibold : .regular))
                                .foregroundStyle(isCurrent ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.tertiary))
                                .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if !typeSize.isAccessibilitySize {
                        Spacer(minLength: 0)
                        trailingIcon
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressableRow)
            .disabled(!isOpenable)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(hint)

            if !row.isEmpty {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.body)
                        .frame(width: 28, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .tint(Theme.negativeCash)
                .accessibilityLabel("Delete slot \(row.slot + 1)")
            }
        }
        .padding(Theme.Spacing.md)
        .background(
            isCurrent ? Theme.accent.opacity(0.10) : Theme.cardBackground,
            in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
        )
    }

    /// The mark at the end of the row: the tick on the game you are in,
    /// the plus on an empty slot, the chevron on anything else.
    @ViewBuilder
    private var trailingIcon: some View {
        if isCurrent {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.accent)
        } else if row.isEmpty {
            Image(systemName: "plus.circle")
                .foregroundStyle(.tertiary)
        } else if row.summary != nil {
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    /// "Current · Played an hour ago", or just when it was played.
    private var footnote: String? {
        var parts: [String] = []
        if isCurrent { parts.append("Current") }
        if let lastPlayed = row.lastPlayed {
            parts.append("Played \(Self.relative.localizedString(for: lastPlayed, relativeTo: Date()))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .full
        return formatter
    }()

    /// The slot's number in the pixel face, on its own small tile.
    private var slotNumber: some View {
        PixelText(text: "\(row.slot + 1)", scale: 2, color: Theme.pixelInk)
            .frame(width: 28, height: 28)
            .background(Theme.pixelPaper)
            .overlay {
                PixelPanelBorder(thickness: 2, corner: 2)
                    .fill(Theme.pixelInk)
            }
            .accessibilityHidden(true)
    }

    private var isOpenable: Bool {
        switch row.contents {
        case .empty, .saved: true
        case .corrupt, .futureFormat: false
        }
    }

    private var title: String {
        switch row.contents {
        case .empty: "Empty"
        case .saved(let summary, _): summary.companyName
        case .corrupt: "Damaged save"
        case .futureFormat: "Needs a newer app"
        }
    }

    private var detail: String {
        switch row.contents {
        case .empty:
            "Start a company here"
        case .saved(let summary, _):
            "\(summary.founderName) · Day \(summary.day) · \(summary.endingKind?.headline ?? "Running")"
        case .corrupt:
            "The file couldn't be read. Delete it to free the slot."
        case .futureFormat(let version):
            "Saved by a newer version (format \(version))."
        }
    }

    private var accessibilityLabel: String {
        "Slot \(row.slot + 1), \(title). \(detail)"
            + (isCurrent ? ". Current game" : "")
    }

    private var hint: String {
        switch row.contents {
        case .empty: "Starts a new company in this slot"
        case .saved: isCurrent ? "Continues this game" : "Opens this game"
        case .corrupt, .futureFormat: ""
        }
    }
}

// MARK: - Previews

#Preview("With a save") {
    let engine = GameEngine.newGame(
        companyName: "Northgate Softworks", seed: 4242,
        founder: FounderProfile(name: "Mira Okafor", archetype: .hacker, appearanceSeed: 0x5EED)
    )
    let summary = SaveSummary(state: engine.state)
    return ScrollView {
        TitleScreenContent(
            scene: TitleScene.input(for: engine.state),
            current: summary,
            currentSlot: 0,
            slots: [
                SlotSummary(slot: 0, contents: .saved(
                    summary: summary,
                    envelope: SaveEnvelope(formatVersion: 1, savedAt: Date(), appVersion: "0.1.0", summary: summary)
                )),
                SlotSummary(slot: 1, contents: .empty),
                SlotSummary(slot: 2, contents: .corrupt),
            ]
        )
        .padding()
    }
    .background(Theme.screenBackground)
}

#Preview("Fresh install") {
    ScrollView {
        TitleScreenContent(
            scene: TitleScene.emptyGarage,
            current: nil,
            currentSlot: 0,
            slots: (0..<3).map { SlotSummary(slot: $0, contents: .empty) }
        )
        .padding()
    }
    .background(Theme.screenBackground)
}
