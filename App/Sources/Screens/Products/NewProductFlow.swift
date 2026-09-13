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
    /// M1: the product the flow just started. Setting it pushes the
    /// feature board — the last step of starting a product is saying what
    /// it *is*, and the board cannot exist before the product does.
    @State private var startedProductID: UUID?
    // MARK: S3 (product names)
    /// The Hall of Fame lives on the session's ledger; its names stay out
    /// of the suggestions.
    @Environment(\.gameSession) private var session
    /// How many times Shuffle was pressed: the batch index the seed hashes.
    @State private var nameReroll = 0
    /// The batch Shuffle replaced, kept out of the next one so three new
    /// names always come.
    @State private var shuffledAway: [String] = []
    /// The product a v2 is being started for. Its sequels lead the chips
    /// while the type and topic are still its own.
    @State private var sequelParentID: UUID?
    // MARK: end S3

    /// - Parameter initialTopicID: a topic to arrive with already selected,
    ///   for deep links from the market screens (`Route.newProduct`). The
    ///   flow still opens on the type step; the topic step shows it chosen.
    init(
        engine: GameEngine,
        initialTopicID: String? = nil,
        // MARK: K2 (product lifecycle)
        successorOf: UUID? = nil,
        // MARK: end K2
        // MARK: S3 (product names) — the debug landing on the name step.
        landingOnName: ProductNameLanding? = nil
        // MARK: end S3
    ) {
        self.engine = engine
        _selectedTopicID = State(initialValue: initialTopicID)
        // MARK: K2 (product lifecycle) — "Build its v2" from a product's
        // page: type, topic, codebase and name filled, straight to the
        // details. Back still walks every step.
        if let successorOf, let parent = engine.state.product(id: successorOf) {
            _selectedTypeID = State(initialValue: parent.typeID)
            _selectedTopicID = State(initialValue: parent.topicID)
            _selectedCodebaseID = State(
                initialValue: engine.state.availableCodebases(typeID: parent.typeID).first?.id
            )
            // MARK: S3 (product names) — the sequels lead: "Round 2",
            // "Round II", "Round Next".
            _sequelParentID = State(initialValue: parent.id)
            _name = State(
                initialValue: engine.state.sequelNameSuggestions(parentID: parent.id, content: engine.content).first
                    ?? Self.lifecycleName(for: parent)
            )
            // MARK: end S3
            _step = State(initialValue: .details)
        }
        // MARK: end K2
        // MARK: S3 (product names)
        if let landingOnName {
            _selectedTypeID = State(initialValue: landingOnName.typeID)
            _selectedTopicID = State(initialValue: landingOnName.topicID)
            _nameReroll = State(initialValue: landingOnName.rerolls)
            let away = landingOnName.rerolls > 0
                ? engine.state.productNameSuggestions(
                    typeID: landingOnName.typeID, topicID: landingOnName.topicID,
                    reroll: landingOnName.rerolls - 1, content: engine.content
                )
                : []
            _shuffledAway = State(initialValue: away)
            let first = engine.state.productNameSuggestions(
                typeID: landingOnName.typeID, topicID: landingOnName.topicID,
                reroll: landingOnName.rerolls, content: engine.content,
                alsoTaken: Set(away)
            ).first ?? ""
            _name = State(initialValue: landingOnName.typedName ?? first)
            _nameEdited = State(initialValue: landingOnName.typedName != nil)
            _step = State(initialValue: .details)
        }
        // MARK: end S3
    }

    // MARK: K2 (product lifecycle)

    /// "Round 6" → "Round 6 v2"; "Round 6 v2" → "Round 6 v3".
    static func lifecycleName(for parent: Product) -> String {
        let parts = parent.name.split(separator: " ")
        if let last = parts.last, last.hasPrefix("v"), let number = Int(last.dropFirst()), parts.count > 1 {
            return parts.dropLast().joined(separator: " ") + " v\(number + 1)"
        }
        return parent.name + " v2"
    }

    /// The type step's "v2 of…" chips: the same prefill as above.
    private func prefillSuccessor(of parent: Product) {
        selectedTypeID = parent.typeID
        selectedTopicID = parent.topicID
        selectedCodebaseID = engine.state.availableCodebases(typeID: parent.typeID).first?.id
        // MARK: S3 (product names) — the sequels lead, and a v2 picked
        // from the chips is still a suggestion, not the player's own words.
        sequelParentID = parent.id
        nameReroll = 0
        shuffledAway = []
        name = nameSuggestions.first ?? Self.lifecycleName(for: parent)
        nameEdited = false
        // MARK: end S3
        withAnimation(Theme.Motion.entrance) { step = .details }
    }

    // MARK: end K2

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
            // MARK: M1 (feature board)
            .navigationDestination(item: $startedProductID) { productID in
                FeatureBoardScreen(engine: engine, productID: productID)
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { dismiss() }
                                .font(.system(.headline, design: .rounded))
                        }
                    }
            }
            // MARK: end M1 (feature board)
        }
        .interactiveDismissDisabled(step != .type)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .type:
            // MARK: K2 (product lifecycle) — "v2 of…".
            LifecycleSequelRow(engine: engine) { prefillSuccessor(of: $0) }
            // MARK: end K2
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
                // MARK: S3 (product names)
                suggestions: nameSuggestions,
                refusal: nameClaim?.refusal,
                pickName: pickName,
                shuffleNames: shuffleNames,
                // MARK: end S3
                forecast: preStartForecast,
                matching: selectedTypeID.flatMap { engine.content.productType($0) }.map { PhaseFocus.matching(type: $0) },
                boardSlots: boardSlots
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

    /// M1: how many cards the chosen type's board takes, for the details
    /// page to say what happens after Start.
    private var boardSlots: Int? {
        selectedTypeID
            .flatMap { engine.content.productType($0) }
            .map { FeatureBoard.slots(for: $0, balance: engine.balance) }
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
            // MARK: S3 (product names) — a name the run already has is refused.
            && nameClaim == nil
            // MARK: end S3
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
            // MARK: S3 (product names)
            name = nameSuggestions.first ?? ""
            // MARK: end S3
        }
        withAnimation(Theme.Motion.entrance) {
            step = next
        }
    }

    private func start() {
        guard let typeID = selectedTypeID, let topicID = selectedTopicID, canStart else { return }
        // MARK: T2 (the build) — J4: a v2 picked from the chips (or "Build
        // its v2") and still of its parent's type and topic is declared:
        // shipped beside the parent, it makes the parent the old version.
        let declaredParent = sequelParentID.flatMap { id in
            engine.state.product(id: id).flatMap { $0.typeID == typeID && $0.topicID == topicID ? id : nil }
        }
        // MARK: end T2
        let action: GameAction = if let declaredParent {
            // MARK: T2 (the build)
            .startProductAsV2(
                typeID: typeID, topicID: topicID, name: trimmedName,
                focus: focus, codebaseID: selectedCodebaseID, parentID: declaredParent
            )
            // MARK: end T2
        } else if let codebaseID = selectedCodebaseID {
            .startProductOnCodebase(
                typeID: typeID, topicID: topicID, name: trimmedName,
                focus: focus, codebaseID: codebaseID
            )
        } else {
            .startProduct(typeID: typeID, topicID: topicID, name: trimmedName, focus: focus)
        }
        let events = shell.toasts.send(
            action, to: engine, rejected: "Every development slot is busy."
        )
        // M1: straight on to the board, which is where the product is
        // actually decided. A refused start (every slot busy) has no
        // product to open one for and closes as it always did.
        guard !events.isEmpty, let started = engine.state.products.last else {
            dismiss()
            return
        }
        startedProductID = started.id
    }

    // MARK: - Name suggestion
    // MARK: S3 (product names)

    /// The three names the chips offer: a v2's sequels while the type and
    /// topic are its parent's and Shuffle has not been pressed, otherwise
    /// `ProductNameGenerator` over `ProductNames.json`, seeded from the run
    /// and the reroll index — never the engine's RNG — and clear of every
    /// name in the run, the Hall of Fame and the batch just shuffled away.
    private var nameSuggestions: [String] {
        guard let typeID = selectedTypeID, let topicID = selectedTopicID else { return [] }
        let hall = Set((session?.ledger.hall ?? []).map(\.productName))
        if nameReroll == 0, let parentID = sequelParentID,
           let parent = engine.state.product(id: parentID),
           parent.typeID == typeID, parent.topicID == topicID {
            let sequels = engine.state.sequelNameSuggestions(
                parentID: parentID, content: engine.content, alsoTaken: hall
            )
            if !sequels.isEmpty { return sequels }
        }
        return engine.state.productNameSuggestions(
            typeID: typeID, topicID: topicID, reroll: nameReroll,
            content: engine.content, alsoTaken: hall.union(shuffledAway)
        )
    }

    /// Who already has the typed name, for the refusal under the field.
    private var nameClaim: ProductNameClaim? {
        engine.state.productNameClaim(trimmedName)
    }

    /// A chip tapped: the field takes it, and it is a suggestion again —
    /// the next Shuffle may replace it.
    private func pickName(_ picked: String) {
        name = picked
        nameEdited = false
    }

    /// Three different names for the same product. A name the player
    /// typed stays in the field; only the chips move.
    private func shuffleNames() {
        shuffledAway = nameSuggestions
        nameReroll += 1
        if !nameEdited, let first = nameSuggestions.first {
            name = first
        }
    }

    // MARK: end S3
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
                        // A spin-out's non-compete (WS-H): greyed, with the date.
                        lockedUntil: engine.state.topicUnlockDay(category.id)
                            .map { GameState.dateLabel(forDay: $0) },
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
    /// The date a non-compete lifts, when one covers this topic. A locked
    /// cell is greyed and cannot be selected.
    var lockedUntil: String? = nil
    let isSelected: Bool
    let select: () -> Void

    private var topic: TopicDef { category.topic }
    private var isLocked: Bool { lockedUntil != nil }

    var body: some View {
        Button(action: select) {
            VStack(spacing: Theme.Spacing.xs) {
                Image(systemName: isLocked ? "lock.fill" : topic.iconSystemName)
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
                if let lockedUntil {
                    Text("Non-compete until \(lockedUntil)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.warning)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                } else {
                    Text(fit?.text ?? " ")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(fit?.tint ?? .clear)
                }
                if let ceiling, !isLocked {
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
            .opacity(isLocked ? 0.45 : 1)
        }
        .buttonStyle(.pressableRow)
        .disabled(isLocked)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var accessibilityText: String {
        var parts = [topic.name]
        if let lockedUntil { parts.append("locked by a non-compete until \(lockedUntil)") }
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
    // MARK: S3 (product names)
    let suggestions: [String]
    /// "You already have a Round 6." — why Start is off, `nil` when free.
    let refusal: String?
    let pickName: (String) -> Void
    let shuffleNames: () -> Void
    // MARK: end S3
    /// The crew's best case on this type and topic, with the one-line fix.
    let forecast: ShipForecast?
    /// The split the type demands, offered as the starting focus.
    let matching: PhaseFocus?
    /// M1: how many feature slots this type's board has, so the page can
    /// say what Start leads to.
    var boardSlots: Int?
    let onNameEdited: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            if let forecast {
                PreStartForecastCard(forecast: forecast)
            }

            CardView("Name", systemImage: "textformat") {
                // MARK: S3 (product names)
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    TextField("Product name", text: $name)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onChange(of: name) { _, newValue in
                            // A programmatic prefill is one of the
                            // suggestions; anything else means the user
                            // took over.
                            if !suggestions.contains(newValue) {
                                onNameEdited()
                            }
                        }
                        .accessibilityLabel("Product name")
                    if let refusal {
                        Label(refusal, systemImage: "exclamationmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !suggestions.isEmpty {
                        ProductNameChips(
                            suggestions: suggestions,
                            current: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            pick: pickName,
                            shuffle: shuffleNames
                        )
                    }
                }
                // MARK: end S3
            }

            CardView("Starting focus", systemImage: "slider.horizontal.3") {
                FocusEditor(focus: $focus, matching: matching)
            }

            // MARK: M1 (feature board)
            if let boardSlots {
                CardView("Next: the board", systemImage: "square.grid.2x2.fill") {
                    Text(
                        "Start opens the feature board — \(boardSlots) slots to fill from the cards your research and your team can build. You can change it until design is finished."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            // MARK: end M1 (feature board)
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
