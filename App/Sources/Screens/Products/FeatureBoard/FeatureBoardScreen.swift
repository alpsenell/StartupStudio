import SwiftUI
import TycoonContent
import TycoonEngine

/// The feature board: what the product actually *is*, argued with rather
/// than sliders.
///
/// The board is the type's slots drawn as pixel cards; the hand is a
/// fanned row underneath with each card's fit written in words; a line is
/// drawn between placed cards that were written for each other. Every
/// button says what it will do to the number before it is pressed
/// (iteration 10's rule 7), and a refusal says why.
///
/// Pixel chrome, not SF: `PixelPanel`, `PixelText` and `PixelButtonStyle`,
/// the same material as the war room and the venue sheet.
struct FeatureBoardScreen: View {
    let engine: GameEngine
    let productID: UUID

    @Environment(GameShell.self) private var injectedShell: GameShell?
    private var shell: GameShell { injectedShell ?? .shared }

    /// The slot the next tapped card goes into: `nil` means "the first
    /// free one", which is what a player who never touches a slot gets.
    @State private var selectedSlot: Int?
    /// The card whose back is showing.
    @State private var inspecting: String?

    private var product: Product? { engine.state.product(id: productID) }

    private var reading: FeatureBoardReading? {
        product.map {
            FeatureBoard.reading(
                for: $0, state: engine.state, content: engine.content, balance: engine.balance
            )
        }
    }

    private var hand: [FeatureCard] {
        guard let product else { return [] }
        return FeatureBoard.hand(
            for: product, state: engine.state, content: engine.content, balance: engine.balance
        )
    }

    var body: some View {
        Group {
            if let product, let reading {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        FeatureBoardVerdictPanel(reading: reading, productName: product.name)
                        FeatureBoardAppetitePanel(tags: reading.appetite)
                        FeatureBoardSlotsPanel(
                            reading: reading,
                            selectedSlot: $selectedSlot,
                            onRemove: remove(slot:)
                        )
                        FeatureBoardHandPanel(
                            hand: hand,
                            reading: reading,
                            product: product,
                            appetite: Set(reading.appetite),
                            inspecting: $inspecting,
                            onPlace: place(cardID:),
                            // MARK: J3 (rivals and the market)
                            copiedBy: copiedBy(product)
                            // MARK: end J3
                        )
                    }
                    .padding(Theme.Spacing.lg)
                }
            } else {
                ContentUnavailableView(
                    "No board",
                    systemImage: "square.grid.2x2",
                    description: Text("This product is no longer in the save.")
                )
            }
        }
        .background(Theme.screenBackground)
        .navigationTitle("Feature board")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    // MARK: - Sending

    /// Placing a card produces no event — a board is a plan, not news —
    /// so the toast cannot be driven off the event stream the way most
    /// actions are. The engine is asked first (`FeatureBoard.refusal`, a
    /// dry run of the same code the reducer runs), which is also what puts
    /// a true sentence on a refusal.
    private func place(cardID: String) {
        guard let reading else { return }
        let slot = selectedSlot ?? reading.filled
        if let refusal = FeatureBoard.refusal(
            placing: cardID, slot: slot, productID: productID,
            state: engine.state, content: engine.content, balance: engine.balance
        ) {
            shell.toasts.show(
                refusal.reason, icon: "exclamationmark.triangle.fill",
                tint: Theme.warning, severity: .notable
            )
            return
        }
        engine.send(.placeFeature(productID: productID, cardID: cardID, slot: slot))
        Haptics.commit()
        shell.toasts.show(
            "\(engine.content.featureCard(cardID)?.name ?? "Feature") placed",
            icon: "square.grid.2x2.fill",
            tint: Theme.accent
        )
        selectedSlot = nil
    }

    // MARK: J3 (rivals and the market)
    /// The cards in this hand a rival's live clone has already lifted in
    /// this topic, by card id, with the studio's name. Empty until a clone
    /// copies a card, which needs a board somebody placed a card on.
    private func copiedBy(_ product: Product) -> [String: String] {
        var copied: [String: String] = [:]
        for card in hand {
            if let rival = RivalMarket.copiedBy(
                cardName: card.name, topicID: product.topicID, state: engine.state
            ) {
                copied[card.id] = rival.name
            }
        }
        return copied
    }
    // MARK: end J3

    private func remove(slot: Int) {
        if let refusal = FeatureBoard.refusal(
            removingSlot: slot, productID: productID,
            state: engine.state, content: engine.content, balance: engine.balance
        ) {
            shell.toasts.show(
                refusal.reason, icon: "exclamationmark.triangle.fill",
                tint: Theme.warning, severity: .notable
            )
            return
        }
        engine.send(.removeFeature(productID: productID, slot: slot))
        selectedSlot = nil
    }
}

