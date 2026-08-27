/// Per-outlet review voices, loaded from `Reviews.json`.
///
/// Scaffold shape: an empty catalog, so `ReviewBlurbs` keeps using its
/// built-in bands and the loader path is exercised. WS-B owns this file and
/// gives each outlet a persona with blurbs per score band.
public struct ReviewCatalog: Codable, Equatable, Sendable {
    public init() {}

    /// The catalog a missing or empty `Reviews.json` yields.
    public static let empty = ReviewCatalog()
}
