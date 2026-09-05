import PixelKit
import SwiftUI
import TycoonContent
import TycoonEngine

/// The pages of the new-game flow, in order.
private enum OnboardingStep: Int, CaseIterable, Comparable {
    // Iteration 7: `.custom` (R4) before You and `.heirlooms` (R2) after
    // Stakes, each shown only when `NewGameOptions` asks; the step list
    // is `NewGameFlow.steps`, so the flow walks the visible ones.
    case custom, founder, company, difficulty, heirlooms, intro

    var title: String {
        switch self {
        case .custom: "Custom"
        case .founder: "You"
        case .company: "Studio"
        case .difficulty: "Stakes"
        case .heirlooms: "Heirlooms"
        case .intro: "Ready"
        }
    }

    static func < (lhs: OnboardingStep, rhs: OnboardingStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Full-screen new-game flow: who you are, what the studio is called, how
/// hard it should be, and a four-panel look at what you are about to run.
///
/// Shown on first launch (no save) and from Settings → "Start a new
/// game…". It is the only place the founder and company names are set —
/// nothing in the app is called "Founder" or "Startup Studio" any more.
/// Iteration 7: how the flow is opened. The defaults are the flow the
/// game always had; the title menu's rows (R3/R4) and the ledger (R2)
/// turn pages on.
struct NewGameOptions {
    /// Show the Custom page (seed, difficulty, rivals, incumbent, cash). R4.
    var showsCustomStep = false
    /// Show the Heirlooms page — only when the ledger offers something. R2.
    var showsHeirloomsStep = false
    /// A code that arrived by URL or the *From a code* row, prefilling
    /// the Custom page. R4.
    var seedCode: SeedCode?
    /// The endings the ledger has, for the origin lock and the earned
    /// looks (R4). Passed in rather than read from the environment: a
    /// full-screen cover does not see the presenting view's environment.
    var endingsReached: Set<EndingKind> = []

    static let standard = NewGameOptions()

    /// The origins padlocked on the Stakes page.
    var lockedOrigins: Set<FoundingOrigin> {
        Unlocks.lockedOrigins(endingsReached: endingsReached)
    }
}

struct NewGameFlow: View {
    /// Content catalog, for founder-name suggestions.
    let content: ContentCatalog
    /// Which optional pages the flow shows (iteration 7).
    var options: NewGameOptions = .standard
    /// Called with everything the flow collected; the session builds the
    /// engine from it. Iteration 7 (R4): the fifth value is what the
    /// custom page added — `.standard` on the plain path.
    let onStart: (FounderProfile, String, Difficulty, FoundingOrigin, RunSetup) -> Void
    /// Shown only when there is a game to go back to (Settings entry).
    var onCancel: (() -> Void)?

    @State private var step: OnboardingStep = .founder
    @State private var openedOnFirstStep = false

    /// The pages this flow walks, in order.
    private var steps: [OnboardingStep] {
        OnboardingStep.allCases.filter { candidate in
            switch candidate {
            case .custom: options.showsCustomStep
            case .heirlooms: options.showsHeirloomsStep
            default: true
            }
        }
    }

    private var previousStep: OnboardingStep? {
        guard let index = steps.firstIndex(of: step), index > 0 else { return nil }
        return steps[index - 1]
    }

    private var nextStep: OnboardingStep {
        guard let index = steps.firstIndex(of: step), index + 1 < steps.count else { return .intro }
        return steps[index + 1]
    }
    @State private var founderName = ""
    @State private var founderNameEdited = false
    @State private var companyName = ""
    @State private var companyNameEdited = false
    @State private var archetype: FounderArchetype = .hacker
    @State private var difficulty: Difficulty = .normal
    @State private var origin: FoundingOrigin = .garage
    @State private var appearanceIndex = 0
    @State private var nameShuffle = 0
    @State private var introPage = 0
    /// Iteration 7 (R4): what the custom page collects.
    @State private var custom = CustomChoices()
    @State private var prefilledFromCode = false

    /// Appearance seeds the picker cycles through. Fixed and small so the
    /// founder you chose is the founder you get.
    static let appearanceSeeds: [UInt64] = (0..<24).map { 0x5EED_0000 &+ UInt64($0) &* 2_654_435_761 }

    /// The 24 base looks and, after them, one per ending the ledger has
    /// reached (R4), each with the ending it was earned for.
    private var looks: [(seed: UInt64, earnedFor: EndingKind?)] {
        Self.appearanceSeeds.map { ($0, nil) }
            + Unlocks.earnedLookSeeds(endingsReached: options.endingsReached).map { ($0.seed, $0.ending) }
    }

    private var appearanceSeed: UInt64 {
        looks[appearanceIndex % looks.count].seed
    }

    /// The ending the current look was earned for, if it is one of those.
    private var currentLookEarnedFor: EndingKind? {
        looks[appearanceIndex % looks.count].earnedFor
    }

    private var suggestedFounderName: String {
        StudioNameGenerator.founderName(index: nameShuffle, names: content.names)
    }

    private var suggestedCompanyName: String {
        StudioNameGenerator.companyName(index: nameShuffle)
    }

    private var resolvedFounderName: String {
        let trimmed = founderName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? suggestedFounderName : trimmed
    }

    private var resolvedCompanyName: String {
        let trimmed = companyName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? suggestedCompanyName : trimmed
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                stepContent
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.xl)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Theme.screenBackground)
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .onAppear {
            if founderName.isEmpty { founderName = suggestedFounderName }
            if companyName.isEmpty { companyName = suggestedCompanyName }
            if !openedOnFirstStep, let first = steps.first {
                openedOnFirstStep = true
                step = first
            }
            // R4: a code from a card or a URL fills the custom page and
            // sets the origin the Stakes page opens on.
            if !prefilledFromCode, let code = options.seedCode {
                prefilledFromCode = true
                origin = custom.prefill(with: code)
                difficulty = code.difficulty
            }
        }
        // R4: the custom page's difficulty is the run's; the Stakes page
        // keeps only the origins on this path.
        .onChange(of: custom.difficulty) { _, new in
            if options.showsCustomStep { difficulty = new }
        }
        // A code typed later on the page carries its own origin too.
        .onChange(of: custom.entry) { old, new in
            if case .code(let code) = new, old != new {
                origin = code.origin
                custom.difficulty = code.difficulty
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: Theme.Spacing.sm) {
            PixelText(text: "Startup Studio", scale: 3, color: Theme.pixelAccent, shadow: true)
                .padding(.top, Theme.Spacing.md)
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(steps, id: \.self) { candidate in
                    Capsule()
                        .fill(candidate <= step ? Theme.pixelAccent : Theme.chipBackground)
                        .frame(height: 4)
                        .animation(Theme.Motion.entrance, value: step)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .accessibilityLabel("Step \((steps.firstIndex(of: step) ?? 0) + 1) of \(steps.count): \(step.title)")
        }
        .padding(.bottom, Theme.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .custom: customStep
        case .founder: founderStep
        case .company: companyStep
        case .difficulty: difficultyStep
        case .heirlooms: heirloomsStep
        case .intro: introStep
        }
    }

    // MARK: - Iteration 7 placeholders

    /// R4: seed, difficulty, rivals, incumbent, starting cash, and the
    /// line about leaderboards.
    private var customStep: some View {
        CustomStepContent(choices: $custom, defaultCash: DifficultyCash.startingCash(for:))
    }

    /// R2 replaces this with `HeirloomsStep` (one person, perk or deed
    /// from the ledger, spent once).
    private var heirloomsStep: some View {
        StepHeadline(
            title: "One thing from the last company",
            detail: "A person, a perk, or the deed. It carries once, and a company that carries one is unranked."
        )
    }

    // MARK: - Step 1: the founder

    private var founderStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            StepHeadline(
                title: "Who's starting this?",
                detail: "Your name goes on the incorporation papers and on every review."
            )

            CardView("Your name", systemImage: "person.fill") {
                HStack(spacing: Theme.Spacing.sm) {
                    TextField("Founder name", text: $founderName)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .onChange(of: founderName) { _, _ in founderNameEdited = true }
                    ShuffleButton(label: "Shuffle names") {
                        nameShuffle += 1
                        if !founderNameEdited { founderName = suggestedFounderName }
                        if !companyNameEdited { companyName = suggestedCompanyName }
                    }
                }
            }

            CardView("Look", systemImage: "face.smiling") {
                VStack(spacing: Theme.Spacing.md) {
                    HStack(spacing: Theme.Spacing.lg) {
                        Button {
                            appearanceIndex = (appearanceIndex + looks.count - 1) % looks.count
                        } label: {
                            Image(systemName: "chevron.left.circle.fill").font(.title2)
                        }
                        .accessibilityLabel("Previous look")

                        PixelPortrait(seed: appearanceSeed, isFounder: true, size: 96)
                            .id(appearanceSeed)
                            .transition(Theme.Motion.transition(.scale.combined(with: .opacity)))

                        Button {
                            appearanceIndex = (appearanceIndex + 1) % looks.count
                        } label: {
                            Image(systemName: "chevron.right.circle.fill").font(.title2)
                        }
                        .accessibilityLabel("Next look")
                    }
                    .animation(Theme.Motion.selection, value: appearanceIndex)

                    Text("Look \(appearanceIndex + 1) of \(looks.count)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    // R4: the ribbon on a look an ending earned.
                    if let earnedFor = currentLookEarnedFor {
                        EarnedLookRibbon(ending: earnedFor)
                            .transition(Theme.Motion.transition(.opacity))
                    }
                }
                .frame(maxWidth: .infinity)
            }

            CardView("What you're good at", systemImage: "sparkles") {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(FounderArchetype.allCases, id: \.self) { candidate in
                        ArchetypeRow(
                            archetype: candidate,
                            isSelected: candidate == archetype
                        ) {
                            withAnimation(Theme.Motion.selection) { archetype = candidate }
                        }
                    }
                }
            }
        }
        .padding(.top, Theme.Spacing.lg)
    }

