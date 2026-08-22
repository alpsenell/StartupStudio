import CoreGraphics
import Foundation
@testable import PixelKit

/// Renders a CGImage into a plain RGBA8 (premultiplied-last, sRGB) byte buffer.
/// Row 0 of the result is the TOP row of the image.
func rgbaBytes(of image: CGImage) -> [UInt8] {
    let width = image.width
    let height = image.height
    var data = [UInt8](repeating: 0, count: width * height * 4)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    data.withUnsafeMutableBytes { buffer in
        let context = CGContext(
            data: buffer.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.interpolationQuality = .none
        context.setAllowsAntialiasing(false)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    return data
}

/// RGBA of the pixel at (x, y) with (0, 0) at the top-left.
func pixel(_ bytes: [UInt8], width: Int, x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
    let i = (y * width + x) * 4
    return (bytes[i], bytes[i + 1], bytes[i + 2], bytes[i + 3])
}
