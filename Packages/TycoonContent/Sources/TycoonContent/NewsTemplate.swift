/// One industry-news headline template, loaded from `News.json`.
///
/// Scaffold shape: an id and a template string with `{placeholder}` slots.
/// WS-B owns this file, writes the templates, and defines which
/// placeholders each category supports; the catalog ships empty (`[]`).
public struct NewsTemplate: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    /// e.g. `"{rival} ships {product} — critics call it {adjective}"`.
    public var template: String

    public init(id: String, template: String) {
        self.id = id
        self.template = template
    }
}
