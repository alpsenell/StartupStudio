import PixelKit
import SwiftUI
import TycoonContent
import TycoonEngine

// MARK: T4 (publisher)

// Iteration 17 — T4 (genre G1): the app's half of the publishing deal
// (`Publisher.swift` is the engine's). One home: the sheet. It opens from
// the Financing row on a build's Ship date card and from the studio's
// profile; the row and the profile only say what the sheet will. Every
// number is the engine's query, printed before the tap.

/// The Financing row under the ship date: the deal a publisher would sign
/// today, the deal that stands, or why there is none.
struct PublisherRow: View {
    let engine: GameEngine
    let product: Product

    @State private var showingSheet = false

    var body: some View {
        let state = engine.state
        let terms = state.publisherTerms(productID: product.id, balance: engine.balance, content: engine.content)
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Divider()
            Text("Financing")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if let publisher = product.publisher {
                published(publisher)
            } else if terms.isOpen, let name = terms.rivalName {
                Button {
                    Haptics.tap()
                    showingSheet = true
                } label: {
                    Label("Shop it to \(name): \(terms.advance.money) now", systemImage: "banknote.fill")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.xs)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .accessibilityHint("Opens the publisher's terms")
                Text("\(PublisherCopy.percent(terms.share)) of it is theirs for as long as it sells, and the date is theirs\(terms.date.map { ": \(label($0))" } ?? "").")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let refusal = terms.refusal {
                Text(refusal.sentence)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sheet(isPresented: $showingSheet) {
            PublisherSheet(engine: engine, productID: product.id)
        }
        .task {
            if PublisherDebug.wantsSheet(for: product.id, engine: engine) { showingSheet = true }
        }
    }

    @ViewBuilder
    private func published(_ publisher: Publisher) -> some View {
        Button {
            Haptics.tap()
            showingSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("Published by \(publisher.rivalName) · \(PublisherCopy.percent(publisher.share))")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text("Advance \(publisher.advance.money) · buy them out for \((engine.state.publisherBuyoutPrice(for: product, balance: engine.balance) ?? 0).money)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.pressableRow)
    }

    private func label(_ day: Int) -> String {
        AnnounceEventPresenter.dateLabel(day, today: engine.state.day)
    }
}

/// The term sheet before signing, and the deal once it stands, with the
/// two answers on their buttons.
struct PublisherSheet: View {
    let engine: GameEngine
    let productID: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI updates
    /// presented content before the environment is installed.
    private var shell: GameShell { injectedShell ?? .shared }

    private var state: GameState { engine.state }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    if let product = state.product(id: productID) {
                        if let publisher = product.publisher {
                            standing(product, publisher)
                        } else {
                            offer(product)
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle(state.product(id: productID)?.publisher == nil ? "Shop it to a publisher" : "The publisher")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // MARK: - Before

    @ViewBuilder
    private func offer(_ product: Product) -> some View {
        let terms = state.publisherTerms(productID: productID, balance: engine.balance, content: engine.content)
        PixelPanel(contentPadding: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                PixelSectionTitle(title: "Term sheet")
                PixelText(text: terms.rivalName ?? "Nobody", scale: 3, color: Theme.pixelInk, shadow: true)
                Text(terms.rivalName == nil
                    ? "No studio is big enough to publish anyone."
                    : "The strongest studio in the field offers to publish \(product.name).")
                    .font(.callout)
                    .foregroundStyle(Theme.pixelInk)
                    .fixedSize(horizontal: false, vertical: true)
                Divider().overlay(Theme.pixelInk.opacity(0.3))
                ForEach(lines(product, terms), id: \.text) { line in
                    PublisherLine(line: line)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        if let refusal = terms.refusal {
            Text(refusal.sentence)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else if let name = terms.rivalName {
            VStack(spacing: Theme.Spacing.sm) {
                Button { sign(product, terms: terms) } label: {
                    PublisherChoice(
                        title: "Take \(terms.advance.money) from \(name)",
                        detail: "Cash today. \(PublisherCopy.percent(terms.share)) of \(product.name) is theirs for as long as it sells, and so is the date.",
                        emphasised: true
                    )
                }
                .buttonStyle(.pressableRow)
                Button { dismiss() } label: {
                    PublisherChoice(
                        title: "Keep it yours",
                        detail: "No advance and no date. Every dollar it earns stays here; the build runs on the money you have.",
                        emphasised: false
                    )
                }
                .buttonStyle(.pressableRow)
            }
        }
    }

    private func lines(_ product: Product, _ terms: PublisherTerms) -> [PublisherLine.Item] {
        let name = terms.rivalName ?? "They"
        let announce = engine.balance.announce
        let slip = Announce.slipCost(slipNumber: product.slips + 1, balance: engine.balance)
        let topic = engine.content.topic(terms.topicID)?.name ?? terms.topicID
        let floored = terms.crewLine > terms.crewPay
        var items: [PublisherLine.Item] = [
            .init(
                icon: "banknote.fill",
                text: "Advance: \(terms.advance.money) today. The crew \(terms.crewLine.money)\(floored ? " (at least \(terms.crewLine.money), whatever they are paid)" : ""), running costs \(terms.runningCost.money) and rent \(terms.rent.money) a week, for \(PublisherCopy.weeks(terms.weeksPaid)) — half the \(terms.daysToETA) days to the ETA.",
                tint: Theme.positiveCash
            ),
            .init(
                icon: "chart.pie.fill",
                text: "Their share: \(PublisherCopy.percent(terms.share)) of everything \(product.name) earns, every week, for as long as it sells."
                    + (terms.estimate.map { " If it reviews \($0.review), that is about \($0.theirs.money) of its first \($0.weeks) weeks." } ?? ""),
                tint: Theme.warning
            ),
        ]
        if let date = terms.date {
            items.append(.init(
                icon: "calendar.badge.exclamationmark",
                text: (terms.keepsStandingDate
                    ? "The date you gave stands, \(label(date)), and now it is theirs too."
                    : "Their date: \(label(date)), the ETA plus \(engine.balance.publisher.dateSlackDays / 7) weeks, in print today.")
                    + " Miss it: reputation −\(Int(slip.reputation)), hype ×\(PublisherCopy.factor(slip.hypeFactor)), and \(terms.clawbackPerSlip.money) of the advance goes back to \(name).",
                tint: Theme.warning
            ))
        }
        items.append(.init(
            icon: "flame.fill",
            text: "Their name on launch day: hype +\(Int(terms.launchHype.rounded())).",
            tint: Theme.pixelAccent
        ))
        items.append(.init(
            icon: "eye.fill",
            text: (terms.topicIsHome
                ? "\(name) already lives in \(topic), and now they have seen your board."
                : "\(name) reads the board: they move into \(topic) today.")
                + " The copycat is ready \(announce.copycatDelayWeeks) weeks after launch, not \(RivalDepthTuning.copycatDelayWeeks).",
            tint: Theme.warning
        ))
        items.append(.init(
            icon: "arrow.uturn.backward.circle.fill",
            text: "Buy them out any time: \(PublisherCopy.factor(engine.balance.publisher.buyoutMultiple))× the advance, \(terms.buyoutAtSigning.money), less whatever they have been paid by then.",
            tint: Theme.pixelAccent
        ))
        return items
    }

    private func sign(_ product: Product, terms: PublisherTerms) {
        let refusal = state.publisherTerms(productID: productID, balance: engine.balance, content: engine.content).refusal
        shell.toasts.send(
            .shopToPublisher(productID: productID),
            to: engine,
            ack: "\(terms.rivalName ?? "They") publish \(product.name): \(terms.advance.money) in the account",
            rejected: refusal?.sentence ?? "Nobody would publish this.",
            icon: "banknote.fill"
        )
        Haptics.commit()
        dismiss()
    }

    // MARK: - While it stands

    @ViewBuilder
    private func standing(_ product: Product, _ publisher: Publisher) -> some View {
        let price = state.publisherBuyoutPrice(for: product, balance: engine.balance) ?? 0
        let blocker = state.publisherBuyoutBlocker(productID: productID, balance: engine.balance)
        let active = state.publisherIsActive(product)
        PixelPanel(contentPadding: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                PixelSectionTitle(title: "Published by")
                PixelText(text: publisher.rivalName, scale: 3, color: Theme.pixelInk, shadow: true)
                Divider().overlay(Theme.pixelInk.opacity(0.3))
                PublisherLine(line: .init(
                    icon: "banknote.fill",
                    text: "Advance \(publisher.advance.money), signed \(PublisherCopy.ago(state.day - publisher.signedDay)).",
                    tint: Theme.positiveCash
                ))
                PublisherLine(line: .init(
                    icon: "chart.pie.fill",
                    text: active
                        ? "\(PublisherCopy.percent(publisher.share)) of \(product.name) is theirs: \(publisher.paidBack.money) paid so far."
                        : "\(publisher.rivalName) is gone from the field, and the share went with them: \(publisher.paidBack.money) paid in all.",
                    tint: Theme.warning
                ))
                if publisher.clawedBack > 0 {
                    PublisherLine(line: .init(
                        icon: "calendar.badge.exclamationmark",
                        text: "Missed dates have cost \(publisher.clawedBack.money) of the advance.",
                        tint: Theme.negativeCash
                    ))
                }
                if let date = product.announcedDay, case .development = product.stage {
                    PublisherLine(line: .init(
                        icon: "calendar",
                        text: "Their date: \(label(date)). Each miss hands back \(Int((Double(publisher.advance) * engine.balance.publisher.clawbackPerSlip).rounded()).money).",
                        tint: Theme.pixelAccent
                    ))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        if active {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Button { buyOut(product, publisher: publisher, price: price) } label: {
                    PublisherChoice(
                        title: "Buy \(publisher.rivalName) out for \(price.money)",
                        detail: blocker ?? "\(PublisherCopy.factor(engine.balance.publisher.buyoutMultiple))× the \(publisher.advance.money) advance, less the \(publisher.paidBack.money) they have had. The share stops today; the date stays in print.",
                        emphasised: true
                    )
                }
                .buttonStyle(.pressableRow)
                .disabled(blocker != nil)
                Button { dismiss() } label: {
                    PublisherChoice(
                        title: "Keep the deal",
                        detail: "\(PublisherCopy.percent(publisher.share)) of every week keeps going to \(publisher.rivalName); the price to leave falls by what they are paid.",
                        emphasised: false
                    )
                }
                .buttonStyle(.pressableRow)
            }
        }
    }

    private func buyOut(_ product: Product, publisher: Publisher, price: Int) {
        shell.toasts.send(
            .buyOutPublisher(productID: productID),
            to: engine,
            ack: "\(product.name) is yours again, for \(price.money)",
            rejected: state.publisherBuyoutBlocker(productID: productID, balance: engine.balance) ?? "They would not sell.",
            icon: "arrow.uturn.backward.circle.fill"
        )
        Haptics.commit()
        dismiss()
    }

    private func label(_ day: Int) -> String {
        AnnounceEventPresenter.dateLabel(day, today: state.day)
    }
}

/// One line of the term sheet, on pixel paper.
struct PublisherLine: View {
    struct Item {
        let icon: String
        let text: String
        let tint: Color
    }

    let line: Item

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
            Image(systemName: line.icon)
                .font(.caption)
                .foregroundStyle(line.tint)
                .frame(width: 18)
                .accessibilityHidden(true)
            Text(line.text)
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(Theme.pixelInk.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// One answer, with its consequence under it.
struct PublisherChoice: View {
    let title: String
    let detail: String
    let emphasised: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(emphasised ? Theme.accent : .primary)
            Text(detail)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - The studio's profile

/// On a rival's profile: the builds they publish for you, each opening its
/// sheet — or, for the studio a publisher deal would go to, where to find
/// one.
struct PublisherProfileRows: View {
    let engine: GameEngine
    let rival: Rival

    private struct Target: Identifiable {
        let id: UUID
    }

    @State private var target: Target?

    var body: some View {
        let state = engine.state
        let published = state.productsPublished(by: rival.id)
        Group {
            if !published.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Divider()
                    Text("They publish for you")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(published) { product in
                        Button {
                            Haptics.tap()
                            target = Target(id: product.id)
                        } label: {
                            HStack {
                                Text(product.name)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(PublisherCopy.percent(product.publisher?.share ?? 0)) · \((product.publisher?.paidBack ?? 0).money) paid")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                            .monospacedDigit()
                        }
                        .buttonStyle(.pressable)
                    }
                }
            } else if state.publisherCandidate(balance: engine.balance)?.id == rival.id {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Divider()
                    Text("They would publish a build of yours: an advance now for \(PublisherCopy.percent(engine.balance.publisher.share)) of it and a date. Ask from the build's Ship date card.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .sheet(item: $target) { target in
            PublisherSheet(engine: engine, productID: target.id)
        }
        .task { PublisherDebug.prepare(engine: engine) }
    }
}

// MARK: - Copy

enum PublisherCopy {
    /// "40%".
    static func percent(_ share: Double) -> String {
        "\(Int((share * 100).rounded()))%"
    }

    /// "1.5", "0.6", "2".
    static func factor(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))" : String(format: "%g", value)
    }

    /// "4.4 weeks", "1 week".
    static func weeks(_ value: Double) -> String {
        let tenths = (value * 10).rounded() / 10
        let text = tenths == tenths.rounded() ? "\(Int(tenths))" : String(format: "%.1f", tenths)
        return "\(text) week\(tenths == 1 ? "" : "s")"
    }

    /// "today", "3 days ago".
    static func ago(_ days: Int) -> String {
        days <= 0 ? "today" : "\(days) day\(days == 1 ? "" : "s") ago"
    }
}

// MARK: - Debug

/// `-autoRoute t4-publisher -autoTab business` pushes the build a publisher
/// would take (the Business tab's T4 landing); `-autoPublisher offer`
/// opens its sheet, `sign` signs the deal first, `slip` signs it and
/// misses the date once. With `-autoRoute rivalprofile`, `sign` dresses
/// the strongest studio's profile. Debug builds only; the actions sent are
/// the real ones.
@MainActor
enum PublisherDebug {
    private static var prepared = false
    private static var sheetShown = false

    static var word: String? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-autoPublisher"), arguments.indices.contains(flag + 1)
        else { return nil }
        return arguments[flag + 1].lowercased()
        #else
        return nil
        #endif
    }

    /// Whether `-autoRoute t4-publisher` asked for the landing.
    static var wantsLanding: Bool {
        DebugLaunch.autoRouteName == "t4-publisher"
    }

    /// The build the route lands on: one already published, else the first
    /// a publisher would take today, else the first in development.
    static func candidate(in engine: GameEngine) -> UUID? {
        let state = engine.state
        let builds = state.productsInDevelopment
        return builds.first { $0.publisher != nil }?.id
            ?? builds.first {
                state.publisherTerms(productID: $0.id, balance: engine.balance, content: engine.content).isOpen
            }?.id
            ?? builds.first?.id
    }

    /// Signs (and with `slip`, misses the date once) for the candidate,
    /// once per launch.
    static func prepare(engine: GameEngine) {
        #if DEBUG
        guard !prepared, let word, word == "sign" || word == "slip", let id = candidate(in: engine) else { return }
        prepared = true
        let signed = engine.send(.shopToPublisher(productID: id))
        if word == "slip" { _ = engine.send(.announceForceSlip(productID: id)) }
        print("[T4] -autoPublisher \(word): \(signed.isEmpty ? "refused" : "signed (\(signed.count) events)")")
        #endif
    }

    /// Whether the row for `productID` should open its sheet on appear.
    static func wantsSheet(for productID: UUID, engine: GameEngine) -> Bool {
        #if DEBUG
        guard !sheetShown, let word, ["offer", "sign", "slip"].contains(word) else { return false }
        prepare(engine: engine)
        guard candidate(in: engine) == productID else { return false }
        sheetShown = true
        return true
        #else
        return false
        #endif
    }
}

// MARK: end T4
