/// Simulation speed. Speed only changes tick cadence — one tick is always
/// exactly one game day regardless of speed.
public enum SimSpeed: String, Codable, Equatable, Sendable, CaseIterable {
    case paused, x1, x2, x4

    /// Ticks per real-time second, or `nil` when paused.
    public var ticksPerSecond: Double? {
        switch self {
        case .paused: nil
        case .x1: 1
        case .x2: 2
        case .x4: 4
        }
    }

    public var label: String {
        switch self {
        case .paused: "Paused"
        case .x1: "1x"
        case .x2: "2x"
        case .x4: "4x"
        }
    }
}

/// Office tiers, from the founder's garage up to a full campus.
public enum OfficeTier: String, Codable, Equatable, Sendable, CaseIterable {
    case garage, loft, studio, campus

    public var displayName: String {
        switch self {
        case .garage: "Garage"
        case .loft: "Loft"
        case .studio: "Studio"
        case .campus: "Campus"
        }
    }

    /// Position on the garage → campus ladder, for minimum-tier comparisons
    /// (e.g. launch events require at least `balance.launchEventMinTier`).
    var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    /// The tier one rung up the ladder: garage → loft → studio → campus,
    /// and `nil` at the top.
    public var next: OfficeTier? {
        let ladder = Self.allCases
        let index = ladder.index(after: rank)
        return index < ladder.endIndex ? ladder[index] : nil
    }
}
