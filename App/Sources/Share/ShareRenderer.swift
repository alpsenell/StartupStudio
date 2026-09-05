import CoreGraphics

// MARK: Iteration 7 — share cards (R4)

/// The three cards (biography, front page, office photo) are laid out at
/// `cardSize` points and rendered at `scale` for a 1080×1350 image.
enum ShareRenderer {
    static let cardSize = CGSize(width: 540, height: 675)
    static let scale: CGFloat = 2
}
