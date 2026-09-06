import SwiftUI

/// The founder's evening at home: a tier-specific room, the household, and
/// the founder doing tonight's activity with a mood bubble overhead.
///
/// Same renderer as `OfficeSceneView`: integer pixel scaling (floored) to
/// fit the width, nearest-neighbor drawing, cosmetic ~4 fps timeline.
public struct HomeSceneView: View {
    private let placements: [PlacedSprite]
    private let regions: [HomeHitRegion]
    private let occupants: HomeOccupants
    private let tier: HomeTierStyle
    private let activity: HomeActivity
    private let mood: MoodLevel
    private let sceneSize: (width: Int, height: Int)
    private let onTapRegion: ((HomeHitRegion.Kind) -> Void)?
    private let accessibilityHint: ((HomeHitRegion.Kind) -> String?)?
    // MARK: Iteration 9 — L7 (furnish)
    /// What a slot is called out loud — the app knows the names, PixelKit
    /// only knows the ids.
    private let decorLabel: ((String) -> String)?
    private let scale: PixelSceneView.Scale
    // MARK: end of Iteration 9 — L7

    public init(
        tier: HomeTierStyle,
        occupants: HomeOccupants,
        activity: HomeActivity,
        mood: MoodLevel,
        ambience: HomeAmbience = .evening,
        signals: HomeSignals = .none,
        // MARK: Iteration 9 — L7 (furnish)
        decor: [String: SpriteLibrary.HomeDecorName] = [:],
        emptyDecorSlots: Bool = false,
        decorLabel: ((String) -> String)? = nil,
        /// How the room maps into the view: the card's fit-to-width by
        /// default, a fixed pixel scale for the furnish sheet, which puts
        /// the big tiers in a horizontal scroller rather than shrinking
        /// them to a thumbnail.
        scale: PixelSceneView.Scale = .fitWidth,
        // MARK: end of Iteration 9 — L7
        onTapRegion: ((HomeHitRegion.Kind) -> Void)? = nil,
        accessibilityHint: ((HomeHitRegion.Kind) -> String?)? = nil
    ) {
        self.placements = HomeSceneComposer.compose(
            tier: tier, occupants: occupants, activity: activity, mood: mood,
            ambience: ambience, signals: signals, decor: decor
        )
        self.regions = HomeSceneComposer.hitRegions(
            tier: tier, occupants: occupants, activity: activity, mood: mood,
            ambience: ambience, signals: signals,
            decor: decor, emptyDecorSlots: emptyDecorSlots
        )
        self.decorLabel = decorLabel
        self.scale = scale
        self.occupants = occupants
        self.tier = tier
        self.activity = activity
        self.mood = mood
        self.sceneSize = HomeSceneComposer.sceneSize(for: tier)
        self.onTapRegion = onTapRegion
        self.accessibilityHint = accessibilityHint
    }

    public var body: some View {
        PixelSceneView(
            placements: placements,
            sceneSize: sceneSize,
            scale: scale,
            accessibilityLabel: sceneSummary
        )
        // To VoiceOver the canvas is one picture. The regions laid over it
        // are the things *in* the picture, so the picture steps aside and
        // the container carries the summary.
        .accessibilityHidden(true)
        // Iteration 9 — L7: a real finger layer, under the accessibility
        // one, and only when the caller asked for taps.
        .overlay { if onTapRegion != nil { tapRegions } }
        .overlay { accessibilityRegions }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(sceneSummary)
    }

    // MARK: Iteration 9 — L7 (furnish)

