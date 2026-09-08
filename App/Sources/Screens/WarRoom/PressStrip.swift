import SwiftUI
import TycoonContent
import TycoonEngine

/// The press in the last week before a launch: a strip of one-line
/// mentions, half about the build and half about the industry around it,
/// each with an outlet's byline.
///
/// Nothing here is drawn. The lines are a pure function of the day and
/// the product — `News.json`'s templates and the review outlets, picked
/// and filled by a stable hash of `(day, product id, slot)` — so the same
/// day shows the same lines however often the view rebuilds, and the
/// engine's RNG streams are never touched. The mentions about the build
/// itself are the room's own, chosen by how much hype it is carrying:
/// a launch nobody has heard of reads differently from one the front
/// pages are counting down to.
enum PressStrip {
    /// One line of the strip.
    struct Line: Equatable, Identifiable {
        let id: Int
        let outlet: String
        let text: String
    }

    /// Where the build is, as far as the press is concerned.
    enum Phase: Equatable {
        case countdown(days: Int?)
        case launchDay
        case onMarket(weeks: Int)
    }

    /// The strip for `product` today: `count` lines, alternating a mention
    /// of the build with an industry headline.
    static func lines(
        for product: Product,
        state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog,
        count: Int = 6
    ) -> [Line] {
        let outlets = balance.reviewOutlets.isEmpty ? ["The Trade"] : balance.reviewOutlets
        let phase = phase(of: product, state: state, balance: balance, content: content)
        let hype = hype(of: product)
        let topicName = (content.topic(product.topicID)?.name ?? product.topicID).lowercased()

        return (0..<count).map { slot in
            var hash = StableHash(day: state.day, product: product.id, slot: slot)
            let outlet = outlets[hash.pick(outlets.count)]
            let text: String
            if slot.isMultiple(of: 2) {
                let pool = mentionTemplates(phase: phase, hype: hype)
                text = fill(
                    pool[hash.pick(pool.count)],
                    product: product, outlet: outlet, topicName: topicName,
                    phase: phase, state: state, content: content, hash: &hash
                )
            } else {
                text = headline(state: state, content: content, hash: &hash)
            }
            return Line(id: slot, outlet: outlet, text: text)
        }
    }

    // MARK: - The build