    // MARK: - Step 2: the company

    private var companyStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            StepHeadline(
                title: "Name the studio",
                detail: "Two people in a garage, one laptop, and a name you'll have to defend."
            )

            CardView("Company name", systemImage: "building.2.fill") {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    HStack(spacing: Theme.Spacing.sm) {
                        TextField("Company name", text: $companyName)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .onChange(of: companyName) { _, _ in companyNameEdited = true }
                        ShuffleButton(label: "Shuffle company names") {
                            nameShuffle += 1
                            companyName = suggestedCompanyName
                            companyNameEdited = false
                        }
                    }
                    PixelPanel {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            PixelText(text: resolvedCompanyName, scale: 2, color: Theme.pixelInk)
                            Text("Founded by \(resolvedFounderName)")
                                .font(.footnote)
                                .foregroundStyle(Theme.pixelInk.opacity(0.7))
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Sign preview: \(resolvedCompanyName), founded by \(resolvedFounderName)")
                }
            }
        }
        .padding(.top, Theme.Spacing.lg)
    }

    // MARK: - Step 3: the stakes

    private var difficultyStep: some View {
        StakesStepContent(
            origin: $origin, difficulty: $difficulty,
            showsDifficulty: !options.showsCustomStep,
            lockedOrigins: options.lockedOrigins
        )
    }

    // MARK: - Step 4: the illustrated intro

    private var introStep: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            StepHeadline(
                title: "Here's the job",
                detail: "Four things you'll be juggling from day one."
            )
            TabView(selection: $introPage) {
                ForEach(Array(IntroPanel.all.enumerated()), id: \.offset) { index, panel in
                    IntroPanelView(panel: panel, appearanceSeed: appearanceSeed)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .frame(height: 420)
        }
        .padding(.top, Theme.Spacing.lg)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: Theme.Spacing.md) {
            if let previous = previousStep {
                Button {
                    withAnimation(Theme.Motion.entrance) { step = previous }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.xs)
                }
                .buttonStyle(.bordered)
            } else if let onCancel {
                Button("Cancel", role: .cancel) { onCancel() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
            }

            Button {
                advance()
            } label: {
                Text(step == .intro ? "Start the company" : "Next")
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.xs)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        }
        .padding(Theme.Spacing.lg)
        .background(.bar)
    }

    private func advance() {
        Haptics.tap()
        Sounds.play(.tap)
        guard step == .intro else {
            withAnimation(Theme.Motion.entrance) {
                step = nextStep
            }
            return
        }
        Sounds.play(.goal)
        Haptics.success()
        let profile = FounderProfile(
            name: resolvedFounderName,
            archetype: archetype,
            appearanceSeed: appearanceSeed
        )
        onStart(profile, resolvedCompanyName, difficulty, origin, runSetup)
    }

    /// R4: what the custom page adds. `.standard` unless the page was
    /// shown and something on it moved.
    private var runSetup: RunSetup {
        guard options.showsCustomStep else { return .standard }
        let defaultCash = DifficultyCash.startingCash(for: custom.difficulty)
        return RunSetup(
            seed: custom.entry.seed,
            rules: custom.rules(defaultCash: defaultCash),
            mode: custom.mode(defaultCash: defaultCash)
        )
    }
}

