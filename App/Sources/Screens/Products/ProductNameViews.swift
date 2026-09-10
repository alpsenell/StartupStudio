import SwiftUI
import TycoonContent
import TycoonEngine

// MARK: S3 (product names)

/// Iteration 16 — S3. The name card's three suggestions as pixel chips and
/// the *Shuffle* tile beside them. The chip that matches the field is lit;
/// tapping one fills the field with it.
struct ProductNameChips: View {
    let suggestions: [String]
    let current: String
    let pick: (String) -> Void
    let shuffle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            PixelFlow(wordSpacing: Theme.Spacing.sm, lineSpacing: Theme.Spacing.sm) {
                ForEach(suggestions, id: \.self) { name in
                    Button { pick(name) } label: {
                        ProductNameChipLabel(name: name, isCurrent: name == current)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Name it \(name)")
                    .accessibilityAddTraits(name == current ? .isSelected : [])
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                Haptics.tap()
                Sounds.play(.tap)
                shuffle()
            } label: {
                Image(systemName: "die.face.5.fill")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Theme.ink(on: Theme.pixelAccent))
                    .frame(width: 40, height: 36)
                    .background(Theme.pixelAccent)
                    .overlay { PixelPanelBorder(thickness: 2, corner: 2).fill(Theme.pixelInk.opacity(0.55)) }
                    .compositingGroup()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Shuffle names")
            .accessibilityHint("Three different names for the same product")
        }
    }
}

private struct ProductNameChipLabel: View {
    let name: String
    let isCurrent: Bool

    var body: some View {
        let fill = isCurrent ? Theme.pixelAccent : Theme.pixelPaper
        Text(name)
            .font(.system(.footnote, design: .rounded).weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(isCurrent ? Theme.ink(on: fill) : Theme.pixelInk)
            .padding(.horizontal, Theme.Spacing.sm + 2)
            .frame(minHeight: 36)
            .background(fill)
            .overlay { PixelPanelBorder(thickness: 2, corner: 2).fill(Theme.pixelInk.opacity(isCurrent ? 0.7 : 0.45)) }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 2)
                    .padding(.horizontal, 2)
                    .padding(.top, 2)
            }
            .compositingGroup()
    }
}

extension ProductNameClaim {
    /// The inline refusal under the name field.
    var refusal: String {
        switch self {
        case .yours(let product): "You already have a \(product)."
        case .rival(let studio, let product): "\(studio) already sells a \(product)."
        }
    }
}

/// Where `-autoRoute s3-names…` lands the new-product flow: a type and a
/// topic already chosen, on the name step.
struct ProductNameLanding: Equatable {
    var typeID: String
    var topicID: String
    /// Typed into the field instead of the first suggestion (the refusal
    /// shot types a name the studio already has).
    var typedName: String?
    /// Shuffles already taken, for the "three new names" shot.
    var rerolls: Int = 0
}

/// Iteration 16 — S3. The headless screenshot pass for the name step, with
/// `-unlocked -autoFixture release-studio-day400 -autoTab products`:
///
/// - `s3-names`: a new product of the same type and topic as the studio's
///   biggest live product — the owner's case — on the name step;
/// - `s3-names-shuffle`: the same after one Shuffle;
/// - `s3-names-taken`: the same with that product's own name typed, refused;
/// - `s3-names-v2`: the flow as that product's v2, the sequels leading.
///
/// DEBUG only; inert without the flag.
private struct ProductNameAutoRoute: ViewModifier {
    let engine: GameEngine

    private struct Presented: Identifiable {
        let id = UUID()
        let landing: ProductNameLanding?
        let successorOf: UUID?
    }

    @State private var presented: Presented?

    func body(content: Content) -> some View {
        content
            .task {
                #if DEBUG
                guard let route = DebugLaunch.autoRouteName, route.hasPrefix("s3-names") else { return }
                await run(route)
                #endif
            }
            .sheet(item: $presented) { item in
                NewProductFlow(engine: engine, successorOf: item.successorOf, landingOnName: item.landing)
            }
    }

    #if DEBUG
    private var subject: Product? {
        engine.state.products
            .filter { $0.releaseInfo.map { !$0.offMarket } ?? false }
            .max { ($0.releaseInfo?.subscribers ?? 0) < ($1.releaseInfo?.subscribers ?? 0) }
    }

    private func run(_ route: String) async {
        for _ in 0..<20 where subject == nil { try? await Task.sleep(for: .seconds(1)) }
        try? await Task.sleep(for: .seconds(2))
        guard let parent = subject else { return }
        var landing = ProductNameLanding(typeID: parent.typeID, topicID: parent.topicID)
        switch route {
        case "s3-names-v2":
            presented = Presented(landing: nil, successorOf: parent.id)
            return
        case "s3-names-taken":
            landing.typedName = parent.name
        case "s3-names-shuffle":
            landing.rerolls = 1
        default:
            break
        }
        presented = Presented(landing: landing, successorOf: nil)
    }
    #endif
}

extension View {
    /// One line in `ProductsScreen`; everything the flag does lives here.
    func productNameAutoRoute(engine: GameEngine) -> some View {
        modifier(ProductNameAutoRoute(engine: engine))
    }
}

// MARK: end S3
