import Foundation

// Iteration 11 — N4 owns this file and may reshape it freely. The founder's
// public feed, followers, fame, and the things fame brings.

public struct FeedPost: Codable, Equatable, Sendable, Identifiable {
    /// Ordinal, so identical states encode identically.
    public var id: Int
    public var day: Int
    public var text: String
    public var reach: Int

    public init(id: Int, day: Int, text: String, reach: Int) {
        self.id = id
        self.day = day
        self.text = text
        self.reach = reach
    }
}

public struct FameState: Codable, Equatable, Sendable {
    public var followers: Int
    /// 0…100.
    public var fame: Double
    public var posts: [FeedPost]

    public init(followers: Int = 0, fame: Double = 0, posts: [FeedPost] = []) {
        self.followers = followers
        self.fame = fame
        self.posts = posts
    }

    public static let empty = FameState()
}
