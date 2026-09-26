import Foundation

extension SpriteLibrary {
    public static func hiResPortrait(
        appearance: CharacterAppearance,
        isFounder: Bool = false,
        role: RoleLook = .none
    ) -> PixelSprite {
        let founder = isFounder || role == .founder
        let key = "portraitHD.\(appearance.customSeed).\(founder).\(role.rawValue)"
        return SpriteCache.shared(key) {
            let open = PortraitPainter(appearance: appearance, isFounder: founder, role: role, blink: false).paint()
            let blink = PortraitPainter(appearance: appearance, isFounder: founder, role: role, blink: true).paint()
            return PixelSprite(frames: [open, blink], palette: PortraitPainter.palette(appearance, isFounder: founder))
        }
    }
}

struct PortraitPainter {
    static let size = 32

    let appearance: CharacterAppearance
    let isFounder: Bool
    let role: RoleLook
    let blink: Bool

    private var grid = Array(repeating: Array(repeating: Character(" "), count: size), count: size)
    private var faceMask = Array(repeating: Array(repeating: false, count: size), count: size)

    init(appearance: CharacterAppearance, isFounder: Bool, role: RoleLook, blink: Bool) {
        self.appearance = appearance
        self.isFounder = isFounder
        self.role = role
        self.blink = blink
    }

    private var hoodie: Bool { isFounder && appearance.wearsFounderHoodie }
    private var hairStyle: Int { appearance.hairStyle % PersonArt.hairOverlays.count }
    private var headwear: Int? {
        if role == .qa || role == .designer { return nil }
        return appearance.headwear.map { $0 % PersonArt.headwearOverlays.count }
    }
    private var hidesTopHair: Bool { headwear == 0 || headwear == 4 || role == .designer }

    func paint() -> [String] {
        var painter = self
        return painter.run()
    }

    private mutating func run() -> [String] {
        paintBackHair()
        paintBody()
        paintNeck()
        paintEars()
        paintFace()
        if appearance.freckles { paintFreckles() }
        if appearance.hasBeard { paintBeard() }
        paintNose()
        paintMouth()
        paintEyes()
        paintFrontHair()
        paintBrows()
        paintEarrings()
        paintNeckwear()
        paintGlasses()
        paintHeadwear()
        paintRole()
        outline()
        return grid.map { String($0) }
    }

    // MARK: - Grid helpers

    private func inside(_ x: Int, _ y: Int) -> Bool {
        x >= 0 && y >= 0 && x < Self.size && y < Self.size
    }

    private func at(_ x: Int, _ y: Int) -> Character {
        inside(x, y) ? grid[y][x] : " "
    }

    private mutating func set(_ x: Int, _ y: Int, _ c: Character) {
        guard inside(x, y) else { return }
        grid[y][x] = c
    }

    private mutating func rect(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ c: Character) {
        for y in y0...y1 { for x in x0...x1 { set(x, y, c) } }
    }

    private static func inEllipse(_ x: Int, _ y: Int, _ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double) -> Bool {
        let dx = (Double(x) + 0.5 - cx) / rx
        let dy = (Double(y) + 0.5 - cy) / ry
        return dx * dx + dy * dy <= 1
    }

    private mutating func ellipse(
        _ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, _ c: Character,
        where keep: (Int, Int) -> Bool = { _, _ in true }
    ) {
        for y in 0..<Self.size {
            for x in 0..<Self.size where Self.inEllipse(x, y, cx, cy, rx, ry) && keep(x, y) {
                set(x, y, c)
            }
        }
    }

    private mutating func stamp(_ rows: [String], x: Int, y: Int, mirror: Bool = false) {
        for (dy, row) in rows.enumerated() {
            let chars = Array(row)
            for (dx, c) in chars.enumerated() where c != " " {
                set(mirror ? x - dx : x + dx, y + dy, c)
            }
        }
    }

    private mutating func pair(_ rows: [String], leftX: Int, rightX: Int, y: Int) {
        stamp(rows, x: leftX, y: y)
        stamp(rows, x: rightX, y: y, mirror: true)
    }

    // MARK: - Body

    private var shirt: (base: Character, shade: Character) {
        hoodie ? ("D", "d") : ("T", "t")
    }

