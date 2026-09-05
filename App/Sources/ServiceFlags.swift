// MARK: Iteration 7

/// Which of the three service rows in Settings are live. Each lane flips
/// its own constant to `true` when its row does something, so three lanes
/// touch one line each of `SettingsSheet` and never the same one.
enum ServiceFlags {
    /// R2: the iCloud status row.
    static let cloud = true
    /// R3: the Game Center row.
    static let gameCenter = true
    /// R6: Restore purchases.
    static let restore = false
}
