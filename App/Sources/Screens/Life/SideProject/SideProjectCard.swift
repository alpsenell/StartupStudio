import PixelKit
import SwiftUI
import TycoonEngine

/// The thing the founder is building that is not the company, on the Life
/// tab under *You*.
///
/// Three states, and the card is a different size in each: nothing started
/// (an invitation and the five names), something under way (the vignette,
/// the chapter, tonight's button with its price on it), and finished (what
/// they made, and the offer of the next one).
struct SideProjectCard: View {
    let engine: GameEngine
    /// Pushes `SideProjectScreen`, which is where a track gets picked.
    let onOpen: () -> Void

    @State private var playing: PlayingActivity?

    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI updates
    /// this property for presented content before the environment is
    /// installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }

    var body: some View {
        let state = engine.state
        let project = state.life.sideProject

        CardView("On the side", systemImage: "sparkles") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if let project, let track = project.track,
                   let def = engine.balance.sideProject.track(track) {
                    active(project: project, track: track, def: def, state: state)
                } else {
                    idle(project: project)
                }
            }
        }
        .sheet(item: $playing) { playing in
            ActivityPlaybackSheet(playing: playing, appearanceSeed: founderAppearanceSeed)
        }
        .task { await SideProjectDebug.runIfAsked(engine: engine) }
    }

    // MARK: - Something on the go

    @ViewBuilder
    private func active(
        project: SideProjectState,
        track: String,
        def: BalanceConfig.SideProjectBalance.TrackDef,
        state: GameState
    ) -> some View {
        let kind = SideProjectTrack(rawValue: track)
        let chapter = state.sideProjectChapter(engine.balance)
        let blocker = state.sideProjectWorkBlocker(engine.balance)

        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                PixelSceneView(
                    placements: ActivitySceneComposer.compose(
                        style: sideProjectScene(def),
                        appearance: CharacterAppearance(seed: founderAppearanceSeed),
                        isFounder: true
                    ),
                    sceneSize: ActivitySceneComposer.sceneSize(),
                    accessibilityLabel: "\(kind?.displayName ?? track) scene"
                )
                .frame(height: 84)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: kind?.systemImage ?? "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Text(kind?.displayName ?? track)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer(minLength: Theme.Spacing.sm)
                    Text("Chapter \(project.chapter + 1) of \(def.chapters.count)")
                        .font(Theme.Typography.number(.caption2))
                        .foregroundStyle(.secondary)
                }
                ChapterStrip(
                    chapterCount: def.chapters.count,
                    chapter: project.chapter,
                    progress: project.progress
                )
                if let chapter {
                    Text(chapter.title)
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(chapter.blurb)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressableRow)

        SideProjectWorkButton(
            title: kind?.sessionVerb ?? "Work on it tonight",
            consequence: state.sideProjectSessionConsequence(engine.balance),
            blocker: blocker
        ) {
            work(def: def, kind: kind)
        }

        EveningPips(engine: engine, compact: true)

        if let left = state.sideProjectSessionsLeft(engine.balance) {
            Text("About \(left) more evening\(left == 1 ? "" : "s") to finish this chapter, at how good you are right now.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Sends the evening and, only if the engine agreed, plays the little
    /// pixel scene. Same contract as `ActivitiesCard`: no vignette for an
    /// action that was refused.
    private func work(
        def: BalanceConfig.SideProjectBalance.TrackDef,
        kind: SideProjectTrack?
    ) {
        let before = engine.state.life.sideProject?.sessionsThisProject ?? 0
        _ = shell.toasts.send(
            .workOnSideProject,
            to: engine,
            ack: "An evening on it.",
            rejected: "Not tonight — \(engine.state.sideProjectWorkBlocker(engine.balance)?.lowercased() ?? "it will keep").",
            icon: kind?.systemImage ?? "sparkles"
        )
        guard (engine.state.life.sideProject?.sessionsThisProject ?? 0) > before else { return }
        playing = PlayingActivity(
            style: sideProjectScene(def),
            title: kind?.displayName ?? "On the side",
            summary: engine.state.sideProjectSessionConsequence(engine.balance)
        )
    }

    // MARK: - Nothing on the go

    @ViewBuilder
    private func idle(project: SideProjectState?) -> some View {
        let done = project?.completedTracks ?? []

        if done.isEmpty {
            Text("Everything you do is for the company. This is the one thing that isn't.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                ForEach(done) { finished in
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.positiveCash)
                        Text(SideProjectTrack(rawValue: finished.track)?.displayName ?? finished.track)
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                        Spacer(minLength: 0)
                        Text("Day \(finished.finishedDay)")
                            .font(Theme.Typography.number(.caption2))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }

        HStack(spacing: Theme.Spacing.xs) {
            ForEach(engine.balance.sideProject.shippedOrder, id: \.self) { track in
                Image(systemName: track.systemImage)
                    .font(.caption)
                    .foregroundStyle(
                        project?.hasCompleted(track.rawValue) == true
                            ? Theme.positiveCash : Theme.accent.opacity(0.55)
                    )
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)

        Button(action: onOpen) {
            Text(done.isEmpty ? "Start something" : "Start something else")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(Theme.accent)
        }
        .buttonStyle(.pressableRow)
    }

    private var founderAppearanceSeed: UInt64 {
        engine.state.employees.first(where: \.isFounder)?.appearanceSeed ?? 7
    }
}

// MARK: - Tonight's button

/// One evening, with its price written on it and its refusal underneath —
/// the shape every action on this tab has.
struct SideProjectWorkButton: View {
    let title: String
    let consequence: String
    let blocker: String?
    let work: () -> Void

    var body: some View {
        Button(action: work) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text(blocker ?? consequence)
                    .font(Theme.Typography.number(.caption2, weight: .regular))
                    .foregroundStyle(blocker == nil ? Theme.ink(on: Theme.accent).opacity(0.85) : Theme.warning)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                blocker == nil ? Theme.accent : Theme.chipBackground,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .foregroundStyle(blocker == nil ? Theme.ink(on: Theme.accent) : Color.secondary)
        }
        .buttonStyle(.pressableRow)
        .disabled(blocker != nil)
        .accessibilityLabel(title)
        .accessibilityHint(blocker ?? consequence)
    }
}
