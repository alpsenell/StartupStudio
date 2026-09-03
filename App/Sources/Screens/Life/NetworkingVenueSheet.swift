import PixelKit
import SwiftUI
import TycoonEngine

/// The networking floor: a room with people standing in it, drawn rather
/// than listed.
///
/// The list version of this screen worked and felt like a spreadsheet of
/// strangers. Standing the contacts up as pixel figures on a floor, at
/// scattered positions derived from their own appearance seed, costs
/// nothing (the sprites already exist for the office and the flat) and
/// turns "pick row 3" into "go and talk to the one by the window" — which
/// is the whole point of the evening.
///
/// Every figure is a button. Tapping one opens the conversation; the bar
/// along the bottom counts the exchanges left and lets the founder call it
/// a night.
struct NetworkingVenueSheet: View {
    let engine: GameEngine

    @State private var talkingTo: Contact?

    @Environment(\.dismiss) private var dismiss
    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI
    /// updates this property for presented content before the
    /// environment is installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }

    var body: some View {
        let state = engine.state
        let event = state.networking.pendingEvent
        let people = state.networking.contactsInRoom

        NavigationStack {
            VStack(spacing: 0) {
                if let event {
                    EveningPips(engine: engine, compact: true)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, Theme.Spacing.sm)
                    NetworkingFloorView(
                        venue: event.venue,
                        people: people,
                        founderSeed: founderAppearanceSeed
                    ) { contact in
                        talkingTo = contact
                    }
                    ExchangeBar(
                        left: event.conversationsLeft,
                        closesIn: max(0, event.expiresOnDay - state.day)
                    ) {
                        shell.toasts.send(
                            .leaveNetworkingEvent,
                            to: engine,
                            ack: "Called it a night.",
                            icon: "moon.fill"
                        )
                        dismiss()
                    }
                } else {
                    ContentUnavailableView(
                        "The room's empty",
                        systemImage: "moon.zzz.fill",
                        description: Text("Plan another networking weekend to get back out there.")
                    )
                }
            }
            .background(Theme.screenBackground)
            .navigationTitle(event?.venue.displayName ?? "Networking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .sheet(item: $talkingTo) { contact in
            ContactSheet(engine: engine, contactID: contact.id)
        }
        // The room can empty out from under the sheet — the last exchange
        // spent, everybody dealt with, or the event expiring on a tick
        // while it is open. Leave rather than sit on a dead screen.
        .onChange(of: engine.state.networking.pendingEvent == nil) { _, gone in
            if gone, talkingTo == nil { dismiss() }
        }
    }

    private var founderAppearanceSeed: UInt64 {
        engine.state.employees.first(where: \.isFounder)?.appearanceSeed ?? 7
    }
}

// MARK: - The floor

/// The room itself: a backdrop, a floor line, the founder on the left, and
/// everybody else scattered across it.
///
/// Deliberately not `private`, and deliberately free of the sheet's
/// navigation chrome: it is the half of this screen worth looking at in a
/// snapshot, and `ImageRenderer` renders a `NavigationStack` as a "no
/// entry" placeholder rather than the view inside it.
struct NetworkingFloorView: View {
    let venue: NetworkingVenue
    let people: [Contact]
    let founderSeed: UInt64
    let tap: (Contact) -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                venue.backdrop
                    .ignoresSafeArea(edges: .horizontal)

                // A floor, so the figures are standing on something
                // rather than floating in a gradient.
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.black.opacity(0.0), .black.opacity(0.35)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: geometry.size.height * 0.55)
                        .overlay(alignment: .top) {
                            Rectangle()
                                .fill(.white.opacity(0.10))
                                .frame(height: 1)
                        }
                }
                .allowsHitTesting(false)

                Text(venue.blurb)
                    .font(.callout.italic())
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(radius: 3)
                    .padding(Theme.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // The founder, always in the same corner: the player's
                // anchor in a room whose other occupants change.
                VStack(spacing: 2) {
                    PixelFigure(seed: founderSeed, isFounder: true, pose: .standing, height: 80)
                    Text("You")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.35), in: Capsule())
                }
                .position(
                    x: geometry.size.width * 0.16,
                    y: geometry.size.height * 0.88
                )
                .accessibilityHidden(true)

                ForEach(Array(people.enumerated()), id: \.element.id) { index, contact in
                    let spot = position(for: index, of: people.count, in: geometry.size)
                    Button { tap(contact) } label: {
                        GuestFigure(contact: contact)
                    }
                    .buttonStyle(.pressable)
                    .position(spot)
                }

                if people.isEmpty {
                    Text("Everyone's gone home.")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    /// Spread the guests over the floor with a per-person jitter taken
    /// from their own appearance seed — so the same people stand in the
    /// same places every time the sheet is opened, and no two rooms look
    /// laid out on a grid.
    ///
    /// Two to a row rather than three: a five-person room across three
    /// columns bunches into the middle third and leaves the floor empty
    /// above and below it, which reads as a queue rather than a party.
    private func position(for index: Int, of count: Int, in size: CGSize) -> CGPoint {
        let columns = count <= 1 ? 1 : 2
        let column = index % columns
        let row = index / columns
        let rows = max(1, Int(ceil(Double(count) / Double(columns))))
        let seed = people[index].appearanceSeed
        let jitterX = Double(seed % 100) / 100 - 0.5
        let jitterY = Double((seed / 100) % 100) / 100 - 0.5

        // Guests take the upper two-thirds; the founder's corner is below
        // them, so the room reads front-to-back.
        let x = 0.30 + (Double(column) + 0.5) / Double(columns) * 0.62 + jitterX * 0.07
        let y = 0.30 + (Double(row) + 0.5) / Double(rows) * 0.44 + jitterY * 0.05
        return CGPoint(x: size.width * min(0.92, max(0.14, x)), y: size.height * min(0.80, y))
    }
}

