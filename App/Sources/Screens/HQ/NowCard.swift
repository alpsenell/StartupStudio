import SwiftUI
import TycoonContent
import TycoonEngine

/// The first card on HQ: what is happening, and what to do next.
///
/// Above the office, not below five other cards: the build in flight (if
/// there is one) with its bugs and progress, and the goal the run is
/// closest to — with the goal's own action as a button, so "start your
/// first product" is one tap from the moment the game opens rather than
/// three screens of scrolling from the tip that says so.
struct NowCard: View {
    let engine: GameEngine
    /// Opens the new-product flow in place (HQ owns that sheet), rather
    /// than bouncing through the Products tab.
    let startNewProduct: () -> Void

    @Environment(AppRouter.self) private var router

    private var goal: GoalProgress? { engine.state.progression.activeGoals.first }

    var body: some View {
        let build = engine.state.productInDevelopment
        // Before the first tick there are no goals yet (progression opens
        // them on day one), so a brand-new game still leads with the one
        // thing to do.
        let dayZero = goal == nil && build == nil && engine.state.products.isEmpty
        if goal != nil || build != nil || dayZero {
            CardView("Now", systemImage: "arrow.right.circle.fill") {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    if let product = build, case .development(let progress) = product.stage {
                        buildRow(product, progress: progress)
                        if goal != nil {
                            Divider()
                        }
                    }
                    // Launch week (U1): the war room, once a build is inside
                    // seven days of its ETA or shipped today. Empty otherwise.
                    WarRoomOfferRow(engine: engine)
                    // MARK: Iteration 10 — M3 (incident room)
                    // Something on fire, one tap from HQ. Renders nothing
                    // on every ordinary day, so the card reads as it did.
                    IncidentNowRow(engine: engine)
                    // MARK: end M3
                    // MARK: T5 (expo and pre-orders)
                    // The year's expo, from four weeks out. Renders nothing
                    // outside the notice window, so the card reads as it did.
                    ExpoNowRow(engine: engine)
                    // MARK: end T5
                    if let goal {
                        goalRow(goal, buildID: build?.id)
                    } else if dayZero {
                        dayZeroRow
                    }
                }
            }
        }
    }

    /// What the origin put on the desk before the first product (WS-H):
    /// the person, the client and the topic, or the bank. Nothing for a
    /// garage.
    private var originLine: String? {
        let state = engine.state
        switch state.origin {
        case .garage:
            return nil
        case .cofounded:
            guard let cofounder = state.cofounder else { return nil }
            let stake = Int(engine.balance.origins.cofounderEquity.rounded())
            let tier = engine.balance.origins.cofounderPaidFrom.displayName.lowercased()
            return "\(cofounder.name) is at the other desk. They own \(stake)% and draw no salary until the \(tier)."
        case .spinOut:
            var parts: [String] = []
            if let job = state.activeContracts.first {
                parts.append("\(job.clientName) is waiting on the build you brought with you — due \(GameState.dateLabel(forDay: job.deadlineDay)).")
            }
            if let (topicID, unlockDay) = state.lockedTopics.first {
                let topic = engine.content.topic(topicID)?.name ?? topicID
                parts.append("\(topic) is off limits until \(GameState.dateLabel(forDay: unlockDay)).")
            }
            return parts.isEmpty ? nil : parts.joined(separator: " ")
        case .mortgaged:
            return "The bank's \(engine.balance.origins.mortgagedLoan.money) is in the account, and the flat is behind it. Interest posts every week."
        }
    }

    /// Day 0, before the goals exist: the first product, one tap away.
    private var dayZeroRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Start your first product")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
            Text("Pick a type, pick a topic, and get building. Press play when you are ready.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let originLine {
                Label(originLine, systemImage: engine.state.origin.systemImageName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                Haptics.tap()
                Sounds.play(.tap)
                startNewProduct()
            } label: {
                Label("Start a product", systemImage: "hammer.fill")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.xs)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .padding(.top, Theme.Spacing.xs)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - The build in flight

    // MARK: V3 (ux: card weights, the Now card)
    // C11: one segmented phase bar and the sentence the three bars never
    // said — when it ships — read off the engine's own `BuildETA`. The
    // numbers per phase stay on Products.
    private func buildRow(_ product: Product, progress: DevProgress) -> some View {
        let type = engine.content.productType(product.typeID)
        let eta = engine.state.buildETA(productID: product.id, balance: engine.balance, content: engine.content)
        let sentence = NowBuildETA.sentence(eta)
        return Button {
            Haptics.tap()
            router.go(.product(product.id))
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.sm) {
                    // The type as its icon, so the ETA below has the line.
                    if let type {
                        Image(systemName: type.iconSystemName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                    Text(product.name)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: Theme.Spacing.sm)
                    StatPill(
                        systemImage: "ladybug.fill",
                        value: "\(progress.openBugs) bug\(progress.openBugs == 1 ? "" : "s")",
                        tint: progress.openBugs > 0 ? Theme.warning : .secondary
                    )
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                SegmentedPhaseBar(progress: progress, type: type)
                Text(sentence)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(NowBuildETA.isStalled(eta) ? Theme.warning : Theme.accent)
                    .contentTransition(.numericText())
                    .fixedSize(horizontal: false, vertical: true)
                // MARK: K3 (the ladder)
                // The estimate above already reads the crew factor; this
                // line says what it is.
                LadderCrewLine(engine: engine, productID: product.id)
                // MARK: end K3
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressableRow)
        .accessibilityLabel(
            "In development: \(product.name)"
                + (type.map { ", \($0.name)" } ?? "")
                + ". \(sentence). \(progress.openBugs) open bugs"
        )
        .accessibilityHint("Opens the build")
    }

    /// Whether the goal's button would open the build the row above
    /// already opens ("Ship it" → Open the build). The action stays in the
    /// table; the card just doesn't draw the same tap twice.
    private static func duplicatesBuildRow(_ action: NowAction.Action, buildID: UUID?) -> Bool {
        guard let buildID, case .product(let id) = action.route else { return false }
        return id == buildID
    }
    // MARK: end V3

    // MARK: - The goal

    private func goalRow(_ goal: GoalProgress, buildID: UUID?) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                Text(goal.title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Spacer(minLength: Theme.Spacing.xs)
                Text(goal.target <= 1 ? (goal.fraction >= 1 ? "Done" : "Not yet") : goal.countLabel)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            if !goal.detail.isEmpty {
                Text(goal.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ProgressView(value: goal.fraction)
                .tint(goal.fraction >= 1 ? Theme.positiveCash : Theme.accent)
                .animation(Theme.Motion.valueChange, value: goal.fraction)

            if let action = NowAction.action(for: goal.id, state: engine.state),
               !Self.duplicatesBuildRow(action, buildID: buildID) {
                Button {
                    Haptics.tap()
                    Sounds.play(.tap)
                    switch action.route {
                    case .newProduct:
                        startNewProduct()
                    default:
                        router.go(action.route)
                    }
                } label: {
                    Label(action.label, systemImage: action.systemImage)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.xs)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .padding(.top, Theme.Spacing.xs)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Next: \(goal.title). \(goal.detail)")
    }
}

// MARK: V3 (ux: card weights, the Now card)

/// The Now card's one sentence about the build in flight, read off
/// `BuildETA` — the same projection the war room counts down from.
enum NowBuildETA {
    static func sentence(_ eta: BuildETA?) -> String {
        guard let eta else { return "No ship date yet" }
        if eta.isComplete { return "Ready to ship" }
        guard let days = eta.daysToComplete else { return "Stalled: nobody is on the build" }
        if eta.daysToShippable == 0 {
            // Code is past the gate: it could go now, rougher.
            return days <= 1 ? "Could ship now · done tomorrow" : "Could ship now · done in about \(days) days"
        }
        switch days {
        case 0: return "Ready to ship"
        case 1: return "Ships tomorrow"
        default: return "Ships in about \(days) days"
        }
    }

    /// Nothing is moving: nobody on the build, or no type to measure.
    static func isStalled(_ eta: BuildETA?) -> Bool {
        guard let eta else { return true }
        return !eta.isComplete && eta.daysToComplete == nil
    }
}

// MARK: end V3

/// The action a goal implies, as a button. Keyed on the goal ids in
/// `Goals.json` the same way `CoachTip` is; a goal with no obvious tap
/// (move into the loft — the office card is right below) gets none.
enum NowAction {
    struct Action {
        let label: String
        let systemImage: String
        let route: Route
    }

    static func action(for goalID: String, state: GameState) -> Action? {
        switch goalID {
        case "g1_name_a_product", "g3_a_hundred_and_fifty_k_product":
            return Action(label: "Start a product", systemImage: "hammer.fill", route: .newProduct(topicID: nil))
        case "g1_ship_it", "g1_review_40", "g2_review_60", "g3_review_75", "g5_review_90",
             "g4i_review_85", "g4i_two_products_live":
            if let product = state.productInDevelopment {
                return Action(label: "Open the build", systemImage: "hammer.fill", route: .product(product.id))
            }
            return Action(label: "Start a product", systemImage: "hammer.fill", route: .newProduct(topicID: nil))
        case "g1_first_hire", "g2_team_of_three", "g3_form_a_department", "g4_twenty_on_payroll",
             "g3i_six_tenured", "g4i_form_a_department":
            return Action(label: "Hire someone", systemImage: "person.badge.plus", route: .hiring)
        case "g1_first_contract":
            return Action(label: "Find a contract", systemImage: "briefcase.fill", route: .contracts)
        case "g1_week_in_the_black", "g5_millionaire", "g5_five_million_company",
             "g3i_four_profitable_quarters", "g4i_eight_profitable_quarters", "g4i_quarter_million":
            return Action(label: "See the money", systemImage: "banknote.fill", route: .finances)
        case "g2_research_two_techs", "g5_frontier_research":
            return Action(label: "Open R&D", systemImage: "flask.fill", route: .research)
        case "g2_take_a_weekend", "g2_go_on_a_date", "g3_move_in_together", "g5_three_children",
             "g4i_marry":
            return Action(label: "Go to Life", systemImage: "heart.fill", route: .life)
        case "g3_weather_three_crashes", "g4_own_a_topic", "g3i_own_a_topic":
            return Action(label: "Read the market", systemImage: "chart.xyaxis.line", route: .market)
        case "g4_raise_a_round", "g5_ready_to_go_public", "g5i_ready_to_stay_independent":
            return Action(label: "See investors", systemImage: "chart.pie.fill", route: .investors)
        case "g4_acquire_a_rival":
            return Action(label: "See rivals", systemImage: "flag.2.crossed.fill", route: .rivals)
        case "g3i_buy_the_office":
            return Action(label: "Open the city map", systemImage: "map.fill", route: .city)
        // "Five years in" is time passing; there is nothing to tap for it.
        default:
            return nil
        }
    }
}
