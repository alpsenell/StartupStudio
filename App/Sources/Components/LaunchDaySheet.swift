import SwiftUI
import TycoonEngine

/// Launch day: the moment a product stops being a progress bar and becomes
/// a thing in the world.
///
/// Shown when a product ships, and again when its reviews land — at which
/// point the outlets reveal one at a time, each blurb typing itself out
/// under a score that counts up, before the average stamps down.
///
/// The reveal itself (`ReviewRevealList`, `LaunchScoreStamp`,
/// `ReviewCardView`) is shared with the war room, which plays the same
/// moment inside the office when the build ships while the room is open.
struct LaunchDaySheet: View {
    let engine: GameEngine
    let product: Product

    @Environment(\.dismiss) private var dismiss
    /// Optional, not because a sheet might be drawn without a router —
    /// it always has one — but because SwiftUI updates a presented sheet's
    /// content *while the host is being torn down*, and a non-optional
    /// `@Environment(AppRouter.self)` read traps there (the crash
    /// `StorefrontAutoRoute` documents). `OfficeCard` reads it the same
    /// way for the same reason. A nil router means the tap has nowhere to
    /// go, which on a sheet that is closing is exactly right.
    @Environment(AppRouter.self) private var router: AppRouter?

    /// How many reviews have been revealed so far.
    @State private var revealed = 0
    // MARK: J1 (doors)
    /// Life B5: *Tell people* opens the feed's compose sheet over this one.
    @State private var tellingPeople = false
    // MARK: end J1

    private var release: ReleaseInfo? {
        if case .released(let info) = product.stage { return info }
        return nil
    }

    private var typeName: String {
        engine.content.productType(product.typeID)?.name ?? product.typeID.capitalized
    }

