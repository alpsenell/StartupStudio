/// Office amenities rendered as prop zones in the scene. Mirrors the engine's
/// `Amenity` (same raw values) so the app can map one onto the other without
/// PixelKit depending on the engine.
public enum AmenityStyle: String, Sendable, Equatable, Codable, CaseIterable {
    case gameRoom, cafeteria, shuttle, gym
}
