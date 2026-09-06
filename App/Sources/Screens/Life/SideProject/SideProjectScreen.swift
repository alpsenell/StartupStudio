import PixelKit
import SwiftUI
import TycoonEngine

/// The side project in full: what is under way, the four chapters and what
/// each one pays, and — when nothing is — the five tracks to choose from.
///
/// Everything on this screen is a promise made *before* the evening is
/// spent: a track states its whole cost in evenings up front, and every
/// chapter states its payout before it is reached. There is nothing to
/// discover by grinding, which is what makes picking one a decision.
struct SideProjectScreen: View {
    let engine: GameEngine

    @State private var playing: PlayingActivity?
    @State private var confirmingAbandon = false

    @Environment(GameShell.self) private var injectedShell: GameShell?
    private var shell: GameShell { injectedShell ?? .shared }

    var body: some View {
        let state = engine.state
        let project = state.life.sideProject

        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                if let project, let track = project.track,
                   let def = engine.balance.sideProject.track(track) {
                    currentProject(project: project, track: track, def: def, state: state)
                } else {
                    picker(project: project, state: state)
                }
                if let project, !project.completedTracks.isEmpty {
                    finished(project.completedTracks)
                }
                Text("One at a time. Put it down and the chapter you are in goes with it — the ones you finished stay finished.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.screenBackground)
        .navigationTitle("On the side")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $playing) { playing in
            ActivityPlaybackSheet(playing: playing, appearanceSeed: founderAppearanceSeed)
        }
        .confirmationDialog(
            "Put it down?",
            isPresented: $confirmingAbandon,
            titleVisibility: .visible
        ) {
            Button("Put it down", role: .destructive) {
                _ = shell.toasts.send(
                    .abandonSideProject, to: engine,
                    ack: "You put it down.", icon: "xmark.circle.fill"
                )
            }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("The chapter you are in is lost. Anything you already finished stays on your record.")
        }
    }

    // MARK: - The project under way