    private mutating func paintBody() {
        let (base, shade) = shirt
        for y in 25..<Self.size {
            let half = y == 25 ? 8 : (y == 26 ? 10 : 11)
            for x in (16 - half)..<(16 + half) {
                set(x, y, base)
            }
            set(16 - half, y, shade)
            set(16 + half - 1, y, shade)
        }
        for y in 28..<Self.size {
            set(9, y, shade)
            set(22, y, shade)
        }
        let outfit = appearance.outfit % PersonArt.outfitOverlays.count
        if hoodie || outfit == 0 {
            for x in 11...20 { set(x, 25, shade) }
            set(10, 26, shade); set(21, 26, shade)
            for x in 12...19 { set(x, 26, shade) }
            let string: Character = hoodie ? "Y" : "Q"
            for y in 27...30 { set(13, y, string); set(18, y, string) }
            set(13, 31, shade); set(18, 31, shade)
            return
        }
        switch outfit {
        case 1:
            stamp(["QQ", "QQQ", " QQ"], x: 12, y: 25)
            stamp(["QQ", "QQQ", " QQ"], x: 19, y: 25, mirror: true)
            for y in 28..<Self.size { set(16, y, shade) }
            set(15, 29, "Q"); set(15, 31, "Q")
        case 2:
            for y in 25..<Self.size {
                let half = y == 25 ? 8 : (y == 26 ? 10 : 11)
                for x in (16 - half)..<(16 + half) { set(x, y, "V") }
                set(16 - half, y, "v"); set(16 + half - 1, y, "v")
            }
            for y in 25..<Self.size {
                let spread = max(0, 3 - (y - 25) / 2)
                for x in (15 - spread)...(16 + spread) { set(x, y, base) }
            }
            stamp(["vv", " vv", "  v", "  v"], x: 11, y: 25)
            stamp(["vv", " vv", "  v", "  v"], x: 20, y: 25, mirror: true)
            set(14, 26, "Q"); set(17, 26, "Q")
            set(12, 30, "Y")
        case 3:
            rect(12, 21, 19, 26, base)
            for y in 21...26 { set(12, y, shade); set(19, y, shade) }
            for x in 13...18 { set(x, 22, shade); set(x, 24, shade) }
        default:
            for x in 13...18 { set(x, 25, shade) }
            set(12, 25, shade); set(19, 25, shade)
            for x in 14...17 { set(x, 25, "S") }
            set(9, 27, shade); set(22, 27, shade)
        }
    }

    private mutating func paintNeck() {
        let covered = !hoodie && appearance.outfit % PersonArt.outfitOverlays.count == 3
        if covered { return }
        rect(13, 21, 18, 24, "S")
        for x in 13...18 { set(x, 21, "s") }
        set(13, 22, "s"); set(18, 22, "s")
        set(13, 23, "s"); set(18, 23, "s")
        if !hoodie, appearance.outfit % PersonArt.outfitOverlays.count == 4 {
            for x in 14...17 { set(x, 25, "S") }
        }
    }

    // MARK: - Head

    private var faceBottom: Int {
        switch appearance.faceShape % CharacterAppearance.faceShapeCount {
        case 1: 22
        case 3: 23
        default: 22
        }
    }

    private func faceContains(_ x: Int, _ y: Int) -> Bool {
        switch appearance.faceShape % CharacterAppearance.faceShapeCount {
        case 1:
            return Self.inEllipse(x, y, 16, 14.2, 7.6, 7.9)
        case 2:
            guard x >= 9, x <= 22, y >= 6, y <= 21 else { return false }
            let corners: [(Int, Int)] = [(9, 6), (22, 6), (9, 21), (22, 21), (10, 6), (21, 6), (9, 7), (22, 7)]
            return !corners.contains { $0 == x && $1 == y }
        case 3:
            let cy = 13.6, ry = 9.0
            let t = max(0, (Double(y) + 0.5 - cy) / ry)
            return Self.inEllipse(x, y, 16, cy, 7.2 * (1 - 0.32 * t * t) + 0.01, ry)
        default:
            return Self.inEllipse(x, y, 16, 14, 7.0, 8.6)
        }
    }

    private mutating func paintEars() {
        for (x, inner) in [(8, 9), (23, 22)] {
            for y in 13...16 { set(x, y, "S") }
            set(inner, 14, "s"); set(inner, 15, "s")
        }
    }