/// One guest: the figure, their name, and how warm they are toward the
/// founder.
private struct GuestFigure: View {
    let contact: Contact

    var body: some View {
        VStack(spacing: 2) {
            PixelFigure(
                seed: contact.appearanceSeed,
                isFounder: false,
                pose: contact.rapport >= 50 ? .chat : .standing,
                height: 72
            )
            Text(contact.name.split(separator: " ").first.map(String.init) ?? contact.name)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.black.opacity(0.45), in: Capsule())
            RapportPips(rapport: contact.rapport)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(contact.name), \(contact.archetype.displayName). Rapport \(Int(contact.rapport.rounded())) of 100."
        )
        .accessibilityAddTraits(.isButton)
    }
}

/// Five pips, because a progress bar over somebody's head is a HUD and
/// this is meant to be a room.
private struct RapportPips: View {
    let rapport: Double

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { pip in
                Circle()
                    .fill(Double(pip) * 20 < rapport ? Theme.accent : Color.white.opacity(0.3))
                    .frame(width: 4, height: 4)
            }
        }
    }
}

// MARK: - Bottom bar

private struct ExchangeBar: View {
    let left: Int
    let closesIn: Int
    let leave: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(left) conversation\(left == 1 ? "" : "s") left")
                    .font(Theme.Typography.number(.subheadline))
                Text("The room closes in \(closesIn) day\(closesIn == 1 ? "" : "s")")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button("Call it a night", action: leave)
                .buttonStyle(.bordered)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
        }
        .padding(Theme.Spacing.lg)
        .background(.bar)
    }
}

// MARK: - Figures

/// A full-body pixel person, the standing counterpart to `PixelPortrait`.
/// Same deterministic look from the same seed, so the face at the party is
/// the face in the address book and, if they take the job, the face in the
/// office.
struct PixelFigure: View {
    let seed: UInt64
    var isFounder: Bool = false
    var pose: SpriteLibrary.PersonPose = .standing
    var height: CGFloat = 72

    private static let frameDuration: TimeInterval = 0.45

    private var sprite: PixelSprite {
        SpriteLibrary.person(
            appearance: CharacterAppearance(seed: seed),
            pose: pose,
            isFounder: isFounder,
            role: .none
        )
    }

    var body: some View {
        let sprite = sprite
        TimelineView(.periodic(from: .init(timeIntervalSinceReferenceDate: 0), by: Self.frameDuration)) { timeline in
            let tick = Int(timeline.date.timeIntervalSinceReferenceDate / Self.frameDuration)
            // Offset per seed so a room of six does not breathe in unison.
            let frame = (tick + Int(seed % 7)) % max(1, sprite.frameCount)
            Image(decorative: sprite.cgImage(frame: frame), scale: 1)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        }
        .frame(height: height)
        .shadow(color: .black.opacity(0.35), radius: 4, y: 3)
        .accessibilityHidden(true)
    }
}

// MARK: - Venue looks

private extension NetworkingVenue {
    /// A flat two-stop gradient per venue: enough to tell the rooms apart
    /// at a glance without asking PixelKit for five new backdrops.
    var backdrop: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var gradientColors: [Color] {
        switch self {
        case .coworkingMixer: [Color(red: 0.16, green: 0.20, blue: 0.30), Color(red: 0.32, green: 0.36, blue: 0.44)]
        case .rooftopParty: [Color(red: 0.20, green: 0.13, blue: 0.32), Color(red: 0.52, green: 0.26, blue: 0.38)]
        case .demoDay: [Color(red: 0.10, green: 0.22, blue: 0.28), Color(red: 0.22, green: 0.42, blue: 0.44)]
        case .hackerHouse: [Color(red: 0.12, green: 0.14, blue: 0.18), Color(red: 0.26, green: 0.30, blue: 0.34)]
        case .conferenceBar: [Color(red: 0.24, green: 0.15, blue: 0.12), Color(red: 0.44, green: 0.30, blue: 0.20)]
        }
    }
}
