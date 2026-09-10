import PixelKit
import SwiftUI
import TycoonEngine

// MARK: - Iteration 9 — L7: furnishing the home

/// The home, with the places a thing can stand marked, and a shelf of
/// everything the founder owns or has earned underneath it.
///
/// Tap a slot, tap a thing, it is there. Nothing here costs money, moves a
/// meter or takes an evening: the shop already charged for the possession
/// and the ledger already earned the rest. What changes is the picture.
struct FurnishSheet: View {
    let engine: GameEngine

    @Environment(\.dismiss) private var dismiss
    @Environment(\.gameSession) private var session
    @State private var selectedSlot: String?

    private var life: LifeState { engine.state.life }
    private var tier: HomeTier {
        #if DEBUG
        return DebugLaunch.decorTier ?? life.home
        #else
        return life.home
        #endif
    }
    private var tierStyle: HomeTierStyle {
        HomeTierStyle(rawValue: tier.rawValue) ?? .studioFlat
    }

    private var slots: [DecorSlot] { HomeDecor.slots(for: tier) }
    /// What the sheet shows as standing where — the same thing the scene
    /// draws, so the markers and the chips never disagree with the room.
    private var placed: [String: String] {
        #if DEBUG
        if DebugLaunch.fillsDecor {
            return DecorPresentation.showroom(tier: tier).mapValues(\.rawValue)
        }
        #endif
        return Dictionary(uniqueKeysWithValues: life.decor.placed(in: tier).map { ($0.slot, $0.itemID) })
    }

    // MARK: P3 (purchases: surfaces and copy)
    @Environment(\.shopSurface) private var injectedShop

    /// What the store says is owned; empty without one, so a sheet that
    /// never met the store shelves exactly what it did.
    private var shopOwned: Set<String> {
        ShopSurfaceResolver.resolve(injectedShop)?.owned ?? []
    }
    // MARK: end P3

    private var shelf: [DecorItem] {
        // MARK: P3 (purchases: surfaces and copy) — the owned pack joins the shelf.
        ShopLoftPack.shelf(
            DecorPresentation.available(life: life, ledger: session?.ledger ?? .empty),
            owned: shopOwned
        )
        // MARK: end P3
    }

