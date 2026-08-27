/// One chapter goal, loaded from `Goals.json`.
///
/// Scaffold shape: an id, a title, an optional detail line, and the chapter
/// it belongs to. WS-F owns this file and adds `GoalDef.Condition` and the
/// reward block that `ProgressionSystem` evaluates; the catalog ships empty
/// (`[]`).
public struct GoalDef: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    /// One-line explanation shown under the title.
    public var detail: String?
    /// 1-based chapter this goal belongs to.
    public var chapter: Int

    public init(id: String, title: String, detail: String? = nil, chapter: Int) {
        self.id = id
        self.title = title
        self.detail = detail
        self.chapter = chapter
    }
}
