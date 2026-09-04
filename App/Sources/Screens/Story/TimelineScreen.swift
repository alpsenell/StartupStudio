import PixelKit
import SwiftUI
import TycoonEngine

/// The run as a line: a baseline with year and quarter ticks, products as
/// box art at their launch day, hires as portraits at their hire day,
/// chapters as flags, and the world's blows — the crash, the round, the
/// incumbent, the challenge held or lost, the buyout — where they landed.
///
/// Pushed from HQ's chapter card and the `.timeline` route. The strip is
/// `TimelineStrip`, a pure function of the markers and a zoom, so the
/// snapshot suite renders it without the scroll view.
struct TimelineScreen: View {
    let engine: GameEngine

    @State private var zoom: TimelineZoom?
    @State private var selectedID: String?

    private var markers: [TimelineMarker] {
        TimelineBuilder.markers(state: engine.state, content: engine.content, balance: engine.balance)
    }

    /// A young run opens on the quarter, a long one on the year.
    private var resolvedZoom: TimelineZoom {
        zoom ?? (engine.state.day < 91 ? .quarter : .year)
    }

    private func selected(in markers: [TimelineMarker]) -> TimelineMarker? {
        markers.first { $0.id == selectedID }
    }

    var body: some View {
        let markers = markers
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Picker("Zoom", selection: zoomSelection) {
                    ForEach(TimelineZoom.allCases) { zoom in
                        Text(zoom.label).tag(zoom)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Timeline zoom")

                PixelPanel(contentPadding: 0) {
                    GeometryReader { geometry in
                        strip(markers: markers, viewportWidth: geometry.size.width)
                    }
                    .frame(height: TimelineStrip.height)
                }

                detail(markers: markers)
                legend
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.screenBackground)
        .navigationTitle("Timeline")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var zoomSelection: Binding<TimelineZoom> {
        Binding(
            get: { resolvedZoom },
            set: { next in
                Haptics.tap()
                withAnimation(Theme.Motion.selection) { zoom = next }
            }
        )
    }

    private func strip(markers: [TimelineMarker], viewportWidth: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                TimelineStrip(
                    markers: markers,
                    today: engine.state.day,
                    zoom: resolvedZoom,
                    viewportWidth: viewportWidth,
                    selectedID: $selectedID
                )
            }
            .onAppear { proxy.scrollTo(TimelineStrip.todayID, anchor: .trailing) }
            .onChange(of: resolvedZoom) { _, _ in
                withAnimation(Theme.Motion.selection) {
                    proxy.scrollTo(TimelineStrip.todayID, anchor: .trailing)
                }
            }
        }
    }

