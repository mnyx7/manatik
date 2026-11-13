// Renders an SVG (or any HTML) file to a PNG of an exact pixel size with WebKit.
// Usage: swift render.swift <input.svg> <output.png> <width> <height>
// Used instead of headless Chrome, which cannot start inside a sandboxed shell.
import AppKit
import WebKit

let args = CommandLine.arguments
guard args.count == 5, let pixelWidth = Int(args[3]), let pixelHeight = Int(args[4]) else {
    FileHandle.standardError.write("usage: render.swift in.svg out.png width height\n".data(using: .utf8)!)
    exit(2)
}
let input = URL(fileURLWithPath: args[1])
let outputURL = URL(fileURLWithPath: args[2])

final class Renderer: NSObject, WKNavigationDelegate {
    let view: WKWebView
    let width: Int
    let height: Int
    let output: URL
    init(width: Int, height: Int, output: URL) {
        self.width = width
        self.height = height
        self.output = output
        view = WKWebView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        super.init()
        view.navigationDelegate = self
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
        // Give embedded images a moment to decode.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.snapshot() }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: Error) {
        FileHandle.standardError.write("load failed: \(error)\n".data(using: .utf8)!)
        exit(1)
    }

    private func snapshot() {
        let config = WKSnapshotConfiguration()
        config.rect = view.bounds
        view.takeSnapshot(with: config) { [self] image, error in
            guard let image else {
                FileHandle.standardError.write("snapshot failed: \(String(describing: error))\n".data(using: .utf8)!)
                exit(1)
            }
            // Redraw at exactly width x height pixels, whatever the screen scale.
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
            )!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
            NSGraphicsContext.restoreGraphicsState()
            try! rep.representation(using: .png, properties: [:])!.write(to: output)
            exit(0)
        }
    }
}

let app = NSApplication.shared
let renderer = Renderer(width: pixelWidth, height: pixelHeight, output: outputURL)
renderer.view.loadFileURL(input, allowingReadAccessTo: URL(fileURLWithPath: "/"))
app.run()