    /// One button per region, laid over the scene where the region is, so
    /// a finger can land on a slot. Same geometry as the accessibility
    /// overlay, and the same still picture underneath it.
    private var tapRegions: some View {
        GeometryReader { proxy in
            let geometry = PixelSceneGeometry(sceneSize: sceneSize, viewSize: proxy.size, mode: scale)
            ForEach(regions) { region in
                let rect = geometry.viewRect(
                    x: region.x, y: region.y, width: region.width, height: region.height
                )
                Button { onTapRegion?(region.kind) } label: {
                    Color.clear.contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: end of Iteration 9 — L7

    /// One accessibility element per region, laid over the scene where the
    /// region is. Deliberately *not* inside a `TimelineView`: the home is
    /// a still picture with a few looping sprites, its regions are a pure
    /// function of the inputs, and an overlay that rebuilt itself every
    /// second would move VoiceOver's focus out from under the reader. The
    /// office needs a timeline because its people walk; the home does not.
    private var accessibilityRegions: some View {
        GeometryReader { proxy in
            let geometry = PixelSceneGeometry(sceneSize: sceneSize, viewSize: proxy.size, mode: scale)
            ForEach(regions) { region in
                let rect = geometry.viewRect(
                    x: region.x, y: region.y, width: region.width, height: region.height
                )
                Color.clear
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(spokenLabel(for: region.kind))
                    .accessibilityHint(accessibilityHint?(region.kind) ?? "")
                    .accessibilitySortPriority(region.sortPriority)
                    .accessibilityAddTraits(onTapRegion == nil ? [] : .isButton)
                    .accessibilityAction { onTapRegion?(region.kind) }
            }
        }
        .allowsHitTesting(false)
    }

    /// The whole scene in one line, for the container and for a caller
    /// that would rather have the picture than its contents.
    public nonisolated var sceneSummary: String {
        var parts = ["Home scene: the \(tier.accessibilityName)"]
        if let phrase = activity.accessibilityPhrase {
            parts.append("\(occupants.founderName ?? "you"), \(phrase)")
        } else {
            parts.append("\(occupants.founderName ?? "you") away")
        }
        if occupants.partner != nil {
            parts.append(occupants.partnerName.map { "\($0) is in" } ?? "your partner is in")
        }
        switch occupants.childList.count {
        case 0: break
        case 1: parts.append("one child")
        default: parts.append("\(occupants.childList.count) children")
        }
        return parts.joined(separator: ", ")
    }

    /// What VoiceOver says about one thing in the room. Informational —
    /// these are static text unless the app passed an action, in which
    /// case they become buttons.
    public nonisolated func spokenLabel(for kind: HomeHitRegion.Kind) -> String {
        switch kind {
        case .founder:
            var parts = [occupants.founderName ?? "You"]
            if let phrase = activity.accessibilityPhrase { parts.append(phrase) }
            if let phrase = mood.accessibilityPhrase { parts.append(phrase) }
            return parts.joined(separator: ", ")
        case .partner:
            var parts = [occupants.partnerName ?? "Your partner"]
            if occupants.partnerName != nil { parts.append("your partner") }
            if let note = occupants.partnerNote { parts.append(note) }
            return parts.joined(separator: ", ")
        case .child(let id):
            let child = occupants.childList.first { $0.id == id }
            guard let name = child?.name else { return "Your child" }
            return "\(name), your child"
        case .furniture(let fixture):
            return fixture.accessibilityName
        // Iteration 9 — L7: the app names the slot and what is in it.
        case .decorSlot(let id):
            return decorLabel?(id) ?? "A place for something"
        }
    }
}

#Preview("Studio — sleeping") {
    HomeSceneView(
        tier: .studioFlat,
        occupants: HomeOccupants(founder: CharacterAppearance(seed: 7)),
        activity: .sleeping, mood: .okay
    )
    .padding()
}

#Preview("House — gaming with family") {
    HomeSceneView(
        tier: .house,
        occupants: HomeOccupants(
            founder: CharacterAppearance(seed: 7),
            partner: CharacterAppearance(seed: 21),
            children: [CharacterAppearance(seed: 31), CharacterAppearance(seed: 32)]
        ),
        activity: .gaming, mood: .great
    )
    .padding()
}
