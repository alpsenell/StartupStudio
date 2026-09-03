import SwiftUI
import TycoonContent
import TycoonEngine

/// The three pages of the new-product flow.
private enum NewProductStep: Int, CaseIterable, Comparable {
    case type, foundation, topic, details

    var title: String {
        switch self {
        case .type: "Type"
        case .foundation: "Base"
        case .topic: "Topic"
        case .details: "Details"
        }
    }

    static func < (lhs: NewProductStep, rhs: NewProductStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Four-step sheet for starting a new product:
/// 1. pick a type, 2. greenfield or an existing codebase, 3. pick a topic,
/// 4. name it and set the starting focus.
///
/// Step 2 is skipped outright until the studio has shipped something of
/// the chosen type — a first-time player never sees a page offering them a
/// choice with one option — so the flow is three steps for the whole of
/// the first product and four from the second on.
///
/// Ends with `.startProduct` (greenfield) or `.startProductOnCodebase`.
struct NewProductFlow: View {
    let engine: GameEngine

    @Environment(\.dismiss) private var dismiss
    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI
    /// updates this property for presented content before the
    /// environment is installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }

    @State private var step: NewProductStep = .type
    @State private var selectedTypeID: String?
    /// The codebase to build on, `nil` for greenfield — which is the
    /// default, and stays the default if the player never opens step 2.
    @State private var selectedCodebaseID: String?
    @State private var selectedTopicID: String?
    @State private var name = ""
    @State private var focus: PhaseFocus = .balanced
    /// Once the user types their own name, stop regenerating suggestions.
    @State private var nameEdited = false

    /// - Parameter initialTopicID: a topic to arrive with already selected,
    ///   for deep links from the market screens (`Route.newProduct`). The
    ///   flow still opens on the type step; the topic step shows it chosen.
    init(engine: GameEngine, initialTopicID: String? = nil) {
        self.engine = engine
        _selectedTopicID = State(initialValue: initialTopicID)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                StepIndicator(current: step, steps: visibleSteps)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.md)

                ScrollView {
                    stepContent
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.bottom, Theme.Spacing.lg)
                }
            }
            .background(Theme.screenBackground)
            .navigationTitle("New product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        }
        .interactiveDismissDisabled(step != .type)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .type:
            TypeStep(engine: engine, selectedTypeID: $selectedTypeID)
        case .foundation:
            FoundationStep(
                engine: engine,
                codebases: availableCodebases,
                selectedCodebaseID: $selectedCodebaseID
            )
        case .topic:
            TopicStep(
                engine: engine,
                selectedTypeID: selectedTypeID,
                selectedTopicID: $selectedTopicID
            )
        case .details:
            DetailsStep(
                name: $name,
                focus: $focus,
                suggestion: suggestion,
                forecast: preStartForecast,
                matching: selectedTypeID.flatMap { engine.content.productType($0) }.map { PhaseFocus.matching(type: $0) }
            ) {
                nameEdited = true
            }
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: Theme.Spacing.md) {
            if let previous = step(-1) {
                Button {
                    withAnimation(Theme.Motion.entrance) {
                        step = previous
                    }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .font(.system(.headline, design: .rounded))
                        .padding(.vertical, Theme.Spacing.xs)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Back to \(previous.title)")
            }

            if step == .details {
                Button(action: start) {
                    Label(startLabel, systemImage: "hammer.fill")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.xs)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(!canStart)
                .accessibilityLabel("Start building \(trimmedName)")
            } else {
                Button(action: advance) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.xs)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(!canAdvance)
                .accessibilityLabel("Next step")
            }
        }
        .padding(Theme.Spacing.lg)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    /// The crew's best case on the chosen type, topic and base.
    private var preStartForecast: ShipForecast? {
        guard let selectedTypeID else { return nil }
        return ShipForecast.preStart(
            typeID: selectedTypeID, topicID: selectedTopicID, codebaseID: selectedCodebaseID,
            state: engine.state, balance: engine.balance, content: engine.content
        )
    }