    private var topicName: String {
        engine.content.topic(product.topicID)?.name ?? product.topicID.capitalized
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    hero
                    // MARK: J1 (doors)
                    // The feed, from the moment that wants it. Nothing is
                    // posted until a row in the compose sheet is tapped.
                    if release != nil {
                        DoorTellPeopleRow(engine: engine) { tellingPeople = true }
                    }
                    // MARK: end J1
                    if let release {
                        if release.reviews.isEmpty {
                            waitingForReviews(release)
                        } else {
                            ReviewRevealList(release: release, revealed: revealed, productID: nil) { route in
                                dismiss()
                                router?.go(route)
                            }
                        }
                        salesSection(release)
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("Launch day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { start() }
        // MARK: J1 (doors)
        .sheet(isPresented: $tellingPeople) {
            FeedComposeSheet(engine: engine, draft: .launch)
        }
        // MARK: end J1
    }

    // MARK: - Hero

    private var hero: some View {
        PixelPanel {
            VStack(spacing: Theme.Spacing.md) {
                ProductBoxArtView(
                    typeID: product.typeID,
                    topicID: product.topicID,
                    seed: product.boxArtSeed,
                    size: 120
                )
                .shadow(color: Theme.pixelShadow, radius: 0, x: 3, y: 3)

                PixelText(text: product.name, scale: 3, color: Theme.pixelInk, shadow: true)
                Text("\(typeName) · \(topicName)")
                    .font(.footnote)
                    .foregroundStyle(Theme.pixelInk.opacity(0.7))
                if let release {
                    Text("Shipped on \(GameCalendar(day: release.launchDay).longLabel)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Theme.pixelInk.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(product.name), a \(typeName) about \(topicName), shipped")
    }

    // MARK: - Reviews

    private func waitingForReviews(_ release: ReleaseInfo) -> some View {
        CardView("The press", systemImage: "newspaper.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Review copies are out. The verdicts land next week.")
                    .font(.subheadline)
                Text(
                    release.adoptionWeeks > 1.5
                        ? "Word of mouth will take about \(Int(release.adoptionWeeks.rounded())) weeks to reach full speed."
                        : "Launch hype is high — sales should peak almost immediately."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Sales

    private func salesSection(_ release: ReleaseInfo) -> some View {
        CardView("The market", systemImage: "chart.line.uptrend.xyaxis") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .top, spacing: Theme.Spacing.xl) {
                    if let firstWeek = release.weeklySales.first {
                        LaunchStat(label: String(localized: "First week", comment: "Launch day figure: revenue in the first week"), value: firstWeek.revenue.money, tint: Theme.positiveCash)
                        LaunchStat(label: String(localized: "Units", comment: "Launch day figure: copies sold"), value: firstWeek.units.formatted(.number.locale(Theme.gameLocale)))
                    } else {
                        LaunchStat(
                            label: String(localized: "Quality", comment: "Launch day figure: the build quality score out of 100"),
                            value: "\(Int(release.quality.rounded()))",
                            tint: Theme.scoreTint(Int(release.quality.rounded()))
                        )
                        LaunchStat(
                            label: String(localized: "Launch hype", comment: "Launch day figure: how much attention the launch had"),
                            value: "\(Int((release.hypeAtLaunch * 100).rounded()))%"
                        )
                    }
                    if release.isSubscription {
                        LaunchStat(label: String(localized: "Subscribers", comment: "Launch day figure: subscribers on a subscription product"), value: release.subscribers.formatted(.number.locale(Theme.gameLocale)))
                    }
                }
                if release.liveBugs > 0 {
                    Label(
                        "\(release.liveBugs) bug\(release.liveBugs == 1 ? "" : "s") already reported in the wild",
                        systemImage: "ladybug.fill"
                    )
                    .font(.footnote)
                    .foregroundStyle(Theme.warning)
                }
            }
        }
    }

    // MARK: - Reveal

    private func start() {
        guard let release, !release.reviews.isEmpty else {
            Sounds.play(.ship)
            Haptics.success()
            return
        }
        Sounds.play(.ship)
        Haptics.commit()
        Task {
            for index in release.reviews.indices {
                try? await Task.sleep(for: .milliseconds(ReviewReveal.delay(forOutlet: index)))
                withAnimation(Theme.Motion.emphatic) { revealed = index + 1 }
                Sounds.play(.tap)
                Haptics.tap()
            }
        }
    }
}

extension Product {
    /// The seed the box art is drawn from: the product's id folded into a
    /// word, so the same product always gets the same cover.
    var boxArtSeed: UInt64 {
        id.uuidString.utf8.reduce(UInt64(0)) { $0 &* 31 &+ UInt64($1) }
    }
}

/// The pacing of the reveal, shared by the sheet and the war room so the
/// outlets arrive at the same beat wherever the moment plays.
enum ReviewReveal {
    /// Milliseconds before outlet `index` lands: a short beat for the
    /// first, a longer one between the rest.
    static func delay(forOutlet index: Int) -> Int {
        index == 0 ? 400 : 900
    }
}

/// The outlets so far, then the average stamp and the reason row once the
/// last one has weighed in. `revealed` is owned by whoever is playing the
/// moment; the list only draws what it is told to.
struct ReviewRevealList: View {
    let release: ReleaseInfo
    let revealed: Int
    /// The product the "Live ops" fix routes to; `nil` when there is no
    /// route back (the launch sheet dismisses to the tab instead).
    var productID: UUID?
    /// Whether each blurb types itself out. Off for a static frame.
    var typesOut = true
    let onRoute: (Route) -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            ForEach(Array(release.reviews.enumerated()), id: \.offset) { index, review in
                if index < revealed {
                    ReviewCardView(review: review, typesOut: typesOut)
                        .transition(Theme.Motion.transition(.move(edge: .bottom).combined(with: .opacity)))
                }
            }

            if revealed >= release.reviews.count {
                LaunchScoreStamp(score: release.averageReviewScore)
                if let forecast = release.launchForecast, let reason = forecast.limitingFactor {
                    LaunchReasonRow(reason: reason, fix: forecast.fix, productID: productID, onRoute: onRoute)
                        .transition(Theme.Motion.transition(.move(edge: .bottom).combined(with: .opacity)))
                }
            }
        }
    }
}

/// The average, stamped down: arrives large and settles, with the review
/// sound and the success haptic.
struct LaunchScoreStamp: View {
    let score: Int

    /// The stamp's scale, animated on arrival.
    @State private var stampScale: CGFloat = 2.4
    @State private var stampOpacity: Double = 0

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            PixelText(
                text: "\(score)",
                scale: 6,
                color: Theme.scoreTint(score),
                shadow: true
            )
            PixelText(text: LaunchVerdict.text(for: score), scale: 2, color: .secondary)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity)
        .overlay {
            PixelPanelBorder(thickness: 3, corner: 3)
                .fill(Theme.scoreTint(score).opacity(0.6))
        }
        .scaleEffect(stampScale)
        .opacity(stampOpacity)
        .onAppear {
            Sounds.play(.review)
            Haptics.success()
            withAnimation(Theme.Motion.emphatic) {
                stampScale = 1
                stampOpacity = 1
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Average score \(score) out of 100. \(LaunchVerdict.text(for: score))."
        )
    }
}

/// The one-word verdict under an average score.
enum LaunchVerdict {
    static func text(for score: Int) -> String {
        switch score {
        case 90...: String(localized: "A hit", comment: "One-word verdict under the average review score, best to worst")
        case 75..<90: String(localized: "Well received", comment: "One-word verdict under the average review score, best to worst")
        case 60..<75: String(localized: "Solid", comment: "One-word verdict under the average review score, best to worst")
        case 45..<60: String(localized: "Mixed", comment: "One-word verdict under the average review score, best to worst")
        case 30..<45: String(localized: "Rough", comment: "One-word verdict under the average review score, best to worst")
        default: String(localized: "A misfire", comment: "One-word verdict under the average review score, best to worst")
        }
    }
}

/// A labelled launch figure.
struct LaunchStat: View {
    let label: String
    let value: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(Theme.Typography.number(.title3))
                .foregroundStyle(tint)
        }
        .accessibilityElement(children: .combine)
    }
}