// MARK: - The verdict

/// What the board is worth, in the one number that reaches the launch.
private struct FeatureBoardVerdictPanel: View {
    let reading: FeatureBoardReading
    let productName: String

    private var percent: Int {
        Int(((reading.qualityMultiplier - 1) * 100).rounded())
    }

    private var tint: Color {
        if percent > 0 { return Theme.positiveCash }
        if percent < 0 { return Theme.negativeCash }
        return Theme.pixelInk
    }

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                PixelSectionTitle(title: "The board")
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                    PixelText(
                        text: percent == 0 ? "NO CHANGE" : "\(percent > 0 ? "+" : "")\(percent)%",
                        scale: 3,
                        color: tint
                    )
                    Text("on quality at launch")
                        .font(.caption)
                        .foregroundStyle(Theme.pixelInk.opacity(0.7))
                }
                Text(reading.summary)
                    .font(.footnote)
                    .foregroundStyle(Theme.pixelInk)
                    .fixedSize(horizontal: false, vertical: true)
                if let closed = reading.closedReason {
                    Label(closed, systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("You can change it while \(productName) is still being designed.")
                        .font(.caption)
                        .foregroundStyle(Theme.pixelInk.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Board worth \(percent) percent on quality. \(reading.summary)"
        )
    }
}

// MARK: - The appetite

/// What the market wants this quarter — the thing that makes the same card
/// worth more in spring than it was in winter.
private struct FeatureBoardAppetitePanel: View {
    let tags: [String]

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                PixelSectionTitle(title: "The market wants")
                if tags.isEmpty {
                    Text("Nothing in particular this quarter.")
                        .font(.footnote)
                        .foregroundStyle(Theme.pixelInk)
                } else {
                    FeatureBoardWrap(spacing: Theme.Spacing.xs) {
                        ForEach(tags, id: \.self) { tag in
                            PixelText(text: tag, scale: 2, color: Theme.pixelAccent)
                                .padding(.horizontal, Theme.Spacing.sm)
                                .padding(.vertical, 5)
                                .background(Theme.pixelAccent.opacity(0.14))
                                .overlay {
                                    PixelPanelBorder(thickness: 2, corner: 2)
                                        .fill(Theme.pixelAccent.opacity(0.5))
                                }
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            tags.isEmpty
                ? "The market wants nothing in particular this quarter"
                : "The market wants \(tags.joined(separator: ", "))"
        )
    }
}

// MARK: - The slots

/// The board itself: one pixel slot per card the type allows, with the
/// synergy lines drawn between the ones that were written for each other.
private struct FeatureBoardSlotsPanel: View {
    let reading: FeatureBoardReading
    @Binding var selectedSlot: Int?
    let onRemove: (Int) -> Void

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: Theme.Spacing.sm)]

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                PixelSectionTitle(title: "Slots \(reading.filled)/\(reading.slots)")
                LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                    ForEach(0..<reading.slots, id: \.self) { slot in
                        if let card = reading.cards.first(where: { $0.slot == slot }) {
                            FeatureBoardSlotCard(card: card, locked: !reading.isOpen) {
                                onRemove(slot)
                            }
                        } else {
                            FeatureBoardEmptySlot(
                                index: slot,
                                isSelected: selectedSlot == slot || (selectedSlot == nil && slot == reading.filled)
                            ) {
                                selectedSlot = selectedSlot == slot ? nil : slot
                            }
                        }
                    }
                }
            }
        }
    }
}