    /// "Start · ~58 best case": the number on the button that commits.
    private var startLabel: String {
        preStartForecast.map { "Start · ~\(Int($0.quality.rounded())) best case" } ?? "Start building"
    }

    private var canAdvance: Bool {
        switch step {
        case .type: selectedTypeID != nil
        // Greenfield is a real answer, so this page is never blocking.
        case .foundation: true
        case .topic: selectedTopicID != nil
        case .details: false
        }
    }

    /// What the chosen type could be built on. Empty until the studio has
    /// shipped one, which is what hides step 2 for the first product.
    private var availableCodebases: [Codebase] {
        guard let typeID = selectedTypeID else { return [] }
        return engine.state.availableCodebases(typeID: typeID)
    }

    /// The steps this run of the sheet actually shows.
    private var visibleSteps: [NewProductStep] {
        NewProductStep.allCases.filter { $0 != .foundation || !availableCodebases.isEmpty }
    }

    /// The step `offset` places from `step` among the visible ones.
    private func step(_ offset: Int) -> NewProductStep? {
        let steps = visibleSteps
        guard let index = steps.firstIndex(of: step) else { return nil }
        let next = index + offset
        return steps.indices.contains(next) ? steps[next] : nil
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canStart: Bool {
        !trimmedName.isEmpty && selectedTypeID != nil && selectedTopicID != nil
    }

    private func advance() {
        guard let next = step(1) else { return }
        // Leaving the type page invalidates any codebase chosen for a
        // different type — the engine would ignore it, and a sheet that
        // shows a head start it will not deliver is worse than no sheet.
        if step == .type, !availableCodebases.contains(where: { $0.id == selectedCodebaseID }) {
            selectedCodebaseID = nil
        }
        if next == .details, !nameEdited {
            name = suggestion
        }
        withAnimation(Theme.Motion.entrance) {
            step = next
        }
    }

    private func start() {
        guard let typeID = selectedTypeID, let topicID = selectedTopicID, canStart else { return }
        let action: GameAction = if let codebaseID = selectedCodebaseID {
            .startProductOnCodebase(
                typeID: typeID, topicID: topicID, name: trimmedName,
                focus: focus, codebaseID: codebaseID
            )
        } else {
            .startProduct(typeID: typeID, topicID: topicID, name: trimmedName, focus: focus)
        }
        shell.toasts.send(action, to: engine, rejected: "Every development slot is busy.")
        dismiss()
    }

    // MARK: - Name suggestion

    /// Tiny local flavor generator: a topic stem plus a type-flavored
    /// suffix, e.g. fitness + mobile app -> "FitTrack". Deterministic by
    /// design — no engine RNG involved.
    private var suggestion: String {
        guard let typeID = selectedTypeID, let topicID = selectedTopicID else { return "" }

        let stems: [String: String] = [
            "fitness": "Fit", "finance": "Fin", "social": "Social",
            "travel": "Trip", "food_delivery": "Bite", "education": "Learn",
            "music": "Tune", "gaming": "Play", "productivity": "Task",
            "health": "Vita", "dating": "Match", "logistics": "Ship",
        ]
        let suffixesByType: [String: [String]] = [
            "mobile_app": ["Go", "Track", "Snap", "Dash"],
            "web_app": ["Hub", "Board", "Space", "Link"],
            "desktop_tool": ["Studio", "Bench", "Works", "Forge"],
            "game": ["Quest", "Rush", "Land", "Saga"],
            "saas_platform": ["Base", "Stack", "Cloud", "HQ"],
            "enterprise_tool": ["Suite", "Core", "Ops", "Desk"],
        ]

        let stem = stems[topicID]
            ?? engine.content.topic(topicID)?.name.split(separator: " ").first.map(String.init)
            ?? "Nova"
        let suffixes = suffixesByType[typeID] ?? ["One", "Pro", "Kit"]
        let index = (topicID.count + typeID.count) % suffixes.count
        return stem + suffixes[index]
    }
}

// MARK: - Step indicator

private struct StepIndicator: View {
    let current: NewProductStep
    /// The pages this run of the sheet shows — the foundation page is
    /// absent until the studio has a codebase of the chosen type.
    let steps: [NewProductStep]

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(steps, id: \.rawValue) { step in
                VStack(spacing: Theme.Spacing.xs) {
                    Capsule()
                        .fill(step <= current ? Theme.accent : Theme.chipBackground)
                        .frame(height: 4)
                    Text(step.title)
                        .font(.caption2.weight(step == current ? .bold : .regular))
                        .foregroundStyle(step == current ? Theme.accent : .secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .animation(Theme.Motion.entrance, value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Step \((steps.firstIndex(of: current) ?? 0) + 1) of \(steps.count): \(current.title)"
        )
    }
}

// MARK: - Step 1: type

private struct TypeStep: View {
    let engine: GameEngine
    @Binding var selectedTypeID: String?

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            if let first = engine.content.productTypes.first,
               let forecast = ShipForecast.preStart(
                   typeID: first.id, topicID: nil, codebaseID: nil,
                   state: engine.state, balance: engine.balance, content: engine.content
               ) {
                CrewCeilingNote(ceiling: Int(forecast.quality.rounded()))
                    .padding(.horizontal, Theme.Spacing.xs)
            }
            ForEach(engine.content.productTypes) { type in
                TypeCard(
                    type: type,
                    // Research unlocks count, not just `unlockedFromStart`.
                    isUnlocked: engine.state.isProductTypeUnlocked(type.id, content: engine.content),
                    ceiling: nil,
                    isSelected: selectedTypeID == type.id,
                    select: { selectedTypeID = type.id }
                )
            }
        }
    }
}

private struct TypeCard: View {
    let type: ProductTypeDef
    let isUnlocked: Bool
    /// What the idle crew could reach on this type, before topic and bugs.
    let ceiling: Int?
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: type.iconSystemName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isUnlocked ? Theme.accent : Color.secondary)
                        .frame(width: 38, height: 38)
                        .background(
                            Theme.chipBackground,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(type.name)
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(type.blurb)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: Theme.Spacing.sm)
                    if !isUnlocked {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                    } else if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.accent)
                    }
                }

                HStack(spacing: Theme.Spacing.lg) {
                    EffortDots(label: "Design", points: type.designPts, tint: Theme.designPhase)
                    EffortDots(label: "Code", points: type.codePts, tint: Theme.codePhase)
                    EffortDots(label: "Polish", points: type.polishPts, tint: Theme.polishPhase)
                }

                HStack(spacing: Theme.Spacing.lg) {
                    if isUnlocked {
                        statLabel(String(format: "$%.2f/unit", type.unitPrice), systemImage: "tag")
                        statLabel(
                            "\(Int(type.marketSize).formatted(.number.notation(.compactName).locale(Theme.gameLocale))) market",
                            systemImage: "chart.bar"
                        )
                        if let ceiling {
                            // The number that used to arrive one step too
                            // late: what this crew could review as.
                            Label("~\(ceiling) with this crew", systemImage: "person.3.fill")
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.scoreTint(ceiling))
                        }
                    } else {
                        statLabel("Research to unlock", systemImage: "lock.fill")
                    }
                }
            }
            .cardStyle()
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent : .clear, lineWidth: 2)
            )
            .opacity(isUnlocked ? 1 : 0.45)
        }
        .buttonStyle(.pressableRow)
        .disabled(!isUnlocked)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var accessibilityText: String {
        isUnlocked
            ? "\(type.name). \(type.blurb)"
            : "\(type.name), locked. Research to unlock."
    }

    private func statLabel(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.secondary)
    }
}

