import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
let size = 1024
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(red: 23/255, green: 28/255, blue: 36/255, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: size, height: size))
let amber = CGColor(red: 1, green: 170/255, blue: 82/255, alpha: 1)
context.setFillColor(amber); context.setStrokeColor(amber)
context.fillEllipse(in: CGRect(x: 292, y: 364, width: 440, height: 440))
func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ width: CGFloat) {
    context.setLineWidth(width); context.setLineCap(.round)
    context.move(to: CGPoint(x: x1, y: 1024-y1)); context.addLine(to: CGPoint(x: x2, y: 1024-y2)); context.strokePath()
}
line(248,696,776,696,48); line(310,794,714,794,48)
line(512,112,512,148,36); line(198,300,230,320,36); line(794,320,826,300,36)
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Icon rendering failed") }