    static func phase(
        of product: Product,
        state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> Phase {
        switch product.stage {
        case .development:
            return .countdown(
                days: state.buildETA(productID: product.id, balance: balance, content: content)?.daysToComplete
            )
        case .released(let info):
            if info.launchDay == state.day { return .launchDay }
            return .onMarket(weeks: max(1, (state.day - info.launchDay) / GameState.daysPerWeek + 1))
        }
    }

    private static func hype(of product: Product) -> Double {
        switch product.stage {
        case .development(let dev): dev.hype
        case .released(let info): info.hypeAtLaunch
        }
    }

    /// What an outlet says about the build, by phase and by how loud the
    /// launch already is.
    static func mentionTemplates(phase: Phase, hype: Double) -> [String] {
        switch phase {
        case .countdown:
            switch hype {
            case ..<15:
                return [
                    "{outlet} has not heard of {name}. Nobody has told them.",
                    "No review copy of {name} has gone out. {outlet} has not asked for one.",
                    "{outlet}'s {topic} desk is quiet this week.",
                    "{outlet} runs a {topic} round-up. {name} is not in it.",
                ]
            case ..<45:
                return [
                    "{outlet} asks for a review copy of {name}.",
                    "{outlet} lists {name} among {number} {topic} apps to watch.",
                    "{outlet} hears {name} ships within the week.",
                    "A {outlet} reporter follows the {name} account. It has {number} posts.",
                ]
            default:
                return [
                    "{outlet} has {name} on its front page. It has not shipped yet.",
                    "{outlet} calls {name} the {topic} launch to watch.",
                    "{outlet} is running a countdown to {name}. So is everyone else.",
                    "{outlet}'s inbox is {number} percent questions about {name}.",
                ]
            }
        case .launchDay:
            return [
                "{outlet} has {name} in review. The verdict lands today.",
                "{outlet}: {name} is out. Filing now.",
                "{outlet}'s {topic} desk clears its afternoon for {name}.",
                "{outlet} refreshes the store page for {name} every {number} minutes.",
            ]
        case .onMarket:
            return [
                "{outlet} readers are arguing about {name} in the comments.",
                "{outlet} runs a follow-up on {name}: {number} percent of readers have tried it.",
                "{name} is in week {weeks} on {outlet}'s {topic} chart.",
                "{outlet} asks what {name} does next. Nobody at {outlet} knows.",
            ]
        }
    }

    private static func fill(
        _ template: String,
        product: Product,
        outlet: String,
        topicName: String,
        phase: Phase,
        state: GameState,
        content: ContentCatalog,
        hash: inout StableHash
    ) -> String {
        var text = template
            .replacingOccurrences(of: "{outlet}", with: outlet)
            .replacingOccurrences(of: "{name}", with: product.name)
            .replacingOccurrences(of: "{topic}", with: topicName)
        if case .onMarket(let weeks) = phase {
            text = text.replacingOccurrences(of: "{weeks}", with: String(weeks))
        }
        if text.contains("{number}") {
            text = text.replacingOccurrences(of: "{number}", with: String(2 + hash.pick(90)))
        }
        return text
    }

    // MARK: - The industry

    /// One of `News.json`'s headlines, filled the way the narrative system
    /// fills them — a rival by name, a product a rival has shipped, a
    /// topic, a verdict, a number — but from the hash rather than the
    /// world's RNG. Rival templates are skipped while there are no rivals,
    /// as they are on the wire.
    static func headline(
        state: GameState,
        content: ContentCatalog,
        hash: inout StableHash
    ) -> String {
        let rivals = state.rivals.rivals.sorted { $0.id.uuidString < $1.id.uuidString }
        let usable = content.news.filter { $0.needsRival ? !rivals.isEmpty : true }
        guard !usable.isEmpty else {
            return "The trade press is between stories."
        }
        var text = usable[hash.pick(usable.count)].template
        if text.contains("{rival}") {
            let name = rivals.isEmpty ? "A stealth-mode studio" : rivals[hash.pick(rivals.count)].name
            text = text.replacingOccurrences(of: "{rival}", with: name)
        }
        if text.contains("{product}") {
            let shipped = rivals.flatMap(\.products)
            let words = content.names.productWords
            let product: String
            if !shipped.isEmpty {
                product = shipped[hash.pick(shipped.count)].name
            } else if words.count >= 2 {
                product = "\(words[hash.pick(words.count)]) \(words[hash.pick(words.count)])"
            } else {
                product = "an unnamed app"
            }
            text = text.replacingOccurrences(of: "{product}", with: product)
        }
        if text.contains("{topic}") {
            let topics = content.topics
            let name = topics.isEmpty ? "software" : topics[hash.pick(topics.count)].name.lowercased()
            text = text.replacingOccurrences(of: "{topic}", with: name)
        }
        if text.contains("{adjective}") {
            text = text.replacingOccurrences(of: "{adjective}", with: adjectives[hash.pick(adjectives.count)])
        }
        if text.contains("{number}") {
            text = text.replacingOccurrences(of: "{number}", with: String(2 + hash.pick(90)))
        }
        return text
    }

    /// A critic's verdicts, for `{adjective}`.
    private static let adjectives = [
        "derivative", "inevitable", "overdue", "competent", "unfinished",
        "quietly brilliant", "expensive", "confusing", "the year's best",
        "a rounding error", "hard to argue with", "a nice idea, badly timed",
    ]
}

/// A small, seeded mixer (SplitMix64) for picking from lists without the
/// simulation's RNG. `Hasher` is seeded per process and cannot serve here:
/// the whole point is that the same day picks the same lines tomorrow.
struct StableHash {
    private var state: UInt64

