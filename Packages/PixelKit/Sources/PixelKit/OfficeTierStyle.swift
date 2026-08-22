/// Office tiers mirroring the game's progression (garage → loft → studio →
/// campus). PixelKit stays decoupled from the engine: this is a plain enum the
/// app maps onto.
public enum OfficeTierStyle: String, Sendable, Equatable, Codable, CaseIterable {
    case garage, loft, studio, campus

    /// Regular desk count for the tier. The founder gets one extra dedicated
    /// desk in every tier on top of this.
    public var deskCapacity: Int {
        switch self {
        case .garage: 3
        case .loft: 6
        case .studio: 14
        case .campus: 40
        }
    }
}
