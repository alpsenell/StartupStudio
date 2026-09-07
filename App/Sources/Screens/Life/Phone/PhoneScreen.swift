import SwiftUI
import TycoonContent
import TycoonEngine

// MARK: Iteration 9 — L1 (the phone)

/// The founder's phone: every thread they have, newest first, drawn as a
/// handset rather than a list — the pixel frame is the point, because the
/// thing this screen exists to produce is a screenshot.
struct PhoneScreen: View {
    let engine: GameEngine
    /// Pushes a thread. The Life stack owns the navigation.
    var onOpenThread: (PhoneCounterpart) -> Void

    /// Whether the debug landing has already pushed a thread.
    @State private var tookAskingThread = false

    var body: some View {
        ScrollView {
            PhoneScreenContent(
                state: engine.state,
                content: engine.content,
                onOpenThread: onOpenThread
            )
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.screenBackground)
        .navigationTitle("Phone")
        .navigationBarTitleDisplayMode(.inline)
        // `-autoThreadAsking`: a headless pass cannot tap the row that is
        // waiting on an answer, and that row is the point of the lane.
        .onChange(of: engine.state.day, initial: true) { _, _ in
            guard DebugLaunch.opensAskingPhoneThread, !tookAskingThread,
                  let asking = PhoneReply.waitingThread(
                      in: engine.state, content: engine.content
                  )
            else { return }
            tookAskingThread = true
            onOpenThread(asking)
        }
    }
}

/// The screen without its scroll view or engine, so a renderer can draw it.
struct PhoneScreenContent: View {
    let state: GameState
    /// `nil` in a renderer that has no catalog: the waiting pill is the
    /// only thing that needs it.
    var content: ContentCatalog?
    var onOpenThread: ((PhoneCounterpart) -> Void)?

    private var threads: [PhoneThread] { state.life.phone.byRecency }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            PhoneHandset(
                title: String(localized: "Messages", comment: "Bitmap title over the phone: the status bar and the share card. Uppercase A-Z only: the pixel face has no lowercase and no accents"),
                subtitle: state.calendar.shortLabel,
                unread: state.life.phone.unreadCount
            ) {
                if threads.isEmpty {
                    Text("Nobody has texted you. That is either peace or a warning.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.pixelInk.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, Theme.Spacing.md)
                } else {
                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(threads) { thread in
                            Button {
                                Haptics.tap()
                                onOpenThread?(thread.counterpart)
                            } label: {
                                PhoneThreadRow(
                                    thread: thread,
                                    name: state.phoneName(for: thread.counterpart),
                                    seed: state.phoneSeed(for: thread.counterpart),
                                    day: state.day,
                                    isAsking: content.map {
                                        PhoneReply.isWaiting(
                                            thread.counterpart, in: state, content: $0
                                        )
                                    } ?? false
                                )
                            }
                            .buttonStyle(.pressableRow)
                        }
                    }
                }
            }

            Text("Every question you were asked landed here, and so did every answer you gave. "
                + "The ones you never answered say so.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The handset: a pixel panel with a bitmap status bar across the top and
/// a speaker slot, so the threads sit inside a phone instead of a card.
struct PhoneHandset<Content: View>: View {
    let title: String
    let subtitle: String
    var unread: Int = 0
    @ViewBuilder var content: () -> Content

    var body: some View {
        PixelPanel(contentPadding: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                // The speaker slot: two pixels tall, centred, the way the
                // office sprites draw a vent.
                Rectangle()
                    .fill(Theme.pixelInk.opacity(0.35))
                    .frame(width: 54, height: 4)
                    .frame(maxWidth: .infinity)
                // One right-hand string rather than two abutting labels:
                // the bitmap face has no space to spare between them, and
                // "78 NEW 16 FEB" read as one number.
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
                    PixelText(text: title, scale: 2, color: Theme.pixelAccent)
                    Spacer(minLength: Theme.Spacing.md)
                    PixelText(
                        text: unread > 0 ? "\(unread) new · \(subtitle)" : subtitle,
                        scale: 2,
                        color: unread > 0 ? Theme.pixelInk : Theme.pixelInk.opacity(0.6)
                    )
                }
                Rectangle()
                    .fill(Theme.pixelAccent.opacity(0.4))
                    .frame(height: 2)
                content()
            }
        }
    }
}
