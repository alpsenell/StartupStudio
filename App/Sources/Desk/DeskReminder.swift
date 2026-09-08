import Foundation
import UserNotifications

// MARK: Iteration 10 — M5 (the morning desk)

/// The one notification the game ever sends: "the desk is set", once a
/// day, at the hour the player cleared it.
///
/// The permission is asked for **from the desk's own button and nowhere
/// else** — never at launch, never on a first run, never as the price of
/// opening a screen. A player who never presses *Remind me tomorrow*
/// never sees the system prompt, and the app has no notification code on
/// any other path.
@MainActor
enum DeskReminder {
    /// Whether the player has asked for the reminder. Off until they do.
    static var isOn: Bool {
        get { UserDefaults.standard.bool(forKey: onKey) }
        set { UserDefaults.standard.set(newValue, forKey: onKey) }
    }

    /// The hour it fires, 0…23 — the hour the desk was last cleared, so
    /// the reminder lands when the player's own morning is.
    static var hour: Int {
        get {
            let stored = UserDefaults.standard.object(forKey: hourKey) as? Int
            return stored.map { min(max(0, $0), 23) } ?? defaultHour
        }
        set { UserDefaults.standard.set(min(max(0, newValue), 23), forKey: hourKey) }
    }

    /// Nine in the morning, until a cleared desk says otherwise.
    static let defaultHour = 9

    /// The label on the button, so it always says what pressing it does.
    static var buttonTitle: String {
        isOn ? "Reminder on · \(clockLabel(hour))" : "Remind me tomorrow"
    }

    static var buttonDetail: String {
        isOn
            ? "One notification a day, at \(clockLabel(hour)). Tap to turn it off."
            : "One notification a day, at \(clockLabel(hour)). Nothing else, ever."
    }

    /// "9am", "10pm" — the hour in the plainest words there are.
    static func clockLabel(_ hour: Int) -> String {
        switch hour {
        case 0: "12am"
        case 1..<12: "\(hour)am"
        case 12: "12pm"
        default: "\(hour - 12)pm"
        }
    }

    /// Turns the reminder on: asks the system for permission (the only
    /// place in the app that does) and schedules the daily notification.
    /// Returns false when permission was refused — the caller says so
    /// rather than pretending it worked.
    @discardableResult
    static func turnOn(at hour: Int) async -> Bool {
        self.hour = hour
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else {
            isOn = false
            return false
        }
        schedule(at: hour)
        isOn = true
        return true
    }

    /// Turns it off and takes the pending notification with it.
    static func turnOff() {
        isOn = false
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [requestID]
        )
    }

    /// Moves the reminder to the hour the desk was just cleared, if it is
    /// on. Never asks for anything.
    static func moveToClearedHour(_ hour: Int) {
        guard isOn, hour != self.hour else { return }
        self.hour = hour
        schedule(at: hour)
    }

    private static func schedule(at hour: Int) {
        let content = UNMutableNotificationContent()
        content.title = String(
            localized: "The desk is set",
            comment: "Title of the one daily notification the morning desk sends"
        )
        content.body = String(
            localized: "One message, one decision, one tap.",
            comment: "Body of the daily morning-desk notification: the three things it asks for"
        )
        content.sound = .default
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let request = UNNotificationRequest(
            identifier: requestID,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestID])
        center.add(request)
    }

    private static let onKey = "desk.reminderOn"
    private static let hourKey = "desk.reminderHour"
    private static let requestID = "desk.morning"
}
