import SwiftUI
import TycoonContent
import TycoonEngine

// MARK: Iteration 11 — N4 (fame and the feed)

/// The founder's feed, drawn as a handset in the phone's grammar — the
/// pixel frame, the bitmap status line, the rows underneath — because it
/// is the same object in the founder's hand and because the thing this
/// screen exists to produce is a screenshot.
///
/// Three things can be waiting above the posts, in this order: an old post
/// that has surfaced, a rival who answered back, and the compose bar. Then
/// the feed itself, newest first, every post carrying the number it
/// reached and whatever the world said under it.
struct FeedScreen: View {
    let engine: GameEngine

    @State private var composing = false
    /// Whether `-autoCompose` has already opened the sheet, once.
    @State private var tookCompose = false

    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI updates
    /// this property for presented content before the environment is
    /// installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }

    var body: some View {
        ScrollView {
            FeedScreenContent(
                state: engine.state,
                balance: engine.balance,
                content: engine.content,
                onCompose: { composing = true },
                onAnswerBeef: { engine.send(.answerFeedBeef(escalate: $0)) },
                onAnswerCancellation: { engine.send(.answerFameCancellation(response: $0)) }
            )
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.screenBackground)
        .navigationTitle("The feed")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $composing) {
            FeedComposeSheet(engine: engine)
        }
        .task { await FeedDebug.runIfAsked(engine: engine) }
        // `-autoCompose`: a headless pass cannot tap *Say something*.
        .onChange(of: engine.state.day, initial: true) { _, _ in
            guard DebugLaunch.opensFeedCompose, !tookCompose else { return }
            tookCompose = true
            composing = true
        }
    }
}

/// The screen without its scroll view or engine, so a renderer can draw it.
struct FeedScreenContent: View {
    let state: GameState
    let balance: BalanceConfig
    /// `nil` in a renderer that has no catalog.
    var content: ContentCatalog?
    var onCompose: (() -> Void)?
    var onAnswerBeef: ((Bool) -> Void)?
    var onAnswerCancellation: ((FameCancelResponse) -> Void)?

    private var posts: [FeedPost] { state.fame.byRecency }

    var body: some View {
        let level = Fame.level(state.fame.fame, balance: balance.fame)

        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            PhoneHandset(
                title: String(localized: "The feed", comment: "Bitmap title over the founder's public feed. Uppercase A-Z only: the pixel face has no lowercase and no accents"),
                subtitle: "\(FeedFormat.count(state.fame.followers)) following you"
            ) {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    FeedStandingStrip(state: state, balance: balance, level: level)

                    if let cancellation = state.fame.cancellation, cancellation.response == nil {
                        FeedCancellationCard(
                            cancellation: cancellation,
                            followers: state.fame.followers,
                            balance: balance.fame,
                            onAnswer: onAnswerCancellation
                        )
                    }
                    if let beef = state.fame.beef, beef.waitingOnYou {
                        FeedBeefCard(
                            beef: beef, balance: balance.fame, onAnswer: onAnswerBeef
                        )
                    }

                    Button {
                        Haptics.tap()
                        onCompose?()
                    } label: {
                        Label(composeLabel, systemImage: "square.and.pencil")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.pressable)
                    .tint(Theme.accent)
                    .disabled(canPostToday == false)

                    if posts.isEmpty {
                        Text("Nothing here yet. Whatever you say first is the thing "
                            + "people will quote at you for years.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.pixelInk.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, Theme.Spacing.md)
                    } else {
                        VStack(spacing: Theme.Spacing.sm) {
                            ForEach(posts.prefix(20)) { post in
                                FeedPostRow(
                                    post: post,
                                    day: state.day,
                                    seed: state.employees.first(where: \.isFounder)?.appearanceSeed ?? 7,
                                    handle: FeedFormat.handle(state.company.name)
                                )
                            }
                        }
                    }
                }
            }

            if !state.fame.perks.isEmpty {
                FeedPerksCard(perks: state.fame.perks)
            }

            Text("Reach is what the post travelled. Followers are what stayed. "
                + "Fame is the slow average of both, and it leaks.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var canPostToday: Bool {
        guard let last = state.fame.lastPostDay else { return true }
        return last < state.day
    }

    private var composeLabel: String {
        canPostToday
            ? "Say something"
            : "You have already posted today"
    }
}

// MARK: - The standing strip

/// Followers, fame, and the week's reach, across the top of the handset.
struct FeedStandingStrip: View {
    let state: GameState
    let balance: BalanceConfig
    let level: FameLevel

    var body: some View {
        let reach = state.fame.recentReach(
            day: state.day, window: balance.fame.recentReachWindow
        )
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                StatPill(
                    systemImage: "person.2.fill",
                    value: FeedFormat.count(state.fame.followers),
                    tint: Theme.accent
                )
                StatPill(
                    systemImage: "chart.line.uptrend.xyaxis",
                    value: FeedFormat.count(reach),
                    tint: .primary
                )
                Spacer(minLength: 0)
                Text(level.displayName.uppercased())
                    .font(.system(size: 10, design: .rounded).weight(.heavy))
                    .kerning(0.6)
                    .foregroundStyle(Theme.ink(on: Theme.accent))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Theme.accent, in: Capsule())
            }
            FameMeter(fame: state.fame.fame, balance: balance.fame)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(state.fame.followers) followers, \(reach) reach this fortnight, \(level.displayName)"
        )
    }
}

// MARK: - One post