/// The Stakes page: how the company starts (WS-H's four origins), then
/// how hard the market is. Internal so the snapshot suite can render the
/// page without driving the flow to it.
struct StakesStepContent: View {
    @Binding var origin: FoundingOrigin
    @Binding var difficulty: Difficulty
    /// Off on the custom path (R4), where the rows live on the custom page.
    var showsDifficulty = true
    /// The origins padlocked (R4); `nil` lets the picker read the session.
    var lockedOrigins: Set<FoundingOrigin>?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            StepHeadline(
                title: "How does it start?",
                detail: "Four ways to found it. Each one costs something the others don't."
            )
            OriginPicker(origin: $origin, lockedOrigins: lockedOrigins)

            if showsDifficulty {
                StepHeadline(
                    title: "How hard should this be?",
                    detail: "Difficulty scales starting cash, costs, and how forgiving the market is."
                )
                .padding(.top, Theme.Spacing.sm)
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(Difficulty.allCases, id: \.self) { candidate in
                        StakesDifficultyRow(difficulty: candidate, isSelected: candidate == difficulty) {
                            withAnimation(Theme.Motion.selection) { difficulty = candidate }
                        }
                    }
                }
            }
        }
        .padding(.top, Theme.Spacing.lg)
    }
}

/// R4: the ribbon under a look an ending earned.
struct EarnedLookRibbon: View {
    let ending: EndingKind

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "rosette")
                .font(.caption2.weight(.bold))
            PixelText(text: Unlocks.ribbon(for: ending), scale: 2, color: Theme.ink(on: Theme.pixelAccent))
        }
        .foregroundStyle(Theme.ink(on: Theme.pixelAccent))
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 4)
        .background(Theme.pixelAccent)
        .overlay {
            PixelPanelBorder(thickness: 2, corner: 2)
                .fill(Theme.pixelInk.opacity(0.55))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Earned look: \(ending.headline)")
    }
}