    private mutating func paintFace() {
        for y in 0..<Self.size {
            for x in 0..<Self.size where faceContains(x, y) {
                faceMask[y][x] = true
                set(x, y, "S")
            }
        }
        for y in 0..<Self.size {
            for x in 0..<Self.size where faceMask[y][x] {
                let rightEdge = x + 1 >= Self.size || !faceMask[y][x + 1]
                let lowEdge = y + 1 >= Self.size || !faceMask[y + 1][x]
                if rightEdge || (lowEdge && x > 15) { set(x, y, "s") }
            }
        }
        for x in 13...18 where at(x, faceBottom + 1) == "S" || at(x, faceBottom + 1) == "s" {
            set(x, faceBottom + 1, "s")
        }
    }

    private mutating func paintFreckles() {
        for (x, y) in [(11, 17), (13, 17), (12, 18), (18, 17), (20, 17), (19, 18)] {
            set(x, y, "f")
        }
    }

    private mutating func paintNose() {
        switch appearance.noseStyle % CharacterAppearance.noseStyleCount {
        case 1:
            for y in 14...16 { set(16, y, "s") }
            stamp(["sss"], x: 15, y: 17)
        case 2:
            for y in 15...16 { set(16, y, "s") }
            stamp(["ssss"], x: 14, y: 17)
        case 3:
            for y in 14...16 { set(16, y, "s") }
            set(17, 17, "s")
            stamp(["ss"], x: 15, y: 18)
        default:
            set(16, 16, "s")
            stamp(["ss"], x: 15, y: 17)
        }
    }

    private mutating func paintMouth() {
        switch appearance.mouthStyle % CharacterAppearance.mouthStyleCount {
        case 1:
            stamp(["MMMM", " pp "], x: 14, y: 20)
        case 2:
            stamp(["MMMMMM", "MWWWWM", " MMMM "], x: 13, y: 19)
        case 3:
            stamp(["    M", " MMM ", "  p  "], x: 13, y: 19)
        default:
            stamp(["M    M", " MMMM ", "  pp  "], x: 13, y: 19)
        }
    }

    private mutating func paintEyes() {
        let shape = appearance.eyeShape % CharacterAppearance.eyeShapeCount
        if blink {
            let lid: [String] = shape == 3 ? ["", "KKKK"] : ["", "KKK"]
            pair(lid, leftX: 11, rightX: 20, y: 13)
            return
        }
        let eye: [String]
        switch shape {
        case 1: eye = [" KKK", "KWEe", " sss"]
        case 2: eye = ["", "KKKK", "WEe "]
        case 3: eye = ["KKKK", "WWEe", "WWEE"]
        default: eye = ["KKK", "WEe", "WEE"]
        }
        let width = eye.map(\.count).max() ?? 3
        let leftX = 14 - width
        stamp(eye, x: leftX, y: 13)
        let mirrored = eye.map { row -> String in
            String(row.padding(toLength: width, withPad: " ", startingAt: 0).reversed())
        }
        stamp(mirrored, x: 18, y: 13)
    }

    private mutating func paintBrows() {
        if headwear == 1 || headwear == 4 { return }
        let brow: [String]
        switch appearance.browStyle % CharacterAppearance.browStyleCount {
        case 1: brow = ["hhhh", "hhh "]
        case 2: brow = [" hh ", "h  h"]
        case 3: brow = ["hhh"]
        default: brow = [" hhh", "h   "]
        }
        let width = brow.map(\.count).max() ?? 3
        stamp(brow, x: 14 - width, y: 11)
        let mirrored = brow.map { String($0.padding(toLength: width, withPad: " ", startingAt: 0).reversed()) }
        stamp(mirrored, x: 18, y: 11)
    }

    // MARK: - Hair

    private mutating func hairEllipse(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, below maxY: Int = 31, _ c: Character = "H") {
        ellipse(cx, cy, rx, ry, c) { _, y in y <= maxY }
    }

    private mutating func paintBackHair() {
        switch hairStyle {
        case 2:
            for (cx, cy) in [(8.5, 12.0), (23.5, 12.0), (8.0, 17.0), (24.0, 17.0)] {
                hairEllipse(cx, cy, 3, 3.2)
            }
        case 3:
            if !hidesTopHair { hairEllipse(16, 3, 3.6, 3.0) }
        case 4:
            ellipse(16, 18, 10, 13, "H") { _, y in y >= 8 && y <= 28 }
            for y in 20...28 { set(6, y, "h"); set(25, y, "h") }
        case 8:
            hairEllipse(24.5, 15, 2.6, 6.5)
            hairEllipse(25, 21, 2.0, 3.5)
        case 9:
            hairEllipse(16, 11.5, 13, 11, below: 22)
        default:
            break
        }
    }