/// One placed card, with what it is doing here written under it.
private struct FeatureBoardSlotCard: View {
    let card: FeatureCardReading
    let locked: Bool
    let onRemove: () -> Void

    private var tint: Color {
        if card.value < 0 { return Theme.negativeCash }
        if card.ridesAppetite || !card.synergyPartners.isEmpty { return Theme.positiveCash }
        return Theme.pixelAccent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PixelText(text: card.name, scale: 2, color: Theme.pixelInk)
            Text(card.verdict)
                .font(.caption2)
                .foregroundStyle(Theme.pixelInk.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Theme.Spacing.xs) {
                if !card.synergyPartners.isEmpty {
                    FeatureBoardBadge(text: "×\(card.synergyPartners.count)", tint: Theme.positiveCash)
                }
                if card.ridesAppetite {
                    FeatureBoardBadge(text: "hot", tint: Theme.warning)
                }
                // MARK: J3 (rivals and the market)
                if card.copiedBy != nil {
                    FeatureBoardBadge(text: "copied", tint: Theme.negativeCash)
                }
                // MARK: end J3
                Spacer(minLength: 0)
                if !locked {
                    Button(action: onRemove) {
                        Image(systemName: "xmark")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.pixelInk.opacity(0.6))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Take \(card.name) off the board")
                }
            }
        }
        .padding(Theme.Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .background(tint.opacity(0.12))
        .overlay { PixelPanelBorder(thickness: 2, corner: 2).fill(tint.opacity(0.75)) }
        .accessibilityElement(children: .contain)
    }
}

/// A slot with nothing in it. Tapping one chooses where the next card
/// lands, which is the whole of the drag gesture a pixel board needs.
private struct FeatureBoardEmptySlot: View {
    let index: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.pixelInk.opacity(isSelected ? 0.8 : 0.3))
                PixelText(
                    text: "SLOT \(index + 1)",
                    scale: 1,
                    color: Theme.pixelInk.opacity(isSelected ? 0.8 : 0.35)
                )
            }
            .frame(maxWidth: .infinity, minHeight: 92)
            .background(Theme.pixelInk.opacity(isSelected ? 0.08 : 0.03))
            .overlay {
                PixelPanelBorder(thickness: 2, corner: 2)
                    .fill(Theme.pixelInk.opacity(isSelected ? 0.5 : 0.2))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Empty slot \(index + 1)")
        .accessibilityHint(isSelected ? "The next feature lands here" : "Put the next feature here")
    }
}

private struct FeatureBoardBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        PixelText(text: text, scale: 1, color: tint)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(tint.opacity(0.16))
    }
}

// MARK: - The hand

/// The cards this crew could build today, best first, each with what it
/// would do to the board written on it.
private struct FeatureBoardHandPanel: View {
    let hand: [FeatureCard]
    let reading: FeatureBoardReading
    let product: Product
    let appetite: Set<String>
    @Binding var inspecting: String?
    let onPlace: (String) -> Void
    // MARK: J3 (rivals and the market)
    /// Card id → the studio whose clone lifted it.
    var copiedBy: [String: String] = [:]
    // MARK: end J3

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                PixelSectionTitle(title: "The hand")
                if hand.isEmpty {
                    Text("Nothing in the catalog fits this product yet.")
                        .font(.footnote)
                        .foregroundStyle(Theme.pixelInk)
                } else {
                    ForEach(hand) { card in
                        FeatureBoardHandRow(
                            card: card,
                            product: product,
                            reading: reading,
                            ridesAppetite: card.appetiteTag.map { appetite.contains($0) } ?? false,
                            isPlaced: product.features.contains(card.id),
                            isOpen: reading.isOpen,
                            isExpanded: inspecting == card.id,
                            onInspect: { inspecting = inspecting == card.id ? nil : card.id },
                            onPlace: { onPlace(card.id) },
                            // MARK: J3 (rivals and the market)
                            copiedBy: copiedBy[card.id]
                            // MARK: end J3
                        )
                    }
                }
            }
        }
    }
}