// MARK: - Pieces

struct StepHeadline: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.system(.title2, design: .rounded).weight(.bold))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ShuffleButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            Sounds.play(.tap)
            action()
        } label: {
            Image(systemName: "die.face.5.fill")
                .font(.body.weight(.semibold))
                .padding(Theme.Spacing.sm)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(label)
    }
}

/// One selectable founder archetype with the skill spread it starts from.
private struct ArchetypeRow: View {
    let archetype: FounderArchetype
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? Theme.accent : .secondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(archetype.displayName)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(blurb)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: Theme.Spacing.sm) {
                        SkillChip(label: "Code", value: spread.coding, tint: Theme.codePhase)
                        SkillChip(label: "Design", value: spread.design, tint: Theme.designPhase)
                        SkillChip(label: "Sales", value: spread.marketing, tint: Theme.polishPhase)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.tertiary))
            }
            .padding(Theme.Spacing.md)
            .background(
                isSelected ? Theme.accent.opacity(0.10) : Color.clear,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// The starting spread each archetype gets. Mirrors the engine's
    /// archetype table so the preview and the first day agree.
    private var spread: (coding: Int, design: Int, marketing: Int) {
        switch archetype {
        case .hacker: (55, 25, 20)
        case .designer: (25, 55, 20)
        case .hustler: (30, 25, 55)
        }
    }

    private var icon: String {
        switch archetype {
        case .hacker: "chevron.left.forwardslash.chevron.right"
        case .designer: "paintbrush.pointed.fill"
        case .hustler: "megaphone.fill"
        }
    }

    private var blurb: String {
        switch archetype {
        case .hacker: "You can build the whole thing yourself. Getting anyone to look at it is the hard part."
        case .designer: "Your first build will feel good. It will also be late."
        case .hustler: "You can sell it before it exists. Then you have to make it."
        }
    }
}