/// Relative effort for one phase as 1–5 filled dots.
struct EffortDots: View {
    let label: String
    let points: Double
    let tint: Color

    private var level: Int {
        min(5, max(1, Int((points / 60).rounded())))
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(index < level ? tint : Theme.chipBackground)
                        .frame(width: 5, height: 5)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) effort \(level) of 5")
    }
}

// MARK: - Step 2: greenfield or the codebase you already have

/// The trade, with both numbers on it and nothing else.
///
/// This game is scrupulous about showing its maths — `ShipForecast` exists
/// to stop the ship sheet quoting a number the launch will not produce —
/// and this is the one screen where a player commits to a quality ceiling
/// months before they see it. So the card states exactly two things: the
/// points already in the bank, and what the debt costs (a ceiling
/// multiplier and a bug-rate multiplier). Both are read from
/// `BalanceConfig.codebase` rather than restated, so they cannot drift
/// from the arithmetic `ProductSystem.ship` performs.
private struct FoundationStep: View {
    let engine: GameEngine
    let codebases: [Codebase]
    @Binding var selectedCodebaseID: String?

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            FoundationCard(
                title: "Start fresh",
                systemImage: "sparkles",
                blurb: "Empty pools, and nothing anyone has to live with.",
                isSelected: selectedCodebaseID == nil,
                select: { selectedCodebaseID = nil }
            ) {
                FoundationTerms(
                    headStart: "No head start",
                    ceiling: "No ceiling penalty",
                    bugs: "Standard bug rate",
                    tint: .secondary
                )
            }

