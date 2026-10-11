// Renders Resources/icon.svg into Resources/AppIcon.iconset PNGs. Usage: swift scripts/render-icon.swift <svg> <iconset dir>
import AppKit

let args = CommandLine.arguments
guard args.count == 3, let image = NSImage(contentsOfFile: args[1]) else {
    FileHandle.standardError.write(Data("cannot load svg\n".utf8)); exit(1)
}
try? FileManager.default.createDirectory(atPath: args[2], withIntermediateDirectories: true)
let sizes: [(Int, String)] = [(16, "16x16"), (32, "16x16@2x"), (32, "32x32"), (64, "32x32@2x"),
    (128, "128x128"), (256, "128x128@2x"), (256, "256x256"), (512, "256x256@2x"),
    (512, "512x512"), (1024, "512x512@2x")]
for (px, name) in sizes {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(args[2])/icon_\(name).png"))
}