private struct SkillChip: View {
    let label: String
    let value: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(Theme.Typography.number(.caption2, weight: .bold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 3)
        .background(tint.opacity(0.12), in: Capsule())
        .accessibilityLabel("\(label) \(value)")
    }
}

struct StakesDifficultyRow: View {
    let difficulty: Difficulty
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: difficulty.systemImage)
                    .font(.title3)
                    .foregroundStyle(isSelected ? Theme.accent : .secondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(difficulty.displayName)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(difficulty.blurb)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.tertiary))
            }
            .padding(Theme.Spacing.md)
            .background(
                isSelected ? Theme.accent.opacity(0.10) : Color.clear,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Intro panels

/// One page of the illustrated intro.
private struct IntroPanel {
    let title: String
    let body: String
    let kind: Kind

    enum Kind {
        case office
        case home
        case products
        case business
    }

    static let all: [IntroPanel] = [
        IntroPanel(
            title: "The office",
            body: "It starts in a garage with one desk. Hire people and it grows into a loft, a studio, a campus — every move costs rent you have to keep earning.",
            kind: .office
        ),
        IntroPanel(
            title: "The life",
            body: "You have energy, health, a mood, and someone waiting at home. Crunch weeks buy you output and cost you all four.",
            kind: .home
        ),
        IntroPanel(
            title: "The products",
            body: "Design, code, polish. Ship it and the press reviews it — your first one will be rough. Then it earns, decays, and needs updates.",
            kind: .products
        ),
        IntroPanel(
            title: "The business",
            body: "Contracts pay the bills while products ramp. Watch the market, run campaigns, take a loan if you must — and keep an eye on the rivals.",
            kind: .business
        ),
    ]
}

private struct IntroPanelView: View {
    let panel: IntroPanel
    let appearanceSeed: UInt64

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            PixelPanel(contentPadding: Theme.Spacing.sm) {
                illustration
                    .frame(maxWidth: .infinity)
            }
            PixelSectionTitle(title: panel.title)
            Text(panel.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.xs)
    }

    @ViewBuilder
    private var illustration: some View {
        switch panel.kind {
        case .office:
            OfficeSceneView(
                tier: .garage,
                occupants: [
                    Occupant(
                        id: UUID(), appearance: CharacterAppearance(seed: appearanceSeed),
                        status: .coding, isFounder: true
                    ),
                ]
            )
        case .home:
            HomeSceneView(
                tier: .studioFlat,
                occupants: HomeOccupants(founder: CharacterAppearance(seed: appearanceSeed)),
                activity: .relaxing,
                mood: .okay
            )
        case .products:
            PixelSceneView(
                placements: ActivitySceneComposer.compose(
                    style: .cinema, appearance: CharacterAppearance(seed: appearanceSeed)
                ),
                sceneSize: ActivitySceneComposer.sceneSize(),
                accessibilityLabel: "A product on a screen"
            )
        case .business:
            PixelSceneView(
                placements: ActivitySceneComposer.compose(
                    style: .restaurant, appearance: CharacterAppearance(seed: appearanceSeed)
                ),
                sceneSize: ActivitySceneComposer.sceneSize(),
                accessibilityLabel: "A client meeting"
            )
        }
    }
}

#Preview {
    NewGameFlow(content: (try? ContentCatalog.loadBundled()) ?? .init(
        productTypes: [], topics: [], techTree: [], events: [],
        names: NamePools(firstNames: [], lastNames: [], clientCompanies: [])
    )) { _, _, _, _, _ in }
}
