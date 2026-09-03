import SwiftUI
import TycoonEngine

/// Launch day: the moment a product stops being a progress bar and becomes
/// a thing in the world.
///
/// Shown when a product ships, and again when its reviews land — at which
/// point the outlets reveal one at a time, each blurb typing itself out
/// under a score that counts up, before the average stamps down.
struct LaunchDaySheet: View {
    let engine: GameEngine
    let product: Product

    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router

    /// How many reviews have been revealed so far.
    @State private var revealed = 0
    /// The average stamp's scale, animated on arrival.
    @State private var stampScale: CGFloat = 2.4
    @State private var stampOpacity: Double = 0

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
                    if let release {
                        if release.reviews.isEmpty {
                            waitingForReviews(release)
                        } else {
                            reviewsSection(release)
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
    }

    // MARK: - Hero

    private var hero: some View {
        PixelPanel {
            VStack(spacing: Theme.Spacing.md) {
                ProductBoxArtView(
                    typeID: product.typeID,
                    topicID: product.topicID,
                    seed: product.id.uuidString.utf8.reduce(UInt64(0)) { $0 &* 31 &+ UInt64($1) },
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

    private func reviewsSection(_ release: ReleaseInfo) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            ForEach(Array(release.reviews.enumerated()), id: \.offset) { index, review in
                if index < revealed {
                    ReviewCardView(review: review)
                        .transition(Theme.Motion.transition(.move(edge: .bottom).combined(with: .opacity)))
                }
            }

            if revealed >= release.reviews.count {
                averageStamp(release)
                if let forecast = release.launchForecast, let reason = forecast.limitingFactor {
                    LaunchReasonRow(reason: reason, fix: forecast.fix) { route in
                        dismiss()
                        router.go(route)
                    }
                    .transition(Theme.Motion.transition(.move(edge: .bottom).combined(with: .opacity)))
                }
            }
        }
    }

    private func averageStamp(_ release: ReleaseInfo) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            PixelText(
                text: "\(release.averageReviewScore)",
                scale: 6,
                color: Theme.scoreTint(release.averageReviewScore),
                shadow: true
            )
            PixelText(text: verdict(release.averageReviewScore), scale: 2, color: .secondary)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity)
        .overlay {
            PixelPanelBorder(thickness: 3, corner: 3)
                .fill(Theme.scoreTint(release.averageReviewScore).opacity(0.6))
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
            "Average score \(release.averageReviewScore) out of 100. \(verdict(release.averageReviewScore))."
        )
    }

    private func verdict(_ score: Int) -> String {
        switch score {
        case 90...: "A hit"
        case 75..<90: "Well received"
        case 60..<75: "Solid"
        case 45..<60: "Mixed"
        case 30..<45: "Rough"
        default: "A misfire"
        }
    }

    // MARK: - Sales

    private func salesSection(_ release: ReleaseInfo) -> some View {
        CardView("The market", systemImage: "chart.line.uptrend.xyaxis") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .top, spacing: Theme.Spacing.xl) {
                    if let firstWeek = release.weeklySales.first {
                        LaunchStat(label: "First week", value: firstWeek.revenue.money, tint: Theme.positiveCash)
                        LaunchStat(label: "Units", value: firstWeek.units.formatted(.number.locale(Theme.gameLocale)))
                    } else {
                        LaunchStat(
                            label: "Quality",
                            value: "\(Int(release.quality.rounded()))",
                            tint: Theme.scoreTint(Int(release.quality.rounded()))
                        )
                        LaunchStat(
                            label: "Launch hype",
                            value: "\(Int((release.hypeAtLaunch * 100).rounded()))%"
                        )
                    }
                    if release.isSubscription {
                        LaunchStat(label: "Subscribers", value: release.subscribers.formatted(.number.locale(Theme.gameLocale)))
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
                try? await Task.sleep(for: .milliseconds(index == 0 ? 400 : 900))
                withAnimation(Theme.Motion.emphatic) { revealed = index + 1 }
                Sounds.play(.tap)
                Haptics.tap()
            }
        }
    }
}

private struct LaunchStat: View {
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

/// One outlet's verdict, with its blurb typing itself out.
private struct ReviewCardView: View {
    let review: Review

    @State private var shownCharacters = 0
    @State private var shownScore = 0

    var body: some View {
        CardView(review.outlet, systemImage: "newspaper") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.sm) {
                    PixelText(
                        text: "\(shownScore)",
                        scale: 3,
                        color: Theme.scoreTint(review.score)
                    )
                    Text("/ 100")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                Text(String(review.blurb.prefix(shownCharacters)))
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
        case .hiring: ("Hire", .hiring)
        case .refactor: ("The team", .hiring)
        case .bugs: productID.map { ("Live ops", .product($0)) }
        case .market: ("The market", .market)
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