    @ViewBuilder
    private func currentProject(
        project: SideProjectState,
        track: String,
        def: BalanceConfig.SideProjectBalance.TrackDef,
        state: GameState
    ) -> some View {
        let kind = SideProjectTrack(rawValue: track)

        CardView(kind?.displayName ?? track, systemImage: kind?.systemImage ?? "sparkles") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                PixelSceneView(
                    placements: ActivitySceneComposer.compose(
                        style: sideProjectScene(def),
                        appearance: CharacterAppearance(seed: founderAppearanceSeed),
                        isFounder: true
                    ),
                    sceneSize: ActivitySceneComposer.sceneSize(),
                    accessibilityLabel: "\(kind?.displayName ?? track) scene"
                )
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))

                Text(def.blurb)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ChapterStrip(
                    chapterCount: def.chapters.count,
                    chapter: project.chapter,
                    progress: project.progress
                )

                HStack(spacing: Theme.Spacing.sm) {
                    SideProjectChip(text: "Runs on \(def.driverSummary.lowercased())")
                    Spacer(minLength: 0)
                    Text("\(project.sessionsThisProject) evening\(project.sessionsThisProject == 1 ? "" : "s") in")
                        .font(Theme.Typography.number(.caption2))
                        .foregroundStyle(.tertiary)
                }

                SideProjectWorkButton(
                    title: kind?.sessionVerb ?? "Work on it tonight",
                    consequence: state.sideProjectSessionConsequence(engine.balance),
                    blocker: state.sideProjectWorkBlocker(engine.balance)
                ) {
                    work(def: def, kind: kind)
                }
                EveningPips(engine: engine)
            }
        }

        CardView("The four chapters", systemImage: "list.number") {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(Array(def.chapters.enumerated()), id: \.offset) { index, chapter in
                    ChapterRow(
                        number: index + 1,
                        chapter: chapter,
                        status: index < project.chapter
                            ? .done
                            : (index == project.chapter ? .current : .ahead)
                    )
                }
            }
        }

        Button(role: .destructive) {
            confirmingAbandon = true
        } label: {
            Text("Put it down")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.sm)
        }
        .buttonStyle(.bordered)
        .tint(Theme.negativeCash)
    }

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

    // MARK: - Picking one

    @ViewBuilder
    private func picker(project: SideProjectState?, state: GameState) -> some View {
        CardView("Something that is yours", systemImage: "sparkles") {
            Text("Four chapters, a season of your evenings, and a line in your biography that is not about the company.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        ForEach(engine.balance.sideProject.shippedOrder, id: \.self) { track in
            if let def = engine.balance.sideProject.track(track) {
                TrackCard(
                    track: track,
                    def: def,
                    appearanceSeed: founderAppearanceSeed,
                    blocker: state.sideProjectStartBlocker(track.rawValue, balance: engine.balance)
                ) {
                    _ = shell.toasts.send(
                        .startSideProject(track: track.rawValue),
                        to: engine,
                        ack: "\(track.displayName): started.",
                        rejected: "Not now.",
                        icon: track.systemImage
                    )
                }
            }
        }
    }

    // MARK: - What they made

    private func finished(_ done: [CompletedSideProject]) -> some View {
        CardView("Finished", systemImage: "checkmark.seal.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                ForEach(done) { entry in
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: SideProjectTrack(rawValue: entry.track)?.systemImage ?? "sparkles")
                            .font(.caption)
                            .foregroundStyle(Theme.positiveCash)
                            .frame(width: 18)
                        Text(SideProjectTrack(rawValue: entry.track)?.displayName ?? entry.track)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        Spacer(minLength: 0)
                        Text("Day \(entry.finishedDay)")
                            .font(Theme.Typography.number(.caption2))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private var founderAppearanceSeed: UInt64 {
        engine.state.employees.first(where: \.isFounder)?.appearanceSeed ?? 7
    }
}

// MARK: - A chapter

private struct ChapterRow: View {
    enum Status { case done, current, ahead }

    let number: Int
    let chapter: BalanceConfig.SideProjectBalance.ChapterDef
    let status: Status

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: status == .done ? "checkmark.circle.fill" : "\(number).circle\(status == .current ? ".fill" : "")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(status == .ahead ? Color.secondary : Theme.accent)
                    .frame(width: 22)
                Text(chapter.title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(status == .ahead ? .secondary : .primary)
                Spacer(minLength: Theme.Spacing.sm)
                Text("\(Int(chapter.sessions)) evenings")
                    .font(Theme.Typography.number(.caption2))
                    .foregroundStyle(.tertiary)
            }
            Text(chapter.blurb)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !chapter.payoutChips.isEmpty {
                // Wrapping is done by the flow of chips, not by a fixed
                // row: three payouts on a large-type phone would otherwise
                // truncate the one that matters.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Theme.Spacing.xs) {
                        ForEach(chapter.payoutChips, id: \.self) { SideProjectChip(text: $0) }
                    }
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        ForEach(chapter.payoutChips, id: \.self) { SideProjectChip(text: $0) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(
            status == .current ? Theme.accent.opacity(0.10) : Theme.chipBackground.opacity(0.5),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - A track on the picker

private struct TrackCard: View {
    let track: SideProjectTrack
    let def: BalanceConfig.SideProjectBalance.TrackDef
    let appearanceSeed: UInt64
    let blocker: String?
    let start: () -> Void

    var body: some View {
        CardView(track.displayName, systemImage: track.systemImage) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                PixelSceneView(
                    placements: ActivitySceneComposer.compose(
                        style: sideProjectScene(def),
                        appearance: CharacterAppearance(seed: appearanceSeed),
                        isFounder: true
                    ),
                    sceneSize: ActivitySceneComposer.sceneSize(),
                    accessibilityLabel: "\(track.displayName) scene"
                )
                .frame(height: 76)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text(def.blurb)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Theme.Spacing.xs) {
                    SideProjectChip(text: def.costSummary)
                    SideProjectChip(text: def.driverSummary)
                }

                if let last = def.chapters.last, !last.payoutChips.isEmpty {
                    Text("Finishes with: \(last.payoutChips.joined(separator: " · "))")
                        .font(Theme.Typography.number(.caption2, weight: .regular))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: start) {
                    VStack(spacing: 2) {
                        Text(blocker == nil ? "Start this" : "Start this")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        if let blocker {
                            Text(blocker)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.warning)
                        } else {
                            Text("Free to begin · costs evenings from here")
                                .font(.caption2)
                                .foregroundStyle(Theme.ink(on: Theme.accent).opacity(0.85))
                        }
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
            }
        }
    }
}