    private mutating func paintFrontHair() {
        if hairStyle == 5 {
            if !hidesTopHair { set(12, 7, "*"); set(13, 7, "*"); set(12, 8, "*") }
            return
        }
        let top: (Int, Int) -> Bool = { _, y in y <= 9 }
        switch hairStyle {
        case 0:
            ellipse(16, 11, 8.4, 7.2, "H", where: top)
            stamp(["HH", "H", "H"], x: 8, y: 10)
            stamp(["HH", "H", "H"], x: 23, y: 10, mirror: true)
            stamp(["HHHH", "HHH", " H"], x: 10, y: 9)
            stamp(["HHH", " HH"], x: 17, y: 9)
        case 1:
            ellipse(16, 11, 8.4, 7.0, "H", where: top)
            for (x, h) in [(9, 3), (12, 5), (15, 6), (18, 5), (21, 4)] {
                for dy in 0..<h {
                    set(x, 5 - dy, "H")
                    if dy < h - 1 { set(x + 1, 5 - dy, "H") }
                }
            }
        case 2:
            for (cx, cy) in [(10.0, 7.0), (13.5, 5.0), (17.5, 5.0), (21.0, 7.0), (9.0, 10.0), (23.0, 10.0), (16.0, 6.0)] {
                ellipse(cx, cy, 3.0, 3.0, "H")
            }
            stamp(["HHH  HH HHH"], x: 10, y: 9)
        case 3:
            ellipse(16, 11, 8.2, 6.8, "H", where: top)
            stamp(["HH", "H"], x: 8, y: 10)
            stamp(["HH", "H"], x: 23, y: 10, mirror: true)
        case 4:
            ellipse(16, 11, 8.6, 7.2, "H", where: top)
            stamp(["HHH", "HH", "H", "H", "H", "H"], x: 8, y: 10)
            stamp(["HHH", "HH", "H", "H", "H", "H"], x: 23, y: 10, mirror: true)
            stamp(["HHHHH", "HHH", "H"], x: 10, y: 9)
        case 6:
            ellipse(16, 11, 8.4, 7.2, "H", where: top)
            stamp(["HHHHHHHHHH", "  HHHHHHH", "     HHHH", "       HH"], x: 13, y: 8)
            stamp(["HH", "H", "H"], x: 8, y: 10)
            stamp(["HH", "H", "H"], x: 23, y: 10, mirror: true)
            set(12, 6, "h"); set(12, 7, "h"); set(12, 8, "h")
        case 7:
            shavedCap(maxY: 9)
            rect(14, 0, 17, 9, "H")
            set(13, 2, "H"); set(18, 2, "H"); set(13, 5, "H"); set(18, 5, "H")
        case 8:
            ellipse(16, 11, 8.3, 7.0, "H", where: top)
            stamp(["HHHHHH", "HHHH"], x: 10, y: 9)
            stamp(["HH", "H"], x: 8, y: 10)
            stamp(["H", "H"], x: 23, y: 10, mirror: true)
            set(23, 8, "Y")
        case 9:
            ellipse(16, 10, 9.5, 7.5, "H", where: top)
            stamp(["H", "H", "H", "H"], x: 8, y: 10)
            stamp(["H", "H", "H", "H"], x: 23, y: 10, mirror: true)
        case 10:
            shavedCap(maxY: 10)
        default:
            break
        }
        shadeHair()
    }

    private mutating func shavedCap(maxY: Int) {
        for y in 0...maxY {
            for x in 0..<Self.size where Self.inEllipse(x, y, 16, 11, 8.2, 7.0) {
                let rim = !Self.inEllipse(x, y - 1, 16, 11, 8.2, 7.0) || !Self.inEllipse(x - 1, y, 16, 11, 8.2, 7.0)
                    || !Self.inEllipse(x + 1, y, 16, 11, 8.2, 7.0)
                set(x, y, rim || (x + y) % 2 == 0 ? "h" : "S")
            }
        }
    }