    private var selected: DecorSlot? {
        slots.first { $0.id == selectedSlot } ?? slots.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    scene
                    slotRow
                    Divider()
                    shelfSection
                    // MARK: P3 (purchases: surfaces and copy)
                    ShopLoftPackSection()
                    // MARK: end P3
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("Furnish")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            if selectedSlot == nil { selectedSlot = firstInteresting()?.id }
        }
    }

    // MARK: The room

    /// Three points per pixel, in a horizontal scroller: the house and the
    /// penthouse are wider than a phone, and a room you cannot see the
    /// things in is not worth furnishing.
    private static let sceneScale = 3

    private var scene: some View {
        PixelPanel(contentPadding: Theme.Spacing.xs) {
            ScrollView(.horizontal, showsIndicators: false) {
                room
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var room: some View {
        HomeSceneView(
                tier: tierStyle,
                occupants: HomeOccupants(founder: CharacterAppearance(seed: founderSeed)),
                activity: .relaxing,
                mood: mood,
                decor: DecorPresentation.sceneDecor(life: life, tier: tier),
                emptyDecorSlots: true,
                decorLabel: { DecorPresentation.spokenSlot($0, life: life, tier: tier) },
                scale: .fixed(Self.sceneScale),
                onTapRegion: { kind in
                    if case .decorSlot(let id) = kind { select(id) }
                }
            )
            .overlay { slotMarkers }
    }

    /// A dotted box on every empty slot and a solid one on the slot being
    /// worked on, drawn in the scene's own pixel geometry so the marks land
    /// exactly where the sprites do.
    private var slotMarkers: some View {
        GeometryReader { proxy in
            let size = HomeSceneComposer.sceneSize(for: tierStyle)
            let geometry = PixelSceneGeometry(
                sceneSize: size, viewSize: proxy.size, mode: .fixed(Self.sceneScale)
            )
            ForEach(HomeSceneComposer.decorSlots(for: tierStyle), id: \.id) { frame in
                let box = frame.tapRect
                let rect = geometry.viewRect(x: box.x, y: box.y, width: box.width, height: box.height)
                let isSelected = frame.id == selected?.id
                let isEmpty = placed[frame.id] == nil
                if isSelected || isEmpty {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(
                            isSelected ? Theme.accent : Theme.accent.opacity(0.45),
                            style: StrokeStyle(lineWidth: isSelected ? 2 : 1, dash: isEmpty ? [3, 3] : [])
                        )
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: The slots

    private var slotRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(slots) { slot in
                        SlotChip(
                            slot: slot,
                            item: placed[slot.id].flatMap { HomeDecor.item($0) },
                            isSelected: slot.id == selected?.id
                        ) { select(slot.id) }
                    }
                }
                .padding(.horizontal, 1)
            }
            if let slot = selected {
                HStack(spacing: Theme.Spacing.sm) {
                    Text(slot.name)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Spacer(minLength: Theme.Spacing.sm)
                    if let itemID = placed[slot.id], let item = HomeDecor.item(itemID) {
                        Button("Put \(item.name.lowercased()) away") { remove(slot.id) }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                    }
                }
                Text(slotHint(slot))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func slotHint(_ slot: DecorSlot) -> String {
        if let itemID = placed[slot.id], let item = HomeDecor.item(itemID) {
            return item.note
        }
        let fitting = shelf.filter { $0.kind == slot.kind && placed.values.contains($0.id) == false }
        if fitting.isEmpty {
            return "Nothing you own \(slot.kind.placementPhrase). Yet."
        }
        return "\(slot.kind.emptyName). \(fitting.count) thing\(fitting.count == 1 ? "" : "s") would go here."
    }

    // MARK: The shelf

    private var shelfSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Your things")
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .textCase(.uppercase)
                .kerning(0.6)
                .foregroundStyle(.secondary)

            if shelf.isEmpty {
                Text("Nothing yet. The shop sells the first few; seasons, endings and awards hand over the rest.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(shelf) { item in
                    ShelfRow(
                        item: item,
                        standingIn: placed.first { $0.value == item.id }.map(\.key).flatMap { HomeDecor.slot($0) },
                        destination: target(for: item),
                        place: { place(item) }
                    )
                }
            }

            Text("Move house and the boxes come with you — the walls do not. You put it all back where you want it.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: Actions

    private func select(_ id: String) {
        selectedSlot = id
        Haptics.tap()
    }

    private func place(_ item: DecorItem) {
        guard let slot = target(for: item) else { return }
        engine.send(.placeDecor(slot: slot.id, itemID: item.id))
        selectedSlot = slot.id
        Haptics.commit()
    }

    private func remove(_ slotID: String) {
        engine.send(.removeDecor(slot: slotID))
        Haptics.tap()
    }

    /// Where a thing would go if you tapped it: the slot being worked on
    /// when it fits, otherwise the first empty one that does.
    private func target(for item: DecorItem) -> DecorSlot? {
        if let selected, selected.kind == item.kind { return selected }
        let taken = Set(placed.keys)
        return slots.first { $0.kind == item.kind && !taken.contains($0.id) }
            ?? slots.first { $0.kind == item.kind }
    }

    /// Where the sheet opens: the first empty slot, or the first slot.
    private func firstInteresting() -> DecorSlot? {
        slots.first { placed[$0.id] == nil } ?? slots.first
    }

    private var founderSeed: UInt64 {
        engine.state.employees.first(where: \.isFounder)?.appearanceSeed ?? 7
    }

    private var mood: MoodLevel {
        let mood = life.meters.mood
        if mood >= 70 { return .great }
        if mood <= 35 { return .low }
        return .okay
    }
}

// MARK: - Rows

/// One slot as a chip: what is in it, or that it is empty.
private struct SlotChip: View {
    let slot: DecorSlot
    let item: DecorItem?
    let isSelected: Bool
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            VStack(spacing: 2) {
                Image(systemName: symbol)
                    .font(.caption)
                Text(item?.name ?? slot.kind.emptyName)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .frame(minWidth: 76)
            .background(
                isSelected ? Theme.accent.opacity(0.18) : Theme.chipBackground,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent : .clear, lineWidth: 1.5)
            }
            .foregroundStyle(item == nil ? Color.secondary : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(slot.name), \(item?.name ?? "empty")")
    }

    private var symbol: String {
        switch slot.kind {
        case .wall: "photo"
        case .shelf: "books.vertical"
        case .floor: "square.grid.2x2"
        // MARK: Iteration 11 — N3 (assets, vices and the doctor)
        // Two slots nothing in the shop fits: only a car bought on the
        // Assets screen goes on the drive, and only an animal takes the
        // corner. Both read as empty here until one is bought, which is
        // what an empty driveway looks like.
        case .driveway: "car"
        case .basket: "pawprint"
        // MARK: end of Iteration 11 — N3
        }
    }
}

/// One thing the founder owns: its sprite, where it came from, and the
/// button that stands it somewhere — with the consequence on the button.
private struct ShelfRow: View {
    let item: DecorItem
    let standingIn: DecorSlot?
    /// Where tapping the button would put it, worked out by the sheet.
    let destination: DecorSlot?
    let place: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            DecorSwatch(itemID: item.id)
                .frame(width: 44, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text(DecorPresentation.caption(for: item))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let standingIn {
                    Text("On show: \(standingIn.name.lowercased())")
                        .font(.caption2)
                        .foregroundStyle(Theme.positiveCash)
                }
            }
            Spacer(minLength: Theme.Spacing.sm)
            Button(buttonTitle, action: place)
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(Theme.accent)
                .disabled(!canPlace)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(canPlace ? "Places it in \(destination?.name ?? "the room")" : "Already where it goes")
    }

    private var canPlace: Bool {
        destination != nil && standingIn?.id != destination?.id
    }

    private var buttonTitle: String {
        guard let destination else { return "Nowhere yet" }
        if standingIn?.id == destination.id { return "In place" }
        return "→ \(destination.name.lowercased())"
    }
}

/// A decor sprite at an integer scale, crisp, centred. Internal since
/// iteration 13 (P3): the loft pack section draws its six with it.
struct DecorSwatch: View {
    let itemID: String

    var body: some View {
        if let name = DecorPresentation.sprite(for: itemID) {
            let sprite = SpriteLibrary.homeDecor(name)
            let scale = max(1, min(3, Int(40 / max(1, sprite.height))))
            Image(decorative: sprite.cgImage(frame: 0), scale: 1)
                .interpolation(.none)
                .resizable()
                .frame(
                    width: CGFloat(sprite.width * scale),
                    height: CGFloat(sprite.height * scale)
                )
                .accessibilityHidden(true)
        }
    }
}
