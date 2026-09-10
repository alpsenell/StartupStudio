import PixelKit
import SwiftUI
import TycoonEngine
import TycoonSave

// MARK: Iteration 13 — P2 (purchases: StoreKit and the session)

// MARK: - The front door

/// What the front door shows of the shop: the locked fourth slot with its
/// one price, and a line while purchases wait for a company. Nothing else
/// of the shop is ever on the title screen (§5).
struct ShopFrontDoor: Sendable {
    /// The fourth slot's row while it is locked; `nil` once owned.
    var lockedSlot: SlotSummary?
    var price: String?
    var isBuying: Bool
    var parkedCount: Int
    /// The last purchase's answer, while the door is up.
    var message: String?
    var onBuySlot: @MainActor @Sendable () -> Void

    @MainActor
    static func make(session: GameSession) -> ShopFrontDoor {
        ShopFrontDoor(
            lockedSlot: session.shop.lockedSlot,
            price: session.shop.price(.fourthSlot),
            isBuying: session.shop.isBuying(.fourthSlot),
            parkedCount: session.shop.parked.count,
            message: session.shop.lastMessage,
            onBuySlot: { session.requestShopPurchase(.fourthSlot) }
        )
    }
}

private struct ShopFrontDoorKey: EnvironmentKey {
    static let defaultValue: ShopFrontDoor? = nil
}

extension EnvironmentValues {
    /// Set by `TitleScreen`; `nil` in the snapshots of `TitleScreenContent`.
    var shopFrontDoor: ShopFrontDoor? {
        get { self[ShopFrontDoorKey.self] }
        set { self[ShopFrontDoorKey.self] = newValue }
    }
}

/// Under the three slots: the fourth, locked, and the parked line.
struct ShopFrontDoorRows: View {
    @Environment(\.shopFrontDoor) private var model

    var body: some View {
        if let model, model.lockedSlot != nil || model.parkedCount > 0 || model.message != nil {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if let row = model.lockedSlot {
                    ShopLockedSlotRow(row: row, price: model.price, isBuying: model.isBuying, onBuy: model.onBuySlot)
                }
                if model.parkedCount > 0 {
                    Label(parkedLine(model.parkedCount), systemImage: "hourglass")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let message = model.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            // Sit with the slot rows, not a section away from them.
            .padding(.top, Theme.Spacing.sm - Theme.Spacing.lg)
        }
    }

    private func parkedLine(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 purchase waiting for a company", comment: "Front door: a bought consumable no company could take yet")
            : String(localized: "\(count) purchases waiting for a company", comment: "Front door: several bought consumables no company could take yet")
    }
}

/// The fourth slot, locked: the number greyed, the lock, and the one
/// price next to the thing it buys. A save a refund left here is named
/// and kept; it opens again when the slot is owned again.
private struct ShopLockedSlotRow: View {
    let row: SlotSummary
    let price: String?
    let isBuying: Bool
    let onBuy: @MainActor @Sendable () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            Sounds.play(.tap)
            onBuy()
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                // A number, not copy: no string literal for the strings audit.
                PixelText(text: String(row.slot + 1), scale: 2, color: Theme.pixelInk.opacity(0.45))
                    .frame(width: 28, height: 28)
                    .background(Theme.pixelPaper)
                    .overlay {
                        PixelPanelBorder(thickness: 2, corner: 2)
                            .fill(Theme.pixelInk.opacity(0.45))
                    }
                    .accessibilityHidden(true)
                if let summary = row.summary {
                    PixelPortrait(seed: summary.founderAppearanceSeed ?? 0, isFounder: true, size: 34)
                        .opacity(0.5)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if isBuying {
                    ProgressView()
                } else {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressableRow)
        .disabled(price == nil || isBuying)
        .padding(Theme.Spacing.md)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Slot \(row.slot + 1), locked. \(title). \(detail)", comment: "Spoken: the locked fourth save slot"))
        .accessibilityHint(price == nil ? "" : String(localized: "Opens the App Store to buy the fourth slot", comment: "Spoken hint on the locked fourth save slot"))
        .accessibilityAddTraits(.isButton)
    }

    /// "A fourth slot · $0.99".
    private var offer: String {
        ShopPresentation.label(.fourthSlot, price: price)
    }

    private var title: String {
        row.summary?.companyName ?? offer
    }

    private var detail: String {
        if let summary = row.summary {
            return String(localized: "Day \(summary.day) · kept safe, locked. \(offer) opens it again, or Restore purchases in Settings.", comment: "Front door: a save in the fourth slot after the slot was refunded")
        }
        if price == nil {
            return String(localized: "The App Store isn't answering. Try again later.", comment: "Front door: the fourth slot's price did not load")
        }
        return String(localized: "A save of its own, synced through iCloud like the other three.", comment: "Front door: what the locked fourth slot is")
    }
}

// MARK: - Settings

/// Restore purchases: `AppStore.sync()`, then an alert that names what
/// came back and says that cash and second chances do not (§5).
struct ShopRestoreRow: View {
    @Environment(\.gameSession) private var session
    @State private var isBusy = false
    @State private var outcome: String?