            ForEach(codebases) { codebase in
                let config = engine.balance.codebase
                let debt = codebase.debt
                let ceiling = config.debtCeiling(debt)
                FoundationCard(
                    title: "Build on \(codebase.name)",
                    systemImage: "shippingbox.fill",
                    blurb: codebase.productsShipped == 1
                        ? "The codebase one shipped product left behind."
                        : "The codebase \(codebase.productsShipped) shipped products left behind.",
                    isSelected: selectedCodebaseID == codebase.id,
                    select: { selectedCodebaseID = codebase.id }
                ) {
                    FoundationTerms(
                        headStart: headStartLabel(codebase),
                        ceiling: debt > 0
                            ? "Quality ceiling ×\(ceiling.twoPlaces) — \(Int(debt.rounded())) debt"
                            : "No ceiling penalty — no debt yet",
                        bugs: debt > 0
                            ? "Bug rate ×\(config.bugRateMultiplier(debt).twoPlaces)"
                            : "Standard bug rate",
                        tint: debt > 0 ? Theme.warning : Theme.positiveCash
                    )
                }
            }

            Text("Refactoring is the only way to pay debt back down. It produces nothing else.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The head start as the share of each pool it fills — the number the
    /// player can compare against the build they just finished.
    private func headStartLabel(_ codebase: Codebase) -> String {
        guard let type = engine.content.productType(codebase.id),
              type.designPts > 0, type.codePts > 0, type.polishPts > 0
        else { return "A head start on every pool" }
        let share = (codebase.designPts / type.designPts
            + codebase.codePts / type.codePts
            + codebase.polishPts / type.polishPts) / 3
        return "Starts \(Int((share * 100).rounded()))% built — \(Int(codebase.codePts.rounded())) code points in the bank"
    }
}

private struct FoundationCard<Terms: View>: View {
    let title: String
    let systemImage: String
    let blurb: String
    let isSelected: Bool
    let select: () -> Void
    @ViewBuilder let terms: Terms

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: systemImage)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 38, height: 38)
                        .background(
                            Theme.chipBackground,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(blurb)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.accent)
                    }
                }
                terms
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.lg)
            .background(Theme.cardBackground, in: RoundedRectangle(
                cornerRadius: Theme.cornerRadius, style: .continuous
            ))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Exactly three lines, always in the same order: what you get, what the
/// ceiling costs, what the bugs cost.
private struct FoundationTerms: View {
    let headStart: String
    let ceiling: String
    let bugs: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            row("arrow.forward.circle.fill", headStart, Theme.positiveCash)
            row("gauge.with.dots.needle.33percent", ceiling, tint)
            row("ladybug.fill", bugs, tint)
        }
        .font(.footnote.monospacedDigit())
    }

    private func row(_ icon: String, _ text: String, _ color: Color) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 16)
            Text(text)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }
}