    private mutating func shadeHair() {
        var shaded = grid
        for y in 0..<Self.size {
            for x in 0..<Self.size where grid[y][x] == "H" {
                let below = at(x, y + 1)
                let right = at(x + 1, y)
                if below != "H" && below != "h" && below != " " { shaded[y][x] = "h" }
                if right == " " && x > 16 { shaded[y][x] = "h" }
            }
        }
        grid = shaded
        for (x, y) in [(11, 5), (12, 4), (13, 4), (11, 6)] where grid[y][x] == "H" {
            grid[y][x] = "+"
        }
    }

    // MARK: - Beard

    private mutating func paintBeard() {
        switch appearance.beardStyle % CharacterAppearance.beardStyleCount {
        case 1:
            stamp(["HHHHHH", "h    h"], x: 13, y: 18)
        case 2:
            stamp(["HHHHHH", "H    H", "H    H", "HhhhhH", " HHHH ", "  hh  "], x: 13, y: 18)
        case 3:
            for y in 16...(faceBottom + 1) {
                for x in 0..<Self.size where faceMask[y][x] && (y >= 19 || x <= 10 || x >= 21) && (x + y) % 2 == 0 {
                    set(x, y, "h")
                }
            }
        default:
            for y in 14...(faceBottom + 2) {
                for x in 0..<Self.size where faceMask[min(y, faceBottom)][x] {
                    let side = x <= 9 || x >= 22
                    if y >= 18 || (side && y >= 14) {
                        set(x, y, "H")
                    }
                }
            }
            for x in 13...18 { set(x, faceBottom + 2, "h") }
            set(12, faceBottom + 1, "h"); set(19, faceBottom + 1, "h")
        }
    }

    // MARK: - Accessories

    private mutating func paintEarrings() {
        guard let style = appearance.earrings else { return }
        if hairStyle == 4 || hairStyle == 9 { return }
        if style % CharacterAppearance.earringStyleCount == 0 {
            set(8, 17, "Y"); set(23, 17, "Y")
        } else {
            for (x, y) in [(8, 17), (7, 18), (9, 18), (8, 19), (23, 17), (22, 18), (24, 18), (23, 19)] {
                set(x, y, "Y")
            }
        }
    }

    private mutating func paintNeckwear() {
        guard let style = appearance.neckwear else { return }
        switch style % CharacterAppearance.neckwearStyleCount {
        case 0:
            rect(11, 23, 20, 26, "R")
            for x in 11...20 { set(x, 24, "r") }
            rect(17, 27, 19, 31, "R")
            set(19, 27, "r"); set(19, 29, "r"); set(17, 31, "r")
        case 1:
            stamp(["Y      Y", " Y    Y", "  YYYY", "   RR"], x: 12, y: 24)
        default:
            stamp(["RR RR", "RRrRR", "RR RR"], x: 13, y: 24)
        }
    }

    private mutating func paintGlasses() {
        guard let style = appearance.glasses else { return }
        let eyeWidth = appearance.eyeShape % CharacterAppearance.eyeShapeCount == 0 ? 3 : 4
        let left = 14 - eyeWidth - 1
        let right = 18
        let width = eyeWidth + 2
        switch style % PersonArt.glassesOverlays.count {
        case 1:
            for lx in [left, right - 1] {
                rect(lx, 12, lx + width - 1, 12, "N")
                rect(lx, 16, lx + width - 1, 16, "N")
                for y in 13...15 { set(lx, y, "N"); set(lx + width - 1, y, "N") }
            }
            set(14, 13, "N"); set(15, 13, "N"); set(16, 13, "N"); set(17, 13, "N")
        case 2:
            for lx in [left, right - 1] {
                stamp([" NNNN", "N    N", "N    N", " NNNN"].map { String($0.prefix(width)) }, x: lx, y: 12)
                set(lx + width - 1, 13, "N"); set(lx + width - 1, 14, "N")
            }
            set(15, 14, "N"); set(16, 14, "N")
        case 3:
            for lx in [left, right - 1] {
                rect(lx, 13, lx + width - 1, 15, "N")
                set(lx + 1, 13, "n")
            }
            rect(14, 13, 17, 13, "N")
            set(left - 1, 13, "N"); set(right + width - 1, 13, "N")
        default:
            for lx in [left, right - 1] {
                set(lx, 13, "N"); set(lx, 14, "N"); set(lx, 15, "N")
                set(lx + width - 1, 13, "N"); set(lx + width - 1, 14, "N"); set(lx + width - 1, 15, "N")
                for x in (lx + 1)..<(lx + width - 1) { set(x, 16, "N") }
            }
            set(15, 13, "N"); set(16, 13, "N")
        }
    }