    var body: some View {
        Button {
            guard let session, !isBusy else { return }
            Task {
                isBusy = true
                let answer = await session.restoreShopPurchases()
                isBusy = false
                outcome = answer
            }
        } label: {
            HStack {
                Label("Restore purchases", systemImage: "arrow.clockwise")
                Spacer()
                if isBusy { ProgressView() }
            }
        }
        .disabled(isBusy || session == nil)
        .alert("Restore purchases", isPresented: Binding(
            get: { outcome != nil },
            set: { presented in if !presented { outcome = nil } }
        )) {
            Button("OK") { outcome = nil }
        } message: {
            Text(outcome ?? "")
        }
    }
}

/// The Purchases row, under Restore: what this Apple ID owns and what
/// each company bought, so the honesty is inspectable.
struct ShopPurchasesRow: View {
    let engine: GameEngine

    /// `-autoPurchases` (DEBUG): the list opens by itself, for the screenshot.
    @State private var debugShowing = DebugLaunch.opensPurchases

    var body: some View {
        NavigationLink {
            ShopPurchasesView(engine: engine)
        } label: {
            Label("Purchases", systemImage: "bag")
        }
        .sheet(isPresented: $debugShowing) {
            NavigationStack { ShopPurchasesView(engine: engine) }
        }
    }
}

/// The list behind the Purchases row. Reads the grants off each save's
/// `purchases` — the record the engine keeps — not off the store.
struct ShopPurchasesView: View {
    let engine: GameEngine

    @Environment(\.gameSession) private var session
    @State private var others: [OtherCompany] = []

    struct OtherCompany: Identifiable {
        var slot: Int
        var name: String
        var grants: [PurchaseGrant]
        var id: Int { slot }
    }

    var body: some View {
        List {
            Section {
                if ownedNames.isEmpty {
                    Text("Nothing bought on this Apple ID.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(ownedNames, id: \.self) { name in
                        Label(name, systemImage: "checkmark.seal")
                    }
                }
            } header: {
                Text("On this Apple ID")
            } footer: {
                Text("These restore on any device signed in to the same Apple ID.")
            }

            Section {
                grantRows(engine.state.purchases.grants)
            } header: {
                Text(engine.state.company.name)
            } footer: {
                if let footer = companyFooter { Text(footer) }
            }

            ForEach(others) { other in
                Section {
                    grantRows(other.grants)
                } header: {
                    Text(String(localized: "\(other.name) · slot \(other.slot + 1)", comment: "Purchases list: another save's heading"))
                }
            }

            if let parked = session?.shop.parked.count, parked > 0 {
                Section {
                    Text(parked == 1
                         ? String(localized: "1 purchase is waiting for a company. It goes to the next one that can take it.", comment: "Purchases list: one parked consumable")
                         : String(localized: "\(parked) purchases are waiting for a company. They go to the next ones that can take them.", comment: "Purchases list: several parked consumables"))
                } header: {
                    Text("Waiting")
                }
            }

            Section {
            } footer: {
                Text("Cash, second chances and veterans are used once, in the company that took them, and don't restore.")
            }
        }
        .navigationTitle("Purchases")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { others = loadOthers() }
    }

    @ViewBuilder
    private func grantRows(_ grants: [PurchaseGrant]) -> some View {
        if grants.isEmpty {
            Text("Nothing bought.")
                .foregroundStyle(.secondary)
        } else {
            ForEach(grants, id: \.transactionID) { grant in
                LabeledContent {
                    if grant.amount > 0 {
                        Text("+\(grant.amount.money)")
                            .monospacedDigit()
                    }
                } label: {
                    Text(ShopCatalog.name(of: grant.kind))
                    Text(String(localized: "Day \(grant.day)", comment: "Purchases list: the game day a grant landed"))
                }
            }
        }
    }

    private var ownedNames: [String] {
        var names: [String] = []
        if session?.unlock.isEntitled == true {
            names.append(String(localized: "The full company", comment: "Purchases list: the unlock"))
        }
        if session?.shop.owns(.fourthSlot) == true { names.append(ShopProduct.fourthSlot.displayName) }
        if session?.shop.owns(.loftPack) == true { names.append(ShopProduct.loftPack.displayName) }
        return names
    }

    private var companyFooter: String? {
        let grants = engine.state.purchases.grants
        if !grants.isEmpty {
            let total = grants.reduce(0) { $0 + $1.amount }
            return String(localized: "Bought in: \(total.money) over \(grants.count) purchases. This company no longer posts to the leaderboards.", comment: "Purchases list: the open company's total, and that it is unranked")
        }
        return engine.state.isRanked
            ? String(localized: "Nothing bought, and this company still posts to the leaderboards.", comment: "Purchases list: the open company bought nothing and is ranked")
            : nil
    }

    /// The other saves that bought something. Read once, on appear.
    private func loadOthers() -> [OtherCompany] {
        guard let session else { return [] }
        return (0..<session.store.slotCount).compactMap { slot in
            if slot == session.currentSlot, !session.isDetached { return nil }
            guard let state = (try? session.store.load(slot: slot))?.state,
                  !state.purchases.grants.isEmpty
            else { return nil }
            return OtherCompany(slot: slot, name: state.company.name, grants: state.purchases.grants)
        }
    }
}