private extension Double {
    /// `0.82` — the form every multiplier in this sheet is quoted in.
    var twoPlaces: String {
        formatted(.number.precision(.fractionLength(2)))
    }
}

// MARK: - Step 3: topic

/// Where a build is aimed. Until "Hold the Category" this step graded only
/// the static `topic.fitByType` and never once read `state.market` — so the
/// screen where the market should decide something was the one screen that
/// could not see it. Now each cell carries the live demand multiplier and
/// the studio's standing, and the selected topic gets the full read
/// underneath: what the market is doing, what your name is worth there,
/// and — in a category you hold — where demand is likely to be by the time
/// this thing ships.
private struct TopicStep: View {
    let engine: GameEngine
    let selectedTypeID: String?
    @Binding var selectedTopicID: String?

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.md),
        GridItem(.flexible(), spacing: Theme.Spacing.md),
        GridItem(.flexible(), spacing: Theme.Spacing.md),
    ]

    private var categories: [CategorySnapshot] {
        engine.content.topics.map {
            CategorySnapshot(topic: $0, state: engine.state, balance: engine.balance)
        }
    }

    var body: some View {
        let categories = self.categories
        VStack(spacing: Theme.Spacing.lg) {
            LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
                ForEach(categories) { category in
                    TopicCell(
                        category: category,
                        fit: fit(for: category.topic),
                        ceiling: ceiling(for: category.topic),
                        isSelected: selectedTopicID == category.id,
                        select: { selectedTopicID = category.id }
                    )
                }
            }

            if let selected = categories.first(where: { $0.id == selectedTopicID }) {
                TopicMarketRead(
                    category: selected,
                    driftSigma: engine.balance.market.driftSigma
                )
            } else {
                Text("Demand shifts every week and your standing follows what you ship. "
                    + "Pick a topic to see both.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// The crew ceiling on this type in this topic: the type's number with
    /// the topic's fit folded in.
    private func ceiling(for topic: TopicDef) -> Int? {
        guard let selectedTypeID else { return nil }
        return ShipForecast.preStart(
            typeID: selectedTypeID, topicID: topic.id, codebaseID: nil,
            state: engine.state, balance: engine.balance, content: engine.content
        ).map { Int($0.quality.rounded()) }
    }

    /// Fit hint against the chosen type: above 1.0 -> great fit,
    /// below 1.0 -> poor fit, absent -> neutral (no hint).
    private func fit(for topic: TopicDef) -> TopicCell.Fit? {
        guard let selectedTypeID, let multiplier = topic.fitByType[selectedTypeID] else {
            return nil
        }
        if multiplier > 1.0 { return .great }
        if multiplier < 1.0 { return .poor }
        return nil
    }
}

/// The live read under the grid, for the topic in hand.
private struct TopicMarketRead: View {
    let category: CategorySnapshot
    let driftSigma: Double

    var body: some View {
        CardView(category.topic.name, systemImage: category.topic.iconSystemName) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(category.market.read)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Theme.Spacing.sm) {
                    Text("Your standing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    StandingBar(fraction: category.standingFraction, tint: category.tint)
                        .frame(maxWidth: 90)
                    Text("\(category.standingLabel) · \(category.tier)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(category.tint)
                }

                Text(category.fieldLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let read = category.forwardRead(driftSigma: driftSigma) {
                    HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                        Image(systemName: "binoculars.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.positiveCash)
                        Text(read)
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text("Hold this category — keep something selling here — and you get to "
                        + "read its demand weeks ahead before you commit a build to it.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct TopicCell: View {
    enum Fit {
        case great, poor

        var text: String {
            switch self {
            case .great: "Great fit"
            case .poor: "Poor fit"
            }
        }

        var tint: Color {
            switch self {
            case .great: Theme.positiveCash
            case .poor: Theme.warning
            }
        }
    }

    let category: CategorySnapshot
    let fit: Fit?
    /// The crew ceiling here, once a type is chosen.
    let ceiling: Int?
    let isSelected: Bool
    let select: () -> Void

    private var topic: TopicDef { category.topic }

    var body: some View {
        Button(action: select) {
            VStack(spacing: Theme.Spacing.xs) {
                Image(systemName: topic.iconSystemName)
                    .font(.title3)
                    .foregroundStyle(isSelected ? Theme.accent : .primary)
                    .frame(height: 26)
                Text(topic.name)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                // The live market, on the screen that decides what to aim a
                // build at: demand now, and the trend under it.
                HStack(spacing: 2) {
                    Image(systemName: category.market.direction.systemImage)
                        .font(.system(size: 8).weight(.bold))
                    Text(category.market.multiplierLabel)
                        .font(.caption2)
                        .monospacedDigit()
                }
                .foregroundStyle(category.market.band.figureTint)
                StandingBar(fraction: category.standingFraction, tint: category.tint)
                    .frame(height: 3)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .opacity(category.standing > 0 ? 1 : 0)
                Text(fit?.text ?? " ")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(fit?.tint ?? .clear)
                if let ceiling {
                    Text("~\(ceiling)")
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.scoreTint(ceiling))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                Theme.cardBackground,
                in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.pressableRow)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var accessibilityText: String {
        var parts = [topic.name]
        if let fit { parts.append(fit.text.lowercased()) }
        if let ceiling { parts.append("could review around \(ceiling)") }
        parts.append("demand \(category.market.multiplierLabel)")
        if category.standing > 0 {
            parts.append("your standing \(category.standingLabel)")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Step 4: name + focus

private struct DetailsStep: View {
    @Binding var name: String
    @Binding var focus: PhaseFocus
    let suggestion: String
    /// The crew's best case on this type and topic, with the one-line fix.
    let forecast: ShipForecast?
    /// The split the type demands, offered as the starting focus.
    let matching: PhaseFocus?
    let onNameEdited: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            if let forecast {
                PreStartForecastCard(forecast: forecast)
            }

            CardView("Name", systemImage: "textformat") {
                TextField("Product name", text: $name)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onChange(of: name) { _, newValue in
                        // A programmatic prefill matches the suggestion;
                        // anything else means the user took over.
                        if newValue != suggestion {
                            onNameEdited()
                        }
                    }
                    .accessibilityLabel("Product name")
            }

            CardView("Starting focus", systemImage: "slider.horizontal.3") {
                FocusEditor(focus: $focus, matching: matching)
            }
        }
        .onAppear {
            // Start on the split the type asks for, not a flat third each;
            // a player who wants to over-polish can still drag.
            if let matching, focus == .balanced { focus = matching }
        }
    }
}

/// "Best case with this crew and topic: 58" — the forecast the detail
/// screen shows, one step earlier, before the player commits.
private struct PreStartForecastCard: View {
    let forecast: ShipForecast

    var body: some View {
        let score = Int(forecast.quality.rounded())
        CardView("Best case with this crew", systemImage: "person.3.fill") {
            HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                PixelText(text: "\(score)", scale: 4, color: Theme.scoreTint(score), shadow: true)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(
                        forecast.crewCeiling >= 0.95
                            ? "Every pool full and no bugs would review around \(score)."
                            : (forecast.limitingFactor ?? "More work still pays — the pools aren't full.")
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    if forecast.topicFit < 0.95 {
                        Text("The topic is a poor match for the type (×\(forecast.topicFit.formatted(.number.precision(.fractionLength(2)).locale(Theme.gameLocale)))).")
                            .font(.caption)
                            .foregroundStyle(Theme.warning)
                    }
                    if forecast.codebaseCeiling < 0.99, let name = forecast.codebaseName {
                        Text("Built on \(name), carrying \(Int(forecast.codebaseDebt.rounded())) debt.")
                            .font(.caption)
                            .foregroundStyle(Theme.warning)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Best case with this crew: \(score) out of 100")
    }
}