    private mutating func paintHeadwear() {
        guard let style = headwear else { return }
        switch style {
        case 0:
            ellipse(16, 10, 9, 8, "A") { _, y in y <= 9 }
            rect(7, 8, 24, 10, "a")
            for x in stride(from: 8, through: 24, by: 2) { set(x, 9, "A") }
            ellipse(16, 1.6, 2, 1.6, "A")
        case 1:
            ellipse(16, 10, 8.8, 7.2, "J") { _, y in y <= 9 }
            rect(6, 9, 24, 10, "j")
            set(16, 4, "Q"); set(15, 5, "Q"); set(16, 5, "Q"); set(17, 5, "Q")
            for x in 7...24 { set(x, 11, "O") }
        case 2:
            rect(8, 8, 23, 9, "L")
            set(23, 10, "l"); set(24, 10, "l"); set(24, 11, "l")
            for x in 8...23 where x % 3 == 0 { set(x, 9, "l") }
        case 3:
            band("N")
            rect(5, 11, 8, 18, "N")
            rect(23, 11, 26, 18, "N")
            rect(6, 12, 7, 17, "R")
            rect(24, 12, 25, 17, "R")
        case 4:
            ellipse(16, 8, 7.4, 6, "X") { _, y in y <= 8 }
            rect(4, 9, 27, 10, "x")
            rect(9, 7, 22, 7, "x")
        default:
            break
        }
    }

    private mutating func band(_ c: Character) {
        for y in 0..<Self.size {
            for x in 0..<Self.size where Self.inEllipse(x, y, 16, 11, 9.4, 9.6)
                && !Self.inEllipse(x, y, 16, 11, 8.0, 8.2) && y <= 11 {
                set(x, y, c)
            }
        }
    }

    private mutating func paintRole() {
        switch role {
        case .qa:
            band("N")
            rect(5, 12, 8, 18, "N")
            rect(23, 12, 26, 18, "N")
            stamp(["N", "N", " N", "  NNNR"], x: 7, y: 19)
        case .designer:
            ellipse(15, 6, 10, 3.6, "R") { _, y in y <= 8 }
            rect(7, 8, 23, 8, "r")
            set(15, 1, "r"); set(15, 2, "r")
        case .lawyer:
            if hoodie { return }
            stamp(["RR", "RR", "rr", "RR", "RR", "rr", "RR"], x: 15, y: 25)
        case .hr:
            stamp(["G      G", " G    G", "  G  G", "   GG", "  QQQQ", "  QNNQ", "  QQQQ"], x: 12, y: 24)
        default:
            break
        }
    }

    // MARK: - Outline

    private mutating func outline() {
        var outlined = grid
        let transparent: Set<Character> = [" "]
        for y in 0..<Self.size {
            for x in 0..<Self.size where grid[y][x] == " " {
                let neighbours = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
                if neighbours.contains(where: { inside($0.0, $0.1) && !transparent.contains(grid[$0.1][$0.0]) }) {
                    outlined[y][x] = "O"
                }
            }
        }
        grid = outlined
    }

    // MARK: - Palette

    static func palette(_ appearance: CharacterAppearance, isFounder: Bool) -> [Character: PixelSprite.RGBA] {
        var palette = SpriteLibrary.personPalette(appearance, isFounder: isFounder && appearance.wearsFounderHoodie)
        let hair = Palettes.hairColors[appearance.hairColor % Palettes.hairColors.count]
        let skin = Palettes.skinTones[appearance.skinTone % Palettes.skinTones.count]
        palette["K"] = Palettes.outline
        palette["W"] = Palettes.stone[0]
        palette["e"] = Palettes.outline
        palette["M"] = Palettes.mouth(forSkin: appearance.skinTone)
        palette["p"] = skin.shade
        palette["+"] = Palettes.hairHighlight(forHair: appearance.hairColor)
        palette["*"] = Palettes.skinHighlight(forSkin: appearance.skinTone)
        palette["h"] = hair.shade
        palette["H"] = hair.base
        palette["s"] = skin.shade
        palette["S"] = skin.base
        return palette
    }
}
