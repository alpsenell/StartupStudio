import PixelKit
import SwiftUI
import TycoonEngine

/// Iteration 11 — N3. Everything that is the founder's rather than the
/// company's: the garage, the deeds, the household, the money that moves
/// on its own, the doctor's office and the four habits.
///
/// **This screen is the switch.** Opening it sends `.noticeAssetsOpened`,
/// which is the one thing that starts `AssetsSystem`. Before that the
/// vices do not creep, the doctor writes nothing down and the weekly bills
/// are not charged — which is how a pacing bot's run stays byte-identical.
struct AssetsScreen: View {
    let engine: GameEngine

    @Environment(GameShell.self) private var injectedShell: GameShell?
    private var shell: GameShell { injectedShell ?? .shared }

    @State private var openedDoctor = false
    @State private var openedCasino = false

    var body: some View {
        let state = engine.state

        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    header(state)
                    EveningPips(engine: engine)

                    ForEach(AssetKind.allCases, id: \.self) { kind in
                        AssetCatalogSection(engine: engine, kind: kind)
                    }

                    AssetWalletCard(engine: engine, onOpenCasino: { openedCasino = true })
                    AssetVicesCard(engine: engine)
                        .id(Self.habitsAnchor)
                    AssetDoctorCard(engine: engine, onOpen: { openedDoctor = true })
                }
                .padding(Theme.Spacing.lg)
            }
            .onAppear { scrollForScreenshots(proxy) }
        }
        .background(Theme.screenBackground)
        .navigationTitle("Your things")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // The one flag. Sent through the ordinary reducer, once, from
            // the one place the player can have arrived at deliberately.
            engine.send(.noticeAssetsOpened)
            // `-autoAssets` fills the garage; `-autoRoute doctor` /
            // `casino` open the sheet a headless pass cannot tap.
            DebugLaunch.startAutoAssets(engine: engine)
            switch DebugLaunch.opensAssetsSheet {
            case "doctor": openedDoctor = true
            case "casino": openedCasino = true
            default: break
            }
        }
        .sheet(isPresented: $openedDoctor) {
            AssetDoctorSheet(engine: engine)
        }
        .sheet(isPresented: $openedCasino) {
            AssetCasinoSheet(engine: engine)
        }
    }

    /// The anchor `-autoRoute habits` scrolls to. A headless screenshot
    /// pass cannot scroll, and the habits are two cards below the fold on
    /// every phone.
    private static let habitsAnchor = "n3.habits"

    private func scrollForScreenshots(_ proxy: ScrollViewProxy) {
        #if DEBUG
        guard DebugLaunch.autoRouteName == "habits" else { return }
        // After the layout pass, or the anchor does not exist yet.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            proxy.scrollTo(Self.habitsAnchor, anchor: .top)
        }
        #endif
    }

    /// The founder's own net worth, over the drive.
    private func header(_ state: GameState) -> some View {
        let owned = state.assets.owned.sorted { $0.catalogID < $1.catalogID }
        return CardView("Your side of the ledger", systemImage: "chart.pie.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .top, spacing: Theme.Spacing.xl) {
                    AssetHeadline(label: "Wallet", value: state.life.wallet.money,
                                  tint: state.life.wallet < 0 ? Theme.negativeCash : .primary)
                    AssetHeadline(label: "Net worth",
                                  value: state.founderNetWorth(balance: engine.balance).money,
                                  tint: .primary)
                }
                if !owned.isEmpty {
                    // The things that have a picture, lined up the way they
                    // would be on a drive.
                    HStack(alignment: .bottom, spacing: Theme.Spacing.md) {
                        ForEach(owned) { asset in
                            AssetSpriteView(catalogID: asset.catalogID, scale: 3)
                                .opacity(asset.needsRepair ? 0.45 : 1)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("Everything on this screen is your own money. The company never pays for any of it.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct AssetHeadline: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(Theme.Typography.number(.title2))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .animation(Theme.Motion.valueChange, value: value)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - One kind of thing

/// The garage, the deeds or the household: what you own of this kind,
/// then what the catalog will sell you.
private struct AssetCatalogSection: View {
    let engine: GameEngine
    let kind: AssetKind

    @Environment(GameShell.self) private var injectedShell: GameShell?
    private var shell: GameShell { injectedShell ?? .shared }

    var body: some View {
        let catalog = engine.balance.assets.everything.filter { $0.assetKind == kind }
        CardView(kind.sectionTitle, systemImage: AssetsPresentation.icon(kind)) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text(AssetsPresentation.sectionNote(kind))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(catalog) { def in
                    AssetRow(engine: engine, def: def, shell: shell)
                }
            }
        }
    }
}

/// One catalog line: what it is, what it costs, and the one button it has
/// today — buy it, pay for it, or sell it.
private struct AssetRow: View {
    let engine: GameEngine
    let def: BalanceConfig.AssetsBalance.AssetDef
    let shell: GameShell

    var body: some View {
        let state = engine.state
        let owned = state.assets.asset(def.id)

        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                AssetSpriteView(catalogID: def.id, scale: 2)
                    .opacity(owned == nil ? 0.35 : 1)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Text(owned.flatMap { $0.petName.isEmpty ? nil : $0.petName } ?? def.name)
                            .font(.subheadline.weight(.semibold))
                        if owned?.needsRepair == true {
                            Text("off the road")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.negativeCash)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Theme.negativeCash.opacity(0.15), in: Capsule())
                        }
                        Spacer(minLength: 0)
                    }
                    Text(def.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(priceLine)
                        .font(Theme.Typography.number(.caption2))
                        .foregroundStyle(.tertiary)
                }
            }

            buttons(owned: owned)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.chipBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Every number the row promises, on one line.
    private var priceLine: String {
        var parts = [def.price.money]
        if def.weeklyCost > 0 { parts.append("\(def.weeklyCost.money)/wk") }
        if def.weeklyRent > 0 { parts.append("lets for \(def.weeklyRent.money)/wk") }
        if def.moodDrift > 0 {
            parts.append("mood +\(def.moodDrift.formatted(.number.precision(.fractionLength(2)).locale(Theme.gameLocale)))/day")
        }
        if def.faultChance > 0 {
            parts.append("\(Int((def.faultChance * 100).rounded()))% a week it goes wrong")
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func buttons(owned: AssetOwned?) -> some View {
        if let owned {
            HStack(spacing: Theme.Spacing.sm) {
                if owned.needsRepair {
                    let blocker = engine.state.assetRepairBlocker(def.id, balance: engine.balance)
                    Button {
                        Haptics.commit()
                        shell.toasts.send(
                            .repairAsset(assetID: def.id), to: engine,
                            ack: "\(def.name) is back on the road", icon: "wrench.and.screwdriver.fill"
                        )
                    } label: {
                        Label("Pay the \(def.repairCost.money) bill", systemImage: "wrench.and.screwdriver.fill")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(blocker != nil)
                }
                let price = engine.state.assetSalePrice(def.id, balance: engine.balance)
                Button {
                    Haptics.commit()
                    shell.toasts.send(
                        .sellAsset(assetID: def.id), to: engine,
                        ack: "Sold for \(price.money)", icon: "arrow.down.circle.fill"
                    )
                } label: {
                    Label(def.assetKind == .pet ? "Rehome — \(price.money)" : "Sell — \(price.money)",
                          systemImage: "arrow.down.circle")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.bordered)
                Spacer(minLength: 0)
            }
            if owned.needsRepair {
                AssetRefusalNote(
                    reason: engine.state.assetRepairBlocker(def.id, balance: engine.balance)
                )
            }
        } else {
            let blocker = engine.state.assetBuyBlocker(def.id, balance: engine.balance)
            Button {
                Haptics.commit()
                shell.toasts.send(
                    .buyAsset(assetID: def.id), to: engine,
                    ack: "\(def.name) is yours", icon: AssetsPresentation.icon(def.assetKind)
                )
            } label: {
                Label(buyLabel, systemImage: "cart.fill")
                    .font(.footnote.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .disabled(blocker != nil)
            AssetRefusalNote(reason: blocker)
        }
    }

    private var buyLabel: String {
        switch def.assetKind {
        case .car: "Buy it — \(def.price.money)"
        case .property: "Buy it — \(def.price.money)"
        case .pet: "Take it home — \(def.price.money)"
        }
    }
}

// MARK: - The money that moves on its own

/// The wallet, the ticket and the door to the tables.
private struct AssetWalletCard: View {
    let engine: GameEngine
    let onOpenCasino: () -> Void

    @Environment(GameShell.self) private var injectedShell: GameShell?
    private var shell: GameShell { injectedShell ?? .shared }

    /// The three sizes a founder actually puts in.
    private static let stakes = [500, 2000, 10_000]

    var body: some View {
        let state = engine.state
        let wallet = state.assets.crypto
        let config = engine.balance.assets

        CardView("Money that moves on its own", systemImage: "chart.line.uptrend.xyaxis") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if let wallet {
                    HStack(alignment: .top, spacing: Theme.Spacing.xl) {
                        AssetHeadline(label: "Worth today", value: wallet.value.money,
                                      tint: wallet.value >= wallet.invested ? Theme.positiveCash : Theme.negativeCash)
                        AssetHeadline(label: "Put in", value: wallet.invested.money, tint: .secondary)
                    }
                    Text("A unit is \(wallet.price.formatted(.number.precision(.fractionLength(2)).locale(Theme.gameLocale))) today. It moves once a week and it does not care what you think.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("An open wallet, a price that steps once a week, and \(Int(config.crypto.spread * 100))% off the top of every trade in both directions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(Self.stakes, id: \.self) { amount in
                        let blocker = state.assetTradeBlocker(dollars: amount, balance: engine.balance)
                        Button {
                            Haptics.commit()
                            shell.toasts.send(
                                .tradeCrypto(dollars: amount), to: engine,
                                ack: "\(amount.money) in", icon: "arrow.up.right"
                            )
                        } label: {
                            Text("+\(amount.money)").font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .disabled(blocker != nil)
                    }
                    if let wallet, wallet.units > 0 {
                        Button {
                            Haptics.commit()
                            shell.toasts.send(
                                .tradeCrypto(dollars: -wallet.value), to: engine,
                                ack: "Out at \(wallet.value.money)", icon: "arrow.down.right"
                            )
                        } label: {
                            Text("Cash out").font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Spacer(minLength: 0)
                }

                Divider()

                // The ticket.
                let ticketBlocker = state.assetTicketBlocker(balance: engine.balance)
                HStack(spacing: Theme.Spacing.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("This week's ticket")
                            .font(.subheadline.weight(.semibold))
                        Text("\(config.lottery.ticketCost.money) for a \(config.lottery.jackpot.money) jackpot you will not win, and a \(config.lottery.smallPrize.money) one you sometimes do.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Button {
                        Haptics.commit()
                        shell.toasts.send(
                            .buyLotteryTicket, to: engine,
                            ack: "One ticket. Drawn at the weekend.", icon: "ticket.fill"
                        )
                    } label: {
                        Label("Buy", systemImage: "ticket.fill").font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .disabled(ticketBlocker != nil)
                }
                AssetRefusalNote(reason: ticketBlocker)

                Button {
                    Haptics.tap()
                    onOpenCasino()
                } label: {
                    HStack {
                        Label("The tables", systemImage: "suit.spade.fill")
                            .font(.footnote.weight(.semibold))
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - The doctor's door

/// What the doctor has written down, and the way in.
private struct AssetDoctorCard: View {
    let engine: GameEngine
    let onOpen: () -> Void

    var body: some View {
        let state = engine.state
        let ailments = state.assets.ailments.sorted { $0.id < $1.id }

        CardView("The doctor", systemImage: "stethoscope") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if ailments.isEmpty, !state.economy.chronicCondition {
                    Text("Nothing on your file. Keep it that way and the file stays short.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(ailments) { ailment in
                        if let def = engine.balance.assets.ailment(ailment.id) {
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: AssetsPresentation.ailmentIcon(def.id))
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(ailment.isBeingTreated ? Theme.accent : Theme.negativeCash)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(def.name).font(.subheadline.weight(.semibold))
                                    Text(ailment.isBeingTreated
                                         ? "Being treated — \(max(0, (ailment.treatedUntilDay ?? 0) - state.day)) days to go"
                                         : def.cause)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    if state.economy.chronicCondition {
                        Text("And the chronic condition, which no course of treatment touches — only three restorative weekends running.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Button {
                    Haptics.tap()
                    onOpen()
                } label: {
                    HStack {
                        Label("The waiting room", systemImage: "cross.case.fill")
                            .font(.footnote.weight(.semibold))
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
