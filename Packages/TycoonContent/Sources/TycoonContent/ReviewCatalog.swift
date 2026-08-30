/// Per-outlet review voices, loaded from `Reviews.json`.
///
/// Each outlet has a persona and eight blurbs per score band, so the four
/// reviews a launch gets read like four different publications rather than
/// four draws from one bucket. Blurbs may use `{name}`, `{type}` and
/// `{topic}` placeholders, which the engine fills from the shipped product.
///
/// On top of the band blurb, a review can carry a **callout** — a clause
/// about the thing that actually stood out at ship time: crashes when the
/// bug count was high, polish when it wasn't, an over-promise when the hype
/// outran the score. Callouts are chosen from the ship context, not drawn,
/// so they cost no RNG.
public struct ReviewCatalog: Codable, Equatable, Sendable {
    /// One publication's voice.
    public struct Outlet: Codable, Equatable, Sendable, Identifiable {
        /// Matches an entry of `balance.reviewOutlets`.
        public var id: String
        /// How this outlet writes, for the app's launch-day sheet.
        public var persona: String
        /// Band raw value -> at least one blurb.
        public var bands: [String: [String]]

        public init(id: String, persona: String, bands: [String: [String]]) {
            self.id = id
            self.persona = persona
            self.bands = bands
        }
    }

    /// A clause appended to a blurb when the ship context earns it.
    public struct Callout: Codable, Equatable, Sendable, Identifiable {
        /// What triggers it — see `ReviewCallout` in the engine.
        public var id: String
        /// Variants, picked by the same word that picked the blurb.
        public var lines: [String]

        public init(id: String, lines: [String]) {
            self.id = id
            self.lines = lines
        }
    }

    public var outlets: [Outlet]
    public var callouts: [Callout]

    public init(outlets: [Outlet] = [], callouts: [Callout] = []) {
        self.outlets = outlets
        self.callouts = callouts
    }

    /// The catalog a missing or empty `Reviews.json` yields — the engine
    /// falls back to its built-in bands.
    public static let empty = ReviewCatalog()

    /// The blurbs this outlet has for a band, or `nil` when the outlet or
    /// the band is missing (the caller falls back).
    public func blurbs(outlet: String, band: String) -> [String]? {
        guard let match = outlets.first(where: { $0.id == outlet }),
              let lines = match.bands[band], !lines.isEmpty
        else { return nil }
        return lines
    }

    /// The lines written for a callout id, or `nil`.
    public func callout(_ id: String) -> [String]? {
        guard let match = callouts.first(where: { $0.id == id }), !match.lines.isEmpty else {
            return nil
        }
        return match.lines
    }

    /// The persona line for an outlet, for the launch-day reveal.
    public func persona(outlet: String) -> String? {
        outlets.first(where: { $0.id == outlet })?.persona
    }

    private enum CodingKeys: String, CodingKey {
        case outlets, callouts
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            outlets: try container.decodeIfPresent([Outlet].self, forKey: .outlets) ?? [],
            callouts: try container.decodeIfPresent([Callout].self, forKey: .callouts) ?? []
        )
    }
}