private struct FeatureBoardHandRow: View {
    let card: FeatureCard
    let product: Product
    let reading: FeatureBoardReading
    let ridesAppetite: Bool
    let isPlaced: Bool
    let isOpen: Bool
    let isExpanded: Bool
    let onInspect: () -> Void
    let onPlace: () -> Void
    // MARK: J3 (rivals and the market)
    /// The studio whose live clone in this topic already has this card.
    var copiedBy: String? = nil
    // MARK: end J3

    /// The pairs this card would make with what is already down.
    private var partners: [String] {
        reading.cards
            .filter { placed in
                card.synergies.contains(placed.cardID)
                    || (placed.cardID != card.id && synergyBack(placed.cardID))
            }
            .map(\.name)
    }

    /// Synergy is symmetric; a placed card may be the one that wrote the
    /// pair down.
    private func synergyBack(_ placedID: String) -> Bool {
        card.synergies.contains(placedID)
    }

    private var fitLine: String {
        let fitsType = card.fits(typeID: product.typeID)
        let fitsTopic = card.fits(topicID: product.topicID)
        if !card.fitsTypes.isEmpty, !card.fitsTopics.isEmpty, fitsType, fitsTopic {
            return "Written for exactly this kind of product."
        }
        if !fitsType { return "Wrong kind of product for it." }
        if !fitsTopic { return "Wrong subject for it." }
        return "At home here."
    }

    /// What the button will do, on the button.
    private var actionLabel: String {
        if isPlaced { return "On the board" }
        if !isOpen { return "Locked" }
        if reading.filled >= reading.slots { return "Board full" }
        var bits: [String] = ["Place"]
        if ridesAppetite { bits.append("· hot") }
        if !partners.isEmpty { bits.append("· ×\(partners.count)") }
        return bits.joined(separator: " ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 4) {
                    PixelText(text: card.name, scale: 2, color: Theme.pixelInk)
                    // MARK: J3 (rivals and the market)
                    // Before you place it: somebody shipped this first, and
                    // while their clone competes it fits half as well here.
                    if let copiedBy {
                        FeatureBoardBadge(text: "copied by \(copiedBy)", tint: Theme.negativeCash)
                            .accessibilityLabel("Copied by \(copiedBy): worth half its fit here while their clone competes")
                    }
                    // MARK: end J3
                    Text("\(card.leansOn.displayName) · \(fitLine)")
                        .font(.caption2)
                        .foregroundStyle(Theme.pixelInk.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button(action: onPlace) {
                    Text(actionLabel)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                }
                .buttonStyle(
                    PixelButtonStyle(fill: isPlaced || !isOpen ? Theme.chipBackground : Theme.pixelAccent)
                )
                .frame(width: 128)
                .disabled(isPlaced || !isOpen || reading.filled >= reading.slots)
                .accessibilityLabel("\(actionLabel): \(card.name)")
            }
            Button(action: onInspect) {
                HStack(spacing: 4) {
                    Text(isExpanded ? "Less" : "What is it?")
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.pixelAccent)
            }
            .buttonStyle(.plain)
            if isExpanded {
                Text(card.blurb)
                    .font(.caption)
                    .foregroundStyle(Theme.pixelInk)
                    .fixedSize(horizontal: false, vertical: true)
                if !partners.isEmpty {
                    Text("Pairs with \(partners.joined(separator: ", ")).")
                        .font(.caption2)
                        .foregroundStyle(Theme.positiveCash)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if ridesAppetite, let tag = card.appetiteTag {
                    Text("The market is asking for \(tag) this quarter.")
                        .font(.caption2)
                        .foregroundStyle(Theme.warning)
                }
                // MARK: J3 (rivals and the market)
                if let copiedBy {
                    Text("\(copiedBy) already sells this in the same market. While their clone competes, it counts for half its fit here — and the reviews will notice.")
                        .font(.caption2)
                        .foregroundStyle(Theme.negativeCash)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // MARK: end J3
            }
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.pixelInk.opacity(0.12)).frame(height: 1)
        }
    }
}

// MARK: - Layout

/// A minimal flow layout for the appetite chips: SwiftUI has no wrapping
/// HStack, and a `Layout` is four lines cheaper than a grid that guesses.
struct FeatureBoardWrap: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? x, height: y + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