/// A post: the founder's face and handle, the line, the number it reached,
/// and whatever came back under it.
struct FeedPostRow: View {
    let post: FeedPost
    let day: Int
    let seed: UInt64
    let handle: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                PixelPortrait(seed: seed, size: 28)
                Text(handle)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                if post.viral {
                    Label("VIRAL", systemImage: "flame.fill")
                        .font(.system(size: 9, design: .rounded).weight(.heavy))
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(Theme.ink(on: Theme.warning))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Theme.warning, in: Capsule())
                }
                Spacer(minLength: 0)
                Text(agoLabel)
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
            Text(post.text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Theme.Spacing.md) {
                FeedStat(systemImage: "eye.fill", value: FeedFormat.count(post.reach))
                if post.followerGain != 0 {
                    FeedStat(
                        systemImage: post.followerGain > 0 ? "person.badge.plus" : "person.badge.minus",
                        value: (post.followerGain > 0 ? "+" : "−")
                            + FeedFormat.count(abs(post.followerGain)),
                        tint: post.followerGain > 0 ? Theme.positiveCash : Theme.negativeCash
                    )
                }
                if !post.subject.isEmpty {
                    FeedStat(systemImage: "at", value: post.subject)
                }
            }

            if !post.replies.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(post.replies) { reply in
                        HStack(alignment: .top, spacing: 6) {
                            Text(reply.handle)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Theme.accent)
                            Text(reply.text)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.leading, Theme.Spacing.sm)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.pixelInk.opacity(0.25))
                        .frame(width: 1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.chipBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(post.text). Reached \(post.reach).")
    }

    private var agoLabel: String {
        let days = day - post.day
        return switch days {
        case ..<1: "Today"
        case 1: "1d"
        default: "\(days)d"
        }
    }
}

/// One small figure under a post.
struct FeedStat: View {
    let systemImage: String
    let value: String
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .semibold))
            Text(value)
                .font(Theme.Typography.number(.caption2))
        }
        .foregroundStyle(tint)
    }
}

// MARK: - The beef

/// A rival answered. Escalate, or let it go — and the buttons say what
/// each one costs before they are pressed.
struct FeedBeefCard: View {
    let beef: FameBeef
    let balance: BalanceConfig.FameBalance
    var onAnswer: ((Bool) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "flame.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.warning)
                Text(beef.rivalName)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                Spacer(minLength: 0)
                Text("ROUND \(beef.rounds)")
                    .font(.system(size: 9, design: .rounded).weight(.heavy))
                    .foregroundStyle(.secondary)
            }
            Text(beef.theirLine)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Theme.Spacing.sm) {
                Button {
                    Haptics.tap()
                    onAnswer?(true)
                } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Escalate")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        Text("+\(balance.beefFollowersPerRound * beef.rounds) followers · "
                            + "reputation −\(Int((balance.beefReputationPerRound * Double(beef.rounds)).rounded())) · mood −\(Int(balance.beefMoodPerRound))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.pressableRow)

                Button {
                    Haptics.tap()
                    onAnswer?(false)
                } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Let it go")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        Text("Costs the last word")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.pressableRow)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(
            Theme.warning.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}

// MARK: - The cancellation

/// An old post surfaced. Three answers, each with its price on it.
struct FeedCancellationCard: View {
    let cancellation: FameCancellation
    let followers: Int
    let balance: BalanceConfig.FameBalance
    var onAnswer: ((FameCancelResponse) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "exclamationmark.bubble.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.negativeCash)
                Text("Somebody went through the archive")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
            }
            Text("“\(cancellation.quote)”")
                .font(.subheadline.italic())
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: Theme.Spacing.xs) {
                ForEach(FameCancelResponse.allCases, id: \.self) { response in
                    Button {
                        Haptics.tap()
                        onAnswer?(response)
                    } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(response.displayName)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            Text(price(response))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.pressableRow)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(
            Theme.negativeCash.opacity(0.1),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    /// Rule 7: the button says what it costs before it is pressed.
    private func price(_ response: FameCancelResponse) -> String {
        let cost = balance.cancelCost(response)
        let lost = Int((Double(followers) * cost.followerLoss).rounded())
        return "−\(FeedFormat.count(lost)) followers · fame \(FeedFormat.signed(-cost.fame)) · "
            + "reputation \(FeedFormat.signed(cost.reputation)) "
            + "· mood \(FeedFormat.signed(cost.mood))"
    }
}

// MARK: - What fame bought

/// The things fame has brought so far, one line each.
struct FeedPerksCard: View {
    let perks: [String]

    var body: some View {
        CardView("What this bought", systemImage: "gift.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                ForEach(perks, id: \.self) { perk in
                    HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.accent)
                        Text(Fame.perkLine(perk))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

// MARK: - Formatting

/// The feed's own numbers: "12.4k", not "12,431". A follower count is
/// read, not counted.
enum FeedFormat {
    static func count(_ value: Int) -> String {
        let magnitude = abs(value)
        if magnitude >= 1_000_000 {
            return trimmed(Double(value) / 1_000_000) + "m"
        }
        if magnitude >= 1_000 {
            return trimmed(Double(value) / 1_000) + "k"
        }
        return "\(value)"
    }

    private static func trimmed(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded()
            ? "\(Int(rounded))"
            : String(format: "%.1f", rounded)
    }

    /// "−6", "+2", "0" — with the typographic minus the rest of the game
    /// writes its deltas in, never the hyphen.
    static func signed(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        if rounded > 0 { return "+\(rounded)" }
        if rounded < 0 { return "−\(abs(rounded))" }
        return "0"
    }

    /// "@driftworks" from "Drift Works".
    static func handle(_ companyName: String) -> String {
        let stripped = companyName.lowercased().filter { $0.isLetter || $0.isNumber }
        return "@" + (stripped.isEmpty ? "founder" : String(stripped.prefix(16)))
    }
}