/// One outlet's verdict, with its blurb typing itself out — unless the
/// player has asked for less motion, or the frame is a static one, in
/// which case the verdict is simply there.
struct ReviewCardView: View {
    let review: Review
    var typesOut = true

    @State private var shownCharacters = 0
    @State private var shownScore = 0

    private var animates: Bool { typesOut && !Theme.Motion.isReduced }

    var body: some View {
        CardView(review.outlet, systemImage: "newspaper") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.sm) {
                    PixelText(
                        text: "\(animates ? shownScore : review.score)",
                        scale: 3,
                        color: Theme.scoreTint(review.score)
                    )
                    Text("/ 100")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                Text(animates ? String(review.blurb.prefix(shownCharacters)) : review.blurb)
                    .font(.subheadline)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(review.outlet) scored it \(review.score). \(review.blurb)")
        .onAppear { animate() }
    }

    private func animate() {
        guard animates else { return }
        Task {
            // Score counts up in ten steps, then the blurb types.
            for step in 1...10 {
                try? await Task.sleep(for: .milliseconds(24))
                shownScore = review.score * step / 10
            }
            for index in 0...review.blurb.count {
                try? await Task.sleep(for: .milliseconds(12))
                shownCharacters = index
            }
        }
    }
}

/// The sentence under the score that says why, with the screen that fixes
/// it one tap away. Shown once the last outlet has weighed in.
struct LaunchReasonRow: View {
    let reason: String
    let fix: LaunchForecast.Fix?
    var productID: UUID?
    let onRoute: (Route) -> Void

    private var action: (label: String, route: Route)? {
        switch fix {
        case .hiring: (String(localized: "Hire", comment: "Button on a launch-day reason: go to the hiring screen"), .hiring)
        case .refactor: (String(localized: "The team", comment: "Button on a launch-day reason: go to the roster"), .hiring)
        case .bugs: productID.map { (String(localized: "Live ops", comment: "Button on a launch-day reason: go to the shipped product"), .product($0)) }
        case .market: (String(localized: "The market", comment: "Button on a launch-day reason: go to the market board"), .market)
        case nil: nil
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: "lightbulb.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.warning)
                .frame(width: 22)
            Text(reason)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Theme.Spacing.sm)
            if let action {
                Button {
                    Haptics.tap()
                    onRoute(action.route)
                } label: {
                    Text(action.label)
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.warning.opacity(0.10), in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Why: \(reason)")
    }
}