    init(day: Int, product: UUID, slot: Int) {
        let bytes = product.uuid
        let hi = UInt64(bytes.0) << 56 | UInt64(bytes.1) << 48 | UInt64(bytes.2) << 40 | UInt64(bytes.3) << 32
            | UInt64(bytes.4) << 24 | UInt64(bytes.5) << 16 | UInt64(bytes.6) << 8 | UInt64(bytes.7)
        let lo = UInt64(bytes.8) << 56 | UInt64(bytes.9) << 48 | UInt64(bytes.10) << 40 | UInt64(bytes.11) << 32
            | UInt64(bytes.12) << 24 | UInt64(bytes.13) << 16 | UInt64(bytes.14) << 8 | UInt64(bytes.15)
        state = hi ^ (lo &* 0x9E37_79B9_7F4A_7C15)
            ^ (UInt64(truncatingIfNeeded: day) &* 0xBF58_476D_1CE4_E5B9)
            ^ (UInt64(truncatingIfNeeded: slot) &* 0x94D0_49BB_1331_11EB)
    }

    /// The next word.
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// An index in `0..<count` (0 for an empty list, so callers can guard).
    mutating func pick(_ count: Int) -> Int {
        guard count > 0 else { return 0 }
        return Int(next() % UInt64(count))
    }
}

// MARK: - The view

/// The strip on screen: one line at a time, the outlet in the bitmap face
/// above the mention, rolling to the next every few seconds. Reduce Motion
/// swaps the lines instead of sliding them.
struct PressStripView: View {
    let lines: [PressStrip.Line]
    // MARK: Iteration 10 — M2 (pitch room)
    /// The engine, when the caller has one: the strip then offers the
    /// interview under it. Defaulted, so every existing call site (and
    /// every snapshot) draws exactly the strip it drew before.
    var engine: GameEngine?
    // MARK: end of Iteration 10 — M2

    /// Which line is up. Advanced by the task below; a snapshot renders
    /// the first.
    @State private var index = 0

    /// Seconds each line stays up.
    static let dwell: Duration = .seconds(4)

    private var current: PressStrip.Line? {
        guard !lines.isEmpty else { return nil }
        return lines[index % lines.count]
    }

    var body: some View {
        // MARK: Iteration 10 — M2 (pitch room)
        // Reading about yourself is passive; twenty minutes with one of
        // these outlets is not. The invitation sits under the panel
        // rather than inside it, because the panel's own accessibility
        // element ignores its children.
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            strip
            if let engine {
                PitchInviteButton(engine: engine, counterpart: .journalist)
            }
        }
    }

    private var strip: some View {
        // MARK: end of Iteration 10 — M2
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    PixelSectionTitle(title: "The press")
                    Spacer(minLength: Theme.Spacing.sm)
                    dots
                }
                ZStack(alignment: .topLeading) {
                    if let current {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            PixelText(text: current.outlet, scale: 2, color: Theme.pixelAccent)
                            Text(current.text)
                                .font(.subheadline)
                                .italic()
                                .foregroundStyle(Theme.pixelInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id(current.id)
                        .transition(
                            Theme.Motion.transition(
                                .asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .move(edge: .top).combined(with: .opacity)
                                )
                            )
                        )
                    } else {
                        Text("The trade press is between stories.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.pixelInk.opacity(0.7))
                    }
                }
                .clipped()
                .animation(Theme.Motion.entrance, value: index)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(current.map { "The press. \($0.outlet): \($0.text)" } ?? "The press is between stories")
        .task(id: lines.count) {
            guard lines.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.dwell)
                guard !Task.isCancelled else { return }
                index += 1
            }
        }
    }

    /// One pip per line, the current one lit.
    private var dots: some View {
        HStack(spacing: 3) {
            ForEach(lines) { line in
                Rectangle()
                    .fill(line.id == current?.id ? Theme.pixelAccent : Theme.pixelInk.opacity(0.25))
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}