    /// What the tapped marker was, or how to read the line.
    @ViewBuilder
    private func detail(markers: [TimelineMarker]) -> some View {
        if let selected = selected(in: markers) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                TimelineMarkerArt(kind: selected.kind, size: 40)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    PixelText(text: selected.title, scale: 2, color: Theme.pixelInk)
                    Text(selected.detail)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(GameCalendar(day: selected.day).longLabel) · Day \(selected.day)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .cardStyle()
            .transition(Theme.Motion.transition(.move(edge: .bottom).combined(with: .opacity)))
            .accessibilityElement(children: .combine)
        } else {
            Text(
                markers.count > 1
                    ? "Tap anything on the line to read it. \(markers.count - 1) moment\(markers.count == 2 ? "" : "s") so far."
                    : "The line fills in as the company does: every launch, every hire, every chapter."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var legend: some View {
        HStack(spacing: Theme.Spacing.lg) {
            LegendItem(systemImage: "shippingbox.fill", label: "Products")
            LegendItem(systemImage: "person.fill", label: "Hires")
            LegendItem(systemImage: "flag.fill", label: "Chapters")
            LegendItem(systemImage: "bolt.fill", label: "The world")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct LegendItem: View {
    let systemImage: String
    let label: String

    var body: some View {
        Label(label, systemImage: systemImage)
            .labelStyle(.titleAndIcon)
    }
}

// MARK: - The strip

/// The scrollable line itself: ticks, the baseline, the markers on their
/// stems, and today's mark. Its width is the run at the zoom's scale.
struct TimelineStrip: View {
    let markers: [TimelineMarker]
    let today: Int
    let zoom: TimelineZoom
    /// How wide the viewport is: one zoom step spans exactly this.
    let viewportWidth: CGFloat
    @Binding var selectedID: String?

    /// Fixed so the screen can frame it; the lanes are laid out inside it.
    static let height: CGFloat = 324
    static let todayID = "today"

    /// Room at either end for a label centred on day 0 and on today.
    private static let inset: CGFloat = 40
    private static let baselineY: CGFloat = 166
    /// Three levels above and three below, so neighbours a week apart do
    /// not cover each other.
    private static let levels: [CGFloat] = [46, 86, 126]
    private static let artSize: CGFloat = 28

    /// Days after today the line keeps running, so today's mark is not
    /// flush with the edge.
    private static let headroom = 7

    private var spanDays: Int { max(today, 1) + Self.headroom }
    private var pointsPerDay: CGFloat {
        max(0.1, (viewportWidth - Self.inset * 2) / CGFloat(zoom.daysAcross(spanDays: spanDays)))
    }
    private var contentWidth: CGFloat {
        max(viewportWidth, x(forDay: spanDays) + Self.inset)
    }

    private func x(forDay day: Int) -> CGFloat {
        Self.inset + CGFloat(day) * pointsPerDay
    }

    /// A marker and the height of its art: products, chapters and the
    /// ending above the line, people and the world's blows below it, each
    /// side alternating between two levels so a run of hires reads as a
    /// row of faces rather than one face.
    private struct Placed: Identifiable {
        let marker: TimelineMarker
        let y: CGFloat
        var id: String { marker.id }
    }

    private var placed: [Placed] {
        var above = 0
        var below = 0
        return markers.map { marker in
            if marker.kind.isAboveBaseline {
                defer { above += 1 }
                return Placed(marker: marker, y: Self.baselineY - Self.levels[above % Self.levels.count])
            } else {
                defer { below += 1 }
                return Placed(marker: marker, y: Self.baselineY + Self.levels[below % Self.levels.count])
            }
        }
    }

    var body: some View {
        let placed = placed
        ZStack(alignment: .topLeading) {
            line(placed: placed)
            tickLabels
            todayMark
            ForEach(placed) { item in
                TimelineMarkerView(
                    marker: item.marker,
                    isSelected: item.marker.id == selectedID,
                    artSize: Self.artSize
                ) {
                    Haptics.tap()
                    withAnimation(Theme.Motion.selection) {
                        selectedID = selectedID == item.marker.id ? nil : item.marker.id
                    }
                }
                .position(x: x(forDay: item.marker.day), y: item.y)
            }
        }
        .frame(width: contentWidth, height: Self.height)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Company timeline, \(markers.count) moments over \(today) days")
    }

    // MARK: The line

    /// The baseline, its ticks and every marker's stem, in one canvas.
    private func line(placed: [Placed]) -> some View {
        Canvas(rendersAsynchronously: false) { context, _ in
            let ink = Theme.pixelInk
            let span = spanDays

            // The baseline, out to the headroom.
            context.fill(
                Path(CGRect(
                    x: Self.inset, y: Self.baselineY - 1,
                    width: CGFloat(span) * pointsPerDay, height: 2
                )),
                with: .color(ink)
            )

            // Weeks at quarter zoom: a faint comb.
            if zoom == .quarter {
                var day = 0
                while day <= span {
                    context.fill(
                        Path(CGRect(x: x(forDay: day), y: Self.baselineY - 3, width: 1, height: 6)),
                        with: .color(ink.opacity(0.25))
                    )
                    day += 7
                }
            }

            // Quarters: a short tick; years: a tall one.
            var day = 0
            while day <= span {
                let isYear = day % 364 == 0
                let height: CGFloat = isYear ? 22 : 12
                context.fill(
                    Path(CGRect(x: x(forDay: day) - 1, y: Self.baselineY - height / 2, width: 2, height: height)),
                    with: .color(ink.opacity(isYear ? 1 : 0.6))
                )
                day += 91
            }

            // Stems, from the line to each marker's art.
            for item in placed {
                let top = min(item.y, Self.baselineY)
                let bottom = max(item.y, Self.baselineY)
                context.fill(
                    Path(CGRect(x: x(forDay: item.marker.day) - 0.5, y: top, width: 1, height: bottom - top)),
                    with: .color(ink.opacity(item.marker.id == selectedID ? 1 : 0.45))
                )
            }
        }
        .frame(width: contentWidth, height: Self.height)
        .accessibilityHidden(true)
    }

    /// "Y1" at every year, "Q2" at every quarter the zoom has room for.
    private var tickLabels: some View {
        let span = spanDays
        let labelQuarters = zoom != .run || span <= 364 * 2
        return ForEach(Array(stride(from: 0, through: span, by: 91)), id: \.self) { day in
            let isYear = day % 364 == 0
            if isYear || labelQuarters {
                let calendar = GameCalendar(day: day)
                let label = isYear ? "Y\(calendar.year)" : "Q\(calendar.quarter)"
                PixelText(text: label, scale: 2, color: isYear ? Theme.pixelInk : Theme.pixelInk.opacity(0.6))
                    .position(x: x(forDay: day) + 4 + CGFloat(PixelFont.width(of: label)), y: Self.baselineY + 20)
                    .accessibilityHidden(true)
            }
        }
    }

    private var todayMark: some View {
        VStack(spacing: 2) {
            PixelText(text: "Today", scale: 2, color: Theme.pixelAccent)
            Rectangle()
                .fill(Theme.pixelAccent)
                .frame(width: 2, height: Self.height - 60)
        }
        .position(x: x(forDay: today), y: Self.height / 2 + 2)
        .id(Self.todayID)
        .accessibilityLabel("Today, day \(today)")
    }
}

// MARK: - One marker

/// The art for a marker and its label, as a button.
private struct TimelineMarkerView: View {
    let marker: TimelineMarker
    let isSelected: Bool
    let artSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                if !marker.kind.isAboveBaseline {
                    TimelineMarkerArt(kind: marker.kind, size: artSize)
                }
                Text(marker.title)
                    .font(.caption2.weight(isSelected ? .bold : .regular))
                    .lineLimit(1)
                    .foregroundStyle(Theme.pixelInk)
                    .frame(width: 72)
                if marker.kind.isAboveBaseline {
                    TimelineMarkerArt(kind: marker.kind, size: artSize)
                }
            }
            .padding(2)
            .background(
                isSelected ? Theme.pixelAccent.opacity(0.18) : Color.clear,
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(marker.title), day \(marker.day)")
        .accessibilityHint(marker.detail)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// What a marker looks like: box art, a portrait, a flag or an icon tile.
struct TimelineMarkerArt: View {
    let kind: TimelineMarker.Kind
    var size: CGFloat = 28

    var body: some View {
        switch kind {
        case .founding(let seed):
            PixelPortrait(seed: seed, isFounder: true, role: .founder, size: size)
        case .product(let typeID, let topicID, let seed):
            ProductBoxArtView(typeID: typeID, topicID: topicID, seed: seed, size: size)
                .overlay {
                    PixelPanelBorder(thickness: 1, corner: 1)
                        .fill(Theme.pixelInk.opacity(0.5))
                }
        case .hire(let seed, let role):
            PixelPortrait(seed: seed, role: role, size: size)
        case .chapter(let number):
            ChapterFlag(number: number, size: size)
        case .crash:
            PixelIconTile(systemImage: "chart.line.downtrend.xyaxis", tint: Theme.negativeCash, size: size)
        case .round:
            PixelIconTile(systemImage: "banknote.fill", tint: Theme.positiveCash, size: size)
        case .incumbent:
            PixelIconTile(systemImage: "building.columns.fill", tint: Theme.warning, size: size)
        case .challengeHeld:
            PixelIconTile(systemImage: "checkmark.shield.fill", tint: Theme.positiveCash, size: size)
        case .challengeLost:
            PixelIconTile(systemImage: "xmark.shield.fill", tint: Theme.negativeCash, size: size)
        case .buyout:
            PixelIconTile(systemImage: "crown.fill", tint: Theme.pixelAccent, size: size)
        case .ending(let ending):
            PixelIconTile(
                systemImage: ending.isSuccess ? "flag.checkered" : "xmark.octagon.fill",
                tint: ending.isSuccess ? Theme.positiveCash : Theme.negativeCash,
                size: size
            )
        }
    }
}

/// A pixel flag on a pole with the chapter number on it.
struct ChapterFlag: View {
    let number: Int
    var size: CGFloat = 28

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, canvasSize in
            let unit = max(1, (canvasSize.width / 14).rounded(.down))
            let ink = Theme.pixelInk
            let cloth = Theme.pixelAccent
            // The pole.
            context.fill(
                Path(CGRect(x: unit, y: 0, width: unit, height: canvasSize.height)),
                with: .color(ink)
            )
            // The flag: a rectangle with a notched fly, two rows of "wind".
            let flag = CGRect(x: unit * 2, y: unit, width: unit * 11, height: unit * 8)
            context.fill(Path(flag), with: .color(cloth))
            context.fill(
                Path(CGRect(x: flag.maxX - unit * 2, y: flag.midY - unit, width: unit * 2, height: unit * 2)),
                with: .color(Theme.pixelPaper)
            )
            context.fill(
                Path(CGRect(x: flag.minX, y: flag.minY, width: flag.width, height: unit)),
                with: .color(ink.opacity(0.35))
            )
            context.fill(
                Path(CGRect(x: flag.minX, y: flag.maxY - unit, width: flag.width, height: unit)),
                with: .color(ink.opacity(0.35))
            )
            // The number, in the bitmap face, on the cloth.
            let label = "\(number)"
            let scale = unit
            let width = CGFloat(PixelFont.width(of: label)) * scale
            let originX = flag.minX + (flag.width - unit * 2 - width) / 2
            let originY = flag.minY + (flag.height - CGFloat(PixelFont.glyphHeight) * scale) / 2
            for run in PixelFont.pixelRuns(of: label) {
                context.fill(
                    Path(CGRect(
                        x: originX + CGFloat(run.x) * scale,
                        y: originY + CGFloat(run.y) * scale,
                        width: CGFloat(run.width) * scale,
                        height: scale
                    )),
                    with: .color(Theme.ink(on: cloth))
                )
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Chapter \(number) flag")
    }
}
