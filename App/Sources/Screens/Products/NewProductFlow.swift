import SwiftUI
import TycoonContent
import TycoonEngine

/// The three pages of the new-product flow.
private enum NewProductStep: Int, CaseIterable, Comparable {
    case type, topic, details

    var title: String {
        switch self {
        case .type: "Type"
        case .topic: "Topic"
        case .details: "Details"
        }
    }

    static func < (lhs: NewProductStep, rhs: NewProductStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Three-step sheet for starting a new product:
/// 1. pick a type, 2. pick a topic, 3. name it and set the starting focus.
/// Ends with `.startProduct` sent to the engine.
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
    @State private var selectedTopicID: String?
    @State private var name = ""
    @State private var focus: PhaseFocus = .balanced
    /// Once the user types their own name, stop regenerating suggestions.
    @State private var nameEdited = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                StepIndicator(current: step)
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
        case .topic:
            TopicStep(
                topics: engine.content.topics,
                selectedTypeID: selectedTypeID,
                selectedTopicID: $selectedTopicID
            )
        case .details:
            DetailsStep(name: $name, focus: $focus, suggestion: suggestion) {
                nameEdited = true
            }
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: Theme.Spacing.md) {
            if let previous = NewProductStep(rawValue: step.rawValue - 1) {
                Button {
                    withAnimation(.spring(duration: 0.3)) {
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
                    Label("Start building", systemImage: "hammer.fill")
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

    private var canAdvance: Bool {
        switch step {
        case .type: selectedTypeID != nil
        case .topic: selectedTopicID != nil
        case .details: false
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canStart: Bool {
        !trimmedName.isEmpty && selectedTypeID != nil && selectedTopicID != nil
    }

    private func advance() {
        guard let next = NewProductStep(rawValue: step.rawValue + 1) else { return }
        if next == .details, !nameEdited {
            name = suggestion
        }
        withAnimation(.spring(duration: 0.3)) {
            step = next
        }
    }

    private func start() {
        guard let typeID = selectedTypeID, let topicID = selectedTopicID, canStart else { return }
        shell.toasts.send(
            .startProduct(typeID: typeID, topicID: topicID, name: trimmedName, focus: focus),
            to: engine,
            rejected: "Every development slot is busy."
        )
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

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(NewProductStep.allCases, id: \.rawValue) { step in
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
        .animation(.spring(duration: 0.3), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current.rawValue + 1) of 3: \(current.title)")
    }
}

// MARK: - Step 1: type

private struct TypeStep: View {
    let engine: GameEngine
    @Binding var selectedTypeID: String?

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            ForEach(engine.content.productTypes) { type in
                TypeCard(
                    type: type,
                    // Research unlocks count, not just `unlockedFromStart`.
                    isUnlocked: engine.state.isProductTypeUnlocked(type.id, content: engine.content),
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
                            "\(Int(type.marketSize).formatted(.number.notation(.compactName))) market",
                            systemImage: "chart.bar"
                        )
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
        .buttonStyle(.plain)
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
private struct EffortDots: View {
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

// MARK: - Step 2: topic

private struct TopicStep: View {
    let topics: [TopicDef]
    let selectedTypeID: String?
    @Binding var selectedTopicID: String?

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.md),
        GridItem(.flexible(), spacing: Theme.Spacing.md),
        GridItem(.flexible(), spacing: Theme.Spacing.md),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
            ForEach(topics) { topic in
                TopicCell(
                    topic: topic,
                    fit: fit(for: topic),
                    isSelected: selectedTopicID == topic.id,
                    select: { selectedTopicID = topic.id }
                )
            }
        }
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

    let topic: TopicDef
    let fit: Fit?
    let isSelected: Bool
    let select: () -> Void

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
                Text(fit?.text ?? " ")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(fit?.tint ?? .clear)
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
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var accessibilityText: String {
        if let fit {
            "\(topic.name), \(fit.text.lowercased())"
        } else {
            topic.name
        }
    }
}

// MARK: - Step 3: name + focus

private struct DetailsStep: View {
    @Binding var name: String
    @Binding var focus: PhaseFocus
    let suggestion: String
    let onNameEdited: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
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
                FocusEditor(focus: $focus)
            }
        }
    }
}
