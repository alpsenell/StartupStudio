import Foundation

// Iteration 9 — L5 owns this file and may reshape it freely.

/// Something the founder builds that is not the company: a novel, a band,
/// a marathon, a weekend app, a restaurant. `nil` on `LifeState` until one
/// is started.
public struct SideProjectState: Codable, Equatable, Sendable {
    /// The track id — L5 defines the catalog.
    public var track: String
    public var startedDay: Int
    public var chapter: Int
    /// 0...1 through the current chapter.
    public var progress: Double

    public init(track: String, startedDay: Int, chapter: Int = 0, progress: Double = 0) {
        self.track = track
        self.startedDay = startedDay
        self.chapter = chapter
        self.progress = progress
    }
}
