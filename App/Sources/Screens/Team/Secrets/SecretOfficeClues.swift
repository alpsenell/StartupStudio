import PixelKit
import SwiftUI
import TycoonEngine

/// The clues in the room (iteration 11, N5).
///
/// A running thread changes what the office looks like: two people at one
/// desk, a shredder that nobody ordered, the meeting-room door shut on a
/// Thursday. They are drawn as a strip of small pixel vignettes under the
/// office scene, one per prop the thread has actually dropped — a prop is
/// never shown for a clue the founder has not been given.
///
/// The sprites are composed from PixelKit's own desk and people where
/// there is one, and hand-drawn from the master palette's exact values
/// where there is not (the ramps are internal to PixelKit; the two new
/// props below use `ink`, `stone`, `sand` and `gold` steps copied
/// verbatim, so the strip belongs to the same world as the room above it).
/// Putting the props inside `OfficeSceneView` itself is a follow-up: that
/// file belongs to no lane this round.
struct SecretOfficeClueStrip: View {
    let props: [SecretOfficeProp]
    /// The founder's own look, so the two at one desk are people from this
    /// office rather than two strangers.
    let appearanceSeed: UInt64

    var body: some View {
        if !props.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Around the room")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .textCase(.uppercase)
                    .kerning(0.6)
                    .foregroundStyle(.secondary)
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    ForEach(props, id: \.rawValue) { prop in
                        VStack(spacing: 4) {
                            PixelSceneView(
                                placements: SecretCluePropArt.placements(
                                    prop, appearanceSeed: appearanceSeed
                                ),
                                sceneSize: SecretCluePropArt.sceneSize,
                                accessibilityLabel: prop.caption
                            )
                            .frame(width: 62, height: 54)
                            .background(Theme.pixelPaper)
                            .overlay {
                                PixelPanelBorder(thickness: 2, corner: 2)
                                    .fill(Theme.pixelInk)
                            }
                            Text(prop.caption)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

/// The art behind the strip: one vignette per prop, all on the same
/// baseline so the three read as one shelf.
enum SecretCluePropArt {
    static let sceneSize = (width: 30, height: 26)

    static func placements(_ prop: SecretOfficeProp, appearanceSeed: UInt64) -> [PlacedSprite] {
        switch prop {
        case .sharedDesk: sharedDesk(appearanceSeed)
        case .shredder: single(shredder(), x: 9)
        case .closedDoor: single(closedDoor(), x: 8)
        }
    }

    private static func single(_ sprite: PixelSprite, x: Int) -> [PlacedSprite] {
        [PlacedSprite(
            sprite: sprite,
            x: x,
            y: sceneSize.height - sprite.height - 1,
            kind: .prop,
            animation: .still,
            phase: 0
        )]
    }

    /// Two people, one chair's worth of desk between them.
    private static func sharedDesk(_ seed: UInt64) -> [PlacedSprite] {
        let left = SpriteLibrary.person(appearance: CharacterAppearance(seed: seed &+ 11))
        let right = SpriteLibrary.person(appearance: CharacterAppearance(seed: seed &+ 29))
        let desk = SpriteLibrary.desk()
        return [
            PlacedSprite(
                sprite: left, x: 1, y: 1, kind: .person, animation: .typing(slow: true), phase: 0
            ),
            PlacedSprite(
                sprite: right, x: 13, y: 1, kind: .person, animation: .typing(slow: true), phase: 3
            ),
            PlacedSprite(
                sprite: desk, x: 3, y: sceneSize.height - desk.height - 1,
                kind: .desk, animation: .still, phase: 0, zIndex: 10_000
            ),
        ]
    }

    // MARK: - Hand-drawn props

    /// A shredder by the printer, with a sheet on the way in.
    private static func shredder() -> PixelSprite {
        let grid = [
            "    PPPP    ",
            "    PPPP    ",
            "    PPPP    ",
            "  OOOOOOOO  ",
            "  OSSSSSSO  ",
            "  OSOOOOSO  ",
            "  OSSSSSSO  ",
            "  OOOOOOOO  ",
            "  OssssssO  ",
            "  OsPPPPsO  ",
            "  OsPsPsPO  ",
            "  OssssssO  ",
            "  OssssssO  ",
            "  OssssssO  ",
            "  OssssssO  ",
            "  OOOOOOOO  ",
        ]
        return PixelSprite(frames: [grid], palette: [
            "O": PixelSprite.RGBA(r: 32, g: 30, b: 42),
            "S": PixelSprite.RGBA(r: 118, g: 122, b: 138),
            "s": PixelSprite.RGBA(r: 78, g: 82, b: 98),
            "P": PixelSprite.RGBA(r: 238, g: 240, b: 244),
        ])
    }

    /// The meeting-room door, shut, with the light on behind the glass.
    private static func closedDoor() -> PixelSprite {
        let grid = [
            "OOOOOOOOOOOOOO",
            "ODDDDDDDDDDDDO",
            "ODdddddddddddO",
            "ODdGGGGGGGGddO",
            "ODdGGGGGGGGddO",
            "ODdGGGGGGGGddO",
            "ODdddddddddddO",
            "ODDDDDDDDDDDDO",
            "ODDDDDDDDDDDDO",
            "ODDDDDDDDDDHDO",
            "ODDDDDDDDDDDDO",
            "ODdddddddddddO",
            "ODDDDDDDDDDDDO",
            "ODDDDDDDDDDDDO",
            "ODdddddddddddO",
            "ODDDDDDDDDDDDO",
            "OOOOOOOOOOOOOO",
        ]
        return PixelSprite(frames: [grid], palette: [
            "O": PixelSprite.RGBA(r: 32, g: 30, b: 42),
            "D": PixelSprite.RGBA(r: 126, g: 90, b: 60),
            "d": PixelSprite.RGBA(r: 84, g: 58, b: 40),
            "G": PixelSprite.RGBA(r: 255, g: 217, b: 142),
            "H": PixelSprite.RGBA(r: 232, g: 180, b: 76),
        ])
    }
}
