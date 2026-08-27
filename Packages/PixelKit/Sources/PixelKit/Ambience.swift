/// Time-of-day and weather for every scene that can show them (office,
/// home, city). Cosmetic only: nothing here comes from — or feeds back
/// into — the simulation.
///
/// WS-D authors the art variants behind these; WS-C drives them from the
/// office scene's own clock. Every consumer defaults to `.day` / `.clear`,
/// which is exactly what the scenes draw today.

/// Where the day is.
public enum TimeOfDay: String, Sendable, Equatable, Codable, CaseIterable {
    case morning, day, dusk, night
}

/// What it is doing outside the window.
public enum Weather: String, Sendable, Equatable, Codable, CaseIterable {
    case clear, rain, snow
}

/// Which window a scene is asking for. WS-D gives office and home windows
/// their own day/dusk/night/rain/snow frames.
public enum WindowStyle: String, Sendable, Equatable, Codable, CaseIterable {
    case office, home
}
